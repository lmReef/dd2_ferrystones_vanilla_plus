local ItemManager = sdk.get_managed_singleton("app.ItemManager")
local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")
local GimmickManager = sdk.get_managed_singleton("app.GimmickManager")

local PERMANENT_PORTCRYSTAL_RADIUS = 20.0

-- Permanent portcrystals are gm80_205 gimmicks. The hardcoded coordinates
-- below are the fallback for when the gimmick list is unavailable.
local GimmickManagerType = sdk.find_type_definition("app.GimmickManager")
local GimmickIDType = sdk.find_type_definition("app.GimmickID")
local PermanentPortcrystalField = GimmickIDType and GimmickIDType:get_field("Gm80_205")
local PermanentPortcrystalID = PermanentPortcrystalField and PermanentPortcrystalField:get_data()
if type(PermanentPortcrystalID) ~= "number" or PermanentPortcrystalID < 0 or PermanentPortcrystalID > 65535 then
	PermanentPortcrystalID = 532
end
local GetGimmickList = GimmickManagerType and GimmickManagerType:get_method("getGimmickList(app.GimmickID)")

log.info("[Ferrystones] permanent portcrystal gimmick id: " .. tostring(PermanentPortcrystalID))

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

-- Disabled while testing the dynamic gimmick detection.
--[[
local PermanentPortcrystals = {
	{ 458.811, 32.915, -1012.04 },  -- Vernworth
	{ -456.106, 2.0164, -608.048 }, -- Harve Village
	{ 140.602, 153.463, -2121.792 }, -- Melve
	{ -1925.309, 236.477, -917.067 }, -- Checkpoint Rest Town
	{ -1445.05, 107.486, 394.835 }, -- Bakbattahl
	{ -258.599, 28.778, 1104.794 }, -- Volcanic Island Camp
	{ -490.768, -16.3092, -232.895 }, -- Seafloor Shrine
	{ -555.132, 117.652, -2257.69 }, -- Sacred Arbor
	{ -894.818, -15.0159, 814.869 }, -- Agamen Volcanic Island
}
]]

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
		changed, config.free_portcrystals_enabled = imgui.checkbox("Free permanent portcrystal teleports (WIP)",
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

local function get_player_transform()
	local character = CharacterManager:get_ManualPlayer()

	if character then
		local gameObject = character:get_GameObject()

		if gameObject then
			return gameObject:get_Transform()
		end
	end

	return nil
end

local function player_pos_is_perm_portcrystal()
	local transform = get_player_transform()
	if transform == nil then
		log.info("[Ferrystones] position check: no player transform")
		return false
	end

	local pos = transform:get_UniversalPosition()
	log.info(string.format("[Ferrystones] position check: player=(%.3f, %.3f, %.3f)", pos.x, pos.y, pos.z))

	local gimmick_manager = GimmickManager or sdk.get_managed_singleton("app.GimmickManager")

	if gimmick_manager ~= nil and GetGimmickList ~= nil and PermanentPortcrystalID ~= nil then
		local found = false
		local count = 0
		local nearest = nil

		local ok, err = pcall(function()
			local gimmicks = GetGimmickList:call(gimmick_manager, PermanentPortcrystalID)
			count = gimmicks:get_Count()

			for i = 0, count - 1 do
				local gimmick = gimmicks[i]
				local crystal_transform = gimmick and gimmick["<Trans>k__BackingField"]

				if crystal_transform ~= nil then
					local crystal_pos = crystal_transform:get_UniversalPosition()
					local distance = (pos - crystal_pos):length()

					if nearest == nil or distance < nearest then
						nearest = distance
					end

					if distance <= PERMANENT_PORTCRYSTAL_RADIUS then
						found = true
						return
					end
				end
			end
		end)

		log.info(string.format("[Ferrystones] dynamic scan: ok=%s gimmicks=%d nearest=%s found=%s err=%s",
			tostring(ok),
			count,
			nearest and string.format("%.3f", nearest) or "n/a",
			tostring(found),
			tostring(err)))

		if found then
			return true
		end
	else
		log.info("[Ferrystones] dynamic scan unavailable (manager, gimmick list, or ID missing)")
	end

	-- Hardcoded fallback disabled while testing dynamic detection.
	--[[
	local radius_sq = PERMANENT_PORTCRYSTAL_RADIUS * PERMANENT_PORTCRYSTAL_RADIUS

	for _, crystal in ipairs(PermanentPortcrystals) do
		local dx = pos.x - crystal[1]
		local dy = pos.y - crystal[2]
		local dz = pos.z - crystal[3]

		if dx * dx + dy * dy + dz * dz <= radius_sq then
			return true
		end
	end
	]]

	log.info("[Ferrystones] no permanent portcrystal within " .. tostring(PERMANENT_PORTCRYSTAL_RADIUS))
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

-- Refund ferrystones used on permanent portcrystals. Check after the warp,
-- not in teleport()'s post-hook, which still sees the origin position.
local free_teleport_pending = false

local function check_free_teleport(clear_on_miss, hook_name)
	log.info(string.format("[Ferrystones] check via %s: pending=%s", hook_name, tostring(free_teleport_pending)))

	if not free_teleport_pending then
		return
	end

	local at_permanent_portcrystal = player_pos_is_perm_portcrystal()
	log.info(string.format("[Ferrystones] check via %s: at_permanent=%s", hook_name, tostring(at_permanent_portcrystal)))

	if at_permanent_portcrystal or clear_on_miss then
		free_teleport_pending = false
	end

	if at_permanent_portcrystal then
		log.info("[Ferrystones] refunding ferrystone")
		add_ferrystone(false)
	end
end

local function schedule_free_teleport_check(hook_name)
	log.info("[Ferrystones] teleport hook: " .. hook_name)

	if config.free_portcrystals_enabled then
		free_teleport_pending = true
		log.info("[Ferrystones] pending refund set by " .. hook_name)
	end
end

local FerrystoneFlowControllerType = sdk.find_type_definition("app.FerrystoneFlowController")

local function hook_ferrystone_method(method_name, post_hook)
	local method = FerrystoneFlowControllerType and FerrystoneFlowControllerType:get_method(method_name)

	if method ~= nil then
		sdk.hook(method, nil, function()
			log.info("[Ferrystones] hook fired: " .. method_name)
			post_hook(method_name)
		end)
	else
		log.info("[Ferrystones] hook missing: " .. method_name)
	end
end

hook_ferrystone_method("teleport", schedule_free_teleport_check)
hook_ferrystone_method("teleportCharacters", schedule_free_teleport_check)
hook_ferrystone_method("onLoadComplete", function(hook_name)
	check_free_teleport(false, hook_name)
end)
hook_ferrystone_method("onFinishChangeArea", function(hook_name)
	check_free_teleport(true, hook_name)
end)

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
