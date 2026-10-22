require "LGTankerFuelBridge/Bridge"

local Bridge = LGTankerFuelBridge

local function toggleAutoRefill(_target, object, playerNum, enabled)
	if not object or not object:getSquare() then return end
	local square = object:getSquare()
	sendClientCommand(Bridge.MOD_ID, "setAutoRefill", {
		x = square:getX(),
		y = square:getY(),
		z = square:getZ(),
		enabled = enabled == true,
		playerNum = playerNum,
	})
end

local function fluidMenuName(object)
	if not object then return nil end
	local name = ISWorldObjectContextMenu and ISWorldObjectContextMenu.getMoveableDisplayName
		and ISWorldObjectContextMenu.getMoveableDisplayName(object)
	if name then return name end
	return object.getFluidUiName and object:getFluidUiName() or nil
end

local function barrelSubMenu(context, object)
	if not context or not context.getSubMenu or type(context.options) ~= "table" then
		return nil
	end
	local fetch = ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars
	local containers = fetch and fetch.fluidcontainer
	if type(containers) ~= "table" then return nil end

	-- Vanilla builds one fluid-container submenu row per object in fetch order.
	-- Pair by both order and identity so two identically named barrels get their
	-- own option rather than both attaching to the first barrel's submenu.
	local from = 1
	for _, candidate in ipairs(containers) do
		local name = fluidMenuName(candidate)
		if name then
			for i = from, #context.options do
				local entry = context.options[i]
				if entry and entry.name == name then
					if candidate == object and entry.subOption then
						local ok, menu = pcall(function()
							return context:getSubMenu(entry.subOption)
						end)
						if ok then return menu end
					end
					from = i + 1
					break
				end
			end
		end
	end
	return nil
end

local function addOption(player, context, object)
	if not Bridge.isEligibleBarrel(object) then return end

	local enabled = Bridge.isAutoEnabled(object)
	local label = enabled
		and getText("ContextMenu_LGTankerFuelBridge_Disable")
		or getText("ContextMenu_LGTankerFuelBridge_Enable")
	local menu = barrelSubMenu(context, object) or context
	local option = menu:addOption(label, object, toggleAutoRefill, object, player, not enabled)
	local tooltip = ISWorldObjectContextMenu.addToolTip()
	tooltip:setName(label)
	tooltip.description = getText("ContextMenu_LGTankerFuelBridge_Tooltip")
	option.toolTip = tooltip
end

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
	if test or not worldobjects then return end

	local seen = {}
	for _, clicked in ipairs(worldobjects) do
		local square = clicked and clicked.getSquare and clicked:getSquare() or nil
		if square then
			local objects = square:getObjects()
			for i = 0, objects:size() - 1 do
				local object = objects:get(i)
				if object and not seen[object] then
					seen[object] = true
					local ok, err = pcall(addOption, player, context, object)
					if not ok then
						print("[LGTankerFuelBridge] Could not build barrel context option: " .. tostring(err))
					end
				end
			end
		end
	end
end)
