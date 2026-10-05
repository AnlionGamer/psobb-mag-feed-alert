# Ephinea Staff Review Notes

This repository is currently **pre-release and pending Ephinea staff review**. No GitHub release or tag has been created.

The complete addon source proposed for use is:

- [`Mag Feed Alert/init.lua`](Mag%20Feed%20Alert/init.lua)

The purpose of this document is to make the relevant behavior easy to audit without requiring a reviewer to infer scope from the UI code.

## Intended behavior

Mag Feed Alert is a visual reminder for manual Mag feeding.

During cooldown it renders:

```text
Feed Mag x:xx
```

When the carried Mag timer indicates feeding is available, it renders:

```text
FEED MAG
```

The **Away** profile can additionally render a larger `FEED MAG` message and a slow screen-edge pulse. These are visual-only ImGui elements.

The player still opens the inventory and feeds the Mag manually.

## Game data read

The addon imports the existing Soly library:

```lua
local items_ok, lib_items = pcall(require, "solylib.items.items")
```

The only inventory acquisition performed by this addon is:

```lua
local ok, inventory = pcall(lib_items.GetInventory, lib_items.Me)
```

`lib_items.Me` requests the local player's inventory. The returned local inventory is scanned only for entries where `item.mag` exists, and the addon reads the already-exposed `item.mag.timer` value.

It does not request another player's inventory index.

It also reads:

- render resolution through `solylib.helpers`, for HUD placement;
- `pso.get_tick_count()`, for UI animation timing and scan throttling.

## No game-memory writes

The addon contains no calls to `pso.write_*` and does not modify PSOBB memory.

The only file it writes is its own preferences file:

```text
addons/Mag Feed Alert/options.lua
```

That file stores addon UI/profile settings only.

## No gameplay automation

The addon does not:

- automate Mag feeding;
- navigate PSO menus;
- move or select inventory items;
- generate keyboard input;
- generate controller input;
- generate gameplay mouse input;
- expose a `key_pressed` or `key_released` gameplay callback;
- perform an action when the timer reaches zero.

Reaching the ready state changes only addon-rendered visuals.

Mouse interaction is limited to ImGui controls belonging to the addon itself: profile selection, configuration, layout placement, and preview controls.

## No packet/network behavior

The addon does not send packets, hook network traffic, or make external network requests.

There is no packet-manipulation or networking code in `Mag Feed Alert/init.lua`.

## No other-player inventory reading

The addon does not enumerate player inventories.

Its inventory call is specifically:

```lua
lib_items.GetInventory(lib_items.Me)
```

and it operates only on the returned local player's items.

## Timer/readiness behavior

The addon does not run an independent 3:30 feeding stopwatch.

It repeatedly reacquires the local inventory and uses the carried Mag timer values supplied by SolyLib.

If multiple carried Mags ever report different timer values, the addon intentionally uses the **largest** remaining value before declaring Ready. This is conservative and avoids announcing readiness early.

Relevant code:

```lua
tracker.remaining = clamp(math.floor(tracker.rawMax), 0, 210)
tracker.ready = tracker.rawMax < 1.0
```

## Rendering behavior

All display behavior is implemented with the existing addon plugin ImGui API.

The large Away-mode ready message and screen-edge border are created in windows using `NoInputs`, so those visual alerts do not accept gameplay clicks or perform interactions.

## Preview mode

The configuration window includes **Preview Cooldown** and **Preview Ready** controls. These create a temporary fake **render state only** so the user can inspect alert appearance without waiting for a real feed cycle.

Preview mode does not alter game memory, inventory, the Mag timer, or feeding state.

## Dependencies

The addon expects the normal PSOBB addon environment and uses:

- `core_mainmenu`
- `solylib.helpers`
- `solylib.items.items`

Upstream projects:

- https://github.com/Solybum/psobbaddonplugin
- https://github.com/Solybum/PSOBBMod-Addons

No upstream files are vendored into this repository.

## Requested clarification

Before normal use or release, clarification is requested on whether the following is permitted on Ephinea:

1. Reading the local player's carried Mag timer through the existing SolyLib item reader.
2. Displaying that timer as a visual countdown.
3. Displaying a larger visual-only reminder and screen-edge pulse when the timer reaches the feed-ready state.

There is intentionally no automated feeding or gameplay input in the proposed addon.
