-- Standalone simulation harness for armor_hud.
-- Run from the mod directory with: luajit tests/simulate.lua
-- It stubs only the Luanti/Mineclonia surface used by the mod and checks the
-- HUD calls emitted in response to joins, equipment changes and globalsteps.

local source = debug.getinfo(1, "S").source
local script = source:sub(1, 1) == "@" and source:sub(2) or source
local root = script:match("^(.*)/tests/[^/]+$")
local MODPATH = (root and root ~= "") and root or "."

local clock = 0
local next_hud_id = 1
local after_jobs = {}
local callbacks = {}
local settings_values = {}

local function deepcopy(v)
	if type(v) ~= "table" then return v end
	local r = {}
	for k, x in pairs(v) do r[k] = deepcopy(x) end
	return r
end

local Meta = {}
Meta.__index = Meta
function Meta.new(data) return setmetatable({ data = data or {} }, Meta) end
function Meta:get_string(k) return self.data[k] or "" end
function Meta:set_string(k, v) self.data[k] = v end

local Stack = {}
Stack.__index = Stack
function Stack.new(name, meta_data, wear)
	return setmetatable({
		name = name or "",
		meta = Meta.new(meta_data),
		wear = wear or 0,
	}, Stack)
end
function Stack:is_empty() return self.name == "" end
function Stack:get_name() return self.name end
function Stack:get_wear() return self.wear end
function Stack:get_meta() return self.meta end
function Stack:get_definition() return core.registered_items[self.name] or {} end

local Inv = {}
Inv.__index = Inv
function Inv.new() return setmetatable({ lists = {} }, Inv) end
function Inv:set_size(list, n)
	self.lists[list] = self.lists[list] or {}
	for i = 1, n do
		if not self.lists[list][i] then self.lists[list][i] = Stack.new("") end
	end
end
function Inv:get_size(list) return self.lists[list] and #self.lists[list] or 0 end
function Inv:get_stack(list, i)
	return self.lists[list] and self.lists[list][i] or Stack.new("")
end
function Inv:set_stack(list, i, stack) self.lists[list][i] = stack end

local Player = {}
Player.__index = Player
function Player.new(name)
	local p = setmetatable({
		name = name,
		inv = Inv.new(),
		hud = {},
		hud_adds = {},
		change_calls = {},
		remove_calls = {},
	}, Player)
	p.inv:set_size("armor", 5)
	return p
end
function Player:is_player() return true end
function Player:get_player_name() return self.name end
function Player:get_inventory() return self.inv end
function Player:hud_add(def)
	local id = next_hud_id
	next_hud_id = next_hud_id + 1
	self.hud[id] = deepcopy(def)
	self.hud_adds[#self.hud_adds + 1] = { id = id, def = deepcopy(def) }
	return id
end
function Player:hud_change(id, field, value)
	assert(self.hud[id], "hud_change on missing id " .. tostring(id))
	self.change_calls[#self.change_calls + 1] = {
		id = id, field = field, value = deepcopy(value),
	}
	self.hud[id][field] = deepcopy(value)
end
function Player:hud_remove(id)
	self.remove_calls[#self.remove_calls + 1] = id
	self.hud[id] = nil
end

core = {}
core.settings = { get = function(_, k) return settings_values[k] end }
core.get_current_modname = function() return "armor_hud" end
core.get_modpath = function(name)
	assert(name == "armor_hud")
	return MODPATH
end
core.log = function() end
core.get_gametime = function() return clock end
core.after = function(delay, fn)
	after_jobs[#after_jobs + 1] = { due = clock + delay, fn = fn }
end
core.registered_items = {}
core.registered_aliases = {}
core.get_item_group = function(name, group)
	local def = core.registered_items[name]
	return def and def.groups and def.groups[group] or 0
end
core.register_on_joinplayer = function(fn) callbacks.join = fn end
core.register_on_leaveplayer = function(fn) callbacks.leave = fn end
core.register_on_dieplayer = function(fn) callbacks.die = fn end
core.register_on_respawnplayer = function(fn) callbacks.respawn = fn end
core.register_on_player_inventory_action = function(fn) callbacks.inventory = fn end
core.register_globalstep = function(fn) callbacks.globalstep = fn end

mcl_armor = {
	elements = {
		head = { index = 2 },
		torso = { index = 3 },
		legs = { index = 4 },
		feet = { index = 5 },
	},
}

mcl_util = {}
function mcl_util.calculate_durability(stack)
	return core.get_item_group(stack:get_name(), "mcl_armor_uses")
end

mcl_enchanting = { overlay = "^[colorize:purple:50" }
function mcl_enchanting.is_enchanted(name)
	return core.get_item_group(name, "enchanted") > 0
end

local function register_item(name, image, groups, extra)
	local def = { inventory_image = image, groups = groups or {} }
	if extra then
		for k, v in pairs(extra) do def[k] = v end
	end
	core.registered_items[name] = def
end

register_item("test:helmet_iron", "mcl_armor_inv_helmet_iron.png^[resize:128x128",
	{ armor = 1, armor_head = 1, mcl_armor_uses = 165 }, { _mcl_armor_element = "head" })
register_item("test:chest_iron", "mcl_armor_inv_chestplate_iron.png^[resize:128x128",
	{ armor = 1, armor_torso = 1, mcl_armor_uses = 241 }, { _mcl_armor_element = "torso" })
register_item("test:legs_iron", "mcl_armor_inv_leggings_iron.png^[resize:128x128",
	{ armor = 1, armor_legs = 1, mcl_armor_uses = 226 }, { _mcl_armor_element = "legs" })
register_item("test:feet_iron", "mcl_armor_inv_boots_iron.png^[resize:128x128",
	{ armor = 1, armor_feet = 1, mcl_armor_uses = 196 }, { _mcl_armor_element = "feet" })
register_item("test:helmet_diamond", "mcl_armor_inv_helmet_diamond.png^[resize:128x128",
	{ armor = 1, armor_head = 1, mcl_armor_uses = 364 }, { _mcl_armor_element = "head" })
register_item("test:helmet_leather", "mcl_armor_inv_helmet_leather.png^[resize:128x128",
	{ armor = 1, armor_head = 1, armor_leather = 1, mcl_armor_uses = 56 },
	{ _mcl_armor_element = "head" })
register_item("test:helmet_thirdparty", "thirdparty_custom_helmet.png^[resize:128x128",
	{ armor = 1, armor_head = 1, mcl_armor_uses = 77 }, { _mcl_armor_element = "head" })
register_item("test:helmet_crown", "test_crown.png^[resize:128x128",
	{ armor = 1, armor_head = 1 }, { _mcl_armor_element = "head" })
register_item("test:helmet_alias", "mcl_armor_inv_helmet_iron.png^[resize:128x128",
	{ armor = 1, armor_head = 1, mcl_armor_uses = 165 }, { _mcl_armor_element = "head" })
register_item("test:helmet_iron_enchanted", "mcl_armor_inv_helmet_iron.png^[colorize:purple:50",
	{ armor = 1, armor_head = 1, mcl_armor_uses = 165, enchanted = 1 },
	{ _mcl_armor_element = "head" })
core.registered_aliases["test:helmet_oldname"] = "test:helmet_alias"

local function fire_after_jobs()
	local pending = {}
	for _, job in ipairs(after_jobs) do
		if job.due <= clock then job.fn() else pending[#pending + 1] = job end
	end
	after_jobs = pending
end

local function step(dt)
	clock = clock + dt
	fire_after_jobs()
	if callbacks.globalstep then callbacks.globalstep(dt) end
end

local function advance(dt, substeps)
	substeps = substeps or 1
	for _ = 1, substeps do step(dt / substeps) end
end

local function join(name)
	local p = Player.new(name)
	callbacks.join(p)
	return p
end

local function equip(p, slot, itemname, wear, meta)
	local index = mcl_armor.elements[slot].index
	p.inv:set_stack("armor", index, Stack.new(itemname, meta, wear))
	callbacks.inventory(p, "put", p.inv, {
		to_list = "armor", to_index = index, stack = p.inv:get_stack("armor", index),
	})
end

local function unequip(p, slot)
	local index = mcl_armor.elements[slot].index
	p.inv:set_stack("armor", index, Stack.new(""))
	callbacks.inventory(p, "take", p.inv, { from_list = "armor", from_index = index })
end

local function set_wear(p, slot, wear)
	p.inv:get_stack("armor", mcl_armor.elements[slot].index).wear = wear
end

local function count_hud(p)
	local n = 0
	for _ in pairs(p.hud) do n = n + 1 end
	return n
end

local function icons(p)
	local out = {}
	for id, e in pairs(p.hud) do
		if e.z_index == 10 then out[#out + 1] = { id = id, e = e } end
	end
	table.sort(out, function(a, b) return a.e.offset.x < b.e.offset.x end)
	return out
end

local function bar_elements(p)
	local out = {}
	for id, e in pairs(p.hud) do
		if e.z_index == 11 or e.z_index == 12 then
			out[#out + 1] = { id = id, e = e }
		end
	end
	table.sort(out, function(a, b)
		if a.e.offset.x == b.e.offset.x then return a.e.z_index < b.e.z_index end
		return a.e.offset.x < b.e.offset.x
	end)
	return out
end

local function reset_calls(p)
	p.hud_adds = {}
	p.change_calls = {}
	p.remove_calls = {}
end

local function assert_eq(a, b, msg)
	if a ~= b then
		error((msg or "values differ") .. ": expected " .. tostring(b) ..
			", got " .. tostring(a), 2)
	end
end

local function assert_true(v, msg)
	if not v then error(msg or "assertion failed", 2) end
end

local function near(a, b) return math.abs(a - b) < 0.001 end

local RESIZE = "^[resize:128x128"

local function defaults()
	return {
		armor_hud_icon_scale = "2.0",
		armor_hud_blink_interval = "200",
		armor_hud_critical_threshold = "10",
	}
end

local function load_mod()
	local saved = settings_values
	settings_values = saved or defaults()
	local settings = dofile(MODPATH .. "/src/settings.lua").load()
	local armor = dofile(MODPATH .. "/src/armor.lua")
	local hud = dofile(MODPATH .. "/src/hud.lua")
	local player = dofile(MODPATH .. "/src/player.lua")
	player.start(settings, armor, hud)
	return settings
end

-- Settings validation.
settings_values = defaults()
settings_values.armor_hud_blink_interval = "zero"
settings_values.armor_hud_critical_threshold = "zero"
local s = dofile(MODPATH .. "/src/settings.lua").load()
assert_eq(s.icon_scale, 2.0, "icon scale is a setting")
assert_eq(s.blink_interval, 200, "blink fallback")
assert_eq(s.critical_threshold, 10, "critical threshold fallback")
assert_eq(s.icon_spacing, 4, "source-defined spacing")
assert_eq(s.poll_interval, 0.5, "source-defined poll interval")
settings_values.armor_hud_icon_scale = "10"
s = dofile(MODPATH .. "/src/settings.lua").load()
assert_eq(s.icon_scale, 4.0, "icon scale clamped")
settings_values.armor_hud_critical_threshold = "150"
s = dofile(MODPATH .. "/src/settings.lua").load()
assert_eq(s.critical_threshold, 100, "critical threshold clamped")
print("ok settings parsing")

settings_values = defaults()
load_mod()

-- Join with no armor.
local p = join("alice")
advance(0.02)
assert_eq(count_hud(p), 0, "no HUD without armor")
assert_eq(#p.hud_adds, 0, "no elements added without armor")
print("ok join with no armor")

-- One piece.
equip(p, "head", "test:helmet_iron", 0)
advance(0.02)
assert_eq(count_hud(p), 4, "one piece has cell + icon + bar bg + bar fill")
local cell
for _, e in pairs(p.hud) do if e.z_index == 9 then cell = e end end
assert_eq(cell.text, "mcl_offhand_slot.png^[resize:128x128", "Mineclonia inventory cell texture")
assert_true(near(cell.offset.x, -516), "cell beside offhand slot")
assert_true(near(cell.offset.y, 0), "cell bottom flush with screen bottom")
assert_true(near(cell.offset.y - 40 / 2, -20), "cell center for flush bottom")
assert_true(near(cell.scale.x, 0.3125), "cell scaled to two thirds of mcl_offhand")
local ic = icons(p)[1]
assert_eq(ic.e.text, "mcl_armor_inv_helmet_iron.png^[resize:128x128", "icon texture")
assert_true(near(ic.e.offset.x, -512), "item centered in cell")
assert_true(near(ic.e.offset.y, -4), "item bottom inside cell")
assert_eq(ic.e.position.x, 0.5, "fixed left position")
assert_true(near(ic.e.scale.x, 0.25), "item scaled to two thirds of mcl_offhand")
local b = bar_elements(p)
assert_eq(#b, 2, "bar elements")
assert_true(near(b[1].e.offset.x, -509.5), "bar centered in cell")
assert_true(near(b[1].e.offset.y, -6.3333), "bar overlays lower item like offhand")
assert_eq(b[2].e.scale.x, 27, "full bar fill")
assert_eq(b[2].e.scale.y, 2, "scaled offhand bar height")
assert_eq(b[2].e.text, "mcl_wear_bar.png^[colorize:#0aff00", "Mineclonia green wear color")
print("ok one piece")

-- Offhand HUD visibility shifts the fixed left HUD.
core.registered_items["test:offhand"] = { inventory_image = "test_offhand.png" }
p.inv:set_size("offhand", 1)
p.inv:set_stack("offhand", 1, Stack.new("test:offhand"))
advance(0.6)
local shifted_cell
for _, e in pairs(p.hud) do if e.z_index == 9 then shifted_cell = e end end
assert_true(near(shifted_cell.offset.x, -580), "offhand HUD shifts armor HUD left")
p.inv:set_stack("offhand", 1, Stack.new(""))
advance(0.6)
local restored_cell
for _, e in pairs(p.hud) do if e.z_index == 9 then restored_cell = e end end
assert_true(near(restored_cell.offset.x, -516), "armor HUD returns when offhand is hidden")
print("ok offhand visibility shift")

-- All four pieces.
equip(p, "torso", "test:chest_iron", 0)
equip(p, "legs", "test:legs_iron", 0)
equip(p, "feet", "test:feet_iron", 0)
advance(0.02)
assert_eq(count_hud(p), 16, "four pieces have sixteen elements")
local is = icons(p)
assert_eq(#is, 4, "four icons")
assert_true(near(is[1].e.offset.x, -512), "head x")
assert_true(near(is[2].e.offset.x, -468), "torso x")
assert_true(near(is[3].e.offset.x, -424), "legs x")
assert_true(near(is[4].e.offset.x, -380), "feet x")
assert_eq(is[1].e.text, "mcl_armor_inv_helmet_iron.png^[resize:128x128", "head texture")
assert_eq(is[4].e.text, "mcl_armor_inv_boots_iron.png^[resize:128x128", "feet texture")
print("ok all four pieces")

-- Removal and reflow.
unequip(p, "head")
unequip(p, "torso")
advance(0.02)
assert_eq(count_hud(p), 8, "two remaining pieces")
is = icons(p)
assert_eq(#is, 2, "two icons after removals")
assert_true(near(is[1].e.offset.x, -512), "first remaining icon reflows")
assert_eq(is[1].e.text, "mcl_armor_inv_leggings_iron.png^[resize:128x128", "legs is first")
unequip(p, "legs")
unequip(p, "feet")
advance(0.02)
assert_eq(count_hud(p), 0, "all elements removed when no armor")
print("ok removing armor")

-- Material change reuses ids.
equip(p, "head", "test:helmet_iron", 0)
advance(0.02)
local old_ids = {}
for id in pairs(p.hud) do old_ids[id] = true end
reset_calls(p)
equip(p, "head", "test:helmet_leather", 0)
advance(0.02)
assert_eq(count_hud(p), 4, "still four elements")
for id in pairs(p.hud) do assert_true(old_ids[id], "existing id reused") end
assert_eq(#p.hud_adds, 0, "no recreation for material change")
assert_eq(icons(p)[1].e.text, "mcl_armor_inv_helmet_leather.png^[resize:128x128", "new texture")
print("ok material change")

-- Durability polling and threshold colours.
unequip(p, "head")
equip(p, "torso", "test:chest_iron", 0)
advance(0.02)
local fill_id
for id, e in pairs(p.hud) do if e.z_index == 12 then fill_id = id end end
assert_eq(p.hud[fill_id].scale.x, 27, "full torso bar")
set_wear(p, "torso", 32768)
advance(0.6)
assert_eq(p.hud[fill_id].scale.x, 14, "half torso bar after polling")
assert_eq(p.hud[fill_id].text, "mcl_wear_bar.png^[colorize:#ffc900",
	"Mineclonia yellow wear color at half durability")
set_wear(p, "torso", math.floor(65536 * 0.75))
advance(0.6)
assert_eq(p.hud[fill_id].text, "mcl_wear_bar.png^[colorize:#ff3300",
	"Mineclonia orange wear color")
assert_eq(p.hud[fill_id].scale.x, 7, "quarter fill width")
print("ok durability and wear-bar gradient")

-- Critical blink.
equip(p, "head", "test:helmet_diamond", 0)
set_wear(p, "torso", 59000)
advance(0.02)
assert_eq(icons(p)[2].e.text, "mcl_armor_inv_chestplate_iron.png^[resize:128x128", "critical visible initially")
advance(0.21)
assert_eq(icons(p)[1].e.text, "mcl_armor_inv_helmet_diamond.png^[resize:128x128", "non-critical unaffected")
assert_eq(icons(p)[2].e.text, "", "critical icon hidden on blink")
local visible_bars = 0
for _, e in pairs(p.hud) do
	if near(e.offset.x, -465.5) and e.z_index == 11 then
		assert_eq(e.text, "mcl_wear_bar.png^[colorize:#1b1b1b",
			"critical bar background stays visible")
		visible_bars = visible_bars + 1
	elseif near(e.offset.x, -465.5) and e.z_index == 12 then
		assert_eq(e.text, "mcl_wear_bar.png^[colorize:#ff0000",
			"critical bar fill stays visible")
		assert_eq(e.scale.x, 3, "critical bar fill keeps its width")
		visible_bars = visible_bars + 1
	end
end
assert_eq(visible_bars, 2, "both critical bar elements stay visible")
advance(0.21)
assert_eq(icons(p)[2].e.text, "mcl_armor_inv_chestplate_iron.png^[resize:128x128", "critical icon restored")
print("ok critical icon blink without hiding the bar")

-- Multiplayer isolation.
local q = join("bob")
advance(0.02)
equip(q, "head", "test:helmet_diamond", 0)
equip(q, "torso", "test:chest_iron", 0)
equip(q, "legs", "test:legs_iron", 0)
equip(q, "feet", "test:feet_iron", 0)
advance(0.02)
advance(0.21)
for _, e in pairs(p.hud) do
	if e.z_index == 10 and near(e.offset.x, -468) then
		assert_eq(e.text, "", "alice critical hidden")
	end
end
for _, e in pairs(q.hud) do
	if e.z_index == 10 and near(e.offset.x, -468) then
		assert_eq(e.text, "mcl_armor_inv_chestplate_iron.png^[resize:128x128", "bob unaffected")
	end
end
local alice_ids = {}
for id in pairs(p.hud) do alice_ids[id] = true end
for id in pairs(q.hud) do assert_true(not alice_ids[id], "ids not shared") end
print("ok multiplayer isolation")

-- Unbreakable, third-party, alias and appearance overrides.
local r = join("carol")
advance(0.02)
equip(r, "head", "test:helmet_crown", 0)
advance(0.02)
assert_eq(count_hud(r), 4, "unbreakable element record")
assert_eq(icons(r)[1].e.text, "test_crown.png^[resize:128x128", "crown icon")
for _, e in pairs(r.hud) do
	if e.z_index == 11 or e.z_index == 12 then
		assert_eq(e.text, "", "no bar for unbreakable armor")
	end
end
equip(r, "head", "test:helmet_thirdparty", 0)
advance(0.02)
assert_eq(icons(r)[1].e.text, "thirdparty_custom_helmet.png^[resize:128x128", "third-party texture")
equip(r, "head", "test:helmet_oldname", 0)
advance(0.02)
assert_eq(icons(r)[1].e.text, "mcl_armor_inv_helmet_iron.png^[resize:128x128", "alias texture")
local leather = "mcl_armor_inv_helmet_leather_desat.png^[multiply:#ff0000"
equip(r, "head", "test:helmet_leather", 0, { ["inventory_image"] = leather })
advance(0.02)
assert_eq(icons(r)[1].e.text, leather .. RESIZE, "leather meta texture")
local trim = "mcl_armor_inv_helmet_iron.png^(helmet_trim.png^[colorize:#5faed8:150)"
equip(r, "head", "test:helmet_iron", 0, { ["inventory_image"] = trim })
advance(0.02)
assert_eq(icons(r)[1].e.text, trim .. RESIZE, "trim meta texture")
equip(r, "head", "test:helmet_iron_enchanted", 0, { ["inventory_image"] = trim })
advance(0.02)
assert_true(icons(r)[1].e.text:find(mcl_enchanting.overlay, 1, true) ~= nil,
	"glint added to meta image")
local already = trim .. mcl_enchanting.overlay
equip(r, "head", "test:helmet_iron_enchanted", 0, { ["inventory_image"] = already })
advance(0.02)
assert_eq(icons(r)[1].e.text, already .. RESIZE, "glint not duplicated")
print("ok third-party and special appearances")

-- Diffing: stable HUD produces no hud_change calls.
unequip(r, "head")
equip(r, "torso", "test:chest_iron", 0)
advance(0.02)
reset_calls(r)
advance(2.0, 20)
assert_eq(#r.hud_adds, 0, "stable HUD not recreated")
assert_eq(#r.change_calls, 0, "stable HUD emits no changes")
print("ok change diffing")

-- Death, respawn and disconnect.
local d = join("dave")
advance(0.02)
equip(d, "head", "test:helmet_iron", 0)
advance(0.02)
assert_eq(count_hud(d), 4, "armor before death")
callbacks.die(d)
assert_eq(count_hud(d), 0, "death clears HUD")
advance(0.6)
assert_eq(count_hud(d), 4, "retained armor returns")
callbacks.respawn(d)
advance(0.6)
assert_eq(count_hud(d), 4, "respawn refreshes HUD")
local old_count = count_hud(d)
callbacks.leave(d)
assert_eq(count_hud(d), 0, "leave removes elements")
assert_true(#d.remove_calls >= old_count, "leave removes every element")
local d2 = join("dave")
advance(0.02)
assert_eq(count_hud(d2), 0, "fresh reconnect state")
equip(d2, "head", "test:helmet_diamond", 0)
advance(0.02)
assert_eq(count_hud(d2), 4, "reconnected player updates")
print("ok lifecycle")

-- Configurable critical threshold drives the blink state.
settings_values = defaults()
settings_values.armor_hud_critical_threshold = "25"
local threshold_cfg = load_mod()
assert_eq(threshold_cfg.critical_threshold, 25, "critical threshold setting")
local e = join("eve")
advance(0.02)
equip(e, "torso", "test:chest_iron", 49152)
advance(0.02)
assert_eq(icons(e)[1].e.text, "mcl_armor_inv_chestplate_iron.png^[resize:128x128",
	"critical icon visible initially")
advance(0.21)
assert_eq(icons(e)[1].e.text, "", "custom threshold makes 25% critical")
threshold_cfg.critical_threshold = 10
advance(0.6)
assert_eq(icons(e)[1].e.text, "mcl_armor_inv_chestplate_iron.png^[resize:128x128",
	"lowering threshold clears critical state")
print("ok configurable critical threshold")

print("\nALL SIMULATED TESTS PASSED")
