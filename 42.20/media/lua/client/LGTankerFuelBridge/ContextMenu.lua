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

local function barrelSubMenu(context, object)
	if not context or not context.getSubMenu or type(fluidBlockEntries) ~= "function" then
		return nil
	end

	-- LGEP pairs vanilla fluid-container submenu rows with their actual world
	-- objects. Use object identity so identical barrels don't share one submenu.
	local ok, entries = pcall(fluidBlockEntries, context)
	if not ok or type(entries) ~= "table" then return nil end
	for _, entry in ipairs(entries) do
		if entry.object == object and entry.option and entry.option.subOption then
			local menuOk, menu = pcall(function()
				return context:getSubMenu(entry.option.subOption)
			end)
			if menuOk then return menu end
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
