-- ============================================================================
-- OneLock_Procs - Alerts Engine
-- Reactive alerts for Shadow Trance, Backlash, and target CC immunity
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local Alerts = {}
ns.Alerts = Alerts

local SHADOW_TRANCE_ID = 17941
local BACKLASH_ID = 34936

local IMMUNITY_SPELLS = {
    [710]  = "Banish",
    [5782] = "Fear",
}

-------------------------------------------------------------------------------
-- Alert Banner UI
-------------------------------------------------------------------------------
local function CreateAlertBanner()
    local banner = CreateFrame("Frame", "OneLockProcAlertBanner", UIParent, "BackdropTemplate")
    banner:SetSize(240, 48)
    banner:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    banner:SetScale((ns.db and ns.db.alertScale) or 1.2)
    banner:SetClampedToScreen(true)

    banner:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    banner:SetBackdropColor(0.05, 0.05, 0.08, 0.90)
    banner:SetBackdropBorderColor(1.0, 0.8, 0.0, 1.0)

    local icon = banner:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", banner, "LEFT", 6, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    banner.icon = icon

    local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
    title:SetPoint("RIGHT", banner, "RIGHT", -6, 0)
    title:SetJustifyH("LEFT")
    banner.title = title

    local subtext = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtext:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 4)
    subtext:SetPoint("RIGHT", banner, "RIGHT", -6, 0)
    subtext:SetJustifyH("LEFT")
    banner.subtext = subtext

    banner:Hide()
    Alerts.banner = banner
end

local fadeTimer = 0
local function ShowAlert(titleText, subText, iconPath, borderColor, soundId)
    local banner = Alerts.banner
    if not banner then return end

    banner.title:SetText(titleText)
    banner.subtext:SetText(subText)
    banner.icon:SetTexture(iconPath)

    if borderColor then
        banner:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 1.0)
    else
        banner:SetBackdropBorderColor(1.0, 0.8, 0.0, 1.0)
    end

    banner:SetAlpha(1.0)
    banner:Show()
    fadeTimer = 2.5

    if ns.db and ns.db.playAudio and soundId then
        pcall(PlaySound, soundId)
    end
end

-------------------------------------------------------------------------------
-- OnUpdate Fade-out
-------------------------------------------------------------------------------
local function OnBannerUpdate(self, elapsed)
    if fadeTimer > 0 then
        fadeTimer = fadeTimer - elapsed
        if fadeTimer <= 0.5 and fadeTimer > 0 then
            Alerts.banner:SetAlpha(fadeTimer / 0.5)
        elseif fadeTimer <= 0 then
            Alerts.banner:Hide()
            Alerts.banner:SetAlpha(1.0)
        end
    end
end

-------------------------------------------------------------------------------
-- Player Aura Monitoring (Nightfall & Backlash)
-------------------------------------------------------------------------------
local hadShadowTrance = false
local hadBacklash = false

local function CheckPlayerBuffs()
    local hasShadowTrance = false
    local hasBacklash = false

    local i = 1
    while true do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellId = UnitBuff("player", i)
        if not name then break end

        if (spellId == SHADOW_TRANCE_ID or name == "Shadow Trance") then
            hasShadowTrance = true
        elseif (spellId == BACKLASH_ID or name == "Backlash") then
            hasBacklash = true
        end
        i = i + 1
    end

    if hasShadowTrance and not hadShadowTrance then
        if ns.db and ns.db.enableNightfall then
            local icon = GetSpellTexture(SHADOW_TRANCE_ID) or "Interface\\Icons\\Spell_Shadow_Twilight"
            ShowAlert("|cffffd100SHADOW TRANCE!|r", "Instant Shadow Bolt Ready", icon, { r = 0.8, g = 0.4, b = 1.0 }, (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 8959)
        end
    end
    hadShadowTrance = hasShadowTrance

    if hasBacklash and not hadBacklash then
        if ns.db and ns.db.enableBacklash then
            local icon = GetSpellTexture(BACKLASH_ID) or "Interface\\Icons\\Spell_Fire_PlayingWithFire"
            ShowAlert("|cffff8800BACKLASH!|r", "Instant Shadow Bolt / Incinerate Ready", icon, { r = 1.0, g = 0.5, b = 0.0 }, (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 8959)
        end
    end
    hadBacklash = hasBacklash
end

-------------------------------------------------------------------------------
-- Combat Log CC Immunity Detection
-------------------------------------------------------------------------------
local function OnCombatLogEvent()
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= UnitGUID("player") then return end

    if subevent == "SPELL_MISSED" then
        local spellId, spellName, spellSchool, missType = select(12, CombatLogGetCurrentEventInfo())
        if (missType == "IMMUNE" or subevent == "SPELL_IMMUNE") and spellId and IMMUNITY_SPELLS[spellId] then
            if ns.db and ns.db.enableImmunityAlert then
                local icon = GetSpellTexture(spellId) or "Interface\\Icons\\Spell_Shadow_Possession"
                local targetDesc = destName or "Target"
                ShowAlert(string.format("|cffff2222%s IMMUNE!|r", IMMUNITY_SPELLS[spellId]:upper()), string.format("%s is immune to %s", targetDesc, IMMUNITY_SPELLS[spellId]), icon, { r = 1.0, g = 0.1, b = 0.1 }, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Test Alert Hook
-------------------------------------------------------------------------------
function Alerts:TriggerTestAlert()
    local icon = GetSpellTexture(SHADOW_TRANCE_ID) or "Interface\\Icons\\Spell_Shadow_Twilight"
    ShowAlert("|cffffd100SHADOW TRANCE (Test)|r", "Instant Shadow Bolt Ready", icon, { r = 0.8, g = 0.4, b = 1.0 }, (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 8959)
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
function Alerts:Initialize()
    CreateAlertBanner()

    local eventFrame = CreateFrame("Frame", "OneLock_Procs_AlertsFrame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    eventFrame:SetScript("OnEvent", function(self, event, unit)
        if event == "UNIT_AURA" and unit == "player" then
            CheckPlayerBuffs()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent()
        end
    end)

    Alerts.banner:SetScript("OnUpdate", OnBannerUpdate)
    Alerts.frame = eventFrame
end
