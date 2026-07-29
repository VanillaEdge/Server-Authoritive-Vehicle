--!strict

local Units = require(script.Parent.Parent.Units)

local Engine = {}

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
	local engineIdler = math.map(math.clamp(cache.EngineRPM, tune.IdleRPM - 200, tune.IdleRPM + 200), tune.IdleRPM - 200, tune.IdleRPM + 200, tune.IdleThrottle, 0)
	cache.EngineTimer += deltaTime

	if cache.EngineTimer >= 0.1 then
		cache.EngineTimer = 0
		cache.EngineInstability = math.random() * (1 - tune.ThrottleStability) + tune.ThrottleStability
	end

	engineIdler *= cache.EngineInstability

	-- Rev limiter
	cache.EngineThrottleCutTimer = math.max(cache.EngineThrottleCutTimer - deltaTime, 0)
	if cache.EngineThrottleCutTimer <= 0 and cache.EngineRPM >= tune.RedlineRPM then
		cache.EngineThrottleCutTimer = tune.ThrottleCutOffDuration
	end

	-- Throttle
	const throttleInput = cache.EngineThrottleOverrideEnabled and cache.EngineThrottleOverride or cache.InputThrottle
	if cache.EngineThrottleCutTimer <= 0 then
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
