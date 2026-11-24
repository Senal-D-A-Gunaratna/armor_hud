# AGENTS.md

For AI agents: read this file before working in this repository. It is the
fastest source of truth for project knowledge. Keep it current: whenever code,
settings, tests, dependencies, verification commands or packaging change,
update the relevant section in the same change. Prefer verifying against the
source before relying on any statement here.

## Project

Server-side Luanti/Mineclonia mod: shows equipped armor icons with durability
bars and blinking at critical durability. No formspec, chat command or items.
Target: Mineclonia release `39603`, Luanti 5.17.0 (Luanti >= 5.10 required).
License: MIT; the mod ships no media. All textures, including the 1x1 white
bar pixel (`mcl_wear_bar.png`), are referenced from Mineclonia at runtime.

Dependencies (`mod.conf`): `mcl_armor`, `mcl_util`, `mcl_enchanting`,
`mcl_offhand`.

## File map

- `AGENTS.md`: this file; AI agents read it as the source of truth and update it
  when the code, settings, tests, dependencies or workflow change.
- `init.lua`: checks `mcl_armor.elements`, loads `src/*.lua` with `dofile`, calls
  `player.start(settings, armor, hud)`.
- `src/settings.lua`: three user settings + `VALUES` table (source-defined
  layout/threshold/poll values), validation and clamping.
- `src/armor.lua`: reads inventory list `armor` in `head, torso, legs, feet`
  order using `mcl_armor.elements[slot].index` (2,3,4,5); resolves aliases,
  item definitions and per-stack textures.
- `src/durability.lua`: durability math from wear and `mcl_armor_uses`.
- `src/hud.lua`: image HUD elements, diffed updates, visibility toggles.
- `src/player.lua`: per-player state, layout, blink, lifecycle, polling.
- `tests/simulate.lua`: standalone LuaJIT simulation harness.
- `README.md`, `settingtypes.txt`, `mod.conf`: user-facing docs/metadata.
- `mcl_armor_hud.zip` (in parent `mods/` dir): release archive, rebuild after
  every change.

## Runtime facts

- Armor inventory list is `armor`, size 5; slot indices come from
  `mcl_armor.elements[slot].index`. Formspec `list[...]` indices are 1-based,
  Lua `get_stack` indices are 1-based; Mineclonia's formspec strings use
  1..4 for slots 2..5.
- Texture resolution (`src/armor.lua:16`): stack meta `inventory_image` overrides
  the item definition's `inventory_image`; empty → `unknown_item.png`. Append
  `inventory_overlay` (meta first, then def) with `^`. If
  `mcl_enchanting.is_enchanted(name)`, append `mcl_enchanting.overlay` (glint)
  unless already present. Item aliases are resolved via
  `core.registered_aliases` before the definition lookup.
- Durability (`src/durability.lua:11`): `max_uses` from
  `mcl_util.calculate_durability(stack)` (includes Unbreaking); `nil`/`<= 0`
  means unbreakable → icon only, no bar. Wear range 0..65535; divisor 65536;
  `fraction = clamp(65536 - wear, 0, 65536) / 65536`;
  `percent = fraction * 100`; `remaining_uses = floor(remaining_wear *
  max_uses / 65536)`.
- HUD elements (`src/hud.lua`): three per piece — icon (z=12), bar background
  (z=10), bar fill (z=11). `type="image"`, `position={x=pos_x,y=1}`,
  `alignment={x=1,y=-1}`. With y=-1 the element's bottom edge is at
  `position.y + offset.y`; with x=1 it starts at the left edge of the anchor.
  `scale=1` renders a 16x16 texture at native size. Bar color uses Mineclonia's
  wear-bar gradient (`src/player.lua:16`): `wear_i =
  min(floor(wear / 65535 * 600) + 10, 511)`; if `wear_i <= 255` color is
  `(wear_i, 255, 0)` (green→yellow), else `(255, 511 - wear_i, 0)`
  (yellow→red). This matches Luanti's `drawItemStack.cpp` and Mineclonia's
  `mcl_offhand/init.lua`. Both bar elements use Mineclonia's
  `mcl_wear_bar.png` (1x1 white pixel) as their base texture. Bar background
  `#1b1b1b`; fill width =
  `round(bar_width * fraction)`.
- Critical blink (`src/player.lua:84`): time between visibility *flips* is
  `blink_interval` ms (full cycle = 2x). Only the icon is hidden; both bar
  elements stay visible. The phase resets when a piece first becomes critical.
- There is no reliable Mineclonia armor-change callback: use
  `core.register_on_player_inventory_action` + a 0.5 s durability poll. Never
  monkey-patch Mineclonia functions.
- Lifecycle: join creates state and refreshes; inventory action marks dirty;
  globalstep polls/blinks; leave clears HUD and state; death clears HUD and
  schedules refresh; respawn refreshes again. States are keyed by player name
  and fully independent.

## Configuration

Only three user settings (`settingtypes.txt`, read in `src/settings.lua`):

| Setting | Default | Range |
|---|---:|---|
| `mcl_armor_hud_anchor` | `left` | `left`, `center`, `right` |
| `mcl_armor_hud_icon_scale` | `2.0` | 0.25–4.0 |
| `mcl_armor_hud_blink_interval` | `200` ms | 100–10000 |

Invalid anchor falls back to `left`; non-numeric/clamped values use defaults
and range bounds.

All other values live in the `VALUES` table at `src/settings.lua:3` and are
**not** settings: `offset_x=8`, `offset_y=8`, `icon_spacing=4`,
`critical_threshold=10` (blink only), `poll_interval=0.5`.
Layout uses
`icon_px = 16 * icon_scale`, `step = icon_px + icon_spacing`,
`bar_width = round(icon_px)`, `bar_height = max(2, round(icon_px/8))`,
`gap = max(1, round(icon_px/16))`, `icon_y = -(offset_y + bar_height + gap)`,
`bar_y = -offset_y`. Right anchor: positive `offset_x` moves left; center/left:
positive moves right. Edit `README.md` if this table changes.

## Testing

- Syntax: `for f in init.lua src/*.lua; do luac -p "$f"; done`
- Simulation: `luajit tests/simulate.lua` from the mod dir; success ends with
  `ALL SIMULATED TESTS PASSED`. The harness derives MODPATH via
  `debug.getinfo`, stubs `core`/`mcl_armor`/`mcl_util`/`mcl_enchanting`, and
  checks HUD calls, texture/alias/enchant cases, durability polling, colors,
  blink with bar still visible, per-player isolation, diffing, lifecycle and
  all three anchors. To test non-configurable offsets, mutate the returned
  config table after `load_mod()` (e.g. `cfg.offset_x = 10`).
- Test pitfalls: wear `59000` for critical (the rounded 10% boundary is
  `math.floor(65536*0.9)=58982`, which is still above the 10% threshold);
  advance `0.21` s per blink flip to avoid float boundary at exactly `0.2`.
  Expected gradient colors: wear 0 → `#0aff00`, 32768 → `#ffc900`,
  49152 → `#ff3300`, 59000 → `#ff0000`.
- Headless load: world at `/tmp/opencode/armor_hud_world` with `world.mt`:
  `gameid = mineclonia`, sqlite3 backends, `load_mod_mcl_armor_hud = true`.
  Run `timeout 12s luanti --server --world /tmp/opencode/armor_hud_world
  --gameid mineclonia --port 39019 --logfile .../debug.txt --verbose`;
  exit `124` (timeout) is expected. Grep stdout for
  `Mod "mcl_armor_hud" loaded` and absence of `ERROR|WARNING`. No live
  graphical client test has been done.

## Packaging and workflow

- Build: from `/home/senal/.minetest/mods`, `zip -qr mcl_armor_hud.zip
  mcl_armor_hud -x 'mcl_armor_hud/.git/*' 'mcl_armor_hud/.git'`. Validate with
  `unzip -t` and by extracting to `/tmp/opencode/zipcheck/mods` and running
  `diff -r --exclude=.git`.
- Loading a ZIP copy via `LUANTI_MOD_PATH` requires moving the global source
  dir out of `mods/`; merely renaming it inside `mods/` still triggers
  `Mod name conflict detected`.
- Commit each logical step separately when the user asks for commits; do not
  commit unless asked. Current HEAD before the no-media change:
  `b51719c`, clean tree.
- History note: an inventory-cell redesign was committed once and then
  discarded by an external `git reset` to `bfa374f`; the current code is the
  simple icon + durability-bar design. Do not assume those cell commits exist.
