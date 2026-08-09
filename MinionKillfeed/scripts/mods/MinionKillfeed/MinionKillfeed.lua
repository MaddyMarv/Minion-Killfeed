local mod = get_mod("MinionKillfeed")

local _companion_owner_cache = setmetatable({}, { __mode = "k" })
local _not_companion_cache = setmetatable({}, { __mode = "k" })

local function get_all_companion_units(spawner_ext)
	local units = {}
	if spawner_ext._spawned_units then
		for _, u in ipairs(spawner_ext._spawned_units) do
			table.insert(units, u)
		end
	end
	
	local SpecialRules = require("scripts/settings/ability/special_rules_settings").special_rules
	if SpecialRules and spawner_ext.spawned_unit_lookup then
		local rules = {
			"cryptic_servo_skull", "cryptic_servo_skull_lasgun",
			"cryptic_servo_skull_flamethrower", "cryptic_servo_skull_hack",
			"cryptic_servo_skull_inject_ally"
		}
		for _, rule_name in ipairs(rules) do
			local success, rule = pcall(function() return SpecialRules[rule_name] end)
			if success and rule then
				local u = spawner_ext:spawned_unit_lookup(rule)
				if u then table.insert(units, u) end
			end
		end
	end
	return units
end

local function unit_is_companion(unit)
	if not Managers.player or not unit then return false end
	if _companion_owner_cache[unit] then return true end
	if _not_companion_cache[unit] then return false end

	local players = Managers.player:players()
	for _, player in pairs(players) do
		local player_unit = player.player_unit
		if player_unit and ALIVE[player_unit] then
			local spawner_ext = ScriptUnit.has_extension(player_unit, "companion_spawner_system")
			if spawner_ext then
				local companions = get_all_companion_units(spawner_ext)
				for _, spawned_unit in ipairs(companions) do
					if spawned_unit == unit then
						_companion_owner_cache[unit] = player
						return true
					end
				end
			end
		end
	end

	_not_companion_cache[unit] = true
	return false
end

local function is_teammate_kill(attacking_unit)
	local local_player = Managers.player and Managers.player:local_player(1)
	if not local_player then return false end

	local owner_player = Managers.player:player_by_unit(attacking_unit)
	if not owner_player then
		if unit_is_companion(attacking_unit) then
			owner_player = _companion_owner_cache[attacking_unit]
		end
	end

	if owner_player and owner_player ~= local_player then
		return true
	end
	return false
end

local _triggered_deaths = setmetatable({}, { __mode = "k" })

mod:hook("AttackReportManager", "_process_attack_result", function(func, self, buffer_data)
	if not mod:get("enable_all_kills") then
		return func(self, buffer_data)
	end

	local attack_result = buffer_data.attack_result
	local attacked_unit = buffer_data.attacked_unit
	local attacking_unit = buffer_data.attacking_unit

	if attack_result == "died" and attacked_unit and attacking_unit then
		local companion_mod = get_mod("CompanionKillfeed")
		if companion_mod and companion_mod:is_enabled() then
			if companion_mod:get("show_non_elite_kills") and unit_is_companion(attacking_unit) then
				return func(self, buffer_data)
			end
		end

		if not mod:get("show_teammate_kills") and is_teammate_kill(attacking_unit) then
			return func(self, buffer_data)
		end

		local is_player = Managers.player and Managers.player:player_by_unit(attacking_unit) ~= nil
		local is_companion = unit_is_companion(attacking_unit)
		local is_enemy_killer = not is_player and not is_companion
		
		if is_player and not is_teammate_kill(attacking_unit) and not mod:get("show_own_kills") then
			return func(self, buffer_data)
		end
		
		if is_enemy_killer and not mod:get("show_enemy_kills") then
			return func(self, buffer_data)
		end

		local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
		local breed_or_nil = unit_data_extension and unit_data_extension:breed()
		
		local tags = breed_or_nil and breed_or_nil.tags
		local allowed_breed = tags and (tags.monster or tags.special or tags.elite)
		
		local should_trigger = false
		if not allowed_breed then
			should_trigger = true
		else
			if is_enemy_killer then
				should_trigger = true
			end
		end
		
		if should_trigger then
			local now = Managers.time and Managers.time:time("gameplay") or 0
			if _triggered_deaths[attacked_unit] and (now - _triggered_deaths[attacked_unit] < 0.1) then
				return func(self, buffer_data)
			end
			if now > 0 then
				_triggered_deaths[attacked_unit] = now
			end

			Managers.event:trigger("event_combat_feed_kill", attacking_unit, attacked_unit)
		end
	end
	
	func(self, buffer_data)
end)

local _feed_processed_kills = setmetatable({}, { __mode = "k" })

local temp_kill_message_params = { killer = "n/a", victim = "n/a" }

local function merge_non_elite_kill(self, attacking_unit, attacked_unit)
	if not self._notifications or not self._remove_notification or not self._set_text then
		return
	end
	
	local is_player = Managers.player and Managers.player:player_by_unit(attacked_unit) ~= nil
	if is_player then return end

	local unit_data_ext = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
	local breed_or_nil = unit_data_ext and unit_data_ext:breed()


	local tags = breed_or_nil and breed_or_nil.tags
	if tags and (tags.monster or tags.special or tags.elite or tags.captain or tags.boss) then
		return
	end

	local notifications = self._notifications
	local new_notification = notifications[1]
	if not new_notification then return end

	new_notification.count = 1
	new_notification.breed = breed_or_nil
	new_notification.player = attacking_unit

	for _, notification in ipairs(notifications) do
		if notification.breed == breed_or_nil
			and notification.player == attacking_unit
			and notification.id ~= new_notification.id then
			new_notification.count = (notification.count or 1) + 1
			self:_remove_notification(notification.id)
		end
	end

	if new_notification.count > 1 then
		local killer = self:_get_unit_presentation_name(attacking_unit) or "Unknown"
		local victim = self:_get_unit_presentation_name(attacked_unit)
		if not victim and breed_or_nil and breed_or_nil.display_name then
			victim = Localize(breed_or_nil.display_name)
		end
		victim = victim or "Heretic"
		
		temp_kill_message_params.killer = killer
		temp_kill_message_params.victim = victim
		local text = self:_localize("loc_hud_combat_feed_kill_message", true, temp_kill_message_params)
		text = text .. " x" .. tostring(new_notification.count)
		self:_set_text(new_notification.id, text)
	end
end

mod:hook("HudElementCombatFeed", "event_combat_feed_kill", function(func, self, attacking_unit, attacked_unit, ...)
	if attacked_unit then
		local now = Managers.time and Managers.time:time("gameplay") or 0
		if _feed_processed_kills[attacked_unit] and (now - _feed_processed_kills[attacked_unit] < 0.1) then
			return
		end
		if now > 0 then
			_feed_processed_kills[attacked_unit] = now
		end
	end

	local killer_name = self:_get_unit_presentation_name(attacking_unit)
	local victim_name = self:_get_unit_presentation_name(attacked_unit)

	local is_player_killer = Managers.player and Managers.player:player_by_unit(attacking_unit) ~= nil
	local is_companion_killer = attacking_unit and unit_is_companion(attacking_unit)
	local is_teammate_killer = is_player_killer or is_companion_killer

	local is_player_victim = Managers.player and Managers.player:player_by_unit(attacked_unit) ~= nil
	local is_companion_victim = attacked_unit and unit_is_companion(attacked_unit)
	local is_teammate_victim = is_player_victim or is_companion_victim

	if is_teammate_killer and victim_name == "Heretic" then
		return
	end
	
	if is_teammate_victim and killer_name == "Heretic" then
		return
	end

	if is_teammate_killer and killer_name == "Heretic" then
		return
	end

	if is_teammate_victim and victim_name == "Heretic" then
		return
	end

	func(self, attacking_unit, attacked_unit, ...)
	
	if mod:get("enable_all_kills") and mod:get("stack_kills") then
		local companion_mod = get_mod("CompanionKillfeed")
		local skip_merge = false
		if companion_mod and companion_mod:is_enabled() and companion_mod:get("show_non_elite_kills") and companion_mod:get("stack_non_elite_kills") then
			if unit_is_companion(attacking_unit) then
				skip_merge = true
			end
		end
		
		if not skip_merge then
			merge_non_elite_kill(self, attacking_unit, attacked_unit)
		end
	end
end)

mod:hook("HudElementCombatFeed", "_get_unit_presentation_name", function(func, self, unit, ...)
	local result = func(self, unit, ...)
	if result == nil then
		return "Heretic"
	end
	return result
end)
