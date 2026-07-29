--!strict

local Units = require(script.Parent.Parent.Units)

local Steering = {}

const forwardOrientation = Vector3.new(0, 0, 90)

local function SampleCurve(curve: { { number } }, x: number): number
	for i = 2, #curve do
		const a = curve[i - 1]
		const b = curve[i]

		if x <= b[1] then
			const t = (x - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * math.clamp(t, 0, 1)
		end
	end

	return curve[#curve][2]
end

local function MoveToward(current: number, target: number, step: number): number
	if current < target then
		return math.min(current + step, target)
	elseif current > target then
		return math.max(current - step, target)
	end

	return target
end

local function StepForTime(dt: number, time: number, range: number ?): number
	const span = range or 1

	if time <= 0 then
		return span
	end

	return span * dt / time
end

Steering.FixedUpdate = function(cache: { [string]: any }, tune: { [string]: any }, deltaTime: number)
	local input = cache.InputSteer
	if math.abs(input) > tune.SteerDeadzone then
		input = math.sign(input) * SampleCurve(tune.SteerInputCurve, math.abs(input))
	else
		input = 0
	end

	local target = math.clamp(input, -1, 1)
	if math.abs(target) < 0.001 then
		target = 0
	end

	const returning = math.abs(target) < math.abs(cache.SteerAmount) or target * cache.SteerAmount < 0
	const steerTime = returning and tune.ReturnTime or tune.SteerTime
	cache.SteerAmount = MoveToward(cache.SteerAmount, target, StepForTime(deltaTime, steerTime))

	const speed = cache.Velocity.Magnitude * Units.StudToMetres * 3.6
	const angleScale = SampleCurve(tune.MaxAngleCurve, speed)

	for wheel, data in cache.Wheels :: { [BasePart]: { [string]: any } } do
		if data.IsSteerable then
			const maxAngle = data.IsFrontWheel and tune.MaxSteerAngle or tune.RMaxSteerAngle
			const direction = data.IsFrontWheel and 1 or -1
			const steerAngle = cache.SteerAmount * maxAngle * angleScale * direction
			data.SteeringAttachment.Orientation = forwardOrientation + Vector3.new(0, -steerAngle, 0)
		else
			data.SteeringAttachment.Orientation = forwardOrientation
		end
	end
end

return Steering
