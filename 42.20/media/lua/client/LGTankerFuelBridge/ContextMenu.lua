require "LGTankerFuelBridge/Bridge"

local Bridge = LGTankerFuelBridge

local function setBarrelSetting(_target, object, playerNum, setting, value)
	if not object or not object:getSquare() then return end
	local square = object:getSquare()
	sendClientCommand(Bridge.MOD_ID, "setBarrelSetting", {
		x = square:getX(),
		y = square:getY(),
		z = square:getZ(),
		setting = setting,
		value = value == true,
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
	local enabled = Bridge.isTransferEnabled(object)
	local drainDirection = Bridge.isDrainDirection(object)
	local transferBarrel = Bridge.isTransferBarrel(object)
	if not enabled and not transferBarrel then return end
	local canEnable = drainDirection
		and Bridge.isDrainableBarrel(object)
		or (not drainDirection and Bridge.isEligibleBarrel(object))

	local menu = barrelSubMenu(context, object) or context
	local function addSetting(labelKey, tooltipKey, setting, value, unavailable)
		local label = getText(labelKey)
		local option = menu:addOption(label, object, setBarrelSetting,
			object, player, setting, value)
		option.notAvailable = unavailable == true
		local tooltip = ISWorldObjectContextMenu.addToolTip()
		tooltip:setName(label)
		tooltip.description = getText(tooltipKey)
		option.toolTip = tooltip
	end

	addSetting(drainDirection
		and "ContextMenu_LGTankerFuelBridge_DirectionDrain"
		or "ContextMenu_LGTankerFuelBridge_DirectionRefill",
		"ContextMenu_LGTankerFuelBridge_DirectionTooltip",
		"direction", not drainDirection, false)
	addSetting(enabled
		and "ContextMenu_LGTankerFuelBridge_DisableTransfer"
		or "ContextMenu_LGTankerFuelBridge_EnableTransfer",
		drainDirection and "ContextMenu_LGTankerFuelBridge_DrainTooltip"
		or "ContextMenu_LGTankerFuelBridge_Tooltip",
		"enabled", not enabled, not enabled and not canEnable)
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
