local H = {}

-- Mineclonia's own 1x1 white wear-bar pixel, recolored with texture modifiers.
-- Referencing it at runtime avoids shipping or copying any media.
local PIXEL = "mcl_wear_bar.png"
local BAR_BACKGROUND = PIXEL .. "^[colorize:#1b1b1b"

-- Mineclonia's own inventory-cell texture, used by mcl_offhand for the slot
-- behind the offhand item. It resizes both the slot and the item texture to
-- 128x128 before applying HUD scales; do the same for pixel-identical results.
local TEXTURE_PX = 128
local CELL = "mcl_offhand_slot.png^[resize:" .. TEXTURE_PX .. "x" .. TEXTURE_PX
local CELL_TEXTURE_SIZE = TEXTURE_PX

local Z_CELL = 9
local Z_ICON = 10
local Z_BAR_BG = 11
local Z_BAR_FILL = 12

local function bar_texture(color)
	return PIXEL .. "^[colorize:" .. color
end

local function item_texture(text)
	if text == "" or text:find("^[resize:", 1, true) then
		return text
	end
	return text .. "^[resize:" .. TEXTURE_PX .. "x" .. TEXTURE_PX
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
---  pos_x, x, cell_y, cell_px, inset, icon_y, icon_scale (HUD scale), icon_text,
---  icon_visible, has_bar, bar_y, bar_width, bar_height, fill_px, bar_color
function H.update_piece(player, rec, p)
	local icon_text = p.icon_visible and item_texture(p.icon_text) or ""
	local bar_bg_text = p.has_bar and BAR_BACKGROUND or ""
	local fill_shown = p.has_bar and p.fill_px > 0
	local fill_text = fill_shown and bar_texture(p.bar_color) or ""
	local item_x = p.x + p.inset
	local bar_x = p.x + (p.cell_px - p.bar_width) / 2
	local cell_scale = p.cell_px / CELL_TEXTURE_SIZE

	if not rec.cell_id then
		rec.cell_id = add_image(player, p,
			{ x = p.x, y = p.cell_y },
			{ x = cell_scale, y = cell_scale },
			CELL, Z_CELL)
		rec.cell_x, rec.cell_y = p.x, p.cell_y
		rec.cell_w, rec.cell_h = cell_scale, cell_scale
	else
		set_offset(player, rec.cell_id, rec, "cell", p.x, p.cell_y)
		set_scale(player, rec.cell_id, rec, "cell", cell_scale, cell_scale)
	end

	if not rec.icon_id then
		rec.icon_id = add_image(player, p,
			{ x = item_x, y = p.icon_y },
			{ x = p.icon_scale, y = p.icon_scale },
			icon_text, Z_ICON)
		rec.icon_text = icon_text
		rec.icon_x, rec.icon_y = item_x, p.icon_y
		rec.icon_w, rec.icon_h = p.icon_scale, p.icon_scale
	else
		set_text(player, rec.icon_id, rec, "icon_text", icon_text)
		set_offset(player, rec.icon_id, rec, "icon", item_x, p.icon_y)
		set_scale(player, rec.icon_id, rec, "icon", p.icon_scale, p.icon_scale)
	end

	if not rec.bg_id then
		rec.bg_id = add_image(player, p,
			{ x = bar_x, y = p.bar_y },
			{ x = p.bar_width, y = p.bar_height },
			bar_bg_text, Z_BAR_BG)
		rec.bg_text = bar_bg_text
		rec.bg_x, rec.bg_y = bar_x, p.bar_y
		rec.bg_w, rec.bg_h = p.bar_width, p.bar_height
	else
		set_text(player, rec.bg_id, rec, "bg_text", bar_bg_text)
		set_offset(player, rec.bg_id, rec, "bg", bar_x, p.bar_y)
		set_scale(player, rec.bg_id, rec, "bg", p.bar_width, p.bar_height)
	end

	if not rec.fill_id then
		rec.fill_id = add_image(player, p,
			{ x = bar_x, y = p.bar_y },
			{ x = p.fill_px, y = p.bar_height },
			fill_text, Z_BAR_FILL)
		rec.fill_text = fill_text
		rec.fill_x, rec.fill_y = bar_x, p.bar_y
		rec.fill_w, rec.fill_h = p.fill_px, p.bar_height
	else
		set_text(player, rec.fill_id, rec, "fill_text", fill_text)
		set_offset(player, rec.fill_id, rec, "fill", bar_x, p.bar_y)
		set_scale(player, rec.fill_id, rec, "fill", p.fill_px, p.bar_height)
	end

	rec.params = p
end

function H.set_icon_visible(player, rec, visible)
	local p = rec.params
	if not p or p.icon_visible == visible then
		return
	end
	p.icon_visible = visible
	H.update_piece(player, rec, p)
end

function H.remove_piece(player, rec)
	for _, id in ipairs({ rec.cell_id, rec.icon_id, rec.bg_id, rec.fill_id }) do
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
