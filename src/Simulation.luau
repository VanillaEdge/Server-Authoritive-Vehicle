--!strict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Units = require(script.Parent.Units)
local Steering = require(script.Steering)
local Engine = require(script.Engine)
local Clutch = require(script.Clutch)
local Gearbox = require(script.Gearbox)
local Differential = require(script.Differential)
local Wheels = require(script.Wheels)
local Flip = require(script.Flip)

const localPlayer = Players.LocalPlayer
const isServer = RunService:IsServer()

local Simulation = {}

Simulation.Cache = {} :: { [Model]: {
	CharacterParts: { [BasePart]: { [string]: boolean } },
	Connections: { RBXScriptConnection },
	States: { [string]: any }
} }

Simulation.StorePlayerInputs = function(player: Player, predictedInstance: BasePart)
	const inputsFolder = player:FindFirstChild("InputContexts") :: Folder ?
	if not inputsFolder then
		return
	end

	const inputContext = inputsFolder:FindFirstChild("CarContext") :: InputContext ?
	if not inputContext then
		return
	end

	for i, inputAction in inputContext:GetChildren() do
		if not inputAction:IsA("InputAction") then
			continue
		end

		const name = inputAction.Name:gsub("Action", "")
		predictedInstance:SetAttribute(name, inputAction:GetState())
	end
end

Simulation.Start = function(vehicle: Model, seat: Seat, tune: { [string]: any })
	if Simulation.Cache[vehicle] then
		Simulation.Stop(vehicle)
	end

	const character = seat.Occupant and seat.Occupant.Parent :: Model ?
	if not character then
		return
	end

	const wheelsFolder = vehicle:WaitForChild("Wheels", 5) :: Folder ?
	if not wheelsFolder then
		return
	end

	const chassis = vehicle:WaitForChild("Chassis", 5) :: Part ?
	if not chassis then
		return
	end

	const flipAlignOrientation = chassis:WaitForChild("FlipAlignOrientation") :: AlignOrientation ?
	if not flipAlignOrientation then
		return
	end

	local connections = {}

	table.insert(connections, RunService:BindToSimulation(function(deltaTime: number)
		const driver = seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent :: Model)
		if driver and (localPlayer == driver or isServer) then
			Simulation.StorePlayerInputs(driver, seat)
		end

		local cache = Simulation.Cache[vehicle].States
		cache.InputThrottle = seat:GetAttribute("Throttle") or 0
		cache.InputBrake = seat:GetAttribute("Brake") or 0
		cache.InputSteer = seat:GetAttribute("Steer") or 0

		cache.Velocity = seat.AssemblyLinearVelocity
		cache.SteerAmount = cache.SteerAmount or 0

		cache.EngineThrottleOverride = cache.EngineThrottleOverride or false
		cache.GearboxCurrentGearIndex = cache.GearboxCurrentGearIndex or ((table.find(tune.GearRatios, 0) or 0) + 1)
		cache.GearboxCurrentGearRatio = cache.GearboxCurrentGearRatio or tune.GearRatios[cache.GearboxCurrentGearIndex]
		cache.GearboxShifting = cache.GearboxShifting or false
		cache.DirectionShiftTimer = cache.DirectionShiftTimer or 0

		if cache.GearboxInGear == nil then
			cache.GearboxInGear = true
		end

		cache.ClutchTorque = cache.ClutchTorque or 0

		cache.EngineThrottleCut = cache.EngineThrottleCut or false
		cache.EngineTimer = cache.EngineTimer or 0
		cache.EngineInstability = cache.EngineInstability or 1
		cache.EngineThrottle = cache.EngineThrottle or (tune.IdleThrottle * 0.5)
		cache.EngineVelocity = cache.EngineVelocity or (tune.IdleRPM * (Units.Tau / 60)) -- angular
		cache.EngineRPM = cache.EngineRPM or tune.IdleRPM

		cache.FlipActive = cache.FlipActive or false
		cache.FlipTimer = cache.FlipTimer or 0

		Steering.FixedUpdate(cache, tune, deltaTime)

		Gearbox.FixedUpdate(cache, tune, deltaTime, Differential.GetUpstreamAngularVelocity(cache, tune))

		Clutch.FixedUpdate(cache, tune, deltaTime, Gearbox.GetUpstreamAngularVelocity(cache, Differential.GetUpstreamAngularVelocity(cache, tune)))

		Engine.FixedUpdate(cache, tune, deltaTime)

		Wheels.FixedUpdate(cache, tune, deltaTime, Differential.GetDownstreamTorque(cache, tune, Gearbox.GetDownstreamTorque(cache)))

		if isServer then
			Flip.FixedUpdate(cache, tune, deltaTime)
		end

	end, Enum.StepFrequency.Hz60))

	local characterParts = {}

	for i, descendant in character:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		characterParts[descendant] = {
			CanCollide = descendant.CanCollide,
			Massless = descendant.Massless
		}

		descendant.CanCollide = false
		descendant.Massless = true
	end

	local wheels = {}

	for i, wheelModel in wheelsFolder:GetChildren() do
		local entry = {}

		entry.Model = wheelModel
		entry.Wheel = wheelModel:WaitForChild("Wheel", 5) :: Part ?
		entry.Mount = wheelModel:WaitForChild("Mount", 5) :: Part ?

		if entry.Wheel then
			const localPosition = seat.CFrame:ToObjectSpace(entry.Wheel.CFrame).Position
			entry.IsFrontWheel = localPosition.Z < 0
			entry.IsLeftWheel = localPosition.X < 0
		end

		entry.IsSteerable = wheelModel:GetAttribute("Steerable") or false
		entry.SteeringAttachment = entry.Mount and entry.Mount:WaitForChild("Attachment", 5) :: Attachment ?

		entry.IsPowered = wheelModel:GetAttribute("Powered") or false
		entry.Torque = wheelModel:WaitForChild("Torque", 5) :: Torque ?
		entry.Brake = wheelModel:WaitForChild("AngularVelocity", 5) :: AngularVelocity ?

		wheels[entry.Wheel] = entry
	end

	Simulation.Cache[vehicle] = {
		CharacterParts = characterParts,
		Connections = connections,
		States = {
			FlipAlignOrientation = flipAlignOrientation,
			Chassis = chassis,
			Wheels = wheels
		}
	}
end

Simulation.Stop = function(vehicle: Model)
	if not Simulation.Cache[vehicle] then
		return
	end

	for i, connection in Simulation.Cache[vehicle].Connections do
		connection:Disconnect()
	end

	for i, entry in Simulation.Cache[vehicle].States.Wheels do
		entry.Torque.Torque = Vector3.new(0, 0, 0)
		entry.Brake.MaxTorque = 1000
	end

	for descendant, states in Simulation.Cache[vehicle].CharacterParts do
		descendant.CanCollide = states.CanCollide
		descendant.Massless = states.Massless
	end

	Simulation.Cache[vehicle].States.FlipAlignOrientation.Enabled = false

	Simulation.Cache[vehicle] = nil
end

return Simulation
