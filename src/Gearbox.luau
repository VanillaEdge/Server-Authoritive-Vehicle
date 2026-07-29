--!strict

local Units = require(script.Parent.Parent.Units)

local Gearbox = {}

const engaged = 0
const shifting = 1
const revMatching = 2

Gearbox.GetDownstreamTorque = function(cache: { [string]: any }): number
	return cache.ClutchTorque * cache.GearboxCurrentGearRatio
end

Gearbox.GetUpstreamAngularVelocity = function(cache: { [string]: any }, angularVelocity: number): number
	return angularVelocity * cache.GearboxCurrentGearRatio
end

Gearbox.UpdateDerivedState = function(cache: { [string]: any }, tune: { [string]: any })
	const gearRatio = tune.GearRatios[cache.GearboxCurrentGearIndex]
	const isEngaged = cache.GearboxShiftState == engaged

	cache.GearboxShifting = cache.GearboxShiftState ~= engaged
	cache.GearboxRevMatching = cache.GearboxShiftState == revMatching
	cache.GearboxInGear = isEngaged and gearRatio ~= 0
	cache.GearboxCurrentGearRatio = cache.GearboxInGear and gearRatio or 0
end

Gearbox.ShiftToGear = function(cache: { [string]: any }, targetGear: number)
	if cache.GearboxShiftState ~= engaged then
		return
	end

	cache.GearboxCurrentGearIndex = targetGear
	cache.GearboxShiftState = shifting
	cache.GearboxTimer = 0
end

Gearbox.FixedUpdate = function(cache: { [string]: any }, tune: { [string]: any }, deltaTime: number, gearboxOutputVelocity: number)
	Gearbox.UpdateDerivedState(cache, tune)

	const currentGearRatio = tune.GearRatios[cache.GearboxCurrentGearIndex]
	const inReverse = currentGearRatio < 0
	const firstDrive = (table.find(tune.GearRatios, 0) or 0) + 1
	const reverseGear = firstDrive - 2

	-- Reverse
	if inReverse then
		cache.InputThrottle, cache.InputBrake = cache.InputBrake, cache.InputThrottle
	end

	-- Engaged
	if cache.GearboxShiftState == engaged then
		cache.EngineThrottleOverrideEnabled = false
		cache.EngineThrottleOverride = 0

		-- Reverse / forward
		if cache.Velocity.Magnitude <= 1 and (cache.GearboxCurrentGearIndex == firstDrive or inReverse) and cache.InputBrake > 0.5 then
			cache.GearboxTimer += deltaTime
			if cache.GearboxTimer >= (tune.ShiftDuration * 1.5) then
				Gearbox.ShiftToGear(cache, inReverse and firstDrive or reverseGear)
				Gearbox.UpdateDerivedState(cache, tune)
				return
			end
		else
			cache.GearboxTimer = 0
		end

		-- Shift up / down
		const currentGearRPM = math.abs(gearboxOutputVelocity * currentGearRatio) * (60 / Units.Tau)
		if cache.GearboxCurrentGearIndex > firstDrive and currentGearRPM < tune.AutoShiftDownRPM then
			local targetGear = cache.GearboxCurrentGearIndex
			for gear = targetGear - 1, firstDrive, -1 do
				const gearRPM = math.abs(gearboxOutputVelocity * tune.GearRatios[gear]) * (60 / Units.Tau)
				if gearRPM > tune.AutoShiftUpRPM then
					break
				end
				targetGear = gear
			end

			if targetGear ~= cache.GearboxCurrentGearIndex then
				Gearbox.ShiftToGear(cache, targetGear)
			end

		elseif cache.GearboxCurrentGearIndex >= firstDrive and cache.GearboxCurrentGearIndex < #tune.GearRatios and currentGearRPM > tune.AutoShiftUpRPM then
			Gearbox.ShiftToGear(cache, cache.GearboxCurrentGearIndex + 1)
		end

		-- Shift delay
	elseif cache.GearboxShiftState == shifting then
		cache.EngineThrottleOverrideEnabled = true
		cache.EngineThrottleOverride = 0
		cache.GearboxTimer += deltaTime

		if cache.GearboxTimer >= tune.ShiftDuration then
			cache.GearboxTimer = 0
			cache.GearboxShiftState = revMatching
		end

		-- Revmatching
	elseif cache.GearboxShiftState == revMatching then
		cache.EngineThrottleOverrideEnabled = true
		cache.EngineThrottleOverride = 0

		const targetEngineRPM = math.max(math.abs(gearboxOutputVelocity * currentGearRatio) * (60 / Units.Tau), tune.IdleRPM)

		if cache.EngineRPM < targetEngineRPM - tune.RevMatchToleranceRPM then
			cache.EngineThrottleOverride = tune.RevMatchThrottle
		elseif cache.EngineRPM <= targetEngineRPM + tune.RevMatchToleranceRPM then
			cache.GearboxShiftState = engaged
			cache.GearboxTimer = 0
			cache.EngineThrottleOverrideEnabled = false
			cache.EngineThrottleOverride = 0
		end
	end

	Gearbox.UpdateDerivedState(cache, tune)
end

return Gearbox
