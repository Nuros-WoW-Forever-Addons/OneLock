# Changelog

All notable changes to the **OneLock** addon suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
