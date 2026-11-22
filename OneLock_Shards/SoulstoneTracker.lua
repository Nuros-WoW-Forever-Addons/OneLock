-- ============================================================================
-- OneLock_Shards - SoulstoneTracker
-- 30-minute persistent Soulstone tracking HUD with alive/dead status detection,
-- movable edit-mode anchor, simulated test mode, and proc alert banners
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local SoulstoneTracker = {}
ns.SoulstoneTracker = SoulstoneTracker

local SOULSTONE_DURATION = 1800 -- 30 minutes in seconds
local currentSoulstone = nil
local isTestMode = false

-- Soulstone spell IDs
local SOULSTONE_SPELLS = {
    [20707] = "Minor Soulstone",
    [20762] = "Lesser Soulstone",
    [20763] = "Soulstone",
    [20764] = "Greater Soulstone",
    [20765] = "Major Soulstone",
    [27239] = "Master Soulstone",
}

-------------------------------------------------------------------------------
-- Helper: Secret Value Guard & Time Formatter
-------------------------------------------------------------------------------
local function IsSecret(val)
    return issecretvalue and issecretvalue(val)
end

local function FormatTime(seconds)
    if not seconds or seconds < 0 then
        return "0.0s"
    elseif seconds >= 60 then
        return string.format("%dm %02ds", math.floor(seconds / 60), math.floor(seconds % 60))
    else
        return string.format("%.1fs", seconds)
    end
end

-------------------------------------------------------------------------------
-- Proc Alert Banner Integration
-------------------------------------------------------------------------------
local function TriggerProcAlert(titleText, subText, iconPath, borderColor, fallbackSoundId)
    if not (ns.db and ns.db.enableSoulstoneAlerts ~= false) then return end

    if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.ShowAlert then
        _G.OneLock_Procs.Alerts:ShowAlert(titleText, subText, iconPath, borderColor, fallbackSoundId)
    elseif RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, titleText .. " - " .. subText, ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.5, b = 0 })
        if fallbackSoundId and fallbackSoundId > 0 then
            pcall(PlaySound, fallbackSoundId)
        end
    end
end

-------------------------------------------------------------------------------
-- Group Announcement Router (Raid Warning / Raid / Party / Solo)
-------------------------------------------------------------------------------
local function SendGroupAnnouncement(plainMsg, colorMsg, isTest)
    if colorMsg then
        ns:Print(colorMsg)
    else
        ns:Print(plainMsg)
    end

    if isTest then
        return
    end

    if not (ns.db and ns.db.announceSoulstone ~= false) then
        return
    end

    -- 1. Check Raid status first (party is a subset of raid)
    local inRaid = (IsInRaid and IsInRaid())
    local inGroup = (IsInGroup and IsInGroup())

    if inRaid then
        -- 2. Check Raid Alert permission first (not all characters can send raid alerts)
        local canRaidAlert = false
        if UnitIsGroupLeader and UnitIsGroupLeader("player") then
            canRaidAlert = true
        elseif UnitIsGroupAssistant and UnitIsGroupAssistant("player") then
            canRaidAlert = true
        elseif IsRaidLeader and IsRaidLeader() then
            canRaidAlert = true
        elseif IsRaidOfficer and IsRaidOfficer() then
            canRaidAlert = true
        end

        if canRaidAlert then
            local ok = pcall(SendChatMessage, plainMsg, "RAID_WARNING")
            if not ok then
                pcall(SendChatMessage, plainMsg, "RAID")
            end
        else
            pcall(SendChatMessage, plainMsg, "RAID")
        end
    elseif inGroup then
        pcall(SendChatMessage, plainMsg, "PARTY")
    end
end

-------------------------------------------------------------------------------
-- Target Alive / Dead Status Check
-------------------------------------------------------------------------------
local function CheckTargetStatus(targetName, targetGUID)
    if not targetName or IsSecret(targetName) then return "UNKNOWN" end

    local function MatchesTarget(unit)
        if not unit then return false end
        if targetGUID then
            local uGuid = UnitGUID(unit)
            if uGuid and not IsSecret(uGuid) and uGuid == targetGUID then
                return true
            end
        end
        local uName = UnitName(unit)
        if uName and not IsSecret(uName) then
            if uName == targetName then return true end
            local shortName = uName:match("^([^-]+)")
            if shortName and shortName == targetName then return true end
            local shortTarget = targetName:match("^([^-]+)")
            if shortTarget and shortTarget == uName then return true end
        end
        return false
    end

    local function EvaluateUnitStatus(unit)
        if UnitIsConnected and not UnitIsConnected(unit) then
            return "OFFLINE"
        end
        local isDead = UnitIsDeadOrGhost(unit)
        if IsSecret(isDead) then
            return "UNKNOWN"
        end
        return isDead and "DEAD" or "ALIVE"
    end

    -- Check party/raid units
    if IsInRaid and IsInRaid() then
        local num = (GetNumGroupMembers and GetNumGroupMembers()) or 0
        for i = 1, num do
            local unit = "raid" .. i
            if MatchesTarget(unit) then
                return EvaluateUnitStatus(unit)
            end
        end
    elseif IsInGroup and IsInGroup() then
        local num = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0
        for i = 1, num do
            local unit = "party" .. i
            if MatchesTarget(unit) then
                return EvaluateUnitStatus(unit)
            end
        end
    end

    if MatchesTarget("target") then
        return EvaluateUnitStatus("target")
    end

    if MatchesTarget("focus") then
        return EvaluateUnitStatus("focus")
    end

    if MatchesTarget("player") then
        return EvaluateUnitStatus("player")
    end

    return "ACTIVE"
end

-------------------------------------------------------------------------------
-- UI Display Frame & Movable Purple Shadow Box Anchor
-------------------------------------------------------------------------------
local function CreateSoulstoneHUD()
    local db = ns.db or {}
    local anchor = CreateFrame("Frame", "OneLockSoulstoneAnchor", UIParent)
    anchor:SetSize(db.soulstoneWidth or 180, 22)
    anchor:SetScale(db.soulstoneScale or 1.0)
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)

    local pos = db.position or db.soulstoneAnchor or { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 250, y = 200 }
    anchor:ClearAllPoints()
    anchor:SetPoint(pos.point or "BOTTOMLEFT", UIParent, pos.relativePoint or "BOTTOMLEFT", pos.x or 250, pos.y or 200)

    -- Edit Mode Translucent Purple Shadow Box
    local shadowBox = CreateFrame("Frame", "OneLockSoulstoneShadowBox", anchor, "BackdropTemplate")
    shadowBox:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    shadowBox:SetSize(db.soulstoneWidth or 180, 26)
    shadowBox:SetFrameStrata("HIGH")

    shadowBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    shadowBox:SetBackdropColor(0.20, 0.08, 0.35, 0.65)
    shadowBox:SetBackdropBorderColor(0.75, 0.35, 1.00, 0.95)

    local shadowIcon = shadowBox:CreateTexture(nil, "ARTWORK")
    shadowIcon:SetSize(18, 18)
    shadowIcon:SetPoint("LEFT", shadowBox, "LEFT", 4, 0)
    shadowIcon:SetTexture("Interface\\Icons\\Spell_Shadow_SoulGem")
    shadowIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local shadowTitle = shadowBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shadowTitle:SetPoint("LEFT", shadowIcon, "RIGHT", 6, 0)
    shadowTitle:SetText("|cffdd99ffSoulstone (Drag to Move)|r")

    shadowBox:EnableMouse(true)
    shadowBox:RegisterForDrag("LeftButton")

    shadowBox:SetScript("OnDragStart", function(self)
        anchor:StartMoving()
    end)

    shadowBox:SetScript("OnDragStop", function(self)
        anchor:StopMovingOrSizing()
        local point, _, relPoint, x, y = anchor:GetPoint()
        if ns.db then
            if not ns.db.position then ns.db.position = {} end
            ns.db.position.point = point
            ns.db.position.relativePoint = relPoint
            ns.db.position.x = x
            ns.db.position.y = y
        end
    end)

    anchor.shadowBox = shadowBox

    -- Active Soulstone Bar HUD Frame
    local hud = CreateFrame("Frame", "OneLockSoulstoneFrame", anchor, "BackdropTemplate")
    hud:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    hud:SetSize(db.soulstoneWidth or 180, 22)
    hud:SetClampedToScreen(true)

    hud:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    hud:SetBackdropColor(0.08, 0.08, 0.12, 0.85)
    hud:SetBackdropBorderColor(0.5, 0.2, 0.7, 0.8)

    local icon = hud:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", hud, "LEFT", 2, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_SoulGem")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    hud.icon = icon

    local bar = CreateFrame("StatusBar", nil, hud)
    bar:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    bar:SetPoint("RIGHT", hud, "RIGHT", -2, 0)
    bar:SetHeight(16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.55, 0.20, 0.80, 0.9)
    bar:SetMinMaxValues(0, SOULSTONE_DURATION)
    hud.bar = bar

    -- Spark for Pandemic Window (< 1m)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(12, 26)
    spark:Hide()
    hud.spark = spark

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    text:SetPoint("RIGHT", bar, "RIGHT", -48, 0)
    text:SetJustifyH("LEFT")
    hud.text = text

    local timerText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timerText:SetJustifyH("RIGHT")
    hud.timerText = timerText

    -- Direct Drag on HUD frame when unlocked
    hud:RegisterForDrag("LeftButton")
    hud:SetScript("OnDragStart", function(self)
        if not (ns.db and ns.db.locked) then
            anchor:StartMoving()
        end
    end)
    hud:SetScript("OnDragStop", function(self)
        anchor:StopMovingOrSizing()
        local point, _, relPoint, x, y = anchor:GetPoint()
        if ns.db then
            if not ns.db.position then ns.db.position = {} end
            ns.db.position.point = point
            ns.db.position.relativePoint = relPoint
            ns.db.position.x = x
            ns.db.position.y = y
        end
    end)

    hud:Hide()
    SoulstoneTracker.anchor = anchor
    SoulstoneTracker.hud = hud
    SoulstoneTracker:UpdateAnchorState()
end

function SoulstoneTracker:ApplySettings()
    local anchor = self.anchor
    if not anchor then return end
    local width = (ns.db and ns.db.soulstoneWidth) or 180
    local scale = (ns.db and ns.db.soulstoneScale) or 1.0

    anchor:SetSize(width, 22)
    anchor:SetScale(scale)

    if anchor.shadowBox then
        anchor.shadowBox:SetSize(width, 26)
    end
    if self.hud then
        self.hud:SetSize(width, 22)
    end
end

function SoulstoneTracker:UpdateAnchorState()
    local anchor = self.anchor
    if not anchor or not anchor.shadowBox then return end

    if ns.db and ns.db.locked then
        anchor.shadowBox:Hide()
    else
        self:ApplySettings()
        anchor.shadowBox:Show()
    end

    if self.hud then
        self.hud:EnableMouse(not (ns.db and ns.db.locked))
    end
end

function SoulstoneTracker:ToggleLock()
    if not ns.db then return true end
    ns.db.locked = not ns.db.locked
    self:UpdateAnchorState()
    return ns.db.locked
end

function SoulstoneTracker:IsLocked()
    return (ns.db and ns.db.locked) ~= false
end

function SoulstoneTracker:ResetPosition()
    if not self.anchor then return end
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 250, 200)
    if ns.db then
        if not ns.db.position then ns.db.position = {} end
        ns.db.position.point = "BOTTOMLEFT"
        ns.db.position.relativePoint = "BOTTOMLEFT"
        ns.db.position.x = 250
        ns.db.position.y = 200
    end
end

function SoulstoneTracker:ToggleTestMode()
    isTestMode = not isTestMode
    if isTestMode then
        local pName = UnitName("player") or "MainTank"
        currentSoulstone = {
            targetName = pName,
            targetGUID = UnitGUID("player") or "test-guid",
            startTime = GetTime() - 300,
            expirationTime = GetTime() + 1500, -- 25 minutes left
            isTest = true,
            hasAlertedDead = false,
            wasDead = false,
            hasAlertedOneMin = false,
            hasAlertedExpired = false,
        }
        if self.hud then
            self.hud:Show()
        end
    else
        if currentSoulstone and currentSoulstone.isTest then
            currentSoulstone = nil
            if self.hud then
                self.hud:Hide()
            end
        end
    end
    return isTestMode
end

function SoulstoneTracker:ClearSoulstone()
    if currentSoulstone then
        local name = currentSoulstone.targetName
        currentSoulstone = nil
        if self.hud then
            self.hud:Hide()
        end
        isTestMode = false
        ns:Print("Soulstone tracking cleared.")
        ns:Log("INFO", "SoulstoneTracker", "Manually cleared Soulstone tracking for " .. tostring(name))
        return true
    else
        ns:Print("No active Soulstone tracking to clear.")
        return false
    end
end

-------------------------------------------------------------------------------
-- HUD Update Routine & Alert Trigger Monitor
-------------------------------------------------------------------------------
local function OnSoulstoneUpdate(self, elapsed)
    if not currentSoulstone then
        SoulstoneTracker.hud:Hide()
        return
    end

    local now = GetTime()
    local remaining = currentSoulstone.expirationTime - now

    -- 1. Expiration Alert
    if remaining <= 0 then
        if not currentSoulstone.hasAlertedExpired then
            currentSoulstone.hasAlertedExpired = true
            TriggerProcAlert(
                "|cffff4444SOULSTONE EXPIRED|r",
                string.format("Soulstone on %s has expired.", currentSoulstone.targetName),
                "Interface\\Icons\\Spell_Shadow_SoulGem",
                { r = 0.70, g = 0.30, b = 0.90 },
                618 -- Quest Complete / Gong sound
            )
            local targetName = currentSoulstone.targetName or "Target"
            local plainExpired = string.format("%s Soulstone EXPIRED!", targetName)
            local colorExpired = string.format("|cffff4444%s Soulstone EXPIRED!|r", targetName)
            SendGroupAnnouncement(plainExpired, colorExpired, currentSoulstone.isTest)
        end
        currentSoulstone = nil
        SoulstoneTracker.hud:Hide()
        return
    end

    local hud = SoulstoneTracker.hud
    if not (ns.db and ns.db.showSoulstoneBar ~= false) then
        hud:Hide()
    else
        hud:Show()
    end

    hud.bar:SetValue(remaining)
    hud.timerText:SetText(FormatTime(remaining))

    local status = CheckTargetStatus(currentSoulstone.targetName, currentSoulstone.targetGUID)

    -- 2. Target Dead Alert
    if status == "DEAD" then
        hud.text:SetText(string.format("|cffff2222[DEAD]|r %s", currentSoulstone.targetName))
        hud.bar:SetStatusBarColor(0.85, 0.10, 0.10, 0.95)
        hud.spark:Hide()

        currentSoulstone.wasDead = true

        if not currentSoulstone.hasAlertedDead then
            currentSoulstone.hasAlertedDead = true
            TriggerProcAlert(
                "|cffff2222SOULSTONE TARGET DEAD!|r",
                string.format("%s is dead! Soulstone ready to use (%s left)", currentSoulstone.targetName, FormatTime(remaining)),
                "Interface\\Icons\\Spell_Shadow_SoulGem",
                { r = 1.0, g = 0.1, b = 0.1 },
                8960 -- Raid Warning sound
            )
            local targetName = currentSoulstone.targetName or "Target"
            local plainDead = string.format("%s had DIED! Soulstone has %s remaining!", targetName, FormatTime(remaining))
            local colorDead = string.format("|cffff2222%s had DIED! Soulstone has %s remaining!|r", targetName, FormatTime(remaining))
            SendGroupAnnouncement(plainDead, colorDead, currentSoulstone.isTest)
        end
    else
        -- 3. Target Resurrected -> Soulstone Consumed
        if currentSoulstone.wasDead and not currentSoulstone.isTest and status == "ALIVE" then
            TriggerProcAlert(
                "|cff44ff44SOULSTONE RESURRECTION|r",
                string.format("%s resurrected! Soulstone consumed.", currentSoulstone.targetName),
                "Interface\\Icons\\Spell_Shadow_SoulGem",
                { r = 0.20, g = 1.00, b = 0.20 },
                618 -- Quest Complete / Gong sound
            )
            local plainRes = string.format("Soulstone consumed by %s (Resurrected).", currentSoulstone.targetName)
            local colorRes = string.format("Soulstone consumed by |cffffd100%s|r (Resurrected).", currentSoulstone.targetName)
            SendGroupAnnouncement(plainRes, colorRes, false)
            ns:Log("INFO", "SoulstoneTracker", "Soulstone consumed upon resurrection by " .. tostring(currentSoulstone.targetName))
            currentSoulstone = nil
            SoulstoneTracker.hud:Hide()
            return
        end

        -- 4. Pandemic Expiring Soon Alert (< 1 minute)
        if remaining <= 60 then
            hud.text:SetText(string.format("|cffffaa00%s|r", currentSoulstone.targetName))
            hud.bar:SetStatusBarColor(1.00, 0.70, 0.00, 1.00) -- Golden amber pandemic color

            -- Position spark
            local barWidth = hud.bar:GetWidth()
            if barWidth and barWidth > 0 then
                local pct = remaining / SOULSTONE_DURATION
                hud.spark:ClearAllPoints()
                hud.spark:SetPoint("CENTER", hud.bar, "LEFT", barWidth * pct, 0)
                hud.spark:Show()
            end

            if not currentSoulstone.hasAlertedOneMin then
                currentSoulstone.hasAlertedOneMin = true
                TriggerProcAlert(
                    "|cffffaa00SOULSTONE EXPIRING SOON!|r",
                    string.format("Soulstone on %s expires in < 1 minute!", currentSoulstone.targetName),
                    "Interface\\Icons\\Spell_Shadow_SoulGem",
                    { r = 1.0, g = 0.7, b = 0.0 },
                    8959 -- Alarm Clock warning sound
                )
            end
        else
            hud.text:SetText(string.format("%s", currentSoulstone.targetName))
            hud.bar:SetStatusBarColor(0.55, 0.20, 0.80, 0.90) -- Warlock purple
            hud.spark:Hide()
        end
    end
end

-------------------------------------------------------------------------------
-- Event Listener (UNIT_SPELLCAST_SUCCEEDED)
-------------------------------------------------------------------------------
function SoulstoneTracker:Initialize()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "WARLOCK" then
        return
    end

    CreateSoulstoneHUD()

    local eventFrame = CreateFrame("Frame", "OneLock_SoulstoneTracker_EventFrame")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
            local isSoulstone = false
            if spellID and SOULSTONE_SPELLS[spellID] then
                isSoulstone = true
            else
                local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
                if spellName and spellName:find("Soulstone") and not spellName:find("Create") then
                    isSoulstone = true
                end
            end

            if isSoulstone then
                local targetName = UnitName("target") or UnitName("player")
                if IsSecret(targetName) then targetName = "Target" end

                currentSoulstone = {
                    targetName = targetName,
                    targetGUID = UnitGUID("target") or UnitGUID("player"),
                    startTime = GetTime(),
                    expirationTime = GetTime() + SOULSTONE_DURATION,
                    isTest = false,
                    hasAlertedDead = false,
                    wasDead = false,
                    hasAlertedOneMin = false,
                    hasAlertedExpired = false,
                }
                if SoulstoneTracker.hud then
                    SoulstoneTracker.hud:Show()
                end

                local pName = UnitName("player") or "Player"
                if IsSecret(pName) then pName = "Player" end
                local plainCast = string.format("%s Soulstoned %s 30 Minute Timer Started!", pName, targetName)
                local colorCast = string.format("|cffffd100%s|r Soulstoned |cffffd100%s|r 30 Minute Timer Started!", pName, targetName)
                SendGroupAnnouncement(plainCast, colorCast)

                ns:Log("INFO", "SoulstoneTracker", "Soulstone cast on " .. tostring(targetName))
            end
        end
    end)

    SoulstoneTracker.hud:SetScript("OnUpdate", OnSoulstoneUpdate)
    ns:Log("INFO", "SoulstoneTracker", "SoulstoneTracker initialized with alerts and movable anchor.")
end
