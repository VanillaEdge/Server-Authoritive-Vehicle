--!strict

local Units = require(script.Parent.Parent.Units)

local Differential = {}

Differential.GetDownstreamTorque = function(cache: { [string]: any }, tune: { [string]: any }, torque: number): number
	local poweredWheelCount = 0

	for wheel, entry in cache.Wheels do
		if entry.IsPowered then
			poweredWheelCount += 1
		end
	end

	return torque * tune.FinalDriveRatio / poweredWheelCount
end

Differential.GetUpstreamAngularVelocity = function(cache: { [string]: any }, tune: { [string]: any }): number
	local totalAngularVelocity = 0
	local poweredWheelCount = 0

	for wheel, entry in cache.Wheels do
		if entry.IsPowered then
			totalAngularVelocity += wheel.AssemblyAngularVelocity:Dot(wheel.CFrame.RightVector) -- correct
			poweredWheelCount += 1
		end
	end

	return totalAngularVelocity / poweredWheelCount * tune.FinalDriveRatio
end

return Differential
