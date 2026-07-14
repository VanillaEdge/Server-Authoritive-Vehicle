--!strict

local Units = require(script.Parent.Parent.Units)

local Clutch = {}

Clutch.FixedUpdate = function(cache: { [string]: any }, tune: { [string]: any }, deltaTime: number, transmissionVelocity: number)
	const clutchEngagement = cache.GearboxInGear and math.clamp((cache.EngineRPM - tune.AutoClutchStartRPM) / (tune.AutoClutchFullRPM - tune.AutoClutchStartRPM), 0, 1) or 0
	const clutchSlip = cache.GearboxInGear and cache.EngineVelocity - transmissionVelocity or 0

	const torqueCapacity = tune.ClutchTorqueCapacity * clutchEngagement
	const targetTorque = math.clamp(clutchSlip * tune.ClutchStiffness * clutchEngagement, -torqueCapacity, torqueCapacity)

	const alpha = 1 - math.exp(-tune.ClutchDamping * deltaTime)
	cache.ClutchTorque += (targetTorque - cache.ClutchTorque) * alpha
	cache.ClutchTorque = math.clamp(cache.ClutchTorque, -torqueCapacity, torqueCapacity)
end

return Clutch
