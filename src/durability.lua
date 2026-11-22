local M = {}

-- Luanti stores tool wear in the range 0..65535. Mineclonia's own elytra code
-- uses 65536 as the divisor, so the same scale is used here for consistency.
local WEAR_SCALE = 65536

---Returns durability information for an armor stack.
---The maximum uses value comes from Mineclonia's own calculate_durability(),
---which also accounts for the Unbreaking enchantment. Returns nil for items
---without finite durability (for example unbreakable third-party armor).
function M.get(stack)
	if not stack or stack:is_empty() then
		return nil
	end

	local max_uses = mcl_util.calculate_durability(stack)
	if not max_uses or max_uses <= 0 then
		return nil
	end

	local wear = stack:get_wear()
	local remaining_wear = math.max(0, WEAR_SCALE - wear)
	local fraction = remaining_wear / WEAR_SCALE

	return {
		max_uses = max_uses,
		wear = wear,
		remaining_uses = math.floor(remaining_wear * max_uses / WEAR_SCALE),
		fraction = fraction,
		percent = fraction * 100,
	}
end

return M
