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

	local rollbackWhitelist = { -- Values that need to support rollback ONLY
		SteerAmount = 0,

		GearboxCurrentGearIndex = ((table.find(tune.GearRatios, 0) or 0) + 1),
		GearboxShiftState = 0,
		GearboxTimer = 0,

		ClutchTorque = 0,

		EngineThrottleOverrideEnabled = false,
		EngineThrottleOverride = 0,

		EngineThrottleCutTimer = 0,
		EngineTimer = 0,
		EngineInstability = 1,
		EngineThrottle = tune.IdleThrottle * 0.5,
		EngineVelocity = tune.IdleRPM * (Units.Tau / 60), -- angular

		FlipActive = false,
		FlipTimer = 0,
	}

	for name, value in rollbackWhitelist :: { [string]: any } do
		if chassis:GetAttribute(name) == nil then
			chassis:SetAttribute(name, value) -- set default
		end
	end

	local connections = {}

	table.insert(connections, RunService:BindToSimulation(function(deltaTime: number)
		local cache = Simulation.Cache[vehicle].States

		const driver = seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent :: Model)
		if driver and (localPlayer == driver or isServer) then
			Simulation.StorePlayerInputs(driver, chassis)
		end

		local copy = {}
		for name in rollbackWhitelist :: { [string]: any } do
			local value = chassis:GetAttribute(name)
			cache[name] = value
			copy[name] = value
		end

		cache.InputThrottle = chassis:GetAttribute("Throttle") or 0
		cache.InputBrake = chassis:GetAttribute("Brake") or 0
		cache.InputSteer = chassis:GetAttribute("Steer") or 0

		cache.Velocity = chassis.AssemblyLinearVelocity
		cache.EngineRPM = cache.EngineVelocity * (60 / Units.Tau)

		Steering.FixedUpdate(cache, tune, deltaTime)

		Gearbox.FixedUpdate(cache, tune, deltaTime, Differential.GetUpstreamAngularVelocity(cache, tune))

		Clutch.FixedUpdate(cache, tune, deltaTime, Gearbox.GetUpstreamAngularVelocity(cache, Differential.GetUpstreamAngularVelocity(cache, tune)))

		Engine.FixedUpdate(cache, tune, deltaTime)

		Wheels.FixedUpdate(cache, tune, deltaTime, Differential.GetDownstreamTorque(cache, tune, Gearbox.GetDownstreamTorque(cache)))

		Flip.FixedUpdate(cache, tune, deltaTime)

		-- Tie in any of your own code here which DOES affects physics
		-- Lots of properties cannot be edited inside a BindToSimulation loop

		for name in rollbackWhitelist :: { [string]: any } do
			if copy[name] == cache[name] then
				continue
			end

			chassis:SetAttribute(name, cache[name])
		end

		if not isServer then
			chassis:SetAttribute("EngineRPM", cache.EngineRPM) -- dbeug
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
			const localPosition = chassis.CFrame:ToObjectSpace(entry.Wheel.CFrame).Position
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

	-- Tie in any of your own code here which DOESN'T affects physics
	-- E.g. one time code or prerender loops, ensure you clean up with the Stop function

	if not isServer then

	end

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
