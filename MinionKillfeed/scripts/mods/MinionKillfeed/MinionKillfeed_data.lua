local mod = get_mod("MinionKillfeed")

return {
	name = "Minion Killfeed",
	description = "Shows all enemy deaths in the killfeed.",
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "general_settings",
				type = "group",
				tab = "loc_tab_general",
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
						setting_id = "show_enemy_kills",
						type = "checkbox",
						default_value = true,
					},
				}
			}
		}
	}
}
