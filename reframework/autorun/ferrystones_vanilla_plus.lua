local ItemManager = sdk.get_managed_singleton("app.ItemManager")
local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")

-- Dragon's Dogma 2 3.2+/4.0 moved the item event type from a getItem
-- parameter into app.ItemDefine.GetItemOption.EventType, so the old 9-arg
-- getItem hook no longer exists. Hook the option-bearing overloads instead.
local ItemManagerType = sdk.find_type_definition("app.ItemManager")
local GetItemOptionType = sdk.find_type_definition("app.ItemDefine.GetItemOption")
local GetItemEventTypeField = GetItemOptionType and GetItemOptionType:get_field("EventType")
local GetItemPlain = ItemManagerType and ItemManagerType:get_method(
	"getItem(System.Int32, System.Int32, app.Character)")

-- The overloads that carry a GetItemOption. Hooking the outer getItem calls
-- keeps the ferrystones inside the item manager's own update context.
local GetItemOptionHooks = {}
if ItemManagerType ~= nil then
	-- Hook args include the return slot at [1] and `this` at [2], so the
	-- GetItemOption parameter lands at index 6 (or 5 for the ItemResult form).
	local signatures = {
		{ "getItem(System.Int32, System.Int32, app.Character, app.ItemDefine.GetItemOption)", 6 },
		{ "getItem(System.Int32, System.Int32, app.CharacterID, app.ItemDefine.GetItemOption)", 6 },
		{ "getItem(app.ItemDropLottery.ItemResult, app.Character, app.ItemDefine.GetItemOption)", 5 },
	}

	for _, entry in ipairs(signatures) do
		local method = ItemManagerType:get_method(entry[1])
		if method ~= nil then
			GetItemOptionHooks[#GetItemOptionHooks + 1] = {
				method = method,
				option_index = entry[2],
			}
		end
	end
end

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
				chance = 0.02,
			},
			["DeadEnemy"] = {
				enabled = true,
				chance = 0.02,
			},
			["TreasureBox"] = {
				enabled = true,
				chance = 0.05,
			},
			["Talk"] = {
				enabled = true,
				chance = 0.10,
			}
		},
		free_portcrystals_enabled = false
	}
end

local config = get_default_config()

local function load_config()
	local config_file = json.load_file("ferrystones_vanilla_plus.json")
	if config_file ~= nil then
		config = config_file
	end

	-- Free permanent portcrystal teleports are under maintenance in 1.2.
	config.free_portcrystals_enabled = false
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

		-- free portcrystals config (under maintenance in 1.2)
		config.free_portcrystals_enabled = false
		imgui.begin_disabled(true)
		imgui.checkbox("Free permanent portcrystal teleports (under maintenance)", false)
		imgui.end_disabled()

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

		imgui.text("Gathering (includes Norgan spoils)")
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
	local player = CharacterManager:get_ManualPlayer()
	if player ~= nil and GetItemPlain ~= nil then
		-- The 3-arg overload uses the game's default GetItemOption. Item ID 80
		-- is still Ferrystone on the current build.
		GetItemPlain:call(ItemManager, 80, 1, player)
	end
end

local function get_item_event_type(args, option_index)
	if GetItemEventTypeField == nil or args[option_index] == nil then
		return nil
	end

	local ok, event_type = pcall(function()
		return GetItemEventTypeField:get_data(args[option_index])
	end)

	if ok and type(event_type) == "number" then
		return event_type
	end

	return nil
end

-- getItem overloads can call one another. Count nested calls so one pickup
-- only rolls once, and so adding our ferrystone cannot trigger another roll.
local item_event_depth = 0

local function on_item_event_pre(args, option_index)
	local add_ferrystone_now = false

	if item_event_depth == 0 then
		local source = get_item_event_type(args, option_index)
		local event_names = {
			[2] = "Gather",
			[4] = "TreasureBox",
			[8] = "Talk",
			[16] = "DeadEnemy",
		}

		local event_name = event_names[source]
		local drop_config = event_name and config.ferrystone_drop_rates[event_name]

		add_ferrystone_now = drop_config ~= nil and drop_config.enabled and math.random() <= drop_config.chance
	end

	item_event_depth = item_event_depth + 1

	if add_ferrystone_now then
		pcall(add_ferrystone, true)
	end
end

local function on_item_event_post()
	if item_event_depth > 0 then
		item_event_depth = item_event_depth - 1
	end
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

for _, hook in ipairs(GetItemOptionHooks) do
	local option_index = hook.option_index

	sdk.hook(
		hook.method,
		function(args)
			on_item_event_pre(args, option_index)
		end,
		function()
			on_item_event_post()
		end
	)
end
