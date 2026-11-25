local M = {}

local VALUES = {
	icon_scale = 2.25,
	icon_spacing = 4,
	poll_interval = 0.5,
}

local DEFAULTS = {
	blink_interval = 200,
	critical_threshold = 10,
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
		-- This is the time between two visibility flips, not the full cycle.
		blink_interval = integer_setting("armor_hud_blink_interval", DEFAULTS.blink_interval, 100, 10000),

		critical_threshold = integer_setting("armor_hud_critical_threshold",
			DEFAULTS.critical_threshold, 0, 100),
	}

	for key, value in pairs(VALUES) do
		s[key] = value
	end

	return s
end

return M
