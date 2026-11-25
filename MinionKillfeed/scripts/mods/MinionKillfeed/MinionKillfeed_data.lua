local mod = get_mod("MinionKillfeed")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "general_settings",
				type = "group",
				tab = mod:localize("loc_tab_general"),
				sub_widgets = {
					{
						setting_id = "enable_all_kills",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "stack_kills",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "show_teammate_kills",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "show_own_kills",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "show_enemy_kills",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		},
	},
}
