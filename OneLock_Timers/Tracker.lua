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
-- Warlock Spell Database & Rank Duration Mapping
-------------------------------------------------------------------------------
local TRACKED_SPELLS = {}

-- Exact duration lookup by rank spellID (bypasses missing/secret aura durations)
local SPELL_DURATIONS_BY_ID = {
    -- Corruption (Rank 1: 12s, Rank 2: 15s, Rank 3+: 18s)
    [172]   = 12, -- Rank 1 (Level 4)
    [6222]  = 15, -- Rank 2 (Level 14)
    [6223]  = 18, -- Rank 3 (Level 24)
    [7648]  = 18, -- Rank 4 (Level 34)
    [11671] = 18, -- Rank 5 (Level 44)
    [11672] = 18, -- Rank 6 (Level 54)
    [25311] = 18, -- Rank 7 (Level 60)
    [27216] = 18, -- Rank 8 (Level 70)

    -- Fear (Rank 1: 10s, Rank 2: 15s, Rank 3: 20s)
    [5782]  = 10, -- Rank 1 (Level 8)
    [6213]  = 15, -- Rank 2 (Level 20)
    [6215]  = 20, -- Rank 3 (Level 40)

    -- Banish (Rank 1: 20s, Rank 2: 30s)
    [710]   = 20, -- Rank 1 (Level 28)
    [18647] = 30, -- Rank 2 (Level 48)

    -- Howl of Terror
    [5484]  = 10, -- Rank 1 (Level 40)
    [17928] = 15, -- Rank 2 (Level 54)

    -- Death Coil
    [6789]  = 3,
    [17925] = 3,
    [17926] = 3,
    [27223] = 3,

    -- Seduction
    [6358]  = 15,
}

local SPELL_CATALOG = {
    -- SpellID, DefaultDuration, Category, FallbackName
    { 172,   12, "DOT",   "Corruption" },
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
    { 710,   20, "CC",    "Banish" },
    { 5782,  10, "CC",    "Fear" },
    { 5484,  10, "CC",    "Howl of Terror" },
    { 6789,   3, "CC",    "Death Coil" },
    { 6358,  15, "CC",    "Seduction" },
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

-- Generates a table-safe key. Never returns a secret value.
-- Standard Lua tables cannot be indexed with secret keys in WoW Forever.
local function GetSafeUnitKey(unit, fallbackGUID)
    local guid = fallbackGUID
    if not guid and unit then
        local okG, g = pcall(UnitGUID, unit)
        if okG and g then guid = g end
    end
    if guid and not IsSecret(guid) then
        return guid
    end
    return unit or "target"
end

-------------------------------------------------------------------------------
-- Modern C_UnitAuras Scanner (Hardened against Secret Aura Taint)
-------------------------------------------------------------------------------
local function ForEachUnitDebuff(unit, callback)
    local okExists, exists = pcall(UnitExists, unit)
    if okExists and not IsSecret(exists) and exists == false then
        return
    end

    local function SafeInvoke(name, icon, count, duration, expirationTime, sourceUnit, spellId, isPlayerAura)
        if (not name or IsSecret(name)) and spellId and not IsSecret(spellId) then
            local sName = GetSpellDetails(spellId)
            if sName and not IsSecret(sName) then
                name = sName
            end
        end
        pcall(callback, name, icon, count, duration, expirationTime, sourceUnit, spellId, isPlayerAura)
    end

    -- 1. Modern C_UnitAuras.GetDebuffDataByIndex
    if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
        local i = 1
        while true do
            local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, unit, i)
            if not ok or not aura then break end
            SafeInvoke(aura.name, aura.icon, aura.applications, aura.duration, aura.expirationTime, aura.sourceUnit, aura.spellId, aura.isPlayerAura)
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
            SafeInvoke(aura.name, aura.icon, aura.applications, aura.duration, aura.expirationTime, aura.sourceUnit, aura.spellId, aura.isPlayerAura)
            i = i + 1
        end
        return
    end

    -- 3. AuraUtil.ForEachAura
    if AuraUtil and AuraUtil.ForEachAura then
        pcall(AuraUtil.ForEachAura, unit, "HARMFUL", nil, function(aura)
            if aura then
                SafeInvoke(aura.name, aura.icon, aura.applications, aura.duration, aura.expirationTime, aura.sourceUnit, aura.spellId, aura.isPlayerAura)
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
            local isPlayerAura = (unitCaster == "player")
            SafeInvoke(name, icon, count, duration, expirationTime, unitCaster, spellId, isPlayerAura)
            i = i + 1
        end
    end
end

-------------------------------------------------------------------------------
-- Scan and Reconcile Unit Debuffs (Target & Nameplate Only)
-------------------------------------------------------------------------------
local function ScanUnit(unit)
    local okExists, exists = pcall(UnitExists, unit)
    if okExists and not IsSecret(exists) and exists == false then
        return
    end

    local key = GetSafeUnitKey(unit)

    local okDead, isDead = pcall(UnitIsDead, unit)
    if okDead and not IsSecret(isDead) and isDead == true then
        if ns.activeTimers[key] then
            ns.activeTimers[key] = nil
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
        if ns.activeTimers[key] then
            ns.activeTimers[key] = nil
            if ns.Display and ns.Display.OnTimerUpdated then
                ns.Display:OnTimerUpdated()
            end
        end
        return
    end

    local okName, unitName = pcall(UnitName, unit)
    if not okName or not unitName or IsSecret(unitName) then
        unitName = (ns.activeTimers[key] and ns.activeTimers[key].name) or "Target"
    end

    local now = GetTime()
    local foundSpells = {}
    local anyAdded = false
    local anyAurasRead = false

    ForEachUnitDebuff(unit, function(name, icon, count, duration, expirationTime, sourceUnit, spellId)
        anyAurasRead = true

        if (not name or IsSecret(name)) and spellId and not IsSecret(spellId) then
            local sName = GetSpellDetails(spellId)
            if sName and not IsSecret(sName) then
                name = sName
            end
        end
        if not name or IsSecret(name) then return end

        local spellDef = TRACKED_SPELLS[name]
        if not spellDef and spellId and not IsSecret(spellId) and SPELL_DURATIONS_BY_ID[spellId] then
            local sName = GetSpellDetails(spellId)
            if sName and TRACKED_SPELLS[sName] then
                spellDef = TRACKED_SPELLS[sName]
                name = sName
            end
        end

        if not spellDef then return end

        -- Strictly verify that this debuff was cast by the player (or player pet).
        -- Never assume a nil or foreign sourceUnit belongs to the player.
        local isPlayerSource = false
        if isPlayerAura == true then
            isPlayerSource = true
        elseif sourceUnit and not IsSecret(sourceUnit) then
            if sourceUnit == "player" or sourceUnit == "pet" then
                isPlayerSource = true
            else
                local okEq, isEq = pcall(UnitIsUnit, sourceUnit, "player")
                if okEq and isEq then
                    isPlayerSource = true
                else
                    local okPet, isPet = pcall(UnitIsUnit, sourceUnit, "pet")
                    if okPet and isPet then
                        isPlayerSource = true
                    end
                end
            end
        end

        -- If not cast by the player, completely ignore this foreign aura
        if isPlayerSource then
            local rankDur = (spellId and not IsSecret(spellId) and SPELL_DURATIONS_BY_ID[spellId])
            local effDuration = (hasDuration and duration) or rankDur or spellDef.duration
            local hasExp = expirationTime and not IsSecret(expirationTime) and expirationTime > 0
            local effExpiration = hasExp and expirationTime or (now + effDuration)
            local effIcon = icon or spellDef.icon

            if not ns.activeTimers[key] then
                ns.activeTimers[key] = {
                    key = key,
                    name = unitName,
                    lastSeen = now,
                    spells = {},
                }
            else
                ns.activeTimers[key].name = unitName
                ns.activeTimers[key].lastSeen = now
            end

            ns.activeTimers[key].spells[name] = {
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
    -- 3.0s grace period allows network/aura latency before pruning a freshly cast debuff.
    if anyAurasRead and ns.activeTimers[key] then
        local removedAny = false
        for activeName, activeTimer in pairs(ns.activeTimers[key].spells) do
            if not foundSpells[activeName] then
                local age = now - (activeTimer.startTime or 0)
                if age > 3.0 then
                    ns.activeTimers[key].spells[activeName] = nil
                    removedAny = true
                end
            end
        end

        local count = 0
        for _ in pairs(ns.activeTimers[key].spells) do
            count = count + 1
        end

        if count == 0 then
            ns.activeTimers[key] = nil
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
local lastCastTargetKey = "target"

local function SafeNameMatch(unitToken, targetName)
    if not targetName or IsSecret(targetName) then return false end
    local ok, uName = pcall(UnitName, unitToken)
    if not ok or not uName or IsSecret(uName) then return false end
    local okEq, isEq = pcall(function() return uName == targetName end)
    return okEq and isEq
end

local function OnSpellcastSent(unit, target, castGUID, spellID)
    if unit == "player" then
        if target and not IsSecret(target) then
            lastCastTargetName = target
        else
            lastCastTargetName = nil
        end

        if SafeNameMatch("mouseover", target) then
            lastCastTargetKey = GetSafeUnitKey("mouseover")
        elseif SafeNameMatch("focus", target) then
            lastCastTargetKey = GetSafeUnitKey("focus")
        else
            lastCastTargetKey = GetSafeUnitKey("target")
        end
    end
end

local function OnPlayerSpellcastSucceeded(spellID)
    if not spellID or IsSecret(spellID) then return end
    local spellName, icon = GetSpellDetails(spellID)
    if not spellName or IsSecret(spellName) then return end

    local spellDef = TRACKED_SPELLS[spellName]
    if not spellDef then return end

    local effDuration = (SPELL_DURATIONS_BY_ID and SPELL_DURATIONS_BY_ID[spellID]) or spellDef.duration

    local key = lastCastTargetKey or GetSafeUnitKey("target")

    local targetName = lastCastTargetName
    if not targetName or IsSecret(targetName) then
        local okName, uName = pcall(UnitName, "target")
        if okName and uName and not IsSecret(uName) then
            targetName = uName
        else
            targetName = (ns.activeTimers[key] and ns.activeTimers[key].name) or "Target"
        end
    end

    local now = GetTime()
    local effExpiration = now + effDuration
    local effIcon = (icon and icon ~= "") and icon or spellDef.icon

    if not ns.activeTimers[key] then
        ns.activeTimers[key] = {
            key = key,
            name = targetName,
            lastSeen = now,
            spells = {},
        }
    else
        ns.activeTimers[key].name = targetName
        ns.activeTimers[key].lastSeen = now
    end

    ns.activeTimers[key].spells[spellName] = {
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
    local _, playerClass = UnitClass("player")
    if playerClass ~= "WARLOCK" then
        return
    end

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
            local okDead, isDead = pcall(UnitIsDead, "target")
            local key = GetSafeUnitKey("target")
            if okDead and not IsSecret(isDead) and isDead == true then
                if ns.activeTimers[key] then
                    ns.activeTimers[key] = nil
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
            if unit then
                local key = GetSafeUnitKey(unit)
                local okDead, isDead = pcall(UnitIsDead, unit)
                if okDead and not IsSecret(isDead) and isDead == true then
                    if ns.activeTimers[key] then
                        ns.activeTimers[key] = nil
                        if ns.Display and ns.Display.OnTimerUpdated then
                            ns.Display:OnTimerUpdated()
                        end
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
