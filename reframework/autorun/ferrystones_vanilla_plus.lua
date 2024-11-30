local ItemManager = sdk.get_managed_singleton("app.ItemManager")
local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")

local PermanentPortcrystals = {
	"(458.811,32.915,-1012.04)", -- Vernworth
	"(-456.106,2.0164,-608.048)", -- Harve Village
	"(-1445.05,107.486,394.835)", -- Bakbattahl
	-- TODO: havent found these for testing yet
	-- "", -- Sacred Arbor
	-- "", -- Seafloor Shrine
	-- "", -- Agamen Volcanic Island
}

math.randomseed(os.time())

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
		if player_pos_is_perm_portcrystal() then
			add_ferrystone(false)
		end
	end
)

sdk.hook(
	sdk.find_type_definition("app.ItemManager"):get_method(
		"getItem(System.Int32, System.Int32, app.Character, System.Boolean, System.Boolean, System.Boolean, app.ItemManager.GetItemEventType, System.Boolean, System.Boolean)"),
	function(args)
		local type_info = {
			-- [1] = { name = "None", chance = 0.0 },
			[2] = { name = "Gather", chance = 0.03 },
			[4] = { name = "TreasureBox", chance = 0.15 },
			[8] = { name = "Talk", chance = 0.15 },
			[16] = { name = "DeadEnemy", chance = 0.05 }
		}

		if args[9] ~= nil then
			local source = sdk.to_int64(args[9])
			-- log.debug(source)
			-- log.debug(type_info[source].name)

			if source ~= nil and type_info[source] ~= nil then
				if math.random() <= type_info[source].chance then
					-- TODO: currently this just adds to arisen's inv even if a pawn procs it; add to pawn inv?
					add_ferrystone(true)
				end
			end
		end
	end,
	nil
)
