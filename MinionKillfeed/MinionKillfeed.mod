return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MinionKillfeed` encountered an error loading the Darktide Mod Framework.")
		
		new_mod("MinionKillfeed", {
			mod_script       = "MinionKillfeed/scripts/mods/MinionKillfeed/MinionKillfeed",
			mod_data         = "MinionKillfeed/scripts/mods/MinionKillfeed/MinionKillfeed_data",
			mod_localization = "MinionKillfeed/scripts/mods/MinionKillfeed/MinionKillfeed_localization",
		})
	end,
	packages = {},
}
