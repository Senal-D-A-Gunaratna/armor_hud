local M = {}

local settings
local armor
local hud

-- States are keyed by player name. Each state is completely independent so
-- one player's equipment or blink phase can never affect another player.
local states = {}
local poll_elapsed = 0

-- Same green -> yellow -> red gradient as Mineclonia's inventory wear bars and
-- its offhand HUD bar (Luanti's default durability bar colors).
local function wear_bar_color(wear)
	local wear_i = math.min(math.floor((wear / 65535) * 600), 511)
	wear_i = math.min(wear_i + 10, 511)
	local r, g
	if wear_i <= 255 then
		r, g = wear_i, 255
	else
		r, g = 255, 511 - wear_i
	end
	return string.format("#%02x%02x00", r, g)
end

local function get_state(player)
	local name = player:get_player_name()
	local state = states[name]

	if not state then
		state = {
			player = player,
			elements = {},
			by_slot = {},
			has_critical = false,
			blink_on = true,
			last_blink = core.get_gametime(),
			dirty = true,
		}
		states[name] = state
	else
		state.player = player
	end

	return state
end

local function layout(piece_count)
	local anchor = settings.anchor
	local icon_px = 16 * settings.icon_scale
	-- mcl_offhand draws a 48 px item in a 60 px cell; keep that proportion.
	local cell_px = icon_px / 0.8
	local inset = (cell_px - icon_px) / 2
	local spacing = settings.icon_spacing

	local group_width = 0
	if piece_count > 0 then
		group_width = piece_count * cell_px + (piece_count - 1) * spacing
	end

	local pos_x, start_x
	if anchor == "right" then
		pos_x = 1
		start_x = -group_width - settings.offset_x
	elseif anchor == "center" then
		pos_x = 0.5
		start_x = -group_width / 2 + settings.offset_x
	else
		pos_x = 0
		start_x = settings.offset_x
	end

	local bar_width = math.max(1, math.floor(cell_px * 2 / 3 + 0.5))
	local bar_height = math.max(2, math.floor(cell_px / 20 + 0.5))

	return {
		pos_x = pos_x,
		start_x = start_x,
		step = cell_px + spacing,
		cell_px = cell_px,
		inset = inset,
		bar_width = bar_width,
		bar_height = bar_height,
		cell_y = -settings.offset_y,
		icon_y = -(settings.offset_y + inset),
		bar_y = -(settings.offset_y + inset + bar_height),
	}
end

local function update_blink(player, state, now)
	if state.has_critical and now - state.last_blink >= settings.blink_interval / 1000 then
		state.blink_on = not state.blink_on
		state.last_blink = now

		for slot, info in pairs(state.by_slot) do
			if info.critical then
				local rec = state.elements[slot]
				if rec then
					hud.set_icon_visible(player, rec, state.blink_on)
				end
			end
		end
	end
end

local function refresh(player, state)
	local now = core.get_gametime()
	local pieces = armor.read(player)
	local count = #pieces
	local l = layout(count)

	local present = {}
	for _, piece in ipairs(pieces) do
		present[piece.slot] = true
	end

	-- Remove elements that no longer have an equipped piece.
	for slot, rec in pairs(state.elements) do
		if not present[slot] then
			hud.remove_piece(player, rec)
			state.elements[slot] = nil
		end
	end

	local any_critical = false
	local by_slot = {}

	for i, piece in ipairs(pieces) do
		local d = piece.durability
		local critical = d ~= nil and d.percent <= settings.critical_threshold
		if critical then
			any_critical = true
		end

		local fill_px = 0
		local color
		if d then
			fill_px = math.floor(l.bar_width * d.fraction + 0.5)
			color = wear_bar_color(d.wear)
		end

		local p = {
			pos_x = l.pos_x,
			x = l.start_x + (i - 1) * l.step,
			cell_y = l.cell_y,
			cell_px = l.cell_px,
			inset = l.inset,
			icon_y = l.icon_y,
			icon_scale = settings.icon_scale,
			icon_text = piece.texture,
			has_bar = d ~= nil,
			bar_y = l.bar_y,
			bar_width = l.bar_width,
			bar_height = l.bar_height,
			fill_px = fill_px,
			bar_color = color,
			icon_visible = (not critical) or state.blink_on,
		}

		local rec = state.elements[piece.slot]
		if rec then
			hud.update_piece(player, rec, p)
		else
			rec = {}
			state.elements[piece.slot] = rec
			hud.update_piece(player, rec, p)
		end

		by_slot[piece.slot] = { critical = critical }
	end

	local was_critical = state.has_critical
	state.has_critical = any_critical
	state.by_slot = by_slot

	-- Start each critical blink phase with the icon visible and restart the
	-- timer when critical damage first appears. When nothing is critical, keep
	-- every icon shown.
	if any_critical and not was_critical then
		state.blink_on = true
		state.last_blink = now
		for slot, info in pairs(by_slot) do
			local rec = state.elements[slot]
			if info.critical and rec then
				hud.set_icon_visible(player, rec, true)
			end
		end
	elseif not any_critical then
		state.blink_on = true
		state.last_blink = now
	end
end

local function schedule_refresh(player)
	local name = player:get_player_name()
	local state = states[name]
	if not state then
		return
	end

	core.after(0.5, function()
		if states[name] == state and player:is_player() then
			state.dirty = true
		end
	end)
end

local function on_globalstep(dtime)
	poll_elapsed = poll_elapsed + dtime
	local do_poll = poll_elapsed >= settings.poll_interval
	if do_poll then
		poll_elapsed = poll_elapsed % settings.poll_interval
	end

	local now = core.get_gametime()

	for name, state in pairs(states) do
		local player = state.player
		if not player or not player:is_player() then
			states[name] = nil
		else
			if state.dirty or do_poll then
				state.dirty = false
				refresh(player, state)
			end

			update_blink(player, state, now)
		end
	end
end

local function register_events()
	core.register_on_joinplayer(function(player)
		local state = get_state(player)
		state.dirty = true
		state.last_blink = core.get_gametime()

		-- Mineclonia creates the armor list in its own join callback. One
		-- delayed refresh also covers slow player data loading.
		core.after(1.5, function()
			if states[player:get_player_name()] == state and player:is_player() then
				state.dirty = true
			end
		end)
	end)

	core.register_on_leaveplayer(function(player)
		local name = player:get_player_name()
		local state = states[name]
		if state then
			hud.clear(player, state.elements)
			states[name] = nil
		end
	end)

	core.register_on_player_inventory_action(function(player, _, _, info)
		if not info then
			return
		end
		if info.from_list == "armor" or info.to_list == "armor" or info.listname == "armor" then
			local state = states[player:get_player_name()]
			if state then
				state.dirty = true
			end
		end
	end)

	core.register_on_dieplayer(function(player)
		local state = states[player:get_player_name()]
		if not state then
			return
		end

		hud.clear(player, state.elements)
		state.elements = {}
		state.by_slot = {}
		state.has_critical = false
		state.blink_on = true
		state.last_blink = core.get_gametime()
		state.dirty = false
		schedule_refresh(player)
	end)

	core.register_on_respawnplayer(function(player)
		local state = states[player:get_player_name()]
		if state then
			state.dirty = true
		end
		schedule_refresh(player)
	end)

	core.register_globalstep(on_globalstep)
end

function M.start(config, armor_api, hud_api)
	settings = config
	armor = armor_api
	hud = hud_api
	register_events()
end

return M
