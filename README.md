# OneLock Suite

**OneLock** is a modular World of Warcraft addon suite designed specifically for the **WoW: Forever Beta (`v1.60.1` / `Interface: 16001`)** client. It delivers high-signal, zero-bloat raid utility for Warlocks, replacing bulky legacy radial HUDs with clean, modern, combat-safe components.

---

## 📦 Suite Modules

The suite is broken into three lightweight, independently loadable modules:

| Module | Purpose | Status |
| :--- | :--- | :--- |
| **`OneLock_Timers`** | Multi-target raid DoT and crowd-control tracking engine with Pandemic refresh color shifts (< 3.0s) and target grouping. | **Active / Ready** |
| **`OneLock_Shards`** | Automated Soul Shard inventory management, excess shard cleanup, and persistent 30-minute Soulstone tracking. | **Active / Ready** |
| **`OneLock_Procs`** | High-visibility proc alerts for Shadow Trance (Nightfall) and Backlash, plus target CC immunity detection (Fear/Banish). | **Active / Ready** |

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

## ⚙️ Options & Configuration

OneLock includes a full graphical configuration panel available in two modes:

1. **In-Game Settings Menu**:
   - Press `ESC` -> **Options** -> **AddOns** tab -> select **OneLock**.
   - Includes an **`[Open Standalone Window]`** button to pop out into a floating HUD editor and close the Game Menu.
2. **Standalone Floating Window**:
   - Type `/ol` (or `/onelock`, `/olshards`, `/olprocs`) at any time to open or close the movable options panel directly.
   - Configure timer bar dimensions, scale, colors, test bars, soul shard limits, and proc alerts with live updates.

---

## ⌨️ Slash Commands (Quick Shortcuts)

### `OneLock_Timers` (`/onelock`, `/ol`)
- `/ol` — Display available commands and current configuration status.
- `/ol test` — Toggle simulated multi-target test bars for visual alignment and setup.
- `/ol unlock` — Unlock the master anchor frame to reposition the timer bars via dragging.
- `/ol lock` — Lock the master anchor frame in place and persist coordinates.
- `/ol reset` — Reset the master anchor frame to default screen coordinates.
- `/ol scale <0.5 - 2.0>` — Adjust the display scale of the timer bars (e.g., `/ol scale 1.1`).
- `/ol width <100 - 300>` — Set the pixel width of timer bars (e.g., `/ol width 180`).
- `/ol max <1 - 10>` — Set the maximum number of targets tracked simultaneously (e.g., `/ol max 4`).

### `OneLock_Shards` (`/olshards`)
- `/olshards count` — Print current soul shard inventory count.
- `/olshards cap <1-32>` — Configure maximum soul shard retention cap (default: 24).
- `/olshards autodelete` — Toggle automatic out-of-combat deletion of excess shards.
- `/olshards cleanup` — Immediately delete shards above cap out of combat.

### `OneLock_Procs` (`/olprocs`)
- `/olprocs test` — Trigger a test proc alert banner on screen.
- `/olprocs sound` — Toggle proc audio alert sound effects.
- `/olprocs nightfall` — Toggle Shadow Trance alerts.
- `/olprocs backlash` — Toggle Backlash alerts.
- `/olprocs immunity` — Toggle target CC immunity alerts.

---

## 🎯 Architecture & Safety

- **Interface 16001 Native**: Exclusively targets the WoW Forever Beta client utilizing modern `C_Spell`, `C_Container`, and `C_UnitAuras` engine APIs.
- **Combat Lockdown Safe**: All visual display bars are driven by non-protected `StatusBar` and `Frame` pools. They can create, anchor, resize, and hide during active raid combat with zero taint risk.
- **Zero Third-Party Dependencies**: Self-contained with independent drag anchors (`/ol unlock`). No dependencies on `OnePanel` or `MovableFrames`.
- **Diagnostics Integration**: Includes optional `OneSwatter` bridge for centralized logging and error reporting.

---

## 📜 License

Created by Nuros for the WoW Forever community.
