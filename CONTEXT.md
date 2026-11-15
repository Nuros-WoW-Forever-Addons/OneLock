# AI Context & Living Specification — OneLock Suite

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Suite**: OneLock (Modular Warlock Suite)
- **Current Version**: 0.1.1
- **Suite**: Independent Warlock suite in the `Nuros-WoW-Forever-Addons` ecosystem
- **GitHub Repository**:
  - Exists: FALSE *(Will be created at `https://github.com/Nuros-WoW-Forever-Addons/OneLock`)*
- **Branching Policy**: All new features must be developed on a branch != `main` (active: `dev`)
- **Live Sync Path**: `/Applications/World of Warcraft/_forever_/Interface/AddOns/` (Modules: `OneLock_Timers`, `OneLock_Shards`, `OneLock_Procs`)
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OneLock-latest.zip` on push to `main`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Provide a streamlined, high-signal raid utility suite for Warlocks without Necrosis bloat (no spherical 3D HUDs, pop-out demon menus, or RP chat spam), featuring:
  1. **Multi-Target DoT & CC Engine (`OneLock_Timers`)**: Real-time aura duration tracking across multiple raid targets with 3.0s Pandemic refresh indication.
  2. **Soul Shard & Soulstone Manager (`OneLock_Shards`)**: Inventory soul shard threshold management, out-of-combat excess cleanup, and persistent 30-minute Soulstone target tracker.
  3. **Proc & Immunity Alerts (`OneLock_Procs`)**: High-visibility reactive alerts for Shadow Trance (Nightfall) and Backlash procs, plus target CC immunity notifications (Fear/Banish).
- **Diagnostics & Debug Integration**: Seamless optional integration with `OneSwatter` (`OneSwatter:Log`). No dependencies on `OnePanel` or `MovableFrames`.

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
- **`OneLock_Timers`**:
  - `OneLock_Timers.toc`: Manifest, SavedVariables `OneLockTimersDB`, optional dependency on `OneSwatter`. Zero dependency on `OnePanel` or `MovableFrames`.
  - `Core.lua`: Namespace initialization (`OneLock_Timers`), SavedVariables schema defaults, slash command handler (`/onelock`, `/ol`), independent anchor drag management, and `OneSwatter:Log` diagnostic hooks.
  - `Tracker.lua`: Multi-target aura tracking engine using modern `C_UnitAuras` and nameplate routing (`NAME_PLATE_UNIT_ADDED`/`REMOVED`, `UNIT_AURA`, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `UNIT_SPELLCAST_SUCCEEDED`).
  - `Display.lua`: Non-protected frame pool manager (`StatusBar` + Target Headers). Renders vertical groups anchored to `OneLockTimersAnchor`. Highlights current target header, updates countdown text, and shifts bar color to gold/amber when remaining duration is under the 3.0s Pandemic threshold. Includes simulated test mode (`/ol test`).
- **`OneLock_Shards`**:
  - `OneLock_Shards.toc`: Manifest, SavedVariables `OneLockShardsDB`, optional dependency on `OneSwatter`.
  - `Core.lua`: Namespace initialization (`OneLock_Shards`), DB setup, slash command handler (`/olshards`).
  - `ShardManager.lua`: Tracks Soul Shard (itemID 6265) counts on `BAG_UPDATE` using modern `C_Container` APIs (`C_Container.GetContainerNumSlots`, `C_Container.GetContainerItemID`). Provides safe out-of-combat deletion routines for shards exceeding a configurable cap (default 24).
  - `SoulstoneTracker.lua`: Listens for `UNIT_SPELLCAST_SUCCEEDED` on Soulstone spells, displaying a persistent 30-minute expiration bar and tracking target alive/dead status.
- **`OneLock_Procs`**:
  - `OneLock_Procs.toc`: Manifest, SavedVariables `OneLockProcsDB`, optional dependency on `OneSwatter`.
  - `Core.lua`: Namespace initialization (`OneLock_Procs`), DB setup, slash command handler (`/olprocs`).
  - `Alerts.lua`: Event hooks for `UNIT_AURA` (`player`) detecting Shadow Trance (Nightfall) and Backlash procs via `C_UnitAuras.GetPlayerAuraBySpellID`, plus `UI_ERROR_MESSAGE` parsing for Fear and Banish target immunities.

---

## ⚡ Technical Architecture & Verified Interface 16001 API Rules

### Target Client: WoW Forever Beta (`v1.60.1` / `Interface: 16001`, codename *Camelot*)
- **Modern Mainline UI Architecture**: Forever shares Mainline's modern UI architecture with Midnight addon disarmament active.
- **Modern C_ APIs (Absent Legacy Globals)**:
  - `GetSpellInfo` is **absent/nil**. Always use `C_Spell.GetSpellInfo` (returns table) or `C_Spell.GetSpellName`.
  - `GetContainerNumSlots` and `GetContainerItemID` are **absent/nil**. Always use `C_Container.GetContainerNumSlots` and `C_Container.GetContainerItemID`.
  - `UnitBuff` and `UnitDebuff` are **absent/nil**. Always use `C_UnitAuras.GetPlayerAuraBySpellID`, `C_UnitAuras.GetDebuffDataByIndex`, or `C_UnitAuras.GetAuraDataByIndex`.
- **Combat Disarmament**:
  - `COMBAT_LOG_EVENT_UNFILTERED` is disarmed/forbidden by the engine; attempting to call `RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` throws a fatal engine error.
  - Multi-target tracking is routed through supported unit tokens (`"target"`, `"focus"`, `"mouseover"`, `"nameplate1"`..`"nameplate40"`, `"boss1"`..`"boss5"`) via `UNIT_AURA` and `NAME_PLATE_UNIT_ADDED`/`REMOVED`.

---

## 🛡️ Combat Lockdown Restrictions & UI Safety

- **No SecureActionButtonTemplate Mutability**: Never dynamically create, resize, re-anchor, or mutate secure protected action frames while `InCombatLockdown()` is true.
- **Lightweight Non-Protected Frame Pool**: All timer bars and headers in `OneLock_Timers` are non-protected `Frame` and `StatusBar` objects created via an internal frame pool. They can update, re-anchor, show, and hide during active raid combat with zero taint risk.
- **Out-of-Combat Action Safety**: Destructive inventory operations (e.g. `ShardManager.lua` deleting excess soul shards via `C_Container.PickupContainerItem` and `DeleteCursorItem`) are strictly gated by `not InCombatLockdown()` and queued until `PLAYER_REGEN_ENABLED` if triggered during combat.

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
        x = 160,
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

## 🔌 Diagnostics Integration

### `OneSwatter` Integration
- All modules integrate directly with `_G.OneSwatter:Log(addonName, level, category, message, extraData)`.
- If `OneSwatter` is installed and running, OneLock automatically registers itself and logs informational, error, and debug messages directly into OneSwatter's live viewer and SavedVariables (`OneSwatterDB.debugLogs`).

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:
1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and the active backlog item for this spin.
2. **Implementation**: Execute changes adhering strictly to the WoW Forever v1.60.1 / Interface 16001 single-client rules.
3. **Verification**: Verify in-game syntax and test using slash commands (`/ol`, `/ol test`, `/ol lock`, `/ol reset`).

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.1.2 (Blizzard Addons Settings & Standalone Options Panel)
- **Game Menu Options Panel (Settings -> AddOns -> OneLock)**:
  - Registered canvas category via `Settings.RegisterCanvasLayoutCategory` and `Settings.RegisterAddOnCategory`.
  - Added button `[Open Standalone Window]` directly within the Blizzard options canvas, closing the Game Menu and opening the floating HUD editor.
- **Standalone Floating Options Window (`OneLockOptionsFrame`)**:
  - Movable, resizable dialog with dark obsidian/violet theme, header drag bar, close button, and ESC key support (`UISpecialFrames`).
  - Integrated full suite controls across all three modules:
    - **OneLock_Timers**: Unlock/Lock anchor, Reset position, Toggle test bars, Bar Width/Height/Scale steppers, Max Targets stepper, Pandemic Window threshold, Target Header and Spell Icon toggles, and dual Color Pickers.
    - **OneLock_Shards**: Max Soul Shard cap stepper, out-of-combat auto-deletion toggle, and manual "Clean Up Now" button.
    - **OneLock_Procs**: Nightfall, Backlash, CC Immunity toggles, Audio Warning toggle, and "Trigger Test Proc Alert" button.
- **Slash Command Integration**:
  - Updated `/ol`, `/onelock`, `/olshards`, and `/olprocs` with no arguments to toggle the standalone options panel directly.

### Spin 0.1.1 (Engine API Alignment & Zero-Dependency Decoupling)
- **Decoupled OnePanel & MovableFrames**: Removed all references, hooks, and `.toc` optional dependencies on `OnePanel`, `OnePanelUtils`, and `MovableFrames`.
- **Integrated OneSwatter**: Added direct diagnostic logging across all modules to `OneSwatter:Log`.
- **Resolved Fatal 16001 Runtime Errors**:
  - Fixed `GetSpellInfo` nil call in `Tracker.lua` by implementing modern `C_Spell.GetSpellInfo` (table return) and `C_Spell.GetSpellName`.
  - Fixed forbidden `COMBAT_LOG_EVENT_UNFILTERED` registration error across all modules; transitioned aura tracking to modern `C_UnitAuras` and nameplate events (`NAME_PLATE_UNIT_ADDED`/`REMOVED`, `UNIT_AURA`).
  - Fixed `GetContainerNumSlots` nil call in `ShardManager.lua` by implementing modern `C_Container.GetContainerNumSlots` and `C_Container.GetContainerItemID`.
  - Fixed `UnitBuff` nil call in `Alerts.lua` by using `C_UnitAuras.GetPlayerAuraBySpellID`.
- Tested and confirmed clean Lua syntax compilation via `luac -p`.

### Spin 0.1.0 (Initial Scaffold & Multi-Target DoT Engine)
- Initialized modular repository structure (`OneLock_Timers`, `OneLock_Shards`, `OneLock_Procs`).
- Built complete `OneLock_Timers` multi-target DoT and CC tracking engine with 3.0s Pandemic color shift.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **OneLock_Shards In-Game Verification**: Test bag updates on Soul Shard gains and verify out-of-combat deletion cap.
- [ ] **Soulstone Expiration Tracker Testing**: Verify persistent 30-minute HUD bar upon casting Soulstone.

### Priority 2: Medium Priority (Enhancements)
- [ ] **Proc Banner Polish**: Refine Nightfall / Backlash banner visual animations and sound triggers.
- [ ] **Configurable Anchor Drag Bounds**: Add screen boundary clamping to prevent dragging timer bars off-screen.

---

## 🧪 Testing & Verification Guide

- **Toggle Test Bars**: `/ol test` — displays simulated multi-target DoT bars for layout inspection.
- **Unlock Master Anchor**: `/ol unlock` — displays movable drag handle labeled "OneLock Timers (Drag to Move)".
- **Lock Master Anchor**: `/ol lock` — hides drag handle and saves coordinates to `OneLockTimersDB.position`.
- **Reset Anchor Position**: `/ol reset` — repositions anchor to screen center.
- **Adjust Bar Scale**: `/ol scale 1.2` — sets scale to 120%.
- **Adjust Bar Width**: `/ol width 180` — sets width to 180px.
- **Check Soul Shards**: `/olshards count`
- **Test Proc Banner**: `/olprocs test`
