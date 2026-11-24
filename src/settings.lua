local M = {}

local VALUES = {
	offset_x = 8,
	offset_y = 2,
	icon_scale = 2.25,
	icon_spacing = 4,
	critical_threshold = 10,
	poll_interval = 0.5,
}

local DEFAULTS = {
	anchor = "offhand",
	blink_interval = 200,
}

local function number_setting(name, default, min, max)
	local raw = core.settings:get(name)
	local value = tonumber(raw)
	if not value or value ~= value then -- nil, non-numeric, or NaN
		return default
	end
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

local function integer_setting(name, default, min, max)
	return math.floor(number_setting(name, default, min, max) + 0.5)
end

function M.load()
	local s = {
		anchor = (core.settings:get("armor_hud_anchor") or "offhand"):lower(),

		-- This is the time between two visibility flips, not the full cycle.
		blink_interval = integer_setting("armor_hud_blink_interval", DEFAULTS.blink_interval, 100, 10000),
	}

	for key, value in pairs(VALUES) do
		s[key] = value
	end

	if s.anchor ~= "left" and s.anchor ~= "center" and
		s.anchor ~= "right" and s.anchor ~= "offhand" then
		core.log("warning", '[armor_hud] Invalid armor_hud_anchor; using "offhand"')
		s.anchor = DEFAULTS.anchor
	end

	return s
end

return M
