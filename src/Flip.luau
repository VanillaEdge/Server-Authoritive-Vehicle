--!strict

local Units = require(script.Parent.Parent.Units)

local Flip = {}

Flip.FixedUpdate = function(cache: { [string]: any }, tune: { [string]: any }, deltaTime: number)
	if not cache.FlipActive and cache.Chassis.CFrame.UpVector.Y > 0.1 then
		cache.FlipTimer = 0
		return
	end

	cache.FlipTimer += deltaTime

	if cache.FlipTimer < (cache.FlipActive and 0.5 or 3) then
		return
	end

	cache.FlipActive = not cache.FlipActive
	cache.FlipAlignOrientation.Enabled = cache.FlipActive
	cache.FlipTimer = 0
end

return Flip
