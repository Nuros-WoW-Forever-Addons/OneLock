-- ============================================================================
-- OneLock_Timers - Tracker Engine
-- Multi-target Warlock DoT & CC tracking via COMBAT_LOG_EVENT_UNFILTERED
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local Tracker = {}
ns.Tracker = Tracker

-- Active tracking state: [destGUID] = { guid, name, lastSeen, spells = { [spellName] = { ... } } }
ns.activeTimers = {}

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
        local name, _, icon = GetSpellInfo(id)
        name = name or fallbackName
        if name then
            TRACKED_SPELLS[name] = {
                spellId = id,
                name = name,
                duration = baseDuration,
                icon = icon or GetSpellTexture(id),
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
-- UnitDebuff Duration Reconciliation
-------------------------------------------------------------------------------
local function ReconcileUnitDebuffs(unit)
    if not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or not ns.activeTimers[guid] then return end

    local targetEntry = ns.activeTimers[guid]
    local unitName = UnitName(unit)
    if unitName and unitName ~= "" then
        targetEntry.name = unitName
    end
    targetEntry.lastSeen = GetTime()

    local i = 1
    while true do
        local name, icon, count, debuffType, duration, expirationTime, unitCaster, _, _, spellId = UnitDebuff(unit, i)
        if not name then break end

        if unitCaster == "player" and targetEntry.spells[name] then
            local timer = targetEntry.spells[name]
            if duration and duration > 0 and expirationTime and expirationTime > 0 then
                timer.duration = duration
                timer.expirationTime = expirationTime
                timer.startTime = expirationTime - duration
            end
            if icon then
                timer.icon = icon
            end
        end
        i = i + 1
    end
end

function Tracker:ReconcileKnownUnits(targetGUID)
    if UnitGUID("target") == targetGUID then
        ReconcileUnitDebuffs("target")
    elseif UnitGUID("focus") == targetGUID then
        ReconcileUnitDebuffs("focus")
    elseif UnitGUID("mouseover") == targetGUID then
        ReconcileUnitDebuffs("mouseover")
    end
end

-------------------------------------------------------------------------------
-- Combat Log Event Consumer
-------------------------------------------------------------------------------
local function OnCombatLogEvent()
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    if not sourceGUID or sourceGUID ~= ns.playerGUID then
        return
    end

    if not destGUID or destGUID == "" then
        return
    end

    local now = GetTime()

    -- 1. Aura Applied or Refreshed
    if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
        local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
        if not spellName then return end

        local spellDef = TRACKED_SPELLS[spellName]
        if spellDef then
            local duration = spellDef.duration
            local expirationTime = now + duration
            local icon = spellDef.icon or GetSpellTexture(spellId) or ""

            if not ns.activeTimers[destGUID] then
                ns.activeTimers[destGUID] = {
                    guid = destGUID,
                    name = destName or "Unknown",
                    lastSeen = now,
                    spells = {},
                }
            else
                ns.activeTimers[destGUID].lastSeen = now
                if destName and destName ~= "" then
                    ns.activeTimers[destGUID].name = destName
                end
            end

            ns.activeTimers[destGUID].spells[spellName] = {
                spellId = spellId,
                spellName = spellName,
                icon = icon,
                startTime = now,
                duration = duration,
                expirationTime = expirationTime,
                category = spellDef.category,
            }

            -- Attempt immediate reconciliation if unit is currently targeted/focused/moused over
            Tracker:ReconcileKnownUnits(destGUID)

            if ns.Display and ns.Display.OnTimerUpdated then
                ns.Display:OnTimerUpdated()
            end
        end

    -- 2. Aura Removed, Broken, or Dispelled
    elseif subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_BROKEN" or subevent == "SPELL_AURA_BROKEN_SPELL" then
        local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
        if spellName and ns.activeTimers[destGUID] and ns.activeTimers[destGUID].spells[spellName] then
            ns.activeTimers[destGUID].spells[spellName] = nil

            local hasSpells = false
            for _ in pairs(ns.activeTimers[destGUID].spells) do
                hasSpells = true
                break
            end
            if not hasSpells then
                ns.activeTimers[destGUID] = nil
            end

            if ns.Display and ns.Display.OnTimerUpdated then
                ns.Display:OnTimerUpdated()
            end
        end

    -- 3. Target Died or Destroyed
    elseif subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
        if ns.activeTimers[destGUID] then
            ns.activeTimers[destGUID] = nil
            if ns.Display and ns.Display.OnTimerUpdated then
                ns.Display:OnTimerUpdated()
            end
        end
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
    trackerFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    trackerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    trackerFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    trackerFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    trackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    trackerFrame:SetScript("OnEvent", function(self, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent()
        elseif event == "PLAYER_TARGET_CHANGED" then
            ReconcileUnitDebuffs("target")
            if ns.Display and ns.Display.OnTargetChanged then
                ns.Display:OnTargetChanged()
            end
        elseif event == "PLAYER_FOCUS_CHANGED" then
            ReconcileUnitDebuffs("focus")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            ReconcileUnitDebuffs("mouseover")
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Refresh player GUID just in case
            ns.playerGUID = UnitGUID("player")
        end
    end)

    trackerFrame:SetScript("OnUpdate", OnGarbageCollectUpdate)
    Tracker.frame = trackerFrame
end
