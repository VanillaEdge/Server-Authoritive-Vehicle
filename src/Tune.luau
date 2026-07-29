--!strict

local Tune = {}

-- Weight (under real world gravity)
Tune.TotalWeight = 1100
Tune.WheelWeight = 25

Tune.WeightDistribution = 0.5	-- Length offset from wheel center (0-1)
Tune.WeightHeightOffset = -1 	-- Height offset in studs from wheel mounts
Tune.WeightBrickVisible = false

-- Max Steering Angles
Tune.MaxSteerAngle = 32		-- Maximum front wheel steering angle in degrees at standstill, before speed scaling
Tune.RMaxSteerAngle = 10	-- Maximum rear wheel steering angle in degrees at standstill, before speed scaling

-- Steering Response
Tune.SteerTime = 0.75		-- Time in seconds to reach the maximum steering angle from center
Tune.ReturnTime = 0.45		-- Time in seconds to reset from maximum steering angle to center
Tune.SteerDeadzone = 0.05	-- Minimum raw input threshold to filter out stick drift

-- Steering Input
Tune.SteerInputCurve = {	-- [ Input Amount (0-1) : Input Amount Applied (0-1) ]
	{0.00, 0.00},
	{0.25, 0.06},
	{0.65, 0.40},
	{1.00, 1.00},
}

-- Speed Scaling
Tune.MaxAngleCurve = {		-- [ Speed (KMH) : Steering Angle Multiplier (0-1) ]
	{0,   1.00},
	{50,  0.50},
	{100, 0.24},
	{160, 0.12},
	{300, 0.05},
}

-- Engine
Tune.IdleRPM = 900
Tune.IdleThrottle = 0.54
Tune.ThrottleStability = 0.85

Tune.RedlineRPM = 7200
Tune.ThrottleCutOffDuration = 0.075

Tune.TorqueCurve = {
	{0,    60}, -- We dont have a starter input so we cheat here by adding torque
	{500,  80},
	{900,  145},
	{2000, 205},
	{3500, 265},
	{5000, 295},
	{6200, 275},
	{7200, 225},
	{7600, 0},
}

Tune.InitialFrictionTorque = 30
Tune.FrictionLossCoefficient = 0.010
Tune.EngineInertia = 0.275

-- Clutch
Tune.ClutchTorqueCapacity = 600
Tune.ClutchStiffness = 25
Tune.ClutchDamping = 30

Tune.AutoClutchStartRPM = Tune.IdleRPM + 150
Tune.AutoClutchFullRPM = Tune.IdleRPM + 750

-- Gearbox
Tune.GearRatios = { -3, 0, 3, 2, 1.5, 1 }
Tune.ShiftDuration = 0.3

Tune.AutoShiftDownRPM = 2500
Tune.AutoShiftUpRPM = 6800

Tune.RevMatchThrottle = 1
Tune.RevMatchToleranceRPM = 120

-- Differential
Tune.FinalDriveRatio = 3.5

-- Brakes
Tune.BrakeTorque = 1200 -- per wheel

return Tune
