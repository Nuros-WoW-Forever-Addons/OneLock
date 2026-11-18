-- ============================================================================
-- OneLock_Timers - Display Engine & Frame Pool
-- Multi-target vertical bar stack with Pandemic color shifts (< 3.0s)
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local Display = {}
ns.Display = Display

-- Frame pools
local headerPool = {}
local activeHeaders = {}
local barPool = {}
local activeBars = {}

-- Status bar texture
local STATUS_BAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

-------------------------------------------------------------------------------
-- Safe Spell Icon Helper (C_Spell modern API)
-------------------------------------------------------------------------------
local function GetSpellTextureSafe(spellID, fallback)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and tex then return tex end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info and type(info) == "table" and (info.iconID or info.originalIconID) then
            return info.iconID or info.originalIconID
        end
    end
    if _G.GetSpellTexture then
        local ok, tex = pcall(_G.GetSpellTexture, spellID)
        if ok and tex then return tex end
    end
    return fallback or ""
end

-------------------------------------------------------------------------------
-- Time Formatter
-------------------------------------------------------------------------------
local function FormatTime(seconds)
    if not seconds or seconds < 0 then
        return "0.0s"
    elseif seconds >= 60 then
        return string.format("%dm %02ds", math.floor(seconds / 60), math.floor(seconds % 60))
    elseif seconds >= 10 then
        return string.format("%ds", math.floor(seconds + 0.5))
    else
        return string.format("%.1fs", seconds)
    end
end

-------------------------------------------------------------------------------
-- Master Anchor & Edit Mode Purple Shadow Box
-- When locked: Invisible point frame with zero screen footprint.
-- When unlocked (Edit Mode): Purple translucent shadow box for dragging.
-------------------------------------------------------------------------------
local function CreateMasterAnchor()
    local db = ns.db
    local anchor = CreateFrame("Frame", "OneLockTimersAnchor", UIParent)
    anchor:SetSize(db.barWidth or 160, 2)
    anchor:SetScale(db.barScale or 1.0)
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)

    local pos = db.position or { point = "CENTER", relativePoint = "CENTER", x = 160, y = 0 }
    anchor:ClearAllPoints()
    anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)

    -- Edit Mode Purple Shadow Box
    local shadowBox = CreateFrame("Frame", "OneLockTimersShadowBox", anchor, "BackdropTemplate")
    shadowBox:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    shadowBox:SetSize(db.barWidth or 160, 120)
    shadowBox:SetFrameStrata("HIGH")

    shadowBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    shadowBox:SetBackdropColor(0.20, 0.08, 0.35, 0.65) -- Translucent deep purple shadow
    shadowBox:SetBackdropBorderColor(0.75, 0.35, 1.00, 0.95) -- Glowing violet border

    local title = shadowBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", shadowBox, "CENTER", 0, 8)
    title:SetText("|cffdd99ffOneLock Timers|r")

    local hint = shadowBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -4)
    hint:SetText("|cffa8a8a8(Drag to Move)|r")

    shadowBox:EnableMouse(true)
    shadowBox:RegisterForDrag("LeftButton")

    shadowBox:SetScript("OnDragStart", function(self)
        anchor:StartMoving()
    end)

    shadowBox:SetScript("OnDragStop", function(self)
        anchor:StopMovingOrSizing()
        local point, _, relPoint, x, y = anchor:GetPoint()
        ns.db.position.point = point
        ns.db.position.relativePoint = relPoint
        ns.db.position.x = x
        ns.db.position.y = y
    end)

    anchor.shadowBox = shadowBox
    Display.anchor = anchor
    Display:UpdateAnchorState()
end

function Display:UpdateAnchorState()
    local anchor = self.anchor
    if not anchor or not anchor.shadowBox then return end

    if ns.db.locked then
        anchor.shadowBox:Hide()
    else
        anchor.shadowBox:SetWidth(ns.db.barWidth or 160)
        anchor.shadowBox:Show()
    end

    for _, header in ipairs(activeHeaders) do
        header:EnableMouse(not ns.db.locked)
    end
end

function Display:ResetAnchorPosition()
    if not self.anchor then return end
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("CENTER", UIParent, "CENTER", 160, 0)
    ns.db.position.point = "CENTER"
    ns.db.position.relativePoint = "CENTER"
    ns.db.position.x = 160
    ns.db.position.y = 0
end

function Display:ApplyDisplaySettings()
    if not self.anchor then return end
    self.anchor:SetScale(ns.db.barScale or 1.0)
    self.anchor:SetWidth(ns.db.barWidth or 160)
    self:UpdateBars()
end

-------------------------------------------------------------------------------
-- Header Pool
-------------------------------------------------------------------------------
local function AcquireHeader()
    local header = table.remove(headerPool)
    if not header then
        header = CreateFrame("Frame", nil, Display.anchor, "BackdropTemplate")
        header:SetHeight(16)
        header:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = nil,
            tile = false,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })

        local text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", header, "LEFT", 4, 0)
        text:SetPoint("RIGHT", header, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        header.text = text

        header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart", function(self)
            if not ns.db.locked then
                Display.anchor:StartMoving()
            end
        end)
        header:SetScript("OnDragStop", function(self)
            Display.anchor:StopMovingOrSizing()
            local point, _, relPoint, x, y = Display.anchor:GetPoint()
            ns.db.position.point = point
            ns.db.position.relativePoint = relPoint
            ns.db.position.x = x
            ns.db.position.y = y
        end)
    end

    header:SetWidth(ns.db.barWidth or 160)
    header:EnableMouse(not ns.db.locked)
    header:Show()
    table.insert(activeHeaders, header)
    return header
end

local function ReleaseHeaders()
    for _, header in ipairs(activeHeaders) do
        header:Hide()
        header:ClearAllPoints()
        table.insert(headerPool, header)
    end
    wipe(activeHeaders)
end

-------------------------------------------------------------------------------
-- Bar Pool
-------------------------------------------------------------------------------
local function AcquireBar()
    local bar = table.remove(barPool)
    if not bar then
        bar = CreateFrame("StatusBar", nil, Display.anchor)
        bar:SetStatusBarTexture(STATUS_BAR_TEX)
        bar:GetStatusBarTexture():SetHorizTile(false)

        -- Dark Background
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.05, 0.05, 0.05, 0.75)
        bar.bg = bg

        -- Spell Icon
        local icon = bar:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPRIGHT", bar, "TOPLEFT", -2, 0)
        icon:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -2, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        bar.icon = icon

        -- Spell Name Text
        local nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
        nameText:SetPoint("RIGHT", bar, "RIGHT", -42, 0)
        nameText:SetJustifyH("LEFT")
        bar.nameText = nameText

        -- Countdown Time Text
        local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        timeText:SetJustifyH("RIGHT")
        bar.timeText = timeText

        -- Spark
        local spark = bar:CreateTexture(nil, "OVERLAY")
        spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        spark:SetBlendMode("ADD")
        spark:SetSize(12, 28)
        bar.spark = spark
    end

    bar:SetWidth(ns.db.barWidth or 160)
    bar:SetHeight(ns.db.barHeight or 16)
    bar.icon:SetWidth(ns.db.barHeight or 16)
    bar:Show()
    table.insert(activeBars, bar)
    return bar
end

local function ReleaseBars()
    for _, bar in ipairs(activeBars) do
        bar:Hide()
        bar:ClearAllPoints()
        bar.timerData = nil
        table.insert(barPool, bar)
    end
    wipe(activeBars)
end

-------------------------------------------------------------------------------
-- Compact Icon Pool (Compact Mode)
-------------------------------------------------------------------------------
local iconPool = {}
local activeIcons = {}

local function AcquireIcon()
    local iconFrame = table.remove(iconPool)
    if not iconFrame then
        iconFrame = CreateFrame("Frame", nil, Display.anchor, "BackdropTemplate")
        iconFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        iconFrame:SetBackdropColor(0, 0, 0, 0.85)
        iconFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)

        local tex = iconFrame:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconFrame.tex = tex

        -- Countdown Time Text Overlay (Anchored to bottom center below the icon)
        local timeText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timeText:SetPoint("TOP", iconFrame, "BOTTOM", 0, -2)
        timeText:SetJustifyH("CENTER")
        timeText:SetShadowColor(0, 0, 0, 1)
        timeText:SetShadowOffset(1, -1)
        iconFrame.timeText = timeText

        -- Glowing Pandemic Action Border
        local glow = iconFrame:CreateTexture(nil, "OVERLAY")
        glow:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -2, 2)
        glow:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 2, -2)
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1.0, 0.82, 0.0, 0.95)
        glow:Hide()
        iconFrame.glow = glow
    end

    local size = ns.db.iconSize or 24
    iconFrame:SetSize(size, size)
    local fontPath = GameFontHighlightSmall:GetFont() or "Fonts\\FRIZQT__.TTF"
    local fontSize = math.max(9, math.min(13, math.floor(size * 0.45)))
    iconFrame.timeText:SetFont(fontPath, fontSize, "OUTLINE")
    iconFrame.timeText:ClearAllPoints()
    iconFrame.timeText:SetPoint("TOP", iconFrame, "BOTTOM", 0, -2)

    iconFrame:Show()
    table.insert(activeIcons, iconFrame)
    return iconFrame
end

local function ReleaseIcons()
    for _, icon in ipairs(activeIcons) do
        icon:Hide()
        icon:ClearAllPoints()
        icon.timerData = nil
        if icon.glow then icon.glow:Hide() end
        table.insert(iconPool, icon)
    end
    wipe(activeIcons)
end

-------------------------------------------------------------------------------
-- Simulated Test Mode Data
-------------------------------------------------------------------------------
local testTimerCache = nil

function Display:ToggleTestMode()
    ns.isTestMode = not ns.isTestMode
    if ns.isTestMode then
        local now = GetTime()
        testTimerCache = {
            ["TEST_TARGET_1"] = {
                guid = "TEST_TARGET_1",
                name = "High Warlord Naj'entus",
                lastSeen = now,
                isTarget = true,
                spells = {
                    ["Corruption"] = {
                        spellName = "Corruption",
                        spellId = 172,
                        icon = GetSpellTextureSafe(172, "Interface\\Icons\\Spell_Shadow_AbominationExplosion"),
                        duration = 12,
                        expirationTime = now + 2.5, -- In Pandemic window (< 3.0s)
                    },
                    ["Unstable Affliction"] = {
                        spellName = "Unstable Affliction",
                        spellId = 30108,
                        icon = GetSpellTextureSafe(30108, "Interface\\Icons\\Spell_Shadow_UnstableAffliction_3"),
                        duration = 15,
                        expirationTime = now + 8.2,
                    },
                    ["Immolate"] = {
                        spellName = "Immolate",
                        spellId = 348,
                        icon = GetSpellTextureSafe(348, "Interface\\Icons\\Spell_Fire_Immolation"),
                        duration = 15,
                        expirationTime = now + 12.0,
                    },
                },
            },
            ["TEST_TARGET_2"] = {
                guid = "TEST_TARGET_2",
                name = "Coilfang Priest",
                lastSeen = now - 5,
                isTarget = false,
                spells = {
                    ["Corruption"] = {
                        spellName = "Corruption",
                        spellId = 172,
                        icon = GetSpellTextureSafe(172, "Interface\\Icons\\Spell_Shadow_AbominationExplosion"),
                        duration = 12,
                        expirationTime = now + 9.5,
                    },
                    ["Fear"] = {
                        spellName = "Fear",
                        spellId = 5782,
                        icon = GetSpellTextureSafe(5782, "Interface\\Icons\\Spell_Shadow_Possession"),
                        duration = 20,
                        expirationTime = now + 17.8,
                    },
                },
            },
        }
    else
        testTimerCache = nil
    end

    self:UpdateBars()
    return ns.isTestMode
end

-------------------------------------------------------------------------------
-- Vertical Bar Stack Layout & Re-anchoring
-------------------------------------------------------------------------------
function Display:UpdateBars()
    ReleaseHeaders()
    ReleaseBars()
    ReleaseIcons()

    local db = ns.db
    local currentTargetGUID = UnitGUID("target")
    if issecretvalue and issecretvalue(currentTargetGUID) then
        currentTargetGUID = nil
    end

    -- Choose data source (test mode vs active combat data)
    local sourceData = (ns.isTestMode and testTimerCache) or ns.activeTimers
    if not sourceData then return end

    -- Extract and sort target entries
    local targetList = {}
    for guid, target in pairs(sourceData) do
        local hasSpells = false
        for _ in pairs(target.spells) do
            hasSpells = true
            break
        end

        if hasSpells then
            table.insert(targetList, target)
        end
    end

    if #targetList == 0 then return end

    -- Sort: current target always at the top, then by most recently updated
    table.sort(targetList, function(a, b)
        local aIsTarget = (currentTargetGUID and a.guid == currentTargetGUID) or (a.isTarget == true)
        local bIsTarget = (currentTargetGUID and b.guid == currentTargetGUID) or (b.isTarget == true)
        if aIsTarget ~= bIsTarget then
            return aIsTarget
        end
        return (a.lastSeen or 0) > (b.lastSeen or 0)
    end)

    local previousElement = Display.anchor
    local maxTargets = db.maxVisibleTargets or 5
    local targetsShown = 0

    for _, target in ipairs(targetList) do
        if targetsShown >= maxTargets then break end
        targetsShown = targetsShown + 1

        local isCurrentTarget = (currentTargetGUID and target.guid == currentTargetGUID) or (target.isTarget == true)

        -- 1. Create Target Header Frame
        local header = nil
        if db.showTargetHeader then
            header = AcquireHeader()
            header:ClearAllPoints()
            if previousElement == Display.anchor then
                header:SetPoint("TOPLEFT", Display.anchor, "TOPLEFT", 0, 0)
            else
                local gap = (db.displayMode == "ICONS") and -18 or -6
                header:SetPoint("TOPLEFT", previousElement, "BOTTOMLEFT", 0, gap)
            end

            local rawName = target.name
            if not rawName or (issecretvalue and issecretvalue(rawName)) then
                rawName = "Unknown"
            end

            if isCurrentTarget then
                header:SetBackdropColor(0.2, 0.16, 0.05, 0.85)
                header.text:SetText(string.format("|cffffd100[Target]|r %s", rawName))
                header.text:SetTextColor(db.colorTargetHeader.r, db.colorTargetHeader.g, db.colorTargetHeader.b)
            else
                header:SetBackdropColor(0.08, 0.08, 0.1, 0.65)
                header.text:SetText(rawName)
                header.text:SetTextColor(db.colorNonTargetHeader.r, db.colorNonTargetHeader.g, db.colorNonTargetHeader.b)
            end

            previousElement = header
        end

        -- 2. Sort Spells by Remaining Time Ascending (Shortest first)
        local spellList = {}
        for _, timer in pairs(target.spells) do
            table.insert(spellList, timer)
        end

        local now = GetTime()
        table.sort(spellList, function(a, b)
            local aRem = (a.expirationTime or 0) - now
            local bRem = (b.expirationTime or 0) - now
            return aRem < bRem
        end)

        if db.displayMode == "ICONS" then
            -- ================================================================
            -- COMPACT ICON MODE: Spell icons left-to-right under the name header
            -- ================================================================
            local prevIcon = nil
            local rowLeader = nil
            for _, timer in ipairs(spellList) do
                local icon = AcquireIcon()
                icon:ClearAllPoints()
                if not prevIcon then
                    if header then
                        icon:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
                    elseif previousElement == Display.anchor then
                        icon:SetPoint("TOPLEFT", Display.anchor, "TOPLEFT", 0, 0)
                    else
                        icon:SetPoint("TOPLEFT", previousElement, "BOTTOMLEFT", 0, -4)
                    end
                    rowLeader = icon
                else
                    icon:SetPoint("LEFT", prevIcon, "RIGHT", 6, 0)
                end

                icon.timerData = timer
                if timer.icon and timer.icon ~= "" then
                    icon.tex:SetTexture(timer.icon)
                end

                local remaining = math.max(0, (timer.expirationTime or 0) - now)
                icon.timeText:SetText(FormatTime(remaining))

                if remaining <= (db.pandemicThreshold or 3.0) then
                    icon.timeText:SetTextColor(db.colorPandemic.r, db.colorPandemic.g, db.colorPandemic.b, 1.0)
                    if icon.glow then icon.glow:Show() end
                    icon:SetBackdropBorderColor(db.colorPandemic.r, db.colorPandemic.g, db.colorPandemic.b, 1.0)
                else
                    icon.timeText:SetTextColor(db.colorNormal.r, db.colorNormal.g, db.colorNormal.b, 1.0)
                    if icon.glow then icon.glow:Hide() end
                    icon:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)
                end

                prevIcon = icon
            end

            if rowLeader then
                previousElement = rowLeader
            end
        else
            -- ================================================================
            -- FULL BAR MODE: Cascading StatusBars vertically
            -- ================================================================
            for _, timer in ipairs(spellList) do
                local bar = AcquireBar()
                bar:ClearAllPoints()
                if previousElement == Display.anchor then
                    bar:SetPoint("TOPLEFT", Display.anchor, "TOPLEFT", 0, 0)
                else
                    bar:SetPoint("TOPLEFT", previousElement, "BOTTOMLEFT", 0, -2)
                end

                bar.timerData = timer
                bar:SetMinMaxValues(0, timer.duration or 18)

                local remaining = math.max(0, (timer.expirationTime or 0) - now)
                bar:SetValue(remaining)
                bar.nameText:SetText(timer.spellName or "")
                bar.timeText:SetText(FormatTime(remaining))

                if db.showSpellIcon and timer.icon and timer.icon ~= "" then
                    bar.icon:SetTexture(timer.icon)
                    bar.icon:Show()
                else
                    bar.icon:Hide()
                end

                -- Pandemic Refresh Color Shift (< 3.0s)
                if remaining <= (db.pandemicThreshold or 3.0) then
                    bar:SetStatusBarColor(db.colorPandemic.r, db.colorPandemic.g, db.colorPandemic.b, db.colorPandemic.a)
                else
                    bar:SetStatusBarColor(db.colorNormal.r, db.colorNormal.g, db.colorNormal.b, db.colorNormal.a)
                end

                previousElement = bar
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Smooth Continuous OnUpdate Dispatcher (One Frame for All Active Bars/Icons)
-------------------------------------------------------------------------------
local function OnDisplayFrameUpdate(self, elapsed)
    if #activeBars == 0 and #activeIcons == 0 then return end

    local now = GetTime()
    local db = ns.db
    local threshold = db.pandemicThreshold or 3.0

    if #activeBars > 0 then
        for _, bar in ipairs(activeBars) do
            local timer = bar.timerData
            if timer and timer.expirationTime then
                local remaining = timer.expirationTime - now
                if ns.isTestMode and remaining <= 0 then
                    -- Automatically cycle test bars so they constantly animate and loop
                    local dur = timer.duration or 18
                    timer.expirationTime = now + dur
                    remaining = dur
                elseif remaining <= 0 then
                    remaining = 0
                end

                bar:SetValue(remaining)
                bar.timeText:SetText(FormatTime(remaining))

                -- Position Spark
                local duration = timer.duration or 18
                if duration > 0 and bar.spark then
                    local pct = remaining / duration
                    local barWidth = bar:GetWidth()
                    local sparkOffset = (pct * barWidth) - (bar.spark:GetWidth() / 2)
                    bar.spark:ClearAllPoints()
                    bar.spark:SetPoint("CENTER", bar, "LEFT", sparkOffset, 0)
                    if remaining > 0 then
                        bar.spark:Show()
                    else
                        bar.spark:Hide()
                    end
                end

                -- Dynamic Pandemic Color Shift
                if remaining <= threshold then
                    bar:SetStatusBarColor(db.colorPandemic.r, db.colorPandemic.g, db.colorPandemic.b, db.colorPandemic.a)
                else
                    bar:SetStatusBarColor(db.colorNormal.r, db.colorNormal.g, db.colorNormal.b, db.colorNormal.a)
                end
            end
        end
    end

    if #activeIcons > 0 then
        for _, icon in ipairs(activeIcons) do
            local timer = icon.timerData
            if timer and timer.expirationTime then
                local remaining = timer.expirationTime - now
                if ns.isTestMode and remaining <= 0 then
                    local dur = timer.duration or 18
                    timer.expirationTime = now + dur
                    remaining = dur
                elseif remaining <= 0 then
                    remaining = 0
                end

                icon.timeText:SetText(FormatTime(remaining))

                -- Dynamic Pandemic Color Shift on text & glow border
                if remaining <= threshold then
                    icon.timeText:SetTextColor(db.colorPandemic.r, db.colorPandemic.g, db.colorPandemic.b, 1.0)
                    if icon.glow then icon.glow:Show() end
                    icon:SetBackdropBorderColor(db.colorPandemic.r, db.colorPandemic.g, db.colorPandemic.b, 1.0)
                else
                    icon.timeText:SetTextColor(db.colorNormal.r, db.colorNormal.g, db.colorNormal.b, 1.0)
                    if icon.glow then icon.glow:Hide() end
                    icon:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Notification Hooks from Tracker
-------------------------------------------------------------------------------
function Display:OnTimerUpdated()
    self:UpdateBars()
end

function Display:OnTargetChanged()
    self:UpdateBars()
end

-------------------------------------------------------------------------------
-- Display Engine Initialization
-------------------------------------------------------------------------------
function Display:Initialize()
    CreateMasterAnchor()

    local updateFrame = CreateFrame("Frame", "OneLock_Timers_DisplayUpdateFrame")
    updateFrame:SetScript("OnUpdate", OnDisplayFrameUpdate)
    Display.updateFrame = updateFrame
end
