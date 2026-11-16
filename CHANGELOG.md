# Changelog

All notable changes to the **OneLock** addon suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [0.1.9] - 2026-11-15

### Added
- **Soulstone Movable Anchor & Edit Mode (`OneLock_Shards`)**:
  - Implemented `OneLockSoulstoneAnchor` and translucent purple edit-mode shadow box (`OneLockSoulstoneShadowBox`) labeled `Soulstone (Drag to Move)`.
  - Added direct dragging support on the Soulstone HUD frame when unlocked.
  - Added options controls: `[Move Soulstone HUD (Edit)]`, `[Reset Position]`, and steppers for Bar Width (120 - 300 px) and Scale (0.8x - 2.0x).
- **Simulated Soulstone Test Mode (`/olshards test`)**:
  - Added test mode to preview and position the Soulstone HUD bar without needing the spell trained.
- **Soulstone Proc Alert Banners**:
  - **Target Dead Alert**: High-visibility red alert banner `SOULSTONE TARGET DEAD!`, turns the bar crimson, and plays Raid Warning sound when the soulstoned player dies.
  - **Pandemic Expiring Alert (< 1 min)**: Golden amber alert banner and color shift with glowing spark when remaining time drops below 60s.
  - **Expiration Alert**: Notifies when the 30-minute stone expires.
  - Routed through `OneLock_Procs`'s custom alert banner engine.

---

## [0.1.8] - 2026-11-15

### Added
- **Combat Spellcast Engine (`UNIT_SPELLCAST_SUCCEEDED`)**:
  - Implemented direct cast-based timer generation in `Tracker.lua`. When a player casts any Warlock DoT or CC (Corruption, Immolate, Agony, Unstable Affliction, Siphon Life, Fear, Banish, etc.), the timer is immediately created using the spell duration and target GUID.
  - Immune to Midnight / Camelot secret aura taint in combat, ensuring timer bars reliably display even when `C_UnitAuras.GetDebuffDataByIndex` is blocked by engine restrictions.
- **Aura Pruning Isolation**:
  - Gated debuff removal behind `anyAurasRead`. Active cast timers will no longer be pruned if the aura scan returns 0 auras due to secret access blocks.

---

## [0.1.7] - 2026-11-15

### Changed
- **Movable by Default (Controlled Entirely by OneLock)**:
  - Updated default configuration to `locked = false` so anchors display their purple edit-mode boxes immediately on fresh load/reset.
  - Added direct dragging support to active target headers (`RegisterForDrag("LeftButton")`), allowing players to reposition the timer stack by grabbing either the header or the purple shadow box.
  - When locked, mouse interaction on headers is disabled (`EnableMouse(false)`), making them transparent to mouse clicks during combat.
- **Purged OneLock from MovableFrames**:
  - Automatically unmanaged and deleted all residual `OneLock*` custom frames from `MovableFramesDB.customFrames` and `MovableFramesDB.positions`.
  - Added exclusion filter in `MovableFrames` preventing it from hooking or managing OneLock suite elements.

---

## [0.1.6] - 2026-11-15

### Fixed
- **Secret Aura Taint Handling (`C_UnitAuras.GetDebuffDataByIndex`)**:
  - Fixed fatal Lua error `GetDebuffDataByIndex(): Auras cannot be accessed when secret while tainted by 'OneLock_Timers'` triggered during quests with charmed or secret aura units (e.g., Deeprun Rat Roundup).
  - Wrapped all debuff and buff enumerations in `pcall` across `Tracker.lua` and `Alerts.lua` so engine secret access blocks fail gracefully rather than throwing uncaught errors.
- **Offensive Unit Hostility Filter (`UnitCanAttack`)**:
  - Added filter in `ScanUnit` to ignore unattackable, friendly, or charmed units. Since Warlock offensive DoTs and CCs can only be applied to hostile targets, friendly NPCs, charmed critters, and party members are completely bypassed.
- **Secret Value Comparison Protection**:
  - Added `IsSecret` (`issecretvalue`) guards across `Tracker.lua`, `Display.lua`, `Alerts.lua`, and `SoulstoneTracker.lua` to ensure unit names, GUIDs, durations, and spell IDs with secret value flags do not trigger comparison or arithmetic errors.

---

## [0.1.5] - 2026-11-15

### Added
- **Movable & Sizable Proc Alert Banner (`OneLock_Procs`)**:
  - Confirmed the proc banner is a custom frame built specifically for OneLock (`OneLockProcAlertBanner`), allowing full layout and styling control.
  - Implemented `OneLockProcAnchor` with a translucent purple shadow box edit-mode preview (`OneLockProcShadowBox`), toggled from the Options Panel via `[Move Alert Banner (Edit)]`.
  - Added steppers in the Options Panel to customize Alert Banner Width (160 - 360 px) and Scale (0.8 - 2.0x).
  - Added `[Reset Alert Position]` button to quickly return the banner to default screen coordinates.
- **Configurable Proc Sound Effects & Live Preview**:
  - Implemented a 10-preset sound library (`SOUND_OPTIONS`) including Alarm Clock (Default), Raid Warning, Ready Check, Auction Bell / Chime, Sonar / Map Ping, Whisper / Shimmer, Gong / Quest Complete, Level Up, PvP Flag Captured, and None (Mute).
  - Added an interactive sound selector control in the Options Panel with previous/next cycling and a dedicated `[Test Sound]` button to preview sounds instantly.
  - Linked sound choices directly to proc triggers in `Alerts.lua` with full mute support.

---

## [0.1.4] - 2026-11-15

### Changed
- **Removed Static Anchor Header Bar**: Removed the static `OneLock Timers (Drag to Move)` banner from normal display. The first target header/bar now anchors directly to the anchor coordinates with zero extra padding or permanent boxes.
- **Translucent Purple Shadow Box (Edit Mode)**: Added a sleek, translucent purple shadow box with glowing violet borders that only appears when "Edit Mode" is toggled from the Options Panel (`[Move Anchor (Edit)]`). Dragging the purple shadow box repositions the anchor freely.
- **Zero Footprint When Inactive**: When locked and not in test mode, the anchor is completely invisible until a target is selected and an active tracked spell is cast.
- **Continuous Test Bar Looping**: Updated test mode so simulated bars continuously count down, spark, and loop their Pandemic highlight instead of freezing at `0.0s`.

---

## [0.1.3] - 2026-11-15

### Fixed
- **Toggle Test Bars Error**: Fixed fatal `attempt to call a nil value ('GetSpellTexture')` at `Display.lua:238` by introducing `GetSpellTextureSafe` using modern `C_Spell.GetSpellTexture` and `C_Spell.GetSpellInfo`.
- **Options Stepper Initial Value Display**: Fixed an issue where the Soul Shards cap stepper displayed blank instead of `24` until a button was clicked. All steppers, checkboxes, and swatches now update immediately upon instantiation.

---

## [0.1.2] - 2026-11-15

### Added
- **Game Menu Options Panel (Settings -> AddOns -> OneLock)**:
  - Registered canvas category with Blizzard's modern `Settings.RegisterCanvasLayoutCategory` and `Settings.RegisterAddOnCategory`.
  - Added button `[Open Standalone Window]` to transition from the fullscreen Blizzard menu into a floating HUD editor.
- **Standalone Options Panel (`OneLockOptionsFrame`)**:
  - Independent, movable floating options frame styled in obsidian with warlock violet accents, title bar drag handles, close button, and ESC closure (`UISpecialFrames`).
  - Implemented interactive steppers, checkboxes, color swatches, and action buttons for:
    - **OneLock_Timers**: Unlock/Lock anchor, Reset position, Toggle test bars, Width, Height, Scale, Max Visible Targets, Pandemic threshold, Header/Icon toggles, and Normal/Pandemic Color Pickers.
    - **OneLock_Shards**: Max Soul Shards cap, out-of-combat auto-deletion toggle, and manual "Clean Up Now" button.
    - **OneLock_Procs**: Nightfall, Backlash, and CC Immunity toggles, audio warning toggle, and "Trigger Test Proc Alert" button.
- **Slash Command Integration**:
  - Running `/ol`, `/onelock`, `/olshards`, or `/olprocs` with no arguments or `config`/`options` now toggles the standalone options window.

---

## [0.1.1] - 2026-11-15

### Fixed
- **Engine API Alignment (WoW Forever Interface 16001)**:
  - Fixed fatal `GetSpellInfo` nil call in `OneLock_Timers/Tracker.lua` by implementing modern `C_Spell.GetSpellInfo` (table payload) and `C_Spell.GetSpellName`.
  - Fixed fatal `GetContainerNumSlots` nil call in `OneLock_Shards/ShardManager.lua` by implementing modern `C_Container.GetContainerNumSlots` and `C_Container.GetContainerItemID`.
  - Fixed fatal `UnitBuff` nil call in `OneLock_Procs/Alerts.lua` by implementing modern `C_UnitAuras.GetPlayerAuraBySpellID`.
  - Fixed fatal engine error `Forbidden function call: AddOn attempted to call 'RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")'`:
    - Removed `COMBAT_LOG_EVENT_UNFILTERED` across all modules to adhere to WoW Forever's combat log disarmament.
    - Transitioned multi-target aura tracking to modern `C_UnitAuras` and nameplate event routing (`UNIT_AURA`, `NAME_PLATE_UNIT_ADDED`/`REMOVED`, `PLAYER_TARGET_CHANGED`, `UNIT_SPELLCAST_SUCCEEDED`).
    - Transitioned CC immunity alerts to `UI_ERROR_MESSAGE` ("Target is immune").
    - Transitioned Soulstone cast detection to `UNIT_SPELLCAST_SUCCEEDED`.

### Changed
- **Decoupled OnePanel & MovableFrames**:
  - Removed all dependencies and optional dependencies on `OnePanel`, `OnePanelUtils`, and `MovableFrames`.
  - Maintained fully self-contained movable anchor system in `OneLock_Timers` (`/ol unlock` / `/ol lock`).
- **Integrated OneSwatter**:
  - Added optional dependency on `OneSwatter` in all `.toc` files.
  - Implemented `ns:Log(level, category, message, extraData)` routing directly to `OneSwatter:Log` for live diagnostics and debug capturing.

---

## [0.1.0] - 2026-11-15

### Added
- Initial modular scaffolding (`OneLock_Timers`, `OneLock_Shards`, `OneLock_Procs`).
- Initial multi-target timer engine and Pandemic color shift logic.
