require "LGTankerFuelBridge/Bridge"
require "W900_CisternParts"

local Bridge = LGTankerFuelBridge
local previousVehiclePositions = setmetatable({}, { __mode = "k" })

local function isAuthority()
	return not isClient()
end

local function nearPlayer(player, x, y, z)
	if not player or not player.getX or not player.getY then return false end
	local px, py = player:getX(), player:getY()
	if type(px) ~= "number" or type(py) ~= "number" then return false end
	if player.getZ and math.abs((player:getZ() or z) - z) > 1 then return false end
	return math.max(math.abs(math.floor(px) - x), math.abs(math.floor(py) - y)) <= 3
end

local function setTargetAt(player, args)
	if not isAuthority() or type(args) ~= "table" then return end
	local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
	if not x or not y or not z then return end
	x, y, z = math.floor(x), math.floor(y), math.floor(z)
	if not nearPlayer(player, x, y, z) then return end

	local cell = getCell()
	local square = cell and cell:getGridSquare(x, y, z)
	if not square then return end
	local objects = square:getObjects()
	for i = 0, objects:size() - 1 do
		local object = objects:get(i)
		if Bridge.isEligibleBarrel(object) then
			Bridge.setEnabled(object, args.enabled == true)
			return
		end
	end
end

Events.OnClientCommand.Add(function(module, command, player, args)
	if module ~= Bridge.MOD_ID or command ~= "setAutoRefill" then return end
	setTargetAt(player, args)
end)

local function forEachLoadedVehicle(cell, callback)
	if not cell or not cell.getVehicles then return end
	local vehicles = cell:getVehicles()
	if not vehicles or not vehicles.size or not vehicles.get then return end
	for i = 0, vehicles:size() - 1 do
		local vehicle = vehicles:get(i)
		if vehicle then callback(vehicle) end
	end
end

local function scriptLeafName(vehicle)
	if not vehicle or not vehicle.getScriptName then return nil end
	local ok, scriptName = pcall(function() return vehicle:getScriptName() end)
	if not ok or type(scriptName) ~= "string" then return nil end
	return scriptName:match("([^%.]+)$")
end

local function isInstalledContainerPart(part)
	if not part or not part.isContainer or not part:isContainer() then return false end
	local ok, installed = pcall(function()
		return part:getInventoryItem() ~= nil or W900CisternParts.hasPartContainer(part)
	end)
	return ok and installed == true
end

local function getTankerPart(vehicle, partId, contentType)
	local part = vehicle:getPartById(partId)
	if not isInstalledContainerPart(part) then return nil end
	if part:getContainerContentType() ~= contentType then return nil end
	if part:getContainerCapacity() <= 0 then return nil end
	return part
end

local function getFuelSourcePart(vehicle)
	local scriptName = scriptLeafName(vehicle)
	if scriptName == "SemiTrailerCistern" then
		local part = W900CisternParts.getGasTankPart(vehicle)
		if part and W900CisternParts.isValidGasSourcePart(part) then return part end
		return nil
	end

	-- Dedicated tanker vehicles only: don't accidentally drain ordinary cars or boats.
	if scriptName == "TrailerM967tanker" then
		return getTankerPart(vehicle, "1000FuelTank", "Gasoline Storage")
	elseif scriptName == "TrailerISOcontainerM3tanker" then
		return getTankerPart(vehicle, "GasTank", "Gasoline")
	end
	return nil
end

local function centerSquare(vehicle, part)
	local area = part:getArea()
	local center = area and vehicle:getAreaCenter(area) or nil
	if not center then return nil end
	local cell = getCell()
	return cell and cell:getGridSquare(center:getX(), center:getY(), vehicle:getZ()) or nil
end

local function remainedParked(vehicle)
	local x, y = vehicle:getX(), vehicle:getY()
	local previous = previousVehiclePositions[vehicle]
	previousVehiclePositions[vehicle] = { x = x, y = y }
	-- A trailer can report zero speed while being towed. Compare its actual position
	-- across server ticks instead, and require two consecutive stationary samples.
	return previous ~= nil
		and math.abs(previous.x - x) <= 0.05
		and math.abs(previous.y - y) <= 0.05
end

local function transferToBarrel(vehicle, part, object)
	if not Bridge.isAutoEnabled(object) or not Bridge.isEligibleBarrel(object) then return end
	if not object.addFluid then return end

	local container = object:getFluidContainer()
	local free = container:getFreeCapacity()
	local available = part:getContainerContentAmount()
	local wanted = math.min(Bridge.RATE_LITRES_PER_TEN_MINUTES, free, available)
	if wanted <= Bridge.EPSILON then return end

	local previousTotal = container:getAmount()
	local previousPetrol = container:getSpecificFluidAmount(Fluid.Petrol)
	local ok = pcall(function()
		object:addFluid(FluidType.Petrol, wanted)
	end)
	if not ok then return end

	local added = container:getSpecificFluidAmount(Fluid.Petrol) - previousPetrol
	if added <= Bridge.EPSILON then return end

	-- Charge the source only for the amount the destination actually accepted.
	part:setContainerContentAmount(math.max(0, available - added))
	vehicle:transmitPartModData(part)

	if object.transmitModData then object:transmitModData() end
	local square = object:getSquare()
	if square and square.transmitModdata then square:transmitModdata() end
	if object.sync then pcall(function() object:sync() end) end
	if triggerEvent then triggerEvent("OnWaterAmountChange", object, previousTotal) end
end

local function tick()
	if not isAuthority() or not LGEP or not LGEP.isWaterSource then return end
	local cell = getCell()
	if not cell then return end

	forEachLoadedVehicle(cell, function(vehicle)
		local part = getFuelSourcePart(vehicle)
		if not part or part:getContainerContentAmount() <= Bridge.EPSILON then return end
		if not remainedParked(vehicle) then return end

		local square = centerSquare(vehicle, part)
		if not square then return end
		for dy = -Bridge.RANGE, Bridge.RANGE do
			for dx = -Bridge.RANGE, Bridge.RANGE do
				local nearby = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
				if nearby then
					local objects = nearby:getObjects()
					for i = 0, objects:size() - 1 do
						local object = objects:get(i)
						if Bridge.isAutoEnabled(object) then
							transferToBarrel(vehicle, part, object)
						end
					end
				end
			end
		end
	end)
end

Events.EveryTenMinutes.Add(tick)
