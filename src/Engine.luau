--!strict

local Units = require(script.Parent.Parent.Units)

local Engine = {}

local function mapRangeClamped(value: number, inA: number, inB: number, outA: number, outB: number): number
	const t = math.clamp((value - inA) / (inB - inA), 0, 1)
	return outA + (outB - outA) * t
end

local function evaluateCurve(rpm: number, curve): number
	if rpm <= curve[1][1] then
		return curve[1][2]
	end

	for i = 2, #curve do
		const prev = curve[i-1]
		const curr = curve[i]
		if rpm <= curr[1] then
			const t = (rpm - prev[1]) / (curr[1] - prev[1])
			return prev[2] + (curr[2] - prev[2]) * t
		end
	end

	return curve[#curve][2]
end

Engine.FixedUpdate = function(cache: { [string]: any }, tune: { [string]: any }, deltaTime: number)
	-- Idler circuit
	local engineIdler = mapRangeClamped(cache.EngineRPM, tune.IdleRPM - 200, tune.IdleRPM + 200, tune.IdleThrottle, 0)
	cache.EngineTimer += deltaTime

	if cache.EngineTimer >= 0.1 then
		cache.EngineTimer = 0
		cache.EngineInstability = math.random() * (1 - tune.ThrottleStability) + tune.ThrottleStability
	end

	engineIdler *= cache.EngineInstability

	-- Rev limiter
	if cache.EngineRPM >= tune.RedlineRPM and not cache.EngineThrottleCut then
		cache.EngineThrottleCut = true
		task.delay(tune.ThrottleCutOffDuration, function()
			cache.EngineThrottleCut = false
		end)
	end

	-- Throttle
	const throttleInput = cache.EngineThrottleOverride or cache.InputThrottle
	if not cache.EngineThrottleCut then
		cache.EngineThrottle = math.clamp(cache.EngineThrottle + (math.max(throttleInput, engineIdler) - cache.EngineThrottle) * deltaTime * 10, 0, 1)
	else
		cache.EngineThrottle = math.clamp(cache.EngineThrottle - deltaTime * 10, 0, 1)
	end

	-- Torque
	const grossTorque = evaluateCurve(cache.EngineRPM, tune.TorqueCurve) * cache.EngineThrottle
	const frictionLosses = math.min(tune.InitialFrictionTorque + cache.EngineRPM * tune.FrictionLossCoefficient, cache.EngineVelocity * tune.EngineInertia / deltaTime)
	const netTorque = grossTorque - frictionLosses - cache.ClutchTorque

	-- Speed
	const angularAcceleration = netTorque / tune.EngineInertia
	cache.EngineVelocity = math.max(cache.EngineVelocity + angularAcceleration * deltaTime, 0)
	cache.EngineRPM = cache.EngineVelocity * (60 / Units.Tau)
end

return Engine
