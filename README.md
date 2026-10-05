# Mag Feed Alert for PSOBB

A read-only Lua addon for the PSOBB addon plugin ecosystem that displays the live carried-Mag feeding countdown and makes the ready-to-feed state more noticeable.

> **Status: pre-release / pending Ephinea staff review.**
>
> This repository is being made public so Ephinea staff can review the complete source before the addon is used or released. It is **not affiliated with, endorsed by, or approved by Ephinea** unless Ephinea staff explicitly state otherwise.

## What it does

During the Mag feeding cooldown, the HUD displays:

```text
Feed Mag 2:17
```

When feeding becomes available, it changes to:

```text
FEED MAG
```

Three visual profiles are included:

- **Active** — compact HUD with a brief ready pulse.
- **Away** — compact countdown, then a large ready message and slow screen-edge pulse.
- **Custom** — configurable HUD, sizing, colors, pulse behavior, and border behavior.

The factory HUD position is resolution-aware and anchored in the upper-right area below the native minimap.

## Read-only scope

The addon is intentionally limited to notification/UI behavior.

It does **not**:

- automatically feed a Mag;
- press keys, controller buttons, or menu inputs;
- manipulate inventory;
- write PSOBB memory;
- send game/network packets;
- inspect another player's inventory;
- perform gameplay actions on the player's behalf.

It reads the local player's carried inventory through SolyLib and uses the Mag timer already exposed by that library. All actual Mag feeding remains manual.

For an audit-oriented breakdown, see **[STAFF_REVIEW.md](STAFF_REVIEW.md)**.

## Dependencies

The addon is designed for the standard PSOBB addon plugin/Soly addon environment and uses:

- `core_mainmenu`
- `solylib.helpers`
- `solylib.items.items`

Related upstream projects:

- [Solybum/psobbaddonplugin](https://github.com/Solybum/psobbaddonplugin)
- [Solybum/PSOBBMod-Addons](https://github.com/Solybum/PSOBBMod-Addons)

No upstream source files are bundled in this repository.

## Source layout

```text
Mag Feed Alert/
└── init.lua
```

At runtime the addon creates:

```text
addons/Mag Feed Alert/options.lua
```

That file contains only local addon preferences and is intentionally excluded from source control.

## Installation

There is intentionally **no GitHub release yet** while staff review is pending.

For source review, the complete addon is in `Mag Feed Alert/init.lua`.

Once approved for normal use, installation is intended to be:

```text
addons/
└── Mag Feed Alert/
    └── init.lua
```

The normal addon menu can reload Lua addons through **Main > Reload**, allowing most testing and UI iteration without repeatedly reconnecting.

## Development notes

The addon uses the live carried-Mag timer rather than maintaining an independent 3:30 stopwatch. If carried Mag timers ever disagree, it uses the largest remaining timer so it does not announce readiness early.

The configuration UI includes non-gameplay preview modes for the cooldown and ready presentation. Preview mode changes only rendered addon state and does not alter the Mag or game state.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

Developed with assistance from ChatGPT.
