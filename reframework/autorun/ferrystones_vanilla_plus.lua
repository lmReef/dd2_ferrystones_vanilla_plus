local ItemManager = sdk.get_managed_singleton("app.ItemManager")
local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")

local PermanentPortcrystals = {
	"(458.811,32.915,-1012.04)",  -- Vernworth
	"(-456.106,2.0164,-608.048)", -- Harve Village
	"(-1445.05,107.486,394.835)", -- Bakbattahl
	"(-490.768,-16.3092,-232.895)", -- Seafloor Shrine
	"(-555.132, 117.652, -2257.69)", -- Sacred Arbor
	"(-894.818,-15.0159,814.869)", -- Agamen Volcanic Island
}

local function get_default_config()
	return {
		ferrystone_drop_rates = {
			["Gather"] = {
				enabled = true,
				chance = 0.03,
			},
			["DeadEnemy"] = {
				enabled = true,
				chance = 0.05,
			},
			["TreasureBox"] = {
				enabled = true,
				chance = 0.15,
			},
			["Talk"] = {
				enabled = true,
				chance = 0.15,
			}
		},
		free_portcrystals_enabled = true
	}
end

local config = get_default_config()

local function load_config()
	local config_file = json.load_file("ferrystones_vanilla_plus.json")
	if config_file ~= nil then
		config = config_file
	end
end

local function save_config()
	json.dump_file("ferrystones_vanilla_plus.json", config)
end

-- draw the gui config
re.on_draw_ui(function()
	local config_changed = false

	if imgui.tree_node("Ferrystones Vanilla Plus") then
		local changed = false

		imgui.new_line()

		reset_config = imgui.button("Reset all to defaults")
		if reset_config then
			config = get_default_config()
			config_changed = true
		end

		imgui.new_line()

		-- free portcrystals config
		changed, config.free_portcrystals_enabled = imgui.checkbox("Free permanent portcrystal teleports",
			config.free_portcrystals_enabled)
		config_changed = config_changed or changed

		imgui.new_line()

		-- ferrystone_drop_rates
		imgui.text("Looting Enemies")
		changed, config.ferrystone_drop_rates["DeadEnemy"].enabled = imgui.checkbox("Enemies enabled",
			config.ferrystone_drop_rates["DeadEnemy"].enabled)
		config_changed = config_changed or changed

		imgui.begin_disabled(not config.ferrystone_drop_rates["DeadEnemy"].enabled)
		changed, config.ferrystone_drop_rates["DeadEnemy"].chance = imgui.slider_float("Enemies chance",
			config.ferrystone_drop_rates["DeadEnemy"].chance, 0.0, 1.0, "%.2f")
		config_changed = config_changed or changed
		imgui.end_disabled()

		imgui.new_line()

		imgui.text("Gathering")
		changed, config.ferrystone_drop_rates["Gather"].enabled = imgui.checkbox("Gathering enabled",
			config.ferrystone_drop_rates["Gather"].enabled)
		config_changed = config_changed or changed

		imgui.begin_disabled(not config.ferrystone_drop_rates["Gather"].enabled)
		changed, config.ferrystone_drop_rates["Gather"].chance = imgui.slider_float("Gathering chance",
			config.ferrystone_drop_rates["Gather"].chance, 0.0, 1.0, "%.2f")
		config_changed = config_changed or changed
		imgui.end_disabled()

		imgui.new_line()

		imgui.text("Looting Chests")
		changed, config.ferrystone_drop_rates["TreasureBox"].enabled = imgui.checkbox("Chests enabled",
			config.ferrystone_drop_rates["TreasureBox"].enabled)
		config_changed = config_changed or changed

		imgui.begin_disabled(not config.ferrystone_drop_rates["TreasureBox"].enabled)
		changed, config.ferrystone_drop_rates["TreasureBox"].chance = imgui.slider_float("Chests chance",
			config.ferrystone_drop_rates["TreasureBox"].chance, 0.0, 1.0, "%.2f")
		config_changed = config_changed or changed
		imgui.end_disabled()

		imgui.new_line()

		imgui.text("NPC Rewards")
		changed, config.ferrystone_drop_rates["Talk"].enabled = imgui.checkbox("NPC enabled",
			config.ferrystone_drop_rates["Talk"].enabled)
		config_changed = config_changed or changed

		imgui.begin_disabled(not config.ferrystone_drop_rates["Talk"].enabled)
		changed, config.ferrystone_drop_rates["Talk"].chance = imgui.slider_float("NPC chance",
			config.ferrystone_drop_rates["Talk"].chance, 0.0, 1.0, "%.2f")
		config_changed = config_changed or changed
		imgui.end_disabled()

		imgui.new_line()

		imgui.tree_pop()
	end

	if config_changed then save_config() end
end)

re.on_config_save(function()
	save_config()
end)

math.randomseed(os.time())
load_config()

local function get_player_position()
	local character = CharacterManager:get_ManualPlayer()

	if character then
		local gameObject = character:get_GameObject()

		if gameObject then
			local transform = gameObject:get_Transform()

			if transform then
				return transform:get_UniversalPosition():ToString()
			end
		end
	end

	return nil
end

local function player_pos_is_perm_portcrystal()
	local pos = get_player_position()
	for index, location in pairs(PermanentPortcrystals) do
		if pos == location then
			return true
		end
	end
	return false
end

local function add_ferrystone(is_notice)
	ItemManager:call("getItem", 80, 1, 2891076981, is_notice, false, false, 0)
end

-- refund ferrystones used on permanent portcrystals
sdk.hook(
	sdk.find_type_definition("app.FerrystoneFlowController"):get_method("teleport"),
	function()
	end,
	function()
		-- log.debug("Player: " .. get_player_position())
		if config.free_portcrystals_enabled and player_pos_is_perm_portcrystal() then
			add_ferrystone(false)
		end
	end
)

sdk.hook(
	sdk.find_type_definition("app.ItemManager"):get_method(
		"getItem(System.Int32, System.Int32, app.Character, System.Boolean, System.Boolean, System.Boolean, app.ItemManager.GetItemEventType, System.Boolean, System.Boolean)"),
	function(args)
		local type_info = {
			[2] = { name = "Gather", chance = config.ferrystone_drop_rates["Gather"].chance },
			[4] = { name = "TreasureBox", chance = config.ferrystone_drop_rates["TreasureBox"].chance },
			[8] = { name = "Talk", chance = config.ferrystone_drop_rates["Talk"].chance },
			[16] = { name = "DeadEnemy", chance = config.ferrystone_drop_rates["DeadEnemy"].chance }
		}

		if args[9] ~= nil then
			local source = sdk.to_int64(args[9])
			-- log.debug(source)
			-- log.debug(type_info[source].name)

			if source ~= nil and type_info[source] ~= nil and config.ferrystone_drop_rates[type_info[source].name].enabled then
				if math.random() <= type_info[source].chance then
					-- TODO: currently this just adds to arisen's inv even if a pawn procs it; add to pawn inv?
					add_ferrystone(true)
				end
			end
		end
	end,
	nil
)
