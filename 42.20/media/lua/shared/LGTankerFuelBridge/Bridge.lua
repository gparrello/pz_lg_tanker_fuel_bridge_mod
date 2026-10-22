LGTankerFuelBridge = LGTankerFuelBridge or {}

local Bridge = LGTankerFuelBridge

Bridge.MOD_ID = "LGTankerFuelBridge"
-- AUTO_KEY and DRAIN_KEY are retained for upgrading barrel markers from older
-- builds. New saves use separate enabled/direction settings below.
Bridge.AUTO_KEY = "LGTankerFuelBridgeAuto"
Bridge.DRAIN_KEY = "LGTankerFuelBridgeDrain"
Bridge.ENABLED_KEY = "LGTankerFuelBridgeEnabled"
Bridge.DIRECTION_KEY = "LGTankerFuelBridgeDrainDirection"
Bridge.DEFAULT_RATE_LITRES_PER_TEN_MINUTES = 10
Bridge.DEFAULT_RANGE = 5
Bridge.EPSILON = 0.01

function Bridge.getRange()
	local options = SandboxVars and SandboxVars.LGTankerFuelBridge
	local range = options and tonumber(options.RefillRange) or Bridge.DEFAULT_RANGE
	return math.max(1, math.floor(range))
end

function Bridge.getRate()
	local options = SandboxVars and SandboxVars.LGTankerFuelBridge
	local rate = options and tonumber(options.LitresPerTenMinutes)
		or Bridge.DEFAULT_RATE_LITRES_PER_TEN_MINUTES
	return math.max(1, math.floor(rate))
end

function Bridge.isDebugEnabled()
	local options = SandboxVars and SandboxVars.LGTankerFuelBridge
	return options and options.Debug == true
end

local function dataOf(object)
	if not object or not object.hasModData or not object:hasModData() then
		return nil
	end
	return object:getModData()
end

function Bridge.isDrainDirection(object)
	local data = dataOf(object)
	if not data then return false end
	if data[Bridge.DIRECTION_KEY] ~= nil then
		return data[Bridge.DIRECTION_KEY] == true
	end
	-- Old drain mode implied both enabled and tanker-bound direction.
	return data[Bridge.DRAIN_KEY] == true
end

function Bridge.isTransferEnabled(object)
	local data = dataOf(object)
	if not data then return false end
	if data[Bridge.ENABLED_KEY] ~= nil then
		return data[Bridge.ENABLED_KEY] == true
	end
	-- Old keys stored the active direction rather than an independent switch.
	return data[Bridge.AUTO_KEY] == true or data[Bridge.DRAIN_KEY] == true
end

function Bridge.isAutoEnabled(object)
	return Bridge.isTransferEnabled(object) and not Bridge.isDrainDirection(object)
end

function Bridge.isDrainEnabled(object)
	return Bridge.isTransferEnabled(object) and Bridge.isDrainDirection(object)
end

function Bridge.collectorContainer(object)
	if not object or not LGEP or not LGEP.isWaterSource or not LGEP.isIncluded then
		return nil
	end

	local ok, eligible = pcall(function()
		return LGEP.isWaterSource(object) and LGEP.isIncluded(object)
	end)
	if not ok or not eligible then return nil end

	local okContainer, container = pcall(function()
		return object:getFluidContainer()
	end)
	if not okContainer or not container then return nil end
	return container
end

local function isPetrolOnly(container, requirePetrol)
	if not container then return false end
	local okAmounts, total, petrol = pcall(function()
		return container:getAmount(), container:getSpecificFluidAmount(Fluid.Petrol)
	end)
	if not okAmounts then return false end
	if requirePetrol and petrol <= Bridge.EPSILON then return false end
	return total <= Bridge.EPSILON or math.abs(total - petrol) <= Bridge.EPSILON
end

--- A refill target must be a plumbed-in collector which can accept petrol and is
--- empty or already contains petrol only. Never overwrite another liquid.
function Bridge.isEligibleBarrel(object)
	local container = Bridge.collectorContainer(object)
	if not container then return false end

	local okFluid, acceptsPetrol = pcall(function()
		return container:canAddFluid(Fluid.Petrol)
	end)
	if not okFluid or not acceptsPetrol then return false end
	return isPetrolOnly(container, false)
end

--- A drain source must be a plumbed-in collector with petrol and no other liquid.
function Bridge.isDrainableBarrel(object)
	local container = Bridge.collectorContainer(object)
	return isPetrolOnly(container, true)
end

function Bridge.isTransferBarrel(object)
	local container = Bridge.collectorContainer(object)
	return isPetrolOnly(container, false)
end

--- The barrel acts as a powered transfer pump; use the same square power test
--- as LG Extended Plumbing's pump-up behavior.
function Bridge.isBarrelPowered(object)
	if not object or not object.getSquare then return false end
	local ok, powered = pcall(function()
		local square = object:getSquare()
		return square and square:haveElectricity() or false
	end)
	return ok and powered == true
end

local function writeMode(object, enabled, drainDirection)
	local data = object:getModData()
	data[Bridge.ENABLED_KEY] = enabled == true
	data[Bridge.DIRECTION_KEY] = drainDirection == true
	data[Bridge.AUTO_KEY] = nil
	data[Bridge.DRAIN_KEY] = nil
	if object.transmitModData then object:transmitModData() end
end

function Bridge.setEnabled(object, enabled)
	local drainDirection = Bridge.isDrainDirection(object)
	if enabled then
		if not Bridge.isBarrelPowered(object) then return false end
		if drainDirection and not Bridge.isDrainableBarrel(object) then return false end
		if not drainDirection and not Bridge.isEligibleBarrel(object) then return false end
	end
	if not enabled and not Bridge.isTransferEnabled(object) then return false end
	writeMode(object, enabled, drainDirection)
	return true
end

function Bridge.setDrainDirection(object, drainDirection)
	if not Bridge.isTransferBarrel(object) then return false end
	if not Bridge.isBarrelPowered(object) then return false end
	writeMode(object, Bridge.isTransferEnabled(object), drainDirection)
	return true
end

return Bridge
