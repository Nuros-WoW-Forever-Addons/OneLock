-- ============================================================================
-- OneLock_Shards - SoulstoneTracker
-- 30-minute persistent Soulstone tracking HUD with alive/dead status detection
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local SoulstoneTracker = {}
ns.SoulstoneTracker = SoulstoneTracker

local SOULSTONE_DURATION = 1800 -- 30 minutes in seconds
local currentSoulstone = nil

-- Soulstone spell IDs
local SOULSTONE_SPELLS = {
    [20707] = true, -- Minor Soulstone
    [20762] = true, -- Lesser Soulstone
    [20763] = true, -- Soulstone
    [20764] = true, -- Greater Soulstone
    [20765] = true, -- Major Soulstone
    [27239] = true, -- Master Soulstone
}

-------------------------------------------------------------------------------
-- UI Display Frame
-------------------------------------------------------------------------------
local function CreateSoulstoneHUD()
    local frame = CreateFrame("Frame", "OneLockSoulstoneFrame", UIParent, "BackdropTemplate")
    frame:SetSize(160, 22)
    frame:SetScale(1.0)
    frame:SetClampedToScreen(true)

    local pos = (ns.db and ns.db.soulstoneAnchor) or { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 250, y = 200 }
    frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0.08, 0.08, 0.12, 0.85)
    frame:SetBackdropBorderColor(0.5, 0.2, 0.7, 0.8)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", frame, "LEFT", 2, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_SoulGem")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    bar:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    bar:SetHeight(16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.55, 0.20, 0.80, 0.9)
    bar:SetMinMaxValues(0, SOULSTONE_DURATION)
    frame.bar = bar

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    text:SetPoint("RIGHT", bar, "RIGHT", -42, 0)
    text:SetJustifyH("LEFT")
    frame.text = text

    local timerText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timerText:SetJustifyH("RIGHT")
    frame.timerText = timerText

    frame:Hide()
    SoulstoneTracker.hud = frame
end

-------------------------------------------------------------------------------
-- Target Alive / Dead Status Check
-------------------------------------------------------------------------------
local function CheckTargetStatus(targetName)
    if not targetName then return "UNKNOWN" end

    -- Check party/raid units
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitName(unit) == targetName then
                if UnitIsDeadOrGhost(unit) then
                    return "DEAD"
                else
                    return "ALIVE"
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if UnitName(unit) == targetName then
                if UnitIsDeadOrGhost(unit) then
                    return "DEAD"
                else
                    return "ALIVE"
                end
            end
        end
    end

    if UnitName("target") == targetName then
        return UnitIsDeadOrGhost("target") and "DEAD" or "ALIVE"
    end

    return "ACTIVE"
end

-------------------------------------------------------------------------------
-- HUD Update Routine
-------------------------------------------------------------------------------
local function OnSoulstoneUpdate(self, elapsed)
    if not currentSoulstone then
        SoulstoneTracker.hud:Hide()
        return
    end

    local now = GetTime()
    local remaining = currentSoulstone.expirationTime - now

    if remaining <= 0 then
        currentSoulstone = nil
        SoulstoneTracker.hud:Hide()
        return
    end

    local hud = SoulstoneTracker.hud
    hud.bar:SetValue(remaining)

    local minutes = math.floor(remaining / 60)
    local seconds = math.floor(remaining % 60)
    hud.timerText:SetText(string.format("%dm %02ds", minutes, seconds))

    local status = CheckTargetStatus(currentSoulstone.targetName)
    if status == "DEAD" then
        hud.text:SetText(string.format("|cffff4444[DEAD]|r %s", currentSoulstone.targetName))
        hud.bar:SetStatusBarColor(0.8, 0.1, 0.1, 0.9)
    else
        hud.text:SetText(string.format("%s", currentSoulstone.targetName))
        hud.bar:SetStatusBarColor(0.55, 0.20, 0.80, 0.9)
    end
end

-------------------------------------------------------------------------------
-- Combat Log Event Listener
-------------------------------------------------------------------------------
local function OnCombatLogEvent()
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= UnitGUID("player") then return end

    if subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED" then
        local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
        if spellId and SOULSTONE_SPELLS[spellId] then
            currentSoulstone = {
                targetName = destName or UnitName("player"),
                targetGUID = destGUID,
                startTime = GetTime(),
                expirationTime = GetTime() + SOULSTONE_DURATION,
            }
            if SoulstoneTracker.hud then
                SoulstoneTracker.hud:Show()
            end
            ns:Print(string.format("Soulstone stored on |cffffd100%s|r (30 minutes).", currentSoulstone.targetName))
        end
    elseif subevent == "SPELL_AURA_REMOVED" then
        local spellId = select(12, CombatLogGetCurrentEventInfo())
        if spellId and SOULSTONE_SPELLS[spellId] then
            if currentSoulstone and currentSoulstone.targetGUID == destGUID then
                currentSoulstone = nil
                if SoulstoneTracker.hud then
                    SoulstoneTracker.hud:Hide()
                end
                ns:Print("Soulstone buff expired or was consumed.")
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
function SoulstoneTracker:Initialize()
    CreateSoulstoneHUD()

    local eventFrame = CreateFrame("Frame", "OneLock_SoulstoneTracker_EventFrame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent()
        end
    end)

    SoulstoneTracker.hud:SetScript("OnUpdate", OnSoulstoneUpdate)
end
