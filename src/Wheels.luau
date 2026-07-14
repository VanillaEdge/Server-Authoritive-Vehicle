--!strict

local Units = require(script.Parent.Parent.Units)

local Wheels = {}

Wheels.FixedUpdate = function(cache: { [string]: any }, tune: { [string]: any }, deltaTime: number, torque: number)
	const driveTorque = torque * Units.NewtonMetresToRowtonStuds
	const brakeTorque = tune.BrakeTorque * cache.InputBrake * Units.NewtonMetresToRowtonStuds

	for i, entry in cache.Wheels do
		if entry.IsPowered then
			entry.Torque.Torque = Vector3.new(driveTorque, 0, 0)
		end

		entry.Brake.MaxTorque = brakeTorque
	end
end

return Wheels
