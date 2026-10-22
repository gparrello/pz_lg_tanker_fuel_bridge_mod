require "LGTankerFuelBridge/Bridge"

local Bridge = LGTankerFuelBridge

local function setBarrelMode(_target, object, playerNum, mode, enabled)
	if not object or not object:getSquare() then return end
	local square = object:getSquare()
	sendClientCommand(Bridge.MOD_ID, "setBarrelMode", {
		x = square:getX(),
		y = square:getY(),
		z = square:getZ(),
		enabled = enabled == true,
		mode = mode,
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
	local refilling = Bridge.isAutoEnabled(object)
	local draining = Bridge.isDrainEnabled(object)
	local canRefill = not refilling and not draining and Bridge.isEligibleBarrel(object)
	local canDrain = not refilling and not draining and Bridge.isDrainableBarrel(object)
	if not refilling and not draining and not canRefill and not canDrain then return end

	local menu = barrelSubMenu(context, object) or context
	local function addModeOption(labelKey, tooltipKey, mode, enabled)
		local label = getText(labelKey)
		local option = menu:addOption(label, object, setBarrelMode, object, player, mode, enabled)
		local tooltip = ISWorldObjectContextMenu.addToolTip()
		tooltip:setName(label)
		tooltip.description = getText(tooltipKey)
		option.toolTip = tooltip
	end

	if refilling then
		addModeOption("ContextMenu_LGTankerFuelBridge_Disable",
			"ContextMenu_LGTankerFuelBridge_Tooltip", "refill", false)
	elseif draining then
		addModeOption("ContextMenu_LGTankerFuelBridge_StopDrain",
			"ContextMenu_LGTankerFuelBridge_DrainTooltip", "drain", false)
	else
		if canRefill then
			addModeOption("ContextMenu_LGTankerFuelBridge_Enable",
				"ContextMenu_LGTankerFuelBridge_Tooltip", "refill", true)
		end
		if canDrain then
			addModeOption("ContextMenu_LGTankerFuelBridge_StartDrain",
				"ContextMenu_LGTankerFuelBridge_DrainTooltip", "drain", true)
		end
	end
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
