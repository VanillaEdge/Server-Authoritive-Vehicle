--!strict

local Units = require(script.Parent.Parent.Units)

local Gearbox = {}

Gearbox.GetDownstreamTorque = function(cache: { [string]: any }): number
	return cache.ClutchTorque * cache.GearboxCurrentGearRatio
end

Gearbox.GetUpstreamAngularVelocity = function(cache: { [string]: any }, angularVelocity: number): number
	return angularVelocity * cache.GearboxCurrentGearRatio
end

Gearbox.ShiftToGear = function(cache: { [string]: any }, tune: { [string]: any }, targetGear: number)
	if cache.GearboxShifting then
		return
	end

	cache.GearboxShifting = true
	cache.GearboxInGear = false
	cache.GearboxRevMatching = false

	task.delay(tune.ShiftDuration, function()
		cache.GearboxCurrentGearIndex = targetGear
		cache.GearboxRevMatching = true
	end)
end

Gearbox.FixedUpdate = function(cache: { [string]: any }, tune: { [string]: any }, deltaTime: number, gearboxOutputVelocity: number)
	const inReverse = tune.GearRatios[cache.GearboxCurrentGearIndex] < 0
	const firstDrive = (table.find(tune.GearRatios, 0) or 0) + 1
	const reverseGear = firstDrive - 2

	-- Reverse
	if inReverse then
		cache.InputThrottle, cache.InputBrake = cache.InputBrake, cache.InputThrottle
	end

	if cache.GearboxInGear and not cache.GearboxShifting and cache.Velocity.Magnitude <= 1 and (cache.GearboxCurrentGearIndex == firstDrive or inReverse) and cache.InputBrake > 0.5 then
		cache.DirectionShiftTimer += deltaTime
		if cache.DirectionShiftTimer >= (tune.ShiftDuration * 1.5) then
			cache.DirectionShiftTimer = 0
			Gearbox.ShiftToGear(cache, tune, inReverse and firstDrive or reverseGear)
		end
	else
		cache.DirectionShiftTimer = 0
	end

	-- Shifting
	if cache.GearboxInGear and not cache.GearboxShifting then
		if cache.GearboxCurrentGearIndex > firstDrive and cache.EngineRPM < tune.AutoShiftDownRPM then
			const nextGearRatio = tune.GearRatios[cache.GearboxCurrentGearIndex - 1]
			const nextGearRPM = math.abs(gearboxOutputVelocity * nextGearRatio) * (60 / Units.Tau)

			if nextGearRPM <= tune.AutoShiftUpRPM then
				Gearbox.ShiftToGear(cache, tune, cache.GearboxCurrentGearIndex - 1)
			end

		elseif cache.GearboxCurrentGearIndex >= firstDrive and cache.GearboxCurrentGearIndex < #tune.GearRatios and cache.EngineRPM > tune.AutoShiftUpRPM then
			Gearbox.ShiftToGear(cache, tune, cache.GearboxCurrentGearIndex + 1)
		end
	end

	-- Revmatching
	if cache.GearboxShifting then
		cache.EngineThrottleOverride = 0

		if cache.GearboxRevMatching then
			const targetGearRatio = tune.GearRatios[cache.GearboxCurrentGearIndex]
			const targetEngineVelocity = math.abs(gearboxOutputVelocity * targetGearRatio)
			const targetEngineRPM = math.max(targetEngineVelocity * (60 / Units.Tau), tune.IdleRPM)

			if cache.EngineRPM < targetEngineRPM - tune.RevMatchToleranceRPM then
				cache.EngineThrottleOverride = tune.RevMatchThrottle
			elseif cache.EngineRPM <= targetEngineRPM + tune.RevMatchToleranceRPM then
				cache.GearboxRevMatching = false
				cache.GearboxInGear = true
				cache.GearboxShifting = false
				cache.EngineThrottleOverride = 0
			end
		end
	else
		cache.EngineThrottleOverride = false
	end

	-- Neutral
	if cache.GearboxInGear then
		cache.GearboxCurrentGearRatio = tune.GearRatios[cache.GearboxCurrentGearIndex]
	else
		cache.GearboxCurrentGearRatio = 0
	end

	if cache.GearboxCurrentGearRatio == 0 then
		cache.GearboxInGear = false
	end
end

return Gearbox
