LGTankerFuelBridge = LGTankerFuelBridge or {}

local Bridge = LGTankerFuelBridge

Bridge.MOD_ID = "LGTankerFuelBridge"
Bridge.AUTO_KEY = "LGTankerFuelBridgeAuto"
Bridge.DRAIN_KEY = "LGTankerFuelBridgeDrain"
Bridge.RATE_LITRES_PER_TEN_MINUTES = 10
Bridge.DEFAULT_RANGE = 5
Bridge.EPSILON = 0.01

function Bridge.getRange()
	local options = SandboxVars and SandboxVars.LGTankerFuelBridge
	local range = options and tonumber(options.RefillRange) or Bridge.DEFAULT_RANGE
	return math.max(1, math.floor(range))
end

function Bridge.isDebugEnabled()
	local options = SandboxVars and SandboxVars.LGTankerFuelBridge
	return options and options.Debug == true
end

function Bridge.isAutoEnabled(object)
	if not object or not object.hasModData or not object:hasModData() then
		return false
	end
	return object:getModData()[Bridge.AUTO_KEY] == true
end

function Bridge.isDrainEnabled(object)
	if not object or not object.hasModData or not object:hasModData() then
		return false
	end
	return object:getModData()[Bridge.DRAIN_KEY] == true
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

function Bridge.setEnabled(object, enabled)
	if enabled and not Bridge.isEligibleBarrel(object) then return false end
	if not enabled and not Bridge.isAutoEnabled(object) then return false end

	local data = object:getModData()
	data[Bridge.AUTO_KEY] = enabled and true or nil
	if enabled then data[Bridge.DRAIN_KEY] = nil end
	if object.transmitModData then object:transmitModData() end
	return true
end

function Bridge.setDrainEnabled(object, enabled)
	if enabled and not Bridge.isDrainableBarrel(object) then return false end
	if not enabled and not Bridge.isDrainEnabled(object) then return false end

	local data = object:getModData()
	data[Bridge.DRAIN_KEY] = enabled and true or nil
	if enabled then data[Bridge.AUTO_KEY] = nil end
	if object.transmitModData then object:transmitModData() end
	return true
end

return Bridge
