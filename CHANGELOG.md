# Changelog

All notable changes to the **OneLock** addon suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Full `OneLock_Shards` inventory deletion loop and persistent 30-minute Soulstone HUD bar.
- Full `OneLock_Procs` screen alerts and sound triggers for Nightfall, Backlash, and target CC immunity.
- Integrated graphical options panel inside `OnePanel`.

---

## [0.1.0] - 2026-11-15

### Added
- **Suite Scaffolding**: Initialized modular multi-addon layout (`OneLock_Timers`, `OneLock_Shards`, `OneLock_Procs`) targeting WoW Forever Beta (`v1.60.1` / `Interface: 16001`).
- **OneLock_Timers**:
  - Implemented multi-target DoT and CC tracker driven by `COMBAT_LOG_EVENT_UNFILTERED` filtered to player source GUID.
  - Added support for Corruption, Unstable Affliction, Curse/Bane of Agony, Curse of Doom, Curse of the Elements, Curse of Recklessness, Curse of Tongues, Curse of Weakness, Siphon Life, Immolate, Seed of Corruption, Banish, and Fear.
  - Implemented client-authoritative `UnitDebuff` duration reconciliation on target, focus, and mouseover units.
  - Added instant purging on `UNIT_DIED` and `UNIT_DESTROYED` with background OnUpdate timer garbage collection.
  - Built non-protected reusable frame pool (`StatusBar` and target header frames) grouped by `destGUID` under `OneLockTimersAnchor`.
  - Added target name header highlighting for currently selected `target`.
  - Added visual Pandemic refresh color shift when remaining duration is under 3.0 seconds.
  - Added slash command suite (`/onelock`, `/ol`) with `/ol test`, `/ol unlock`, `/ol lock`, `/ol reset`, and scaling/width options.
- **OneLock_Shards**:
  - Initialized module manifest and Core scaffold.
  - Added `BAG_UPDATE` Soul Shard counting stub (itemID 6265) and out-of-combat excess deletion framework.
  - Added 30-minute Soulstone tracking frame stub.
- **OneLock_Procs**:
  - Initialized module manifest and Core scaffold.
  - Added `UNIT_AURA` proc detection stubs for Shadow Trance (Nightfall) and Backlash.
  - Added combat log CC target immunity detection stub.
- **Workspace Tooling**:
  - Integrated `OneLock` into `sync-live.sh` and `rollback-live.sh` with automatic multi-module discovery and syncing.
  - Configured `.github/workflows/package.yml` release packaging workflow.
