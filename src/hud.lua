local H = {}

-- A single white pixel is shipped with the mod and recolored with texture
-- modifiers. This avoids shipping or copying any armor textures.
local PIXEL = "mcl_armor_hud_pixel.png"
local BAR_BACKGROUND = PIXEL .. "^[colorize:#1b1b1b"

local Z_BAR_BG = 10
local Z_BAR_FILL = 11
local Z_ICON = 12

local function bar_texture(color)
	return PIXEL .. "^[colorize:" .. color
end

local function add_image(player, p, offset, scale, text, z_index)
	return player:hud_add({
		type = "image",
		position = { x = p.pos_x, y = 1 },
		offset = offset,
		alignment = { x = 1, y = -1 },
		scale = scale,
		text = text,
		z_index = z_index,
	})
end

local function set_text(player, id, rec, key, value)
	if rec[key] ~= value then
		player:hud_change(id, "text", value)
		rec[key] = value
	end
end

local function set_offset(player, id, rec, key, x, y)
	if rec[key .. "_x"] ~= x or rec[key .. "_y"] ~= y then
		player:hud_change(id, "offset", { x = x, y = y })
		rec[key .. "_x"] = x
		rec[key .. "_y"] = y
	end
end

local function set_scale(player, id, rec, key, x, y)
	if rec[key .. "_w"] ~= x or rec[key .. "_h"] ~= y then
		player:hud_change(id, "scale", { x = x, y = y })
		rec[key .. "_w"] = x
		rec[key .. "_h"] = y
	end
end

---Create or update one armor piece's HUD elements.
---p fields:
---  pos_x, x, icon_y, icon_scale, icon_text,
---  has_bar, bar_y, bar_width, bar_height, fill_px, bar_color, visible
function H.update_piece(player, rec, p)
	local icon_text = p.visible and p.icon_text or ""
	local bar_bg_text = (p.visible and p.has_bar) and BAR_BACKGROUND or ""
	local fill_shown = p.visible and p.has_bar and p.fill_px > 0
	local fill_text = fill_shown and bar_texture(p.bar_color) or ""

	if not rec.icon_id then
		rec.icon_id = add_image(player, p,
			{ x = p.x, y = p.icon_y },
			{ x = p.icon_scale, y = p.icon_scale },
			icon_text, Z_ICON)
		rec.icon_text = icon_text
		rec.icon_x, rec.icon_y = p.x, p.icon_y
		rec.icon_w, rec.icon_h = p.icon_scale, p.icon_scale
	else
		set_text(player, rec.icon_id, rec, "icon_text", icon_text)
		set_offset(player, rec.icon_id, rec, "icon", p.x, p.icon_y)
		set_scale(player, rec.icon_id, rec, "icon", p.icon_scale, p.icon_scale)
	end

	if not rec.bg_id then
		rec.bg_id = add_image(player, p,
			{ x = p.x, y = p.bar_y },
			{ x = p.bar_width, y = p.bar_height },
			bar_bg_text, Z_BAR_BG)
		rec.bg_text = bar_bg_text
		rec.bg_x, rec.bg_y = p.x, p.bar_y
		rec.bg_w, rec.bg_h = p.bar_width, p.bar_height
	else
		set_text(player, rec.bg_id, rec, "bg_text", bar_bg_text)
		set_offset(player, rec.bg_id, rec, "bg", p.x, p.bar_y)
		set_scale(player, rec.bg_id, rec, "bg", p.bar_width, p.bar_height)
	end

	if not rec.fill_id then
		rec.fill_id = add_image(player, p,
			{ x = p.x, y = p.bar_y },
			{ x = p.fill_px, y = p.bar_height },
			fill_text, Z_BAR_FILL)
		rec.fill_text = fill_text
		rec.fill_x, rec.fill_y = p.x, p.bar_y
		rec.fill_w, rec.fill_h = p.fill_px, p.bar_height
	else
		set_text(player, rec.fill_id, rec, "fill_text", fill_text)
		set_offset(player, rec.fill_id, rec, "fill", p.x, p.bar_y)
		set_scale(player, rec.fill_id, rec, "fill", p.fill_px, p.bar_height)
	end

	rec.params = p
end

function H.set_visible(player, rec, visible)
	local p = rec.params
	if not p or p.visible == visible then
		return
	end
	p.visible = visible
	H.update_piece(player, rec, p)
end

function H.remove_piece(player, rec)
	for _, id in ipairs({ rec.icon_id, rec.bg_id, rec.fill_id }) do
		if id then
			player:hud_remove(id)
		end
	end
end

function H.clear(player, elements)
	for _, rec in pairs(elements) do
		H.remove_piece(player, rec)
	end
end

return H
