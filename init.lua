local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)

if not mcl_armor or not mcl_armor.elements then
	error("[" .. modname .. "] Mineclonia's mcl_armor API is required")
end

local settings = dofile(modpath .. "/src/settings.lua").load()
local armor = dofile(modpath .. "/src/armor.lua")
local hud = dofile(modpath .. "/src/hud.lua")
local player = dofile(modpath .. "/src/player.lua")

player.start(settings, armor, hud)
