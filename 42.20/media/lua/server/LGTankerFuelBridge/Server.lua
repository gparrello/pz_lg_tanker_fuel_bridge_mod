require "LGTankerFuelBridge/Bridge"

local Bridge = LGTankerFuelBridge
local previousVehiclePositions = {}
local PARKED_POSITION_TOLERANCE = 0.25

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
		if args.setting == "enabled" and (Bridge.isTransferBarrel(object)
			or (args.value ~= true and Bridge.isTransferEnabled(object))) then
			Bridge.setEnabled(object, args.value == true)
			return
		elseif args.setting == "direction" and Bridge.isTransferBarrel(object) then
			Bridge.setDrainDirection(object, args.value == true)
			return
		end
	end
end

Events.OnClientCommand.Add(function(module, command, player, args)
	if module ~= Bridge.MOD_ID or command ~= "setBarrelSetting" then return end
	setTargetAt(player, args)
end)

local function forEachLoadedVehicle(cell, callback)
	if not cell or not cell.getVehicles then return end
	local vehicles = cell:getVehicles()
	if not vehicles then return end

	-- Build 42 returns a Java Set here (no get(index)); retain the indexed path
	-- for compatibility with builds/contexts that expose a list.
	if type(vehicles.size) == "function" and type(vehicles.get) == "function" then
		for i = 0, vehicles:size() - 1 do
			local vehicle = vehicles:get(i)
			if vehicle then callback(vehicle) end
		end
		return
	end

	if type(vehicles.iterator) == "function" then
		local ok, iterator = pcall(function() return vehicles:iterator() end)
		if not ok or not iterator then return end
		while iterator:hasNext() do
			local vehicle = iterator:next()
			if vehicle then callback(vehicle) end
		end
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
		local hasInstalledItem = part.getInventoryItem and part:getInventoryItem() ~= nil
		local hasPartContainer = part.getItemContainer and part:getItemContainer() ~= nil
		return hasInstalledItem or hasPartContainer
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
		local gasPart = vehicle:getPartById("2000TankG")
		if not isInstalledContainerPart(gasPart) then return nil end
		if gasPart:getContainerContentType() ~= "Gasoline" then return nil end

		-- The W900 cistern can be configured for either gasoline or water. Only
		-- treat it as a fuel source when its gasoline tank is the installed tank.
		local waterPart = vehicle:getPartById("2000TankW")
		if waterPart and isInstalledContainerPart(waterPart) then return nil end
		return gasPart
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
	-- Key by the persistent vehicle ID, not the Lua Java-object wrapper returned
	-- from cell:getVehicles(); wrappers are not guaranteed to be identical each tick.
	local key = nil
	if vehicle.getId then
		local ok, vehicleId = pcall(function() return vehicle:getId() end)
		if ok and vehicleId ~= nil then key = tostring(vehicleId) end
	end
	key = key or tostring(vehicle)
	local previous = previousVehiclePositions[key]
	previousVehiclePositions[key] = { x = x, y = y }
	-- A trailer can report zero speed while being towed. Compare its actual position
	-- across server ticks instead, and require two consecutive stationary samples.
	return previous ~= nil
		and math.abs(previous.x - x) <= PARKED_POSITION_TOLERANCE
		and math.abs(previous.y - y) <= PARKED_POSITION_TOLERANCE
end

local function transferToBarrel(vehicle, part, object)
	if not Bridge.isAutoEnabled(object) or not Bridge.isEligibleBarrel(object) then return 0 end
	if not object.addFluid then return 0 end

	local container = object:getFluidContainer()
	local free = container:getFreeCapacity()
	local available = part:getContainerContentAmount()
	local wanted = math.min(Bridge.getRate(), free, available)
	if wanted <= Bridge.EPSILON then return 0 end

	local previousTotal = container:getAmount()
	local previousPetrol = container:getSpecificFluidAmount(Fluid.Petrol)
	pcall(function()
		object:addFluid(FluidType.Petrol, wanted)
	end)

	local added = container:getSpecificFluidAmount(Fluid.Petrol) - previousPetrol
	if added <= Bridge.EPSILON then return 0 end

	-- Charge the source only for the amount the destination actually accepted.
	part:setContainerContentAmount(math.max(0, available - added))
	vehicle:transmitPartModData(part)

	if object.transmitModData then object:transmitModData() end
	local square = object:getSquare()
	if square and square.transmitModdata then square:transmitModdata() end
	if object.sync then pcall(function() object:sync() end) end
	if triggerEvent then triggerEvent("OnWaterAmountChange", object, previousTotal) end
	return added
end

local function transferToTanker(vehicle, part, object)
	if not Bridge.isDrainEnabled(object) or not Bridge.isDrainableBarrel(object) then return 0 end
	if not object.useFluid then return 0 end

	local container = object:getFluidContainer()
	local barrelPetrolBefore = container:getSpecificFluidAmount(Fluid.Petrol)
	local tankBefore = part:getContainerContentAmount()
	local tankCapacity = part:getContainerCapacity()
	local free = math.max(0, tankCapacity - tankBefore)
	local wanted = math.min(Bridge.getRate(), barrelPetrolBefore, free)
	if wanted <= Bridge.EPSILON then return 0 end

	-- Stage petrol into the vehicle part first, then remove only what the part
	-- actually accepted from the barrel. The measured barrel delta is reconciled
	-- back onto the tanker, so both containers finish with the same transfer.
	part:setContainerContentAmount(math.min(tankCapacity, tankBefore + wanted))
	local stagedAmount = part:getContainerContentAmount() - tankBefore
	if stagedAmount <= Bridge.EPSILON then return 0 end

	-- Measure the barrel even if a listener throws after useFluid has already
	-- changed it; rolling back the tanker based only on the exception would lose
	-- petrol in that case.
	pcall(function() object:useFluid(stagedAmount) end)

	local barrelPetrolAfter = container:getSpecificFluidAmount(Fluid.Petrol)
	local removed = math.max(0, barrelPetrolBefore - barrelPetrolAfter)
	if removed <= Bridge.EPSILON then
		part:setContainerContentAmount(tankBefore)
		vehicle:transmitPartModData(part)
		return 0
	end

	part:setContainerContentAmount(math.min(tankCapacity, tankBefore + removed))
	local tankAdded = math.max(0, part:getContainerContentAmount() - tankBefore)
	vehicle:transmitPartModData(part)

	-- If the vehicle part rounded its update down, return the unaccepted petrol
	-- to the barrel rather than silently losing it.
	if removed - tankAdded > Bridge.EPSILON then
		pcall(function() object:addFluid(FluidType.Petrol, removed - tankAdded) end)
		if object.transmitModData then object:transmitModData() end
		local square = object:getSquare()
		if square and square.transmitModdata then square:transmitModdata() end
	end

	local remaining = container:getSpecificFluidAmount(Fluid.Petrol)
	if remaining <= Bridge.EPSILON and Bridge.isDrainEnabled(object) then
		Bridge.setEnabled(object, false)
	end
	return math.min(removed, tankAdded)
end

local function activeBarrelKey(object, square)
	local index = object.getObjectIndex and object:getObjectIndex() or -1
	return ("%d:%d:%d:%s"):format(square:getX(), square:getY(), square:getZ(), tostring(index))
end

local function tankerId(vehicle)
	if vehicle.getId then
		local ok, id = pcall(function() return vehicle:getId() end)
		if ok and id ~= nil then return tostring(id) end
	end
	return tostring(vehicle)
end

local function candidateHasCapacity(tanker, drainDirection)
	local amount = tanker.part:getContainerContentAmount()
	if drainDirection then
		return tanker.part:getContainerCapacity() - amount > Bridge.EPSILON
	end
	return amount > Bridge.EPSILON
end

local function tick()
	if not isAuthority() or not LGEP or not LGEP.isWaterSource then return end
	local cell = getCell()
	if not cell then return end
	local debugging = Bridge.isDebugEnabled()
	local stats = {
		vehicles = 0,
		tankers = 0,
		tanks = 0,
		fuelled = 0,
		parked = 0,
		barrelsEnabled = 0,
		barrelsDraining = 0,
		barrelsEligible = 0,
		barrelsServed = 0,
		litres = 0,
	}
	local range = Bridge.getRange()
	local tankers, barrelsByKey = {}, {}

	-- Build the currently loaded, parked tanker set once. Build 42's vehicle list
	-- is a Java Set, and every source is considered independently of its fuel level:
	-- an empty tanker can still receive fuel from a barrel.
	forEachLoadedVehicle(cell, function(vehicle)
		stats.vehicles = stats.vehicles + 1
		local scriptName = scriptLeafName(vehicle)
		if scriptName == "SemiTrailerCistern" or scriptName == "TrailerM967tanker"
			or scriptName == "TrailerISOcontainerM3tanker" then
			stats.tankers = stats.tankers + 1
		end

		local part = getFuelSourcePart(vehicle)
		if not part then return end
		stats.tanks = stats.tanks + 1
		if part:getContainerContentAmount() > Bridge.EPSILON then
			stats.fuelled = stats.fuelled + 1
		end
		if not remainedParked(vehicle) then return end
		stats.parked = stats.parked + 1

		local square = centerSquare(vehicle, part)
		if not square then return end
		local tanker = {
			vehicle = vehicle,
			part = part,
			square = square,
			id = tankerId(vehicle),
		}
		tankers[#tankers + 1] = tanker

		-- Find enabled barrels near any candidate tanker; selection happens below
		-- per barrel, so overlapping tanker ranges do not multiply its transfer.
		for dy = -range, range do
			for dx = -range, range do
				local nearby = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
				if nearby then
					local objects = nearby:getObjects()
					for i = 0, objects:size() - 1 do
						local object = objects:get(i)
						if Bridge.isTransferEnabled(object) then
							local key = activeBarrelKey(object, nearby)
							if not barrelsByKey[key] then
								barrelsByKey[key] = {
									object = object,
									square = nearby,
									index = object.getObjectIndex and object:getObjectIndex() or -1,
								}
							end
						end
					end
				end
			end
		end
	end)

	-- Stable tie-breaking means identical distances don't depend on HashSet order.
	table.sort(tankers, function(a, b) return a.id < b.id end)
	local barrels = {}
	for _, barrel in pairs(barrelsByKey) do barrels[#barrels + 1] = barrel end
	table.sort(barrels, function(a, b)
		local as, bs = a.square, b.square
		if as:getZ() ~= bs:getZ() then return as:getZ() < bs:getZ() end
		if as:getY() ~= bs:getY() then return as:getY() < bs:getY() end
		if as:getX() ~= bs:getX() then return as:getX() < bs:getX() end
		return a.index < b.index
	end)

	for _, barrel in ipairs(barrels) do
		local object, square = barrel.object, barrel.square
		local drainDirection = Bridge.isDrainDirection(object)
		local validBarrel
		if drainDirection then validBarrel = Bridge.isDrainableBarrel(object)
		else validBarrel = Bridge.isEligibleBarrel(object) end
		if drainDirection then stats.barrelsDraining = stats.barrelsDraining + 1
		else stats.barrelsEnabled = stats.barrelsEnabled + 1 end
		if validBarrel then stats.barrelsEligible = stats.barrelsEligible + 1 end
		if validBarrel then
			local best, bestDistance = nil, nil
			for _, tanker in ipairs(tankers) do
				local sourceSquare = tanker.square
				if sourceSquare:getZ() == square:getZ() then
					local distance = math.max(math.abs(sourceSquare:getX() - square:getX()),
						math.abs(sourceSquare:getY() - square:getY()))
					if distance <= range and (not bestDistance or distance < bestDistance)
						and candidateHasCapacity(tanker, drainDirection) then
						best, bestDistance = tanker, distance
					end
				end
			end

			if best then
				stats.barrelsServed = stats.barrelsServed + 1
				if drainDirection then
					stats.litres = stats.litres + transferToTanker(best.vehicle, best.part, object)
				else
					stats.litres = stats.litres + transferToBarrel(best.vehicle, best.part, object)
				end
			end
		end
	end

	if debugging then
		print(("[LGTankerFuelBridge] range=%d rate=%dL/10min loadedVehicles=%d supportedTankers=%d validTanks=%d fueledTankers=%d parkedTankers=%d refillBarrels=%d drainingBarrels=%d eligibleBarrels=%d servedBarrels=%d transferred=%.2fL")
			:format(range, Bridge.getRate(), stats.vehicles, stats.tankers, stats.tanks, stats.fuelled,
				stats.parked, stats.barrelsEnabled, stats.barrelsDraining,
				stats.barrelsEligible, stats.barrelsServed, stats.litres))
	end
end

Events.EveryTenMinutes.Add(tick)
