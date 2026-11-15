# OneLock Suite

**OneLock** is a modular World of Warcraft addon suite designed specifically for the **WoW: Forever Beta (`v1.60.1` / `Interface: 16001`)** client. It delivers high-signal, zero-bloat raid utility for Warlocks, replacing bulky legacy radial HUDs with clean, modern, combat-safe components.

---

## 📦 Suite Modules

The suite is broken into three lightweight, independently loadable modules:

| Module | Purpose | Status |
| :--- | :--- | :--- |
| **`OneLock_Timers`** | Multi-target raid DoT and crowd-control tracking engine with Pandemic refresh color shifts (< 3.0s) and target grouping. | **Active / Ready** |
| **`OneLock_Shards`** | Automated Soul Shard inventory management, excess shard cleanup, and persistent 30-minute Soulstone tracking. | **Scaffolded (v0.1.0)** |
| **`OneLock_Procs`** | High-visibility proc alerts for Shadow Trance (Nightfall) and Backlash, plus target CC immunity detection (Fear/Banish). | **Scaffolded (v0.1.0)** |

---

## 🚀 Installation

### Development / Local Sync
1. Clone or copy the `OneLock` repository folder into your development workspace.
2. Run the sync script from the workspace root to deploy the sub-modules directly into your live client's AddOns directory:
   ```bash
   ./sync-live.sh OneLock
   ```
3. In-game, type `/reload` to load the modules.

### Manual Installation
Copy the individual module folders (`OneLock_Timers`, `OneLock_Shards`, and `OneLock_Procs`) from this repository into:
```text
World of Warcraft/_forever_/Interface/AddOns/
```

---

## ⌨️ Slash Commands

Use `/onelock` or `/ol` to manage `OneLock_Timers`:

- `/ol` — Display available commands and current configuration status.
- `/ol test` — Toggle simulated multi-target test bars for visual alignment and setup.
- `/ol unlock` — Unlock the master anchor frame to reposition the timer bars via dragging.
- `/ol lock` — Lock the master anchor frame in place and persist coordinates.
- `/ol reset` — Reset the master anchor frame to default screen coordinates.
- `/ol scale <0.5 - 2.0>` — Adjust the display scale of the timer bars (e.g., `/ol scale 1.1`).
- `/ol width <100 - 300>` — Set the pixel width of timer bars (e.g., `/ol width 180`).
- `/ol max <1 - 10>` — Set the maximum number of targets tracked simultaneously (e.g., `/ol max 4`).

*(Stubs for `/olshards` and `/olprocs` are available in their respective modules)*.

---

## 🎯 Architecture & Safety

- **Interface 16001 Native**: Exclusively targets the WoW Forever Beta client without legacy shims or Dragonflight/TWW retail dependencies.
- **Combat Lockdown Safe**: All visual display bars are driven by non-protected `StatusBar` and `Frame` pools. They can create, anchor, resize, and hide during active raid combat with zero taint risk.
- **Ecosystem Integration**: Seamlessly registers with `MovableFrames` and `OnePanel` if present in your addon list.

---

## 📜 License

Created by Nuros for the WoW Forever community.
