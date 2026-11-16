-- ============================================================================
-- OneLock_Timers - Tracker Engine
-- Multi-target Warlock DoT & CC tracking via modern C_UnitAuras & Nameplate events
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local Tracker = {}
ns.Tracker = Tracker

-- Active tracking state: [destGUID] = { guid, name, lastSeen, spells = { [spellName] = { ... } } }
ns.activeTimers = {}

-------------------------------------------------------------------------------
-- Modern Spell API Helper (C_Spell.GetSpellInfo returns a table on Forever)
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
-- Warlock Spell Database & Definitions
-------------------------------------------------------------------------------
local TRACKED_SPELLS = {}

local SPELL_CATALOG = {
    -- SpellID, BaseDuration, Category, FallbackName
    { 172,   18, "DOT",   "Corruption" },
    { 30108, 15, "DOT",   "Unstable Affliction" },
    { 980,   24, "CURSE", "Curse of Agony" },
    { 603,   60, "CURSE", "Curse of Doom" },
    { 1490, 300, "CURSE", "Curse of the Elements" },
    { 702,  120, "CURSE", "Curse of Recklessness" },
    { 1714,  30, "CURSE", "Curse of Tongues" },
    { 1108, 120, "CURSE", "Curse of Weakness" },
    { 18265, 30, "DOT",   "Siphon Life" },
    { 348,   15, "DOT",   "Immolate" },
    { 27243, 18, "DOT",   "Seed of Corruption" },
    { 710,   30, "CC",    "Banish" },
    { 5782,  20, "CC",    "Fear" },
}

local function InitSpellCatalog()
    for _, def in ipairs(SPELL_CATALOG) do
        local id, baseDuration, category, fallbackName = unpack(def)
        local name, icon = GetSpellDetails(id)
        name = name or fallbackName
        if name then
            TRACKED_SPELLS[name] = {
                spellId = id,
                name = name,
                duration = baseDuration,
                icon = icon or "",
                category = category,
            }
        end
    end

    -- Support Bane variants if present in client database
    if not TRACKED_SPELLS["Bane of Agony"] and TRACKED_SPELLS["Curse of Agony"] then
        TRACKED_SPELLS["Bane of Agony"] = TRACKED_SPELLS["Curse of Agony"]
    end
    if not TRACKED_SPELLS["Bane of Doom"] and TRACKED_SPELLS["Curse of Doom"] then
        TRACKED_SPELLS["Bane of Doom"] = TRACKED_SPELLS["Curse of Doom"]
    end
end

-------------------------------------------------------------------------------
-- Secret Value Helper (WoW Forever Interface 16001 / Midnight Safety)
-------------------------------------------------------------------------------
local function IsSecret(val)
    return issecretvalue and issecretvalue(val)
end

-------------------------------------------------------------------------------
-- Modern C_UnitAuras Scanner (Hardened against Secret Aura Taint)
-------------------------------------------------------------------------------
local function ForEachUnitDebuff(unit, callback)
    local okExists, exists = pcall(UnitExists, unit)
    if not okExists or not exists or IsSecret(exists) then return end

    -- 1. Modern C_UnitAuras.GetDebuffDataByIndex
    if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
        local i = 1
        while true do
            local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, unit, i)
            if not ok or not aura then break end
            if not (IsSecret(aura.name) or IsSecret(aura.spellId)) then
                callback(aura.name, aura.icon, aura.applications, aura.duration, aura.expirationTime, aura.sourceUnit, aura.spellId)
            end
            i = i + 1
        end
        return
    end

    -- 2. Modern C_UnitAuras.GetAuraDataByIndex (Harmful)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local i = 1
        while true do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok or not aura then break end
            if not (IsSecret(aura.name) or IsSecret(aura.spellId)) then
                callback(aura.name, aura.icon, aura.applications, aura.duration, aura.expirationTime, aura.sourceUnit, aura.spellId)
            end
            i = i + 1
        end
        return
    end

    -- 3. AuraUtil.ForEachAura
    if AuraUtil and AuraUtil.ForEachAura then
        pcall(AuraUtil.ForEachAura, unit, "HARMFUL", nil, function(aura)
            if aura and not (IsSecret(aura.name) or IsSecret(aura.spellId)) then
                callback(aura.name, aura.icon, aura.applications, aura.duration, aura.expirationTime, aura.sourceUnit, aura.spellId)
            end
        end)
        return
    end

    -- 4. Legacy UnitDebuff fallback
    if _G.UnitDebuff then
        local i = 1
        while true do
            local ok, name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellId = pcall(_G.UnitDebuff, unit, i)
            if not ok or not name then break end
            if not (IsSecret(name) or IsSecret(spellId)) then
                callback(name, icon, count, duration, expirationTime, unitCaster, spellId)
            end
            i = i + 1
        end
    end
end

-------------------------------------------------------------------------------
-- Scan and Reconcile Unit Debuffs (Target & Nameplate Only)
-------------------------------------------------------------------------------
local function ScanUnit(unit)
    local okExists, exists = pcall(UnitExists, unit)
    if not okExists or not exists or IsSecret(exists) then return end

    local okDead, isDead = pcall(UnitIsDead, unit)
    if not okDead or isDead or IsSecret(isDead) then
        local okGuid, deadGUID = pcall(UnitGUID, unit)
        if okGuid and deadGUID and not IsSecret(deadGUID) and ns.activeTimers[deadGUID] then
            ns.activeTimers[deadGUID] = nil
            if ns.Display and ns.Display.OnTimerUpdated then
                ns.Display:OnTimerUpdated()
            end
        end
        return
    end

    -- Filter out friendly/unattackable units (charmed critters, party members, pets)
    -- Warlock offensive DoTs and CCs can only exist on attackable hostile units.
    local okAttack, canAttack = pcall(UnitCanAttack, "player", unit)
    if okAttack and not IsSecret(canAttack) and canAttack == false then
        local okGuid, nonHostileGUID = pcall(UnitGUID, unit)
        if okGuid and nonHostileGUID and not IsSecret(nonHostileGUID) and ns.activeTimers[nonHostileGUID] then
            ns.activeTimers[nonHostileGUID] = nil
            if ns.Display and ns.Display.OnTimerUpdated then
                ns.Display:OnTimerUpdated()
            end
        end
        return
    end

    local okGuid, guid = pcall(UnitGUID, unit)
    if not okGuid or not guid or IsSecret(guid) then return end

    local okName, unitName = pcall(UnitName, unit)
    if not okName or not unitName or IsSecret(unitName) then
        unitName = "Unknown"
    end

    local now = GetTime()
    local foundSpells = {}
    local anyAdded = false
    local anyAurasRead = false

    ForEachUnitDebuff(unit, function(name, icon, count, duration, expirationTime, sourceUnit, spellId)
        anyAurasRead = true

        -- Only track debuffs cast by the player
        local hasDuration = duration and not IsSecret(duration) and duration > 0
        local isPlayerSource = (sourceUnit == "player") or (sourceUnit == nil and hasDuration)
        if isPlayerSource and name and not IsSecret(name) and (TRACKED_SPELLS[name] or (spellId and not IsSecret(spellId) and TRACKED_SPELLS[spellId])) then
            local spellDef = TRACKED_SPELLS[name] or TRACKED_SPELLS[spellId]
            local effDuration = hasDuration and duration or spellDef.duration
            local hasExp = expirationTime and not IsSecret(expirationTime) and expirationTime > 0
            local effExpiration = hasExp and expirationTime or (now + effDuration)
            local effIcon = icon or spellDef.icon

            if not ns.activeTimers[guid] then
                ns.activeTimers[guid] = {
                    guid = guid,
                    name = unitName,
                    lastSeen = now,
                    spells = {},
                }
            else
                ns.activeTimers[guid].name = unitName
                ns.activeTimers[guid].lastSeen = now
            end

            ns.activeTimers[guid].spells[name] = {
                spellId = (spellId and not IsSecret(spellId) and spellId) or spellDef.spellId,
                spellName = name,
                icon = effIcon,
                startTime = effExpiration - effDuration,
                duration = effDuration,
                expirationTime = effExpiration,
                category = spellDef.category,
            }

            foundSpells[name] = true
            anyAdded = true
        end
    end)

    -- If this unit was previously tracked, ONLY prune if we successfully read real auras from it.
    -- If aura scanning was blocked by combat secret taint, keep active timers running!
    if anyAurasRead and ns.activeTimers[guid] then
        local removedAny = false
        for activeName, _ in pairs(ns.activeTimers[guid].spells) do
            if not foundSpells[activeName] then
                ns.activeTimers[guid].spells[activeName] = nil
                removedAny = true
            end
        end

        local count = 0
        for _ in pairs(ns.activeTimers[guid].spells) do
            count = count + 1
        end

        if count == 0 then
            ns.activeTimers[guid] = nil
            removedAny = true
        end

        if (anyAdded or removedAny) and ns.Display and ns.Display.OnTimerUpdated then
            ns.Display:OnTimerUpdated()
        end
    elseif anyAdded and ns.Display and ns.Display.OnTimerUpdated then
        ns.Display:OnTimerUpdated()
    end
end

-------------------------------------------------------------------------------
-- Player Spellcast Engine (Combat Secret Immunity)
-------------------------------------------------------------------------------
local lastCastTargetName = nil
local lastCastTargetGUID = nil

local function OnSpellcastSent(unit, target, castGUID, spellID)
    if unit == "player" then
        lastCastTargetName = target
        local curTargetName = UnitName("target")
        if target and curTargetName and not IsSecret(curTargetName) and curTargetName == target then
            lastCastTargetGUID = UnitGUID("target")
        elseif target and UnitName("focus") == target then
            lastCastTargetGUID = UnitGUID("focus")
        elseif target and UnitName("mouseover") == target then
            lastCastTargetGUID = UnitGUID("mouseover")
        else
            lastCastTargetGUID = UnitGUID("target")
        end
    end
end

local function OnPlayerSpellcastSucceeded(spellID)
    if not spellID or IsSecret(spellID) then return end
    local spellName, icon = GetSpellDetails(spellID)
    if not spellName or IsSecret(spellName) then return end

    local spellDef = TRACKED_SPELLS[spellName]
    if not spellDef then return end

    local targetGUID = lastCastTargetGUID or UnitGUID("target")
    local targetName = lastCastTargetName or UnitName("target")

    if not targetGUID or IsSecret(targetGUID) then return end
    if not targetName or IsSecret(targetName) then targetName = "Target" end

    local now = GetTime()
    local effDuration = spellDef.duration
    local effExpiration = now + effDuration
    local effIcon = (icon and icon ~= "") and icon or spellDef.icon

    if not ns.activeTimers[targetGUID] then
        ns.activeTimers[targetGUID] = {
            guid = targetGUID,
            name = targetName,
            lastSeen = now,
            spells = {},
        }
    else
        ns.activeTimers[targetGUID].name = targetName
        ns.activeTimers[targetGUID].lastSeen = now
    end

    ns.activeTimers[targetGUID].spells[spellName] = {
        spellId = spellID,
        spellName = spellName,
        icon = effIcon,
        startTime = now,
        duration = effDuration,
        expirationTime = effExpiration,
        category = spellDef.category,
    }

    if ns.Display and ns.Display.OnTimerUpdated then
        ns.Display:OnTimerUpdated()
    end
end

-------------------------------------------------------------------------------
-- Background Garbage Collection (Expired Timers)
-------------------------------------------------------------------------------
local gcTimer = 0
local function OnGarbageCollectUpdate(self, elapsed)
    gcTimer = gcTimer + elapsed
    if gcTimer < 0.25 then return end
    gcTimer = 0

    local now = GetTime()
    local changed = false

    for guid, targetData in pairs(ns.activeTimers) do
        for spellName, timer in pairs(targetData.spells) do
            if timer.expirationTime and timer.expirationTime <= now then
                targetData.spells[spellName] = nil
                changed = true
            end
        end

        local hasSpells = false
        for _ in pairs(targetData.spells) do
            hasSpells = true
            break
        end

        if not hasSpells then
            ns.activeTimers[guid] = nil
            changed = true
        end
    end

    if changed and ns.Display and ns.Display.OnTimerUpdated then
        ns.Display:OnTimerUpdated()
    end
end

-------------------------------------------------------------------------------
-- Tracker Initialization & Event Binding
-------------------------------------------------------------------------------
function Tracker:Initialize()
    ns.playerGUID = UnitGUID("player")
    InitSpellCatalog()

    local trackerFrame = CreateFrame("Frame", "OneLock_Timers_TrackerFrame")
    trackerFrame:RegisterEvent("UNIT_AURA")
    trackerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    trackerFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    trackerFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    trackerFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    trackerFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    trackerFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
    trackerFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    trackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    trackerFrame:SetScript("OnEvent", function(self, event, unit, arg2, arg3, arg4)
        if event == "UNIT_AURA" then
            if unit then
                ScanUnit(unit)
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            if UnitExists("target") and UnitIsDead("target") then
                local guid = UnitGUID("target")
                if guid and not IsSecret(guid) and ns.activeTimers[guid] then
                    ns.activeTimers[guid] = nil
                    if ns.Display and ns.Display.OnTimerUpdated then
                        ns.Display:OnTimerUpdated()
                    end
                end
            else
                ScanUnit("target")
            end
            if ns.Display and ns.Display.OnTargetChanged then
                ns.Display:OnTargetChanged()
            end
        elseif event == "PLAYER_FOCUS_CHANGED" then
            ScanUnit("focus")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            ScanUnit("mouseover")
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            if unit then
                ScanUnit(unit)
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if unit and UnitIsDead(unit) then
                local guid = UnitGUID(unit)
                if guid and not IsSecret(guid) and ns.activeTimers[guid] then
                    ns.activeTimers[guid] = nil
                    if ns.Display and ns.Display.OnTimerUpdated then
                        ns.Display:OnTimerUpdated()
                    end
                end
            end
        elseif event == "UNIT_SPELLCAST_SENT" then
            OnSpellcastSent(unit, arg2, arg3, arg4)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
            local spellID = (type(arg3) == "number" and arg3) or (type(arg2) == "number" and arg2)
            if spellID then
                OnPlayerSpellcastSucceeded(spellID)
            end
            ScanUnit("target")
        elseif event == "PLAYER_REGEN_ENABLED" then
            ns.playerGUID = UnitGUID("player")
        end
    end)

    trackerFrame:SetScript("OnUpdate", OnGarbageCollectUpdate)
    Tracker.frame = trackerFrame
    ns:Log("INFO", "Tracker", "Modern Tracker initialized with C_UnitAuras and spellcast engine.")
end
