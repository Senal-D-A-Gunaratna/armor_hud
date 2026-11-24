# Mineclonia Armor HUD

A lightweight, server-side armor HUD for [Mineclonia](https://github.com/mineclonia/mineclonia).
It shows the armor a player is actually wearing, using the item textures that
Mineclonia and armor-providing mods have already registered.

The mod is designed specifically for Mineclonia's `mcl_armor` API. It is not a
generic 3D Armor compatibility layer.

## Features

- Shows the four equipped armor pieces in head, torso, legs, boots order.
- Each piece is wrapped in an inventory cell using Mineclonia's own
  `mcl_offhand_slot.png` texture, the same slot the offhand HUD uses.
- Hides empty slots and hides the whole HUD when no armor is equipped.
- Uses the equipped `ItemStack`'s inventory image, so leather dyeing, armor
  trims, enchantment glints and third-party armor textures are preserved.
- Shows a small durability bar, centered inside the cell under every
  damageable armor piece.
- The bar uses Mineclonia's own `mcl_wear_bar.png` texture and wear-bar color
  gradient (green to yellow to red), matching the durability bars of items in
  inventories and the offhand HUD.
- When a piece becomes critical, its icon blinks while its durability bar
  stays visible. Other pieces keep their normal appearance.
- Independent state for every player: HUD element IDs, durability and blink
  phase are all per player.
- Event-driven refresh on armor inventory changes, with a 0.5 s polling
  fallback for durability loss that happens without inventory interaction.
- HUD updates are diffed; `hud_change` is only called when a displayed value
  has actually changed.

## Requirements

- Luanti 5.10 or later (the version required by the target Mineclonia release).
- Mineclonia with the `mcl_armor`, `mcl_util`, `mcl_enchanting` and
  `mcl_offhand` mods (all part of the game).
- No additional libraries or external dependencies.

The implementation was researched against Mineclonia `game.conf` release
`39603`, whose armor code uses:

- armor inventory list: `armor`, size 5;
- slot indices: head = 2, torso = 3, legs = 4, feet = 5, exposed through
  `mcl_armor.elements[slot].index`;
- armor definitions registered with `mcl_armor.register_set()` or with the
  fields documented in `mcl_armor/API.md`;
- durability groups: `mcl_armor_uses` (with Unbreaking applied by
  `mcl_util.calculate_durability()`);
- inventory appearance: `inventory_image` on the item definition, overridden
  per stack by the `inventory_image` metadata key (used by leather dyeing and
  armor trims), with `inventory_overlay` drawn on top;
- enchanted variants: item names with the `_enchanted` suffix and the
  `mcl_enchanting.overlay` texture modifier.

## Installation

1. Copy the `mcl_armor_hud` directory into your world's `mods` directory, or
   into the global `mods` directory used by your Luanti installation.
2. Enable the mod for the world.
3. Start the world. The mod has no formspec, chat command or item; it works
   automatically for every player.

The mod depends on `mcl_armor`, `mcl_util`, `mcl_enchanting` and
`mcl_offhand`, so it will not enable in a game where those are unavailable.

## Configuration

Three settings are read from `minetest.conf` (or the in-game **Settings**
menu) and are applied at server start. All other behaviour is controlled by
editable values in `src/settings.lua`, not by user settings.

| Setting | Default | Description |
|---|---:|---|
| `mcl_armor_hud_anchor` | `left` | Horizontal anchor: `left`, `center` or `right`. |
| `mcl_armor_hud_offset_x` | `8` | Pixels from the anchored edge. For `right`, positive values move left. |
| `mcl_armor_hud_offset_y` | `8` | Pixels above the bottom of the screen. |
| `mcl_armor_hud_icon_scale` | `2.0` | Scale of armor cells and items. At 1.0: 16x16 px item in a 20x20 px cell. |
| `mcl_armor_hud_blink_interval` | `200` | Milliseconds between icon visibility flips (a full cycle is twice this). |

### Editable values in the source

The following are **not** user settings. Edit the `VALUES` table near the top
of `src/settings.lua` to change them:

| Value | Default | Description |
|---|---:|---|
| `offset_x` | `8` | Pixels from the anchored edge. For `right`, positive values move left. |
| `offset_y` | `8` | Pixels above the bottom of the screen. |
| `icon_spacing` | `4` | Pixels between adjacent icons. |
| `critical_threshold` | `10` | Percentage at or below which the icon blinks. |
| `poll_interval` | `0.5` | Seconds between durability polls. |

Validation rules:

- Unknown anchors fall back to `left`.
- `icon_scale` and `blink_interval` are clamped to the ranges declared in
  `settingtypes.txt`.
- Non-numeric values fall back to the documented defaults.

Only visible (equipped) pieces are laid out. The group is left-aligned,
centered or right-aligned according to the anchor. Positive horizontal offsets
move the group right for the `left` and `center` anchors and left for the
`right` anchor.

## How it works

`src/armor.lua` reads the player's `armor` list using the indices published by
`mcl_armor.elements`, resolves each stack's inventory image the same way
Luanti's inventory renderer does, and asks `src/durability.lua` for durability
information.

`src/durability.lua` uses `mcl_util.calculate_durability(stack)` for maximum
uses (including Unbreaking) and the engine's 0..65535 wear value for the
remaining fraction. The formula matches Mineclonia's own elytra durability
check: `remaining = (65536 - wear) * max_uses / 65536`. The bar color is
computed from the same wear value with the exact gradient Luanti uses for item
durability bars and Mineclonia uses for its offhand wear bar.

`src/settings.lua` reads the three user settings and holds the remaining
layout, threshold and polling values as editable source constants.

`src/hud.lua` manages image HUD elements per armor slot. Each piece has four
elements: the Mineclonia inventory-cell background, the full-size item image,
a bar background and a bar fill below it, inside the cell. `src/player.lua`
owns all per-player state and lifecycle handling:

- join: create state and refresh;
- armor inventory action: mark dirty and refresh on the next server step;
- global step: poll every 0.5 s, blink critical icons;
- leave: remove all elements and drop the state;
- death: clear the HUD immediately and refresh after death drops;
- respawn: refresh again.

No Mineclonia function is monkey-patched. Armor changes are detected through
the engine's inventory action callback and the durability fallback poll.

## Supported Mineclonia version

Source-compatibility target: Mineclonia release **39603**, on Luanti 5.17.0.
The mod loaded without Lua errors in a headless Luanti server running that
release. The armor API used here is not marked as unstable in
`mcl_armor/API.md`, but Mineclonia does not guarantee that undocumented
internals remain unchanged. Re-check the source if you use a very different
Mineclonia release.

## Known limitations

- If a third-party armor item is placed in an armor slot without being
  registered as an item, it is skipped.
- Unbreakable armor (no finite durability) is shown as an icon without a bar.
- Settings require a server restart to take effect. Changing the source-defined
  values also requires restarting with the updated mod (and rebuilding the ZIP
  if you installed it from a release archive).
- The HUD is server-side and uses image elements. Cell proportions follow
  `mcl_offhand` (a 16 px item in a 20 px cell at scale 1.0), but Mineclonia's
  textures are used instead of Minecraft's.
- Very large icon scales or offsets can place the HUD off-screen. Values are
  clamped to sane ranges but the mod does not measure the player's screen.
- The blink phase restarts whenever a piece becomes critical, so it may not be
  in lockstep with a piece that was already critical.

## Development and testing

Static syntax check:

```sh
find . -name '*.lua' -print0 | xargs -0 -n1 luac -p
```

The standalone test harness stubs `core`, `mcl_armor`, `mcl_util` and
`mcl_enchanting`, loads the modules from `src/`, and simulates player joins,
armor changes, aliases, durability loss, wear-bar colors, critical blinking,
multiple players, disconnects, death/respawn and third-party armor.
It checks the generated HUD calls and per-player state isolation without
starting a server:

```sh
luajit tests/simulate.lua
```

A successful run ends with `ALL SIMULATED TESTS PASSED`. The harness is for
development only and is not loaded by Luanti.

Headless load test:

```sh
luanti --server --world /path/to/test-world --gameid mineclonia
```

The mod loaded without Lua errors in a headless Luanti 5.17.0 server using
Mineclonia release 39603. A live graphical client test has not been performed;
visual placement and blink timing should still be checked in-game before
publishing to a wide audience.

## License

The mod's source code is released under the MIT License. See `LICENSE`. The
mod ships no textures or other media.

This mod does **not** copy or redistribute Mineclonia's armor textures, code
or other media. It references textures registered by Mineclonia and other mods
at runtime. Those textures remain under their respective licenses. Mineclonia's
source is GPLv3-or-later and its media are covered by the licenses described in
its `LICENSE.txt` and `LEGAL.md`.
