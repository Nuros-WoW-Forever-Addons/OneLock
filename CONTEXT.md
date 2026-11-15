# AI Context & Living Specification — OneLock Suite

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Suite**: OneLock (Modular Warlock Suite)
- **Current Version**: 0.1.0
- **Suite**: Part of the **OneSuite** family (`OnePanel`, `OnePanelUtils`, `MovableFrames`, `OneStorage`)
- **GitHub Repository**:
  - Exists: FALSE *(Will be created at `https://github.com/Nuros-WoW-Forever-Addons/OneLock`)*
- **Branching Policy**: All new features must be developed on a branch != `main` (active: `dev`)
- **Live Sync Path**: `/Applications/World of Warcraft/_forever_/Interface/AddOns/` (Modules: `OneLock_Timers`, `OneLock_Shards`, `OneLock_Procs`)
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OneLock-latest.zip` on push to `main`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Provide a streamlined, high-signal raid utility suite for Warlocks without Necrosis bloat (no spherical 3D HUDs, pop-out demon menus, or RP chat spam), featuring:
  1. **Multi-Target DoT & CC Engine (`OneLock_Timers`)**: Real-time combat-log-driven aura duration tracking across multiple raid targets with 3.0s Pandemic refresh indication.
  2. **Soul Shard & Soulstone Manager (`OneLock_Shards`)**: Inventory soul shard threshold management, out-of-combat excess cleanup, and persistent 30-minute Soulstone target tracker.
  3. **Proc & Immunity Alerts (`OneLock_Procs`)**: High-visibility reactive alerts for Shadow Trance (Nightfall) and Backlash procs, plus target CC immunity notifications (Fear/Banish).

---

## 🏗️ Architecture & Component Map

### Repository Structure
```text
OneLock/
├── CONTEXT.md
├── README.md
├── CHANGELOG.md
├── OneLock_Timers/
│   ├── OneLock_Timers.toc
│   ├── Core.lua
│   ├── Tracker.lua
│   └── Display.lua
├── OneLock_Shards/
│   ├── OneLock_Shards.toc
│   ├── Core.lua
│   ├── ShardManager.lua
│   └── SoulstoneTracker.lua
└── OneLock_Procs/
    ├── OneLock_Procs.toc
    ├── Core.lua
    └── Alerts.lua
```

### Module Breakdown
- **`OneLock_Timers`** (Priority 1):
  - `OneLock_Timers.toc`: Manifest, SavedVariables `OneLockTimersDB`, optional dependencies on `OnePanel`, `OnePanelUtils`, `MovableFrames`.
  - `Core.lua`: Namespace initialization (`OneLock_Timers`), SavedVariables schema defaults, slash command handler (`/onelock`, `/ol`), MovableFrames registration, and OnePanel integration.
  - `Tracker.lua`: Multi-target combat log event consumer (`COMBAT_LOG_EVENT_UNFILTERED`) filtered to player GUID. Tracks DoTs and CCs by `destGUID` and `destName`. Reconciles remaining duration against `UnitDebuff` whenever target/focus/mouseover matches `destGUID`. Purges on `UNIT_DIED`/`UNIT_DESTROYED` and provides an OnUpdate garbage collector.
  - `Display.lua`: Non-protected frame pool manager (`StatusBar` + Target Headers). Renders vertical groups anchored to `OneLockTimersAnchor`. Highlights current target header, updates countdown text, and shifts bar color to gold/amber when remaining duration is under the 3.0s Pandemic threshold. Includes simulated test mode (`/ol test`).
- **`OneLock_Shards`** (Priority 2):
  - `OneLock_Shards.toc`: Manifest, SavedVariables `OneLockShardsDB`.
  - `Core.lua`: Namespace initialization (`OneLock_Shards`), DB setup, slash command handler (`/olshards`).
  - `ShardManager.lua`: Tracks Soul Shard (itemID 6265) counts on `BAG_UPDATE`. Provides safe out-of-combat deletion routines for shards exceeding a configurable cap (default 24).
  - `SoulstoneTracker.lua`: Listens for Soulstone Resurrection cast/aura applications, displaying a persistent 30-minute expiration bar and tracking target alive/dead status.
- **`OneLock_Procs`** (Priority 3):
  - `OneLock_Procs.toc`: Manifest, SavedVariables `OneLockProcsDB`.
  - `Core.lua`: Namespace initialization (`OneLock_Procs`), DB setup, slash command handler (`/olprocs`).
  - `Alerts.lua`: Event hooks for `UNIT_AURA` (player) detecting Shadow Trance (Nightfall) and Backlash procs, plus `SPELL_MISSED` (`IMMUNE`) combat log parsing for Fear and Banish.

---

## ⚡ Technical Architecture & Interface 16001 API Rules

### Target Client: WoW Forever Beta (`v1.60.1` / `Interface: 16001`)
- **Exclusive API Set**: All code targets the WoW Forever v1.60.1 client directly.
- **No Retail / TWW APIs**: Do NOT use `C_Container.*`, `C_Spell.*`, `C_UnitAuras.*`, or modernized retail payload unpackers.
- **Combat Log Parsing (`COMBAT_LOG_EVENT_UNFILTERED`)**:
  - Event signature payload:
    ```lua
    local timestamp, subevent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags,
          spellId, spellName, spellSchool,
          auraType, amount = CombatLogGetCurrentEventInfo()
    ```
  - Subevents tracked:
    - `SPELL_AURA_APPLIED`: Create or reset tracked timer for player-cast spells.
    - `SPELL_AURA_REFRESH`: Reset timer to full duration.
    - `SPELL_AURA_REMOVED`, `SPELL_AURA_BROKEN`, `SPELL_AURA_BROKEN_SPELL`: Remove specific timer for `(destGUID, spellName)`.
    - `UNIT_DIED`, `UNIT_DESTROYED`: Purge all active timers associated with `destGUID`.
    - `SPELL_MISSED` (with missType == `"IMMUNE"`): Notify immunity alert in `OneLock_Procs`.
- **Authoritative UnitDebuff Reconciliation**:
  - Combat log events provide aura start times, but not exact durations modified by talents, haste, or combo ranks.
  - When the player targets, focuses, or mouses over a unit whose GUID matches an active `destGUID`, `Tracker.lua` scans `UnitDebuff(unit, i)`:
    ```lua
    local name, icon, count, debuffType, duration, expirationTime, unitCaster = UnitDebuff(unit, i)
    ```
  - If `unitCaster == "player"` and `name == spellName`, the tracked entry's `duration` and `expirationTime` are reconciled with client-authoritative values.

---

## 🛡️ Combat Lockdown Restrictions & UI Safety

- **No SecureActionButtonTemplate Mutability**: Never dynamically create, resize, re-anchor, or mutate secure protected action frames while `InCombatLockdown()` is true.
- **Lightweight Non-Protected Frame Pool**: All timer bars and headers in `OneLock_Timers` are non-protected `Frame` and `StatusBar` objects created via an internal frame pool. They can update, re-anchor, show, and hide during raid combat with zero taint risk.
- **Out-of-Combat Action Safety**: Destructive inventory operations (e.g. `ShardManager.lua` deleting excess soul shards via `PickupContainerItem` and `DeleteCursorItem`) are strictly gated by `not InCombatLockdown()` and queued until `PLAYER_REGEN_ENABLED` if triggered during combat.

---

## 💾 SavedVariables Schemas

### `OneLockTimersDB`
```lua
OneLockTimersDB = {
    version = 1,
    locked = false,                    -- Anchor movement lock
    barWidth = 160,                    -- Width of each timer bar (100 - 300)
    barHeight = 16,                    -- Height of each timer bar (10 - 32)
    barScale = 1.0,                    -- Overall frame scale (0.5 - 2.0)
    maxVisibleTargets = 5,             -- Maximum targets to display simultaneously (1 - 10)
    pandemicThreshold = 3.0,           -- Seconds remaining to trigger Pandemic highlight
    showSpellIcon = true,              -- Display spell texture on left of bar
    showTargetHeader = true,           -- Display target name banner above target bars
    colorNormal = { r = 0.6, g = 0.2, b = 0.8, a = 0.9 },     -- Warlock purple
    colorPandemic = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 },  -- Pandemic amber/gold
    colorTargetHeader = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }, -- Selected target header
    colorNonTargetHeader = { r = 0.7, g = 0.7, b = 0.7, a = 1.0 }, -- Other target header
    position = {                       -- Screen position of master anchor
        point = "CENTER",
        relativePoint = "CENTER",
        x = 150,
        y = 0,
    },
}
```

### `OneLockShardsDB`
```lua
OneLockShardsDB = {
    version = 1,
    maxShards = 24,                    -- Maximum Soul Shards to keep in inventory
    autoDeleteExcess = false,          -- Automatically delete excess shards when out of combat
    showSoulstoneBar = true,           -- Display 30-minute soulstone expiration bar
    soulstoneAnchor = {
        point = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        x = 250,
        y = 200,
    },
}
```

### `OneLockProcsDB`
```lua
OneLockProcsDB = {
    version = 1,
    enableNightfall = true,            -- Shadow Trance alert
    enableBacklash = true,             -- Backlash alert
    enableImmunityAlert = true,        -- Fear/Banish target immunity alert
    playAudio = true,                  -- Sound alert trigger
    alertScale = 1.2,                  -- Visual banner scale
}
```

---

## 🔌 Integration Hooks & Sibling Addon Ecosystem

### `MovableFrames` Integration
- `OneLockTimersAnchor` automatically registers with `MovableFrames` if present:
  ```lua
  if MovableFramesDB and MovableFramesDB.customFrames then
      MovableFramesDB.customFrames["OneLockTimersAnchor"] = true
  end
  ```
- Supports independent positioning and scaling through MovableFrames HUD edit mode or native `/ol unlock` drag handles.

### `OnePanel` & `OnePanelUtils` Integration
- Integrates optional tab in `OnePanel` via `OnePanel:RegisterPlugin` when `OnePanel` is loaded.
- Employs `OnePanelUtils.Logger` if available for structured debugging.

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:
1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and the active backlog item for this spin.
2. **Implementation**: Execute changes adhering strictly to the WoW Forever v1.60.1 / Interface 16001 single-client rules.
3. **Verification**: Verify in-game syntax and test using slash commands (`/ol`, `/ol test`, `/ol lock`, `/ol reset`).
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.1.0 (Initial Scaffold & Multi-Target DoT Engine)
- Initialized modular repository structure (`OneLock_Timers`, `OneLock_Shards`, `OneLock_Procs`).
- Built complete `OneLock_Timers` multi-target DoT and CC tracking engine:
  - Combat log event consumer filtering `sourceGUID == UnitGUID("player")`.
  - Comprehensive spell table supporting Corruption, Unstable Affliction, Curse/Bane of Agony, Curse of Doom, Curse of the Elements, Curse of Recklessness, Curse of Tongues, Curse of Weakness, Siphon Life, Immolate, Seed of Corruption, Banish, and Fear.
  - Client-authoritative `UnitDebuff` duration reconciliation on target, focus, and mouseover change.
  - Automatic purging on `UNIT_DIED` and `UNIT_DESTROYED` with OnUpdate garbage collection.
  - Frame pool architecture (`StatusBar` and target header frames) grouped vertically by `destGUID`.
  - Target highlighting, dynamic countdowns, and Pandemic (< 3.0s) color shifting.
  - Movable master anchor `OneLockTimersAnchor` with `/ol lock`, `/ol unlock`, `/ol reset`, and simulated `/ol test` mode.
- Scaffolded loadable `.toc` and `Core.lua` modules for `OneLock_Shards` and `OneLock_Procs`.
- Integrated `sync-live.sh` and `rollback-live.sh` suite syncing.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **OneLock_Shards Full Implementation**: Implement active `BAG_UPDATE` shard counting badge and out-of-combat `DeleteCursorItem()` garbage collection loop.
- [ ] **Soulstone Expiration Tracker**: Implement the 30-minute persistent soulstone HUD bar with unit alive/dead detection.

### Priority 2: Medium Priority (Enhancements)
- [ ] **OneLock_Procs Full Implementation**: Implement screen-center proc banners for Nightfall (`Shadow Trance`) and Backlash with custom textures and sound effects.
- [ ] **Target CC Immunity Banner**: Add combat log `SPELL_MISSED` immunity toast when a target resists/immunes Banish or Fear.

### Priority 3: Low Priority / Quality of Life
- [ ] **OnePanel Options Canvas**: Create an interactive graphical options panel inside OnePanel for configuring bar colors, textures, and spell blacklists.
- [ ] **Sound Alerts for Pandemic Window**: Optional audio click/tick when a DoT enters the 3.0s Pandemic refresh window.

---

## 🧪 Testing & Verification Guide

- **Toggle Test Bars**: `/ol test` — displays simulated multi-target DoT bars for layout inspection.
- **Unlock Master Anchor**: `/ol unlock` — displays movable drag handle labeled "OneLock Timers (Drag to Move)".
- **Lock Master Anchor**: `/ol lock` — hides drag handle and saves coordinates to `OneLockTimersDB.position`.
- **Reset Anchor Position**: `/ol reset` — repositions anchor to screen center.
- **Adjust Bar Scale**: `/ol scale 1.2` — sets scale to 120%.
- **Adjust Bar Width**: `/ol width 180` — sets width to 180px.
