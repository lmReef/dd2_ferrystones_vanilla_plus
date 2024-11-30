local ItemManager = sdk.get_managed_singleton("app.ItemManager")
-- local FerrystoneFlowController = sdk.get_managed_singleton("app.FerrystoneFlowController")
local CharacterManager = sdk.get_managed_singleton("app.CharacterManager")

local PermanentPortcrystals = {
	"(458.811,32.915,-1012.04)", -- Vernworth
	"(-456.106,2.0164,-608.048)", -- Harve Village
	"(-1445.05,107.486,394.835)", -- Bakbattahl
	-- TODO: havent found these for testing yet
	-- "", -- Sacred Arbor
	-- "", -- Seafloor Shrine
}

local function get_player_position()
	local position = nil

	local character = CharacterManager:get_field("<ManualPlayer>k__BackingField")

	if character then
		local gameObject = character:get_GameObject()

		if gameObject then
			local transform = gameObject:get_Transform()

			if transform then
				local universalPosition = transform:get_UniversalPosition()
				position = universalPosition:ToString()
			end
		end
	end

	return position
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

sdk.hook(
	sdk.find_type_definition("app.FerrystoneFlowController"):get_method("teleport"),
	function()
	end,
	function()
		log.debug("Player: " .. get_player_position())
		if player_pos_is_perm_portcrystal() then
			add_ferrystone(false)
		end
	end
)
