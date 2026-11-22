local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local durability = dofile(modpath .. "/src/durability.lua")

local M = {}

-- Mineclonia's mcl_armor.elements table contains the authoritative slot data.
-- Keeping the iteration order separate makes the rendered order deterministic
-- (Lua's pairs() order is not).
M.slot_order = { "head", "torso", "legs", "feet" }

-- Resolve the image exactly like Luanti's inventory renderer does: a stack's
-- "inventory_image" metadata overrides the registered item definition. This is
-- how Mineclonia exposes leather dyeing, armor trims and other per-stack
-- appearances.
local function resolve_texture(stack, def)
	local meta = stack:get_meta()
	local image = meta:get_string("inventory_image")

	if image == "" then
		image = def.inventory_image
	end
	if type(image) ~= "string" or image == "" then
		image = "unknown_item.png"
	end

	-- A trimmed item's metadata image may have been created before it was
	-- enchanted. Add the glint if the metadata override does not contain it.
	if mcl_enchanting and mcl_enchanting.is_enchanted(stack:get_name()) then
		local overlay = mcl_enchanting.overlay
		if overlay and image:find(overlay, 1, true) == nil then
			image = image .. overlay
		end
	end

	-- Luanti can draw a separate inventory overlay on top of the item image.
	-- Mineclonia armor normally bakes trims into inventory_image, but support
	-- the general item field for third-party armor as well.
	local item_overlay = meta:get_string("inventory_overlay")
	if item_overlay == "" then
		item_overlay = def.inventory_overlay
	end
	if type(item_overlay) == "string" and item_overlay ~= "" then
		image = image .. "^" .. item_overlay
	end

	return image
end

---Reads the player's four armor slots in head-to-feet order.
---Returns an array of piece tables. Empty or unknown items are skipped.
function M.read(player)
	local pieces = {}
	local inv = player:get_inventory()
	if not inv then
		return pieces
	end

	local armor_size = inv:get_size("armor")
	if armor_size < 5 then
		return pieces
	end

	for _, slot in ipairs(M.slot_order) do
		local element = mcl_armor.elements[slot]
		if element and element.index <= armor_size then
			local stack = inv:get_stack("armor", element.index)
			if not stack:is_empty() then
				local itemname = stack:get_name()
				local def = core.registered_items[itemname]
				if def then
					pieces[#pieces + 1] = {
						slot = slot,
						index = element.index,
						itemname = itemname,
						texture = resolve_texture(stack, def),
						durability = durability.get(stack),
					}
				end
			end
		end
	end

	return pieces
end

return M
