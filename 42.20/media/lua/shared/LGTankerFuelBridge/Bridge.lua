LGTankerFuelBridge = LGTankerFuelBridge or {}

local Bridge = LGTankerFuelBridge

Bridge.MOD_ID = "LGTankerFuelBridge"
Bridge.AUTO_KEY = "LGTankerFuelBridgeAuto"
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

--- Only stationary collectors already in LGEP's building supply are valid targets.
--- A barrel with water in it is intentionally refused rather than emptied/replaced.
function Bridge.isEligibleBarrel(object)
	if not object or not LGEP or not LGEP.isWaterSource or not LGEP.isIncluded then
		return false
	end

	local ok, eligible = pcall(function()
		return LGEP.isWaterSource(object) and LGEP.isIncluded(object)
	end)
	if not ok or not eligible then return false end

	local okContainer, container = pcall(function()
		return object:getFluidContainer()
	end)
	if not okContainer or not container then return false end

	local okFluid, acceptsPetrol = pcall(function()
		return container:canAddFluid(Fluid.Petrol)
	end)
	if not okFluid or not acceptsPetrol then return false end

	local okAmounts, total, petrol = pcall(function()
		return container:getAmount(), container:getSpecificFluidAmount(Fluid.Petrol)
	end)
	if not okAmounts then return false end

	-- Do not overwrite water, whiskey, or any other contents. Empty or petrol-only.
	return total <= Bridge.EPSILON or math.abs(total - petrol) <= Bridge.EPSILON
end

function Bridge.setEnabled(object, enabled)
	if not Bridge.isEligibleBarrel(object) then return false end

	local data = object:getModData()
	data[Bridge.AUTO_KEY] = enabled and true or nil
	if object.transmitModData then object:transmitModData() end
	return true
end

return Bridge
