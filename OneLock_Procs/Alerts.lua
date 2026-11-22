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
-- Modern Spell Details Helper
-------------------------------------------------------------------------------
local function GetSpellDetails(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info and type(info) == "table" then
            return info.name, info.iconID or info.originalIconID
        end
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        local icon = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)) or nil
        if ok and name then
            return name, icon
        end
    end
    if _G.GetSpellInfo then
        local ok, name, _, icon = pcall(_G.GetSpellInfo, spellID)
        if ok and name then
            return name, icon
        end
    end
    return nil, nil
end

-------------------------------------------------------------------------------
-- Sound Effect Profiles
-------------------------------------------------------------------------------
local SOUND_OPTIONS = {
    { name = "Alarm Clock (Default)", id = 8959 },
    { name = "Raid Warning", id = 8960 },
    { name = "Gong / Quest Completed", id = 618 },
    { name = "Level Up", id = 888 },
    { name = "PvP Flag Captured", id = 8174 },
    { name = "None (Mute)", id = 0 },
}
Alerts.SOUND_OPTIONS = SOUND_OPTIONS

function Alerts:GetSoundList()
    return SOUND_OPTIONS
end

function Alerts:GetCurrentSoundIndex()
    local idx = ns.db and ns.db.soundIndex or 1
    if idx < 1 or idx > #SOUND_OPTIONS then
        idx = 1
    end
    return idx
end

function Alerts:SetSoundByIndex(idx)
    if not ns.db then return end
    if idx < 1 then idx = #SOUND_OPTIONS end
    if idx > #SOUND_OPTIONS then idx = 1 end
    ns.db.soundIndex = idx
    ns.db.soundId = SOUND_OPTIONS[idx].id
end

function Alerts:PlayCurrentSound()
    local soundId = (ns.db and ns.db.soundId ~= nil) and ns.db.soundId or 8959
    if soundId and soundId > 0 then
        pcall(PlaySound, soundId, "Master")
    end
end

-------------------------------------------------------------------------------
-- Alert Banner UI & Movable Purple Shadow Box Anchor
-------------------------------------------------------------------------------
local function CreateAlertBanner()
    local db = ns.db or {}
    local anchor = CreateFrame("Frame", "OneLockProcAnchor", UIParent)
    anchor:SetSize(db.alertWidth or 240, 48)
    anchor:SetScale(db.alertScale or 1.2)
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)

    local pos = db.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 180 }
    anchor:ClearAllPoints()
    anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 180)

    -- Edit Mode Purple Shadow Box
    local shadowBox = CreateFrame("Frame", "OneLockProcShadowBox", anchor, "BackdropTemplate")
    shadowBox:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    shadowBox:SetSize(db.alertWidth or 240, 48)
    shadowBox:SetFrameStrata("HIGH")

    shadowBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    shadowBox:SetBackdropColor(0.20, 0.08, 0.35, 0.65) -- Translucent deep purple shadow
    shadowBox:SetBackdropBorderColor(0.75, 0.35, 1.00, 0.95) -- Glowing violet border

    local shadowIcon = shadowBox:CreateTexture(nil, "ARTWORK")
    shadowIcon:SetSize(36, 36)
    shadowIcon:SetPoint("LEFT", shadowBox, "LEFT", 6, 0)
    shadowIcon:SetTexture("Interface\\Icons\\Spell_Shadow_Twilight")
    shadowIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local shadowTitle = shadowBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shadowTitle:SetPoint("TOPLEFT", shadowIcon, "TOPRIGHT", 8, -4)
    shadowTitle:SetText("|cffdd99ffOneLock Proc Alert|r")

    local shadowHint = shadowBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shadowHint:SetPoint("BOTTOMLEFT", shadowIcon, "BOTTOMRIGHT", 8, 4)
    shadowHint:SetText("|cffa8a8a8(Drag to Move)|r")

    shadowBox:EnableMouse(true)
    shadowBox:RegisterForDrag("LeftButton")

    shadowBox:SetScript("OnDragStart", function(self)
        anchor:StartMoving()
    end)

    shadowBox:SetScript("OnDragStop", function(self)
        anchor:StopMovingOrSizing()
        local point, _, relPoint, x, y = anchor:GetPoint()
        if ns.db and ns.db.position then
            ns.db.position.point = point
            ns.db.position.relativePoint = relPoint
            ns.db.position.x = x
            ns.db.position.y = y
        end
    end)

    anchor.shadowBox = shadowBox

    -- Active Proc Alert Banner (shown only on procs / alerts)
    local banner = CreateFrame("Frame", "OneLockProcAlertBanner", anchor, "BackdropTemplate")
    banner:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    banner:SetSize(db.alertWidth or 240, 48)

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
    Alerts.anchor = anchor
    Alerts.banner = banner
    Alerts:UpdateAnchorState()
end

function Alerts:ApplyAlertSettings()
    local anchor = self.anchor
    if not anchor then return end
    local db = ns.db or {}
    local width = db.alertWidth or 240
    local scale = db.alertScale or 1.2

    anchor:SetSize(width, 48)
    anchor:SetScale(scale)

    if anchor.shadowBox then
        anchor.shadowBox:SetSize(width, 48)
    end
    if self.banner then
        self.banner:SetSize(width, 48)
    end
end

function Alerts:UpdateAnchorState()
    local anchor = self.anchor
    if not anchor or not anchor.shadowBox then return end

    if ns.db and ns.db.locked then
        anchor.shadowBox:Hide()
    else
        self:ApplyAlertSettings()
        anchor.shadowBox:Show()
    end
end

function Alerts:ToggleLock()
    if not ns.db then return true end
    ns.db.locked = not ns.db.locked
    self:UpdateAnchorState()
    return ns.db.locked
end

function Alerts:IsLocked()
    return (ns.db and ns.db.locked) ~= false
end

function Alerts:ResetAnchorPosition()
    if not self.anchor then return end
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    if ns.db and ns.db.position then
        ns.db.position.point = "CENTER"
        ns.db.position.relativePoint = "CENTER"
        ns.db.position.x = 0
        ns.db.position.y = 180
    end
end

local fadeTimer = 0
function Alerts:ShowAlert(titleText, subText, iconPath, borderColor, fallbackSoundId)
    local banner = Alerts.banner
    if not banner then return end

    banner.title:SetText(titleText)
    banner.subtext:SetText(subText)
    if iconPath and iconPath ~= "" then
        banner.icon:SetTexture(iconPath)
    end

    if borderColor then
        banner:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 1.0)
    else
        banner:SetBackdropBorderColor(1.0, 0.8, 0.0, 1.0)
    end

    banner:SetAlpha(1.0)
    banner:Show()
    fadeTimer = 3.0

    if ns.db and ns.db.playAudio then
        local soundToPlay = ns.db.soundId
        if soundToPlay == nil then
            soundToPlay = fallbackSoundId or 8959
        end
        if soundToPlay and soundToPlay > 0 then
            pcall(PlaySound, soundToPlay, "Master")
        end
    end
end

local function ShowAlert(titleText, subText, iconPath, borderColor, fallbackSoundId)
    Alerts:ShowAlert(titleText, subText, iconPath, borderColor, fallbackSoundId)
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
-- Modern Player Aura Monitoring (C_UnitAuras)
-------------------------------------------------------------------------------
local hadShadowTrance = false
local hadBacklash = false

local function IsSecret(val)
    return issecretvalue and issecretvalue(val)
end

local function HasBuff(spellID, spellName)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok and aura and not IsSecret(aura) then
            return true, aura.icon
        end
    end

    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        local i = 1
        while true do
            local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
            if not ok or not aura then break end
            if not IsSecret(aura.spellId) and aura.spellId == spellID then
                return true, aura.icon
            end
            if not IsSecret(aura.name) and aura.name == spellName then
                return true, aura.icon
            end
            i = i + 1
        end
    end

    if _G.UnitBuff then
        local i = 1
        while true do
            local ok, name, icon, _, _, _, _, _, _, id = pcall(_G.UnitBuff, "player", i)
            if not ok or not name then break end
            if not IsSecret(id) and id == spellID then
                return true, icon
            end
            if not IsSecret(name) and name == spellName then
                return true, icon
            end
            i = i + 1
        end
    end

    return false, nil
end

local function CheckPlayerBuffs()
    local hasShadowTrance, stIcon = HasBuff(SHADOW_TRANCE_ID, "Shadow Trance")
    local hasBacklash, blIcon = HasBuff(BACKLASH_ID, "Backlash")

    if hasShadowTrance and not hadShadowTrance then
        if ns.db and ns.db.enableNightfall then
            local _, icon = GetSpellDetails(SHADOW_TRANCE_ID)
            icon = stIcon or icon or "Interface\\Icons\\Spell_Shadow_Twilight"
            ShowAlert("|cffffd100SHADOW TRANCE!|r", "Instant Shadow Bolt Ready", icon, { r = 0.8, g = 0.4, b = 1.0 }, (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 8959)
            ns:Log("INFO", "Alerts", "Proc detected: Shadow Trance (Nightfall)")
        end
    end
    hadShadowTrance = hasShadowTrance

    if hasBacklash and not hadBacklash then
        if ns.db and ns.db.enableBacklash then
            local _, icon = GetSpellDetails(BACKLASH_ID)
            icon = blIcon or icon or "Interface\\Icons\\Spell_Fire_PlayingWithFire"
            ShowAlert("|cffff8800BACKLASH!|r", "Instant Shadow Bolt / Incinerate Ready", icon, { r = 1.0, g = 0.5, b = 0.0 }, (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 8959)
            ns:Log("INFO", "Alerts", "Proc detected: Backlash")
        end
    end
    hadBacklash = hasBacklash
end

-------------------------------------------------------------------------------
-- Target CC Immunity Detection (UI_ERROR_MESSAGE)
-------------------------------------------------------------------------------
local lastCastSpellName = nil
local lastCastTime = 0

local function OnSpellcastSent(unit, target, castGUID, spellID)
    if unit == "player" and spellID and IMMUNITY_SPELLS[spellID] then
        lastCastSpellName = IMMUNITY_SPELLS[spellID]
        lastCastTime = GetTime()
    end
end

local function OnUIErrorMessage(errorType, message)
    if not message or not ns.db or not ns.db.enableImmunityAlert then return end

    local now = GetTime()
    if (now - lastCastTime) <= 1.5 and lastCastSpellName then
        local lower = message:lower()
        if lower:find("immune") then
            local targetName = UnitName("target") or "Target"
            local _, icon = GetSpellDetails(5782)
            ShowAlert(string.format("|cffff2222%s IMMUNE!|r", lastCastSpellName:upper()), string.format("%s is immune to %s", targetName, lastCastSpellName), icon or "Interface\\Icons\\Spell_Shadow_Possession", { r = 1.0, g = 0.1, b = 0.1 }, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959)
            ns:Log("WARN", "Alerts", string.format("CC Immunity: %s on %s", lastCastSpellName, targetName))
        end
    end
end

-------------------------------------------------------------------------------
-- Test Alert Hook
-------------------------------------------------------------------------------
function Alerts:TriggerTestAlert()
    local _, icon = GetSpellDetails(SHADOW_TRANCE_ID)
    ShowAlert("|cffffd100SHADOW TRANCE (Test)|r", "Instant Shadow Bolt Ready", icon or "Interface\\Icons\\Spell_Shadow_Twilight", { r = 0.8, g = 0.4, b = 1.0 }, (SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3) or 8959)
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
function Alerts:Initialize()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "WARLOCK" then
        return
    end

    CreateAlertBanner()

    local eventFrame = CreateFrame("Frame", "OneLock_Procs_AlertsFrame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
    eventFrame:RegisterEvent("UI_ERROR_MESSAGE")

    eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
        if event == "UNIT_AURA" and arg1 == "player" then
            CheckPlayerBuffs()
        elseif event == "CURRENT_SPELL_CAST_CHANGED" then
            -- Check target spellcasting status
        elseif event == "UI_ERROR_MESSAGE" then
            OnUIErrorMessage(arg1, arg2)
        end
    end)

    -- Hook unit spellcast sent if available
    pcall(function()
        eventFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
        local origHandler = eventFrame:GetScript("OnEvent")
        eventFrame:SetScript("OnEvent", function(self, event, a1, a2, a3, a4)
            if event == "UNIT_SPELLCAST_SENT" then
                OnSpellcastSent(a1, a2, a3, a4)
            else
                origHandler(self, event, a1, a2, a3, a4)
            end
        end)
    end)

    Alerts.banner:SetScript("OnUpdate", OnBannerUpdate)
    Alerts.frame = eventFrame
    ns:Log("INFO", "Alerts", "Alerts engine initialized with C_UnitAuras.")
end
