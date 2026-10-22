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

local function addOption(player, context, object)
	if not Bridge.isEligibleBarrel(object) then return end

	local enabled = Bridge.isAutoEnabled(object)
	local label = enabled
		and getText("ContextMenu_LGTankerFuelBridge_Disable")
		or getText("ContextMenu_LGTankerFuelBridge_Enable")
	local option = context:addOption(label, object, toggleAutoRefill, object, player, not enabled)
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
