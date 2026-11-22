local M = {}

local DEFAULTS = {
	anchor = "left",
	offset_x = 8,
	offset_y = 8,
	icon_scale = 1.0,
	icon_spacing = 4,
	warning_threshold = 25,
	critical_threshold = 10,
	blink_interval = 500,
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
		anchor = (core.settings:get("mcl_armor_hud_anchor") or "left"):lower(),

		offset_x = integer_setting("mcl_armor_hud_offset_x",
			DEFAULTS.offset_x, 0, 1024),
		offset_y = integer_setting("mcl_armor_hud_offset_y",
			DEFAULTS.offset_y, 0, 1024),

		icon_scale = number_setting("mcl_armor_hud_icon_scale",
			DEFAULTS.icon_scale, 0.25, 4.0),
		icon_spacing = integer_setting("mcl_armor_hud_icon_spacing",
			DEFAULTS.icon_spacing, 0, 64),

		warning_threshold = integer_setting("mcl_armor_hud_warning_threshold",
			DEFAULTS.warning_threshold, 0, 100),
		critical_threshold = integer_setting("mcl_armor_hud_critical_threshold",
			DEFAULTS.critical_threshold, 0, 100),

		-- This is the time between two visibility flips, not the full cycle.
		blink_interval = integer_setting("mcl_armor_hud_blink_interval",
			DEFAULTS.blink_interval, 100, 10000),

		-- Kept here so the update loop has a single source of configuration.
		poll_interval = 0.5,
	}

	if s.anchor ~= "left" and s.anchor ~= "center" and s.anchor ~= "right" then
		core.log("warning",
			"[mcl_armor_hud] Invalid mcl_armor_hud_anchor; using \"left\"")
		s.anchor = DEFAULTS.anchor
	end

	if s.critical_threshold > s.warning_threshold then
		core.log("warning",
			"[mcl_armor_hud] Critical threshold is above the warning threshold; " ..
			"clamping it to the warning threshold")
		s.critical_threshold = s.warning_threshold
	end

	return s
end

return M
