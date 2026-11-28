# AI Context & Living Specification — OneLock Suite

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Suite**: OneLock (Modular Warlock Suite)
- **Current Version**: 0.1.13
- **Suite**: Independent Warlock suite in the `Nuros-WoW-Forever-Addons` ecosystem
- **GitHub Repository**:
  - Exists: TRUE (`https://github.com/Nuros-WoW-Forever-Addons/OneLock`)
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
│   ├── Display.lua
│   └── OptionsUI.lua
├── OneLock_Shards/
│   ├── OneLock_Shards.toc
│   ├── Core.lua
│   ├── ShardManager.lua
│   └── SoulstoneTracker.lua
├── OneLock_Procs/
│   ├── OneLock_Procs.toc
│   ├── Core.lua
│   └── Alerts.lua
└── OneLock_Rings/
    ├── OneLock_Rings.toc
    ├── Core.lua
    └── Rings.lua
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
- **`OneLock_Rings`**:
  - `OneLock_Rings.toc`: Manifest, SavedVariables `OneLockRingsDB`, optional dependency on `OneSwatter`.
  - `Core.lua`: Namespace initialization (`OneLock_Rings`), SavedVariables schema defaults, slash commands (`/olrings`), OneAddon chat routing.
  - `Rings.lua`: Circular clock-point radial wheels for Stones (with live Soul Shard inventory count, threshold warnings, and 1-click purge button) and Demon Summoning (with center Ritual of Summoning), circular masks (`TempPortraitAlphaMask`), item/spell cooldown spinners, and edit mode dragging.

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
    version = 2,
    maxShards = 24,                    -- Maximum Soul Shards to keep in inventory
    autoDeleteExcess = false,          -- Out-of-combat cap alert when inventory exceeds maxShards
    autoSortShards = false,            -- Automatically sort Soul Shards to designated bag slot out of combat
    sortTargetBag = 4,                 -- Designated bag slot for Soul Shards (0 = Backpack, 4 = Leftmost Bag)
    autoCreatePurgeMacro = false,      -- Auto-create character-specific #showtooltip Soul Shard /click OneLockPurgeShards macro for Warlocks
    showSoulstoneBar = true,           -- Display 30-minute soulstone expiration bar
    enableSoulstoneAlerts = true,      -- Visual alert banners for Soulstone events
    announceSoulstone = true,          -- Group announcements (Party, Raid, Raid Warning)
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
    version = 2,
    locked = true,                     -- Anchor movement lock (edit mode hidden by default)
    enableNightfall = true,            -- Shadow Trance alert
    enableBacklash = true,             -- Backlash alert
    enableImmunityAlert = true,        -- Fear/Banish target immunity alert
    playAudio = true,                  -- Sound alert trigger
    alertWidth = 240,                  -- Visual banner width (160 - 360 px)
    alertScale = 1.2,                  -- Visual banner scale (0.8 - 2.0x)
    soundIndex = 1,                    -- Index into sound options profile
    soundId = 8959,                    -- Selected SoundKit ID (Alarm Clock default, 0 for mute)
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 180,
    },
}
```

### `OneLockRingsDB`
```lua
OneLockRingsDB = {
    version = 1,
    locked = false,                    -- Anchor movement lock (edit mode visible by default on initial setup)
    showStonesRing = true,             -- Show Warlock Stones radial ring
    showDemonsRing = true,             -- Show Demon Summoning radial ring
    stonesScale = 1.0,                 -- Scale (0.6x to 2.0x)
    demonsScale = 1.0,                 -- Scale (0.6x to 2.0x)
    radius = 50,                       -- Radius from center to satellite buttons (px)
    stonesPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = -130,
        y = -100,
    },
    demonsPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 130,
        y = -100,
    },
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

### Spin 0.1.16 (Radial Utility HUD Wheels: Stones Ring & Demons Ring)
- **Reagent Bag (Slot 5) Integration (`ShardManager.lua`, `Rings.lua`, `OptionsUI.lua`)**:
  - Dynamically calculates maximum player equipped bags via `NUM_TOTAL_EQUIPPED_BAG_SLOTS` (supporting bag index 5).
  - Shard inventory scanning, counting, and auto-sorting now natively support Soul Bags equipped in the character's Reagent Bag slot.
  - Added `"Reagent Bag (5)"` option to the Target Bag Slot stepper in Options UI.
- **Dynamic Known Spell Visibility (`Rings.lua`)**:
  - Implemented `IsSpellKnownSafe()` checking `C_Spell.IsSpellKnownOrOverridesKnown`, `C_Spell.IsSpellKnown`, and `C_SpellBook.GetSpellBookItemName`.
  - Hides unlearned stones (e.g. Firestone, Spellstone) and demons (e.g. Felhunter) until unlocked/learned.
  - Dynamically refreshes visibility on `SPELLS_CHANGED` and `LEARNED_SPELL_IN_TAB`.
- **Thin Circular Action Border Rim (`Rings.lua`)**:
  - Replaced thick honor ring with clean circular action rim (`Interface\Buttons\UI-ActionButton-Border`) sized at `size + 6` (3px uniform padding), ensuring internal spell and item artwork remains completely visible.
- **Combat Secret Value Protection (`Rings.lua`)**:
  - Gated all spell and item cooldown checks (`UpdateDemons`, `UpdateStones`) with `IsSecret(dur)`, `IsSecret(start)`, and `IsSecret(enable)` to prevent fatal Lua errors when entering combat under execution taint.
  - Passes values directly to `Cooldown:SetCooldown()` via `pcall` when flagged secret by the engine.
- **Concentric Circular Border Rings (`Rings.lua`)**:
  - Eliminated legacy `MiniMap-TrackingBorder` which had a built-in tracking icon offset causing the borders to appear small, distorted, and off-center in the top-left quadrant of buttons.
  - Implemented concentric circular `UI-Character-Info-Honor-RewardRing` atlas (with fallback to `UI-Achievement-Guild-Ring`) scaled at `1.48x` button size and centered `(0, 0)`.
- **Low-Rank Item Texture Caching (`Rings.lua`)**:
  - Ordered `HEALTHSTONES`, `SOULSTONES`, `SPELLSTONES`, and `FIRESTONES` starting with Rank 1 item IDs so `GetItemTextureSafe` returns valid artwork on characters who have not yet learned high-level ranks.
- **Radial Stones Ring (`OneLock_Rings/Rings.lua`)**:
  - Center button: Displays live Soul Shard inventory count with color warnings (white = within limit, amber/red = cap exceeded). Clicking the center button out of combat purges 1 excess shard using `ShardManager:PurgeOneExcessShard()`.
  - 4 satellite action buttons at clock points (radius $R = 50$):
    - 9 o'clock ($180^\circ$): Firestone (Left-click Use/Apply, Right-click Create).
    - 11 o'clock ($120^\circ$): Healthstone (Left-click Use highest rank in bag, Right-click Create highest rank known).
    - 1 o'clock ($60^\circ$): Soulstone (Left-click Use/Store on target/mouseover/self, Right-click Create).
    - 3 o'clock ($0^\circ$): Spellstone (Left-click Use/Apply, Right-click Create).
  - Accurate item artwork, subdued desaturated state when item count is 0 with explicit `"0"` counter, and illuminated artwork with bag count when available.
  - Native item cooldown spinners.
- **Radial Demon Summoning Ring (`OneLock_Rings/Rings.lua`)**:
  - Center button: Ritual of Summoning spell button.
  - 4 demon summon satellite buttons:
    - 9 o'clock: Summon Imp.
    - 11 o'clock: Summon Voidwalker.
    - 1 o'clock: Summon Succubus.
    - 3 o'clock: Summon Felhunter.
  - Native spell cooldown frames and circular alpha masks (`TempPortraitAlphaMask`).
- **Interactive Edit Mode & Option Controls (`OptionsUI.lua`)**:
  - Movable anchors (`OneLock_StonesRingAnchor`, `OneLock_DemonsRingAnchor`) with purple backdrop frames when unlocked (`/olrings move`).
  - Section 4 integrated into Options UI with toggles for both rings, scale steppers (0.6x - 2.0x), and radius stepper (35 - 80 px).
- **Packaging Workflow & Live Sync**:
  - Added `OneLock_Rings` to `.github/workflows/package.yml`.
  - Synced to live client via `./sync-live.sh OneLock`.

### Spin 0.1.15 (Foreign Warlock DoT Isolation & Non-Warlock Character Deactivation)
- **Foreign Warlock DoT Isolation (`Tracker.lua`)**:
  - Root cause: In `ScanUnit()`, `ForEachUnitDebuff` evaluated `isPlayerSource = true` whenever `sourceUnit == nil` or `IsSecret(sourceUnit)`. When other Warlocks in dungeons, raids, or the open world cast DoTs on an enemy, the client often leaves `sourceUnit` as `nil` (or a foreign unit token). This caused all external Warlocks' DoTs (Corruption, Curse of Agony, Immolate, etc.) to be captured as if they were cast by the player.
  - Implemented strict source validation in `ForEachUnitDebuff` and `ScanUnit`:
    - Passed `isPlayerAura` boolean from `C_UnitAuras` directly through to the debuff callback.
    - Strictly checks `isPlayerAura == true` or `sourceUnit == "player"` or `sourceUnit == "pet"` or `UnitIsUnit(sourceUnit, "player")` / `UnitIsUnit(sourceUnit, "pet")`.
    - If not verified as cast by the player, the foreign debuff is completely ignored and will never create or update an active timer bar.
- **Suite-Wide Warlock Class Guarding (`All Modules`)**:
  - Root cause: OneLock was executing and registering event listeners on non-Warlock characters (e.g. Rogues, Mages, Warriors), causing the tracker to scan enemy debuffs and display Warlock timers whenever a Warlock in the party debuffed the target.
  - Added strict `UnitClass("player") == "WARLOCK"` guards:
    - `OneLock_Timers`: `Core.lua`, `Tracker.lua`, and `Display.lua` abort initialization and register zero event or OnUpdate hooks on non-Warlocks. Slash command `/ol` reports suite status and exits.
    - `OneLock_Shards`: `Core.lua`, `ShardManager.lua`, and `SoulstoneTracker.lua` abort initialization on non-Warlocks.
    - `OneLock_Procs`: `Core.lua` and `Alerts.lua` abort initialization on non-Warlocks.

### Spin 0.1.14 (Soul Shard Auto-Sorting, Bag Slot Targeting & Character Purge Macro Auto-Creation)
- **Soul Shard Auto-Sort Engine (`ShardManager.lua`)**:
  - Implemented `ShardManager:SortShards(explicitTargetBag)`:
    - Scans player inventory for Soul Shards (`SOUL_SHARD_ITEM_ID = 6265`) located outside the target bag slot.
    - Scans target bag (default: Bag 4, the leftmost bag where Soul Pouches / Felcloth Bags reside) for available empty slots.
    - Safely transfers misplaced Soul Shards into empty slots using `C_Container.PickupContainerItem` (with fallback to `PickupItem`).
    - Validates that cursor is empty (`CursorHasItem()`), player is out of combat (`not InCombatLockdown()`), and uses an `isSorting` re-entrancy lock to prevent event loops.
    - If in combat when triggered, queues action via `pendingSort = true` and flushes automatically on `PLAYER_REGEN_ENABLED`.
  - Added event-driven auto-sorting listening on `BAG_UPDATE_DELAYED` when `autoSortShards = true`.
- **Character Purge Macro Auto-Creation (`ShardManager.lua`)**:
  - Implemented `ShardManager:CheckAndCreatePurgeMacro(verbose)`:
    - Checks character class (`UnitClass("player") == "WARLOCK"`); skips execution for non-Warlocks.
    - Checks combat state (`not InCombatLockdown()`); queues for `PLAYER_REGEN_ENABLED` if triggered during combat.
    - Verifies character macro capacity (`MAX_CHARACTER_MACROS or 18`).
    - Automatically creates or updates character-specific macro `PurgeShard` with body:
      ```text
      #showtooltip Soul Shard
      /click OneLockPurgeShards
      ```
    - Uses FileID `134400` (integer) for question mark icon instead of legacy texture string to comply with modern engine `CreateMacro` requirements.
    - Accurately scans the character-specific macro range (`maxAccount + 1` to `maxAccount + numCharacter`) and verifies `isLocal == true`.
    - Detects any existing character macro targeting `/click OneLockPurgeShards` (including `ShardTrash` or `PurgeShard`).
    - Triggers `pcall(MacroFrame_Update)` if the Blizzard macro dialog is open so new/updated buttons render instantly without closing the panel.
    - Routes feedback to both `ns:Print` and `DEFAULT_CHAT_FRAME` so the user sees results immediately in their primary chat tab.
  - Added checkbox: `"Auto-create Purge Macro under Character Macros (Warlock)"` and button: `[Create / Update Purge Macro Now]`.
  - Added slash command `/olshards macro` to toggle auto-creation and immediately run macro check.
- **Options UI & Slash Commands**:
  - Added checkbox: `"Auto-sort Soul Shards to designated bag"` in Options Panel Section 2.
  - Added stepper: `"Target Bag Slot:"` (0 = Backpack, 1-3 = Bags 1-3, 4 = Bag 4 Leftmost/Soul Bag) using inline formatted stepper display.
  - Added action button: `[Sort Shards to Bag Now]` in Options Panel Section 2.
  - Added slash commands:
    - `/olshards autosort` — Toggle auto-sorting on bag updates.
    - `/olshards bag <0-4>` — Set designated bag slot.
    - `/olshards sort` (or `sortnow`) — Execute an immediate inventory sort to the target bag out of combat.
    - `/olshards macro` — Toggle character purge macro auto-creation.

### Spin 0.1.12 (Compact Icon Mode Configuration — Active on Dev Branch)
- **Compact Horizontal Spell Icon Configuration (`displayMode = "ICONS"`)**:
  - Implemented second display mode for `OneLock_Timers` to significantly reduce vertical screen footprint when tracking 3+ enemies.
  - In `ICONS` mode, spell timers appear as a horizontal row of spell icons running left-to-right immediately under each target's nameplate header without statusbars.
  - The countdown number overlays directly onto each spell icon with an outline font and high-contrast backplate.
  - When remaining duration enters the Pandemic refresh window (< 3.0s or configured threshold), the countdown number turns golden amber (`colorPandemic`) and an action-border glow activates around the icon.
  - Implemented `iconPool` and `activeIcons` frame pooling.
- **OptionsUI & Slash Command Controls**:
  - Added `[Mode: Timer Bars / Compact Icons]` toggle button and `Icon Size` stepper (16 - 48 px) in Options Panel Section 1.
  - Added slash command `/ol mode [bars|icons]`.
- **Branch Policy Notice**:
  - Kept exclusively on `dev` branch for live testing per user instructions; not merged to `main` until verified.

### Spin 0.1.13 (Dungeon Secret String Immunity, Secret Table Indexing Protection & Shard Cleanup Hardening)
- **Resolved Protected Function Call Blocked on Item Deletion (`ShardManager.lua:131`) & Added 1-Click Purge Macro**:
  - Root cause: In modern WoW / Interface 16001, `DeleteCursorItem()` is a protected Blizzard API restricted from automated background execution without a direct hardware event (`Protected function call blocked: AddOn 'OneLock_Shards' attempted to call 'DeleteCursorItem()'`).
  - When `autoDeleteExcess` was enabled with low shard caps (e.g. 6), `ScanBags()` invoked `CleanupExcessShards()`, triggering protected call blocks on every bag update.
  - Replaced automated background `DeleteCursorItem()` calls with a throttled chat notification alerting the player when the inventory shard cap is exceeded.
  - Implemented a 1-click secure hardware button `OneLockPurgeShards` and macro target (`/click OneLockPurgeShards`) in `ShardManager.lua`. When clicked (or triggered via keybind macro out of combat), it safely picks up and purges 1 excess Soul Shard per click under valid hardware context.
  - Added "Purge 1 Excess Shard Now" button in `OptionsUI.lua` and updated `/olshards purge` slash command.
- **Resolved Fatal Secret Key Table Indexing Errors (`Tracker.lua:209, 223, 237, 525`, `Display.lua`)**:
  - Root cause: In combat/dungeons, the engine marks enemy `UnitGUID` returns as secret values. Standard Lua tables (`ns.activeTimers = {}`) cannot be indexed with secret keys in WoW Forever (`attempted to index a table that cannot be indexed with secret keys`).
  - Implemented `GetSafeUnitKey(unit, fallbackGUID)` which extracts non-secret GUIDs when available, and strictly falls back to safe string literals (`unit` or `"target"`, e.g. `"target"`, `"mouseover"`, `"focus"`, `"nameplate1"`). It is guaranteed to never return a secret value.
  - Replaced all raw `ns.activeTimers[guid]` lookups and assignments in `ScanUnit`, `OnPlayerSpellcastSucceeded`, `PLAYER_TARGET_CHANGED`, and `NAME_PLATE_UNIT_REMOVED` with safe key indexing.
  - In `Display.lua`, enhanced target sorting and header rendering to recognize `target.key == "target"` alongside GUID matching.
- **Resolved Stack Overflow in ShardManager (`ShardManager.lua:59`)**:
  - Root cause: `ShardManager:ScanBags()` invoked `QueueCleanup()` when excess shards were present; `CleanupExcessShards()` then called `ScanBags()`, triggering an infinite recursive loop resulting in `stack overflow`.
  - Added `isCleaningUp` re-entrancy lock to ensure bag scans triggered during excess shard deletion do not re-trigger `QueueCleanup()`.
- **Resolved Timer Vanishing in Combat/Dungeons (`Tracker.lua`)**:
  - Root cause: Overly aggressive `IsSecret(...)` guard clauses introduced during secret string hardening inadvertently dropped valid timers:
    1. `OnPlayerSpellcastSucceeded` had `if not targetGUID or IsSecret(targetGUID) then return end`, aborting timer creation whenever `targetGUID` was flagged by the engine.
    2. `ScanUnit` assumed a unit was dead if `UnitIsDead` was secret (`if not okDead or isDead or IsSecret(isDead) then`), causing combat aura scans to wipe out active timers and return early.
    3. `ForEachUnitDebuff` aborted immediately when `UnitExists` was a secret boolean (`if not okExists or not exists or IsSecret(exists) then return end`), failing to scan debuffs on living targets in combat.
    4. Auras with secret names were skipped, preventing debuffs with valid spell IDs from being recognized.
    5. In `OnSpellcastSent`, when `target` was secret, `SafeNameMatch` returned false and fallback `UnitExists` checks skipped, causing `lastCastTargetGUID` to default to `nil`.
  - Fixes implemented:
    - Defaulted `lastCastTargetGUID` directly to `UnitGUID("target")` with `pcall` in `OnSpellcastSent` when not targeting mouseover or focus.
    - In `OnPlayerSpellcastSucceeded`, ensured `targetGUID` falls back to `UnitGUID("target")` without aborting on `IsSecret(targetGUID)`, and safely resolved `targetName` from cached state or `"Target"`.
    - In `ScanUnit`, only treated units as dead when `isDead == true` and not secret (`okDead and not IsSecret(isDead) and isDead == true`).
    - In `ForEachUnitDebuff`, only aborted when `exists == false` and not secret (`okExists and not IsSecret(exists) and exists == false`).
    - Added `SafeInvoke` helper in `ForEachUnitDebuff` to resolve secret aura names from `spellId` via `GetSpellDetails(spellId)`.
    - Protected `PLAYER_TARGET_CHANGED` and `NAME_PLATE_UNIT_REMOVED` against secret boolean branching on `UnitExists`/`UnitIsDead`.
    - Increased prune grace period to 3.0s to allow network/aura latency before debuff verification.
- **Resolved Fatal Secret String Error on Spellcast (`Tracker.lua:326`)**:
  - Root cause: In instances/dungeons under combat taint, `target` in `UNIT_SPELLCAST_SENT` can be passed as an engine secret string value. Evaluating string equality (`curTargetName == target`, `UnitName("focus") == target`, `UnitName("mouseover") == target`) without secret value validation caused fatal Lua errors (`attempt to compare local 'target' (a secret string value, while execution tainted by 'OneLock_Timers')`).
  - Implemented `SafeNameMatch(unitToken, targetName)` with `IsSecret` checks and `pcall` protected comparison.
  - Guarded `lastCastTargetName` to never store secret strings.
- **Debuff Callback & Caster Secret Protection**:
  - Wrapped `ForEachUnitDebuff` callback invocations in `pcall` across all four aura enumeration paths.
  - Hardened `sourceUnit == "player"` comparison against secret string values with `pcall` and `IsSecret` checks.
- **Display Target Comparison Hardening (`Display.lua`)**:
  - Implemented `IsSameGUID(guidA, guidB)` with `issecretvalue` and `pcall` guards to eliminate comparison errors during target sorting and rendering in combat.
  - Guarded `lastSeen` timestamp comparisons in `table.sort`.

### Spin 0.1.12 (Compact Icon Mode Polish, TOC Icon Textures, OneAddon Chat Routing & Corruption Duration Fix)
- **Addon Menu Icons in TOC manifests (`All Modules`)**:
  - Added `## IconTexture` to `OneLock_Timers.toc`, `OneLock_Shards.toc`, and `OneLock_Procs.toc`, replacing default red question marks with high-res warlock spell icons in the Game Menu -> AddOns list.
- **Dedicated Chat Frame Routing (`GetOneAddonChatFrame`)**:
  - Standardized local output across `OneLock_Timers`, `OneLock_Shards`, and `OneLock_Procs` to route via `GetOneAddonChatFrame()` into the `"OneAddon"` or `"OneAddons"` chat tab (matching `OneFish` pattern), falling back to `DEFAULT_CHAT_FRAME`.
  - Preserved group chat routing (Party, Raid, Raid Warning) for combat-critical Soulstone announcements.
- **Options UI Layout & Stepper Alignment (`OptionsUI.lua`)**:
  - Fixed `Icon Size` stepper layout overflow where controls hung off the right side of the options window.
  - Implemented `anchorAfterLabel` layout for compact steppers, anchoring `[-] [value] [+]` immediately after the `:` of `"Icon Size:"`.
  - Relabeled color swatches to indicate dual control of bars and icon text: `"Normal Bar / Icon Text Color:"` and `"Pandemic Bar / Icon Text Color (< 3.0s):"`.
- **Compact Icon Mode Visual Polish & Bottom-Center Shadow Box Text (`Display.lua`)**:
  - Moved countdown timer text to anchor directly below each icon at bottom center (`TOP, icon, BOTTOM, 0, -2`), keeping spell artwork 100% unobstructed for instant recognition.
  - Placed countdown text inside a dedicated translucent black shadow box (`0, 0, 0, 0.75` backdrop + `0.20, 0.20, 0.20, 0.80` border) for maximum readability against complex game terrain.
  - Linked shadow box border to the Pandemic window, shifting to golden amber (`db.colorPandemic`) when under the threshold (< 3.0s).
  - Dynamically scaled text font size proportionally with icon size (`math.max(9, math.min(13, math.floor(size * 0.45)))`).
  - Added vertical row clearance (`-22px` gap) when in icon mode to ensure following target headers do not collide with countdown shadow boxes.
  - Set normal countdown text color to the user's configured normal bar color (default Purple / `db.colorNormal`), with dynamic shift to golden amber (`db.colorPandemic`) and glowing action border during the Pandemic refresh window (< 3.0s).
- **Exact Rank Duration Tracking & Cast Engine Hardening (`Tracker.lua`)**:
  - Resolved Corruption showing 18s instead of 12s on Rank 1 using a pure Lua `SPELL_DURATIONS_BY_ID` integer lookup table (Rank 1: 12s, Rank 2: 15s, Rank 3+: 18s).
  - Eliminated all unverified client calls (`IsPlayerSpell`, `IsSpellKnown`) and removed `SPELLS_CHANGED` event hooks to prevent initialization aborts.
  - Added a 1.5-second aura prune grace period to prevent network latency from deleting newly cast spells before `UNIT_AURA` registers on the target.
  - Removed premature `ScanUnit("target")` call immediately following `OnPlayerSpellcastSucceeded` inside `UNIT_SPELLCAST_SUCCEEDED`.

### Spin 0.1.11 (Soulstone Resurrection Consumption Resolution & State Machine)
- **Resolved Resurrection Timer Persistence**:
  - Addressed issue where the Soulstone HUD bar continued counting down after a soulstoned target died and resurrected.
  - Implemented `wasDead` state tracking in `currentSoulstone`. When `status == "DEAD"`, `wasDead` is marked `true`.
  - When the unit status flips back to `"ALIVE"` (player accepts Soulstone prompt, resurrects, or is revived), `OnSoulstoneUpdate` immediately detects the resurrection, triggers `SOULSTONE RESURRECTION` alert banner (`<targetName> resurrected! Soulstone consumed.`), plays Gong sound (618, Master channel), clears the tracking session, and hides the HUD.
- **Robust Multi-Unit Target Status (`CheckTargetStatus`)**:
  - Upgraded target detection to match by immutable `targetGUID` first, with fallback to `targetName` and realm-stripped short names.
  - Added secret value guards on `UnitIsDeadOrGhost` and unit GUIDs to prevent secret boolean/string errors.
  - Checked `UnitIsConnected` to prevent false resurrection triggers if a dead group member disconnects.
- **Party / Raid / Raid Alert Group Messaging**:
  - Implemented `SendGroupAnnouncement` routing engine for Soulstone events.
  - Automatically evaluates group context hierarchy:
    1. Checks Raid status first (`IsInRaid()`).
    2. If in Raid, checks for Raid Alert permissions (`UnitIsGroupLeader` or `UnitIsGroupAssistant`).
    3. If has permission, broadcasts via Raid Alert (`RAID_WARNING`).
    4. If no permission, broadcasts via Raid chat (`RAID`).
    5. If in a 5-man party (`IsInGroup()`), broadcasts via Party chat (`PARTY`).
    6. If solo, outputs locally to chat with addon prefix.
  - Broadcasts on Soulstone cast: `"<PlayerName> Soulstoned <TargetName> 30 Minute Timer Started!"`.
  - Broadcasts on Soulstone target death: `"<PlayerName> had DIED! Soulstone has <X> remaining!"`.
  - Broadcasts on Soulstone expiration: `"<PlayerName> Soulstone EXPIRED!"`.
  - Broadcasts on Soulstone consumption upon resurrection: `"Soulstone consumed by <TargetName> (Resurrected)."`.
  - Added toggle checkbox in OptionsUI and SavedVariable `announceSoulstone` (default: `true`).
- **Manual Clear Support**:
  - Implemented `SoulstoneTracker:ClearSoulstone()`.
  - Added `/olshards clear` and `/ol clear` slash commands.
  - Added `[Clear Bar]` button directly to OptionsUI in Section 2.

### Spin 0.1.10 (Soulstone Movable Anchor, Test Bar, & Event Alert Banners)
- **Soulstone Movable Anchor & Edit Mode**:
  - Implemented `OneLockSoulstoneAnchor` and translucent purple edit-mode shadow box (`OneLockSoulstoneShadowBox`) labeled `Soulstone (Drag to Move)`.
  - Added direct dragging support on the Soulstone HUD frame when unlocked, with instant click-through transparency when locked.
  - Added options controls in Section 2: `[Move Soulstone HUD (Edit)]` / `[Lock Soulstone HUD]`, `[Reset Position]`, and `[Toggle Test Bar]`.
  - Added steppers for **Soulstone Bar Width** (120 - 300 px) and **Scale** (0.8x - 2.0x).
- **Simulated Soulstone Test Mode (`/olshards test`)**:
  - Toggles a simulated active Soulstone on player/MainTank with 25 minutes remaining, allowing players without the spell to visualize and position the HUD bar anywhere on screen.
- **Soulstone Proc Alert Banners**:
  - **Target Dead Alert**: When the soulstoned player dies (`status == "DEAD"`), triggers high-visibility red alert banner `SOULSTONE TARGET DEAD!`, turns the bar crimson, and plays Raid Warning sound. Resets when target resurrects.
  - **Pandemic Expiring Alert (< 1 min)**: When remaining duration drops below 60 seconds, shifts bar color to golden amber with glowing spark and triggers `SOULSTONE EXPIRING SOON!` banner.
  - **Expiration Alert**: When the 30-minute stone expires, triggers `SOULSTONE EXPIRED` alert banner.
  - Integrated directly with `OneLock_Procs`'s custom alert banner via `Alerts:ShowAlert`.
- **Audio Output & Sound Selection Hardening**:
  - Removed 4 inaudible soft sounds (Ready Check, Auction Bell / Chime, Sonar Map Ping, Whisper Shimmer) from `OneLock_Procs` sound selector.
  - Routed all alert playback explicitly through `"Master"` channel (`PlaySound(soundId, "Master")`) to ensure audio is clear and audible during combat.

### Spin 0.1.9 (Combat Spellcast Engine & Aura Pruning Isolation)
- **Direct Player Spellcast Tracking (`UNIT_SPELLCAST_SUCCEEDED`)**:
  - Addressed Midnight / Camelot combat engine behavior where enemy auras are gated behind secret flags for tainted AddOns during combat.
  - Linked `UNIT_SPELLCAST_SENT` and `UNIT_SPELLCAST_SUCCEEDED` directly to timer creation, recording target GUID, spell duration, icon, and expiration immediately upon player cast completion.
  - Guarantees 100% reliable timer bar generation during active combat even when `C_UnitAuras.GetDebuffDataByIndex` is blocked by secret aura taint.
- **Aura Prune Isolation**:
  - Gated debuff pruning in `ScanUnit` behind `anyAurasRead`. If aura queries fail or return 0 auras due to secret taint, active timers continue running for their full duration rather than being erroneously pruned.
  - Cleaned dead target entries immediately on `PLAYER_TARGET_CHANGED` and `NAME_PLATE_UNIT_REMOVED`.

### Spin 0.1.8 (Complete MovableFrames Decoupling & Native Movable Default)
- **Purged OneLock from MovableFrames**:
  - Identified residual `MovableFramesDB.customFrames["OneLockTimersAnchor"]` entry written during initial v0.1.0 scaffold.
  - Implemented automated purge in `OneLock_Timers/Core.lua` on `ADDON_LOADED` and `PLAYER_LOGIN` that unmanages and deletes all `OneLock*` keys from `MovableFramesDB.customFrames` and `MovableFramesDB.positions`.
  - Added exclusion filter in `MovableFrames/Core.lua` and `MovableFrames/Modules/OptionsUI.lua` preventing `MovableFrames` from listing or hooking `OneLock` elements.
- **Movable by Default (Controlled Entirely by OneLock)**:
  - Updated default configuration to `locked = false` so that timer and proc anchors display their purple edit-mode shadow boxes immediately on fresh load/reset.
  - Added direct dragging support to active target headers (`AcquireHeader` -> `RegisterForDrag("LeftButton")`), allowing players to drag the timer stack directly by grabbing either the header or the purple shadow box when unlocked.
  - Clicking `[Lock Anchor]` or `/ol lock` disables header mouse events (`EnableMouse(false)`) and hides shadow boxes, making them completely transparent to clicks during combat.

### Spin 0.1.7 (Secret Aura Taint & Non-Hostile Unit Hardening)
- **Resolved `GetDebuffDataByIndex` Secret Aura Taint Error**:
  - Addressed fatal runtime error triggered during quests with charmed or secret aura units (e.g., Deeprun Rat Roundup): `GetDebuffDataByIndex(): Auras cannot be accessed when secret while tainted by 'OneLock_Timers'`.
  - Wrapped all `C_UnitAuras.GetDebuffDataByIndex`, `C_UnitAuras.GetAuraDataByIndex`, `AuraUtil.ForEachAura`, and `_G.UnitDebuff` queries in `pcall` across the entire suite. When an aura is flagged secret by the engine, `pcall` cleanly intercepts the failure, preventing unhandled exceptions.
- **Offensive Unit Hostility Filter (`UnitCanAttack`)**:
  - Filtered out unattackable/friendly units in `Tracker.lua`. Offensive Warlock DoTs and CCs can only exist on attackable hostile targets; charmed critters, party members, and friendly NPCs are immediately bypassed.
- **Deep Midnight / Camelot Secret Value Protection**:
  - Added `IsSecret` (`issecretvalue`) checks across `Tracker.lua`, `Display.lua`, `Alerts.lua`, and `SoulstoneTracker.lua`.
  - Guarded `UnitGUID`, `UnitName`, `aura.name`, `aura.spellId`, `duration`, and `expirationTime` against secret string/number comparison and arithmetic throws.

### Spin 0.1.6 (Movable/Sizable Proc Alert Banner & Sound Selection)
- **Clarified Alert Banner Architecture**:
  - Confirmed the proc alert banner (`OneLockProcAlertBanner`) is an addon-built custom frame in `OneLock_Procs/Alerts.lua`, not a Blizzard native alert frame.
- **Movable & Sizable Proc Alert Banner**:
  - Implemented `OneLockProcAnchor` and attached an edit-mode translucent purple shadow box (`OneLockProcShadowBox`) matching the aesthetic of `OneLockTimersShadowBox` (`0.20, 0.08, 0.35, 0.65` purple backdrop + `0.75, 0.35, 1.00, 0.95` violet border).
  - Added `[Move Alert Banner (Edit)]` / `[Lock Alert Banner]` toggle button and `[Reset Alert Position]` button in the Options Panel.
  - Added steppers for **Alert Banner Width** (160 - 360 px, step 10) and **Alert Banner Scale** (0.8 - 2.0x, step 0.05).
  - Saved coordinates and dimensions persisted in `OneLockProcsDB` (`position`, `alertWidth`, `alertScale`).
- **Configurable Proc Sound Effects & Live Preview**:
  - Added sound profile system (`SOUND_OPTIONS`) offering 10 audio options: Alarm Clock (Default), Raid Warning, Ready Check, Auction Bell / Chime, Sonar / Map Ping, Whisper / Shimmer, Gong / Quest Complete, Level Up, PvP Flag Captured, and None (Mute).
  - Integrated `CreateSoundSelector` in OptionsUI with `<` and `>` cycling controls and a dedicated `[Test Sound]` preview button.
  - Linked sound selection directly to proc alert triggers in `Alerts.lua` with full mute support.

### Spin 0.1.5 (Purple Shadow Box Edit Mode & Header Bar Removal)
- **Removed Static "Drag to Move" Header Bar**:
  - Eliminated the permanent yellow/black anchor box above the target frames.
  - Positioned the topmost target header and timer bar directly at the anchor point coordinates (`TOPLEFT, 0, 0`).
- **Introduced Translucent Purple Shadow Box**:
  - Attached `OneLockTimersShadowBox` to `OneLockTimersAnchor` with a deep purple translucent backdrop (`0.20, 0.08, 0.35, 0.65`) and glowing violet border (`0.75, 0.35, 1.00, 0.95`).
  - Labeled `OneLock Timers (Drag to Move)`.
  - When locked (normal play): completely hidden with 0 screen footprint. Nothing shows until a target is selected and a tracked spell is cast.
  - When unlocked (Edit Mode via Options Panel `[Move Anchor (Edit)]`): visible and draggable anywhere on screen.
- **Continuous Test Bar Looping**:
  - Enabled continuous timer cycling in test mode so test bars count down, spark, turn amber during Pandemic window (< 3.0s), and smoothly loop without sticking at `0.0s`.

### Spin 0.1.4 (Test Mode Spell Texture API & Stepper Initialization Fix)
- **Resolved Toggle Test Bars Crash (`GetSpellTexture` nil call)**:
  - Fixed `Display.lua:238: attempt to call a nil value ('GetSpellTexture')` when clicking `[Toggle Test Bars]`.
  - Replaced legacy global `GetSpellTexture` with `GetSpellTextureSafe` using modern `C_Spell.GetSpellTexture` and `C_Spell.GetSpellInfo` (table `iconID`).
- **Resolved Stepper Display Latency (Blank Initial Value)**:
  - Fixed issue where the Soul Shard cap stepper (and other steppers) started blank until `+` or `-` was clicked.
  - Added immediate `container.Refresh()` and `cb.Refresh()` calls upon control creation, ensuring initial values (e.g. `24`, `160 px`) populate immediately.

### Spin 0.1.3 (Dedicated Scroll Child Decoupling for Standalone Options Window)
- **Resolved Empty Standalone Options Window**:
  - Identified root cause: The previous implementation shared a single `uiContentFrame` between the embedded Blizzard Settings canvas and the standalone window by calling `SetParent` and `SetScrollChild` dynamically. When clicking `[Open Standalone Window]`, hiding `SettingsPanel` propagated a `Hide()` call to all its children and detached canvas focus, leaving the reparented content hidden.
  - Decoupled into two completely independent, dedicated content child hierarchies:
    - `OneLockStandaloneContent`: permanently parented to the standalone floating window's scrollframe.
    - `OneLockEmbeddedContent`: permanently parented to the Blizzard Settings canvas scrollframe.
  - Neither window reparents or touches the other's frames, guaranteeing the standalone window is populated immediately upon display.

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
