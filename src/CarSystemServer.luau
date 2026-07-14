--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Simulation = require(script.Parent.Simulation)
local Units = require(script.Parent.Units)

local carContext = script.Parent.CarContext

local connections = {} :: { [Model]: { RBXScriptConnection } }

const tagName = "Car"

local function initialiseAssemblies(vehicle: Model, seat: Seat, tune: { [string]: any })
	const wheelsFolder = vehicle:WaitForChild("Wheels", 5) :: Folder ?
	if not wheelsFolder then
		return
	end

	local children = wheelsFolder:GetChildren()
	local targetWeight = tune.TotalWeight - (tune.WheelWeight * #children)

	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	local mountCount = 0

	for i, wheelModel in children do
		local wheelPart = wheelModel:WaitForChild("Wheel", 5) :: Part ?
		if wheelPart then
			local volume = math.pi * (wheelPart.Size.X / 2) ^ 2 * wheelPart.Size.Y
			local density = (tune.WheelWeight * (1 / Units.RmuToKilograms)) / volume

			local props = wheelPart.CurrentPhysicalProperties
			wheelPart.CustomPhysicalProperties = PhysicalProperties.new(
				density,
				props.Friction,
				props.Elasticity,
				props.FrictionWeight,
				props.ElasticityWeight
			)
		end

		local mount = wheelModel:WaitForChild("Mount", 5) :: Part ?
		if mount then
			local position = seat.CFrame:PointToObjectSpace(mount.Position)
			minimum = Vector3.new(
				math.min(minimum.X, position.X),
				math.min(minimum.Y, position.Y),
				math.min(minimum.Z, position.Z)
			)

			maximum = Vector3.new(
				math.max(maximum.X, position.X),
				math.max(maximum.Y, position.Y),
				math.max(maximum.Z, position.Z)
			)

			mountCount += 1

			local weldConstraint = Instance.new("WeldConstraint")
			weldConstraint.Part0 = mount
			weldConstraint.Part1 = seat
			weldConstraint.Parent = mount
		end

		local weldedFolder = wheelModel:WaitForChild("Welded", 5) :: Folder ?
		if weldedFolder and wheelPart then
			for i, descendant in weldedFolder:GetDescendants() do
				if not descendant:IsA("BasePart") then
					continue
				end

				local weldConstraint = Instance.new("WeldConstraint")
				weldConstraint.Part0 = descendant
				weldConstraint.Part1 = wheelPart
				weldConstraint.Parent = descendant

				descendant.CanCollide = false
				descendant.Massless = true
			end
		end
	end

	local chassisSize = Vector3.one
	local chassisCFrame = seat.CFrame

	if mountCount > 0 then
		local localCentre = (minimum + maximum) / 2
		local bounds = maximum - minimum

		local forward = seat.CFrame:VectorToObjectSpace(seat.CFrame.LookVector)
		local offset = (0.5 - tune.WeightDistribution) * bounds.Z

		localCentre += forward * offset

		chassisSize = Vector3.new(math.max(bounds.X, 0.001), 1, math.max(bounds.Z, 0.001))
		chassisCFrame = seat.CFrame * CFrame.new(localCentre) * CFrame.new(0, tune.WeightHeightOffset, 0)
	end

	local part = Instance.new("Part")
	part.Name = "Chassis"
	part.Size = chassisSize
	part.CFrame = chassisCFrame
	part.Transparency = tune.WeightBrickVisible and 0.5 or 1
	part.CanCollide = false
	part.Anchored = true

	local volume = part.Size.X * part.Size.Y * part.Size.Z
	local density = (targetWeight * (1 / Units.RmuToKilograms)) / volume
	part.CustomPhysicalProperties = PhysicalProperties.new(density, 0, 0)

	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = part
	weldConstraint.Part1 = seat
	weldConstraint.Parent = part

	part.Parent = vehicle

	local attachment = Instance.new("Attachment")
	attachment.Name = "FlipAttachment"
	attachment.Axis = part.CFrame.UpVector
	attachment.Parent = part

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "FlipAlignOrientation"
	alignOrientation.Enabled = false
	alignOrientation.RigidityEnabled = true
	alignOrientation.AlignType = Enum.AlignType.PrimaryAxisParallel
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.PrimaryAxis = Vector3.yAxis
	alignOrientation.Parent = part

	local weldedFolder = vehicle:WaitForChild("Welded", 5) :: Folder ?
	if weldedFolder then
		for i, descendant in weldedFolder:GetDescendants() do
			if not descendant:IsA("BasePart") then
				continue
			end

			local weldConstraint = Instance.new("WeldConstraint")
			weldConstraint.Part0 = descendant
			weldConstraint.Part1 = seat
			weldConstraint.Parent = descendant

			descendant.Massless = true
		end
	end

	for i, descendant in vehicle:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		if not descendant.Massless then
			local attachment = Instance.new("Attachment")
			attachment.Name = "GravityAttachment"
			attachment.Parent = part

			local vectorForce = Instance.new("VectorForce")
			vectorForce.Name = "GravityAttachment"
			vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
			vectorForce.ApplyAtCenterOfMass  = true
			vectorForce.Attachment0 = attachment
			vectorForce.Force = Vector3.new(0, descendant.Mass * (workspace.Gravity - Units.EarthGravityStuds) or 0, 0)
			vectorForce.Parent = descendant
		end

		descendant.Anchored = false
	end

	vehicle:SetAttribute("AssembliesLoaded", true)
end

local function onOccupantChanged(vehicle: Model, seat: Seat, tune: { [string]: any })
	if seat.Occupant then
		-- seat:SetNetworkOwner(Players:GetPlayerFromCharacter(seat.Occupant.Parent :: Model))
		Simulation.Start(vehicle, seat, tune)
	else
		Simulation.Stop(vehicle)
	end
end

local function onVehicleAdded(vehicle: Instance)
	if not vehicle:IsA("Model") then
		return
	end

	if connections[vehicle] then
		return
	end

	local seat = vehicle:WaitForChild("Driver", 5) :: Seat ?
	if not seat then
		return
	end

	local module = vehicle:WaitForChild("Tune", 5) :: ModuleScript ?
	if not module then
		return
	end

	local tune = require(module) :: { [string]: any }

	if not vehicle:GetAttribute("AssembliesLoaded") then
		initialiseAssemblies(vehicle, seat, tune)
	end

	connections[vehicle] = {
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			onOccupantChanged(vehicle, seat, tune)
		end)
	}

	onOccupantChanged(vehicle, seat, tune)
end

local function onVehicleRemoved(vehicle: Instance)
	if not vehicle:IsA("Model") then
		return
	end

	if not connections[vehicle] then
		return
	end

	for i, connection in connections[vehicle] do
		connection:Disconnect()
	end

	connections[vehicle] = nil

	Simulation.Stop(vehicle)
end

local function onPlayerAdded(player: Player)
	local inputsFolder = player:WaitForChild("InputContexts", 3) :: Folder ?
	if not inputsFolder then
		inputsFolder = Instance.new("Folder")
		inputsFolder.Name = "InputContexts"
		inputsFolder.Parent = player
	end

	local clone = carContext:Clone()
	clone.Parent = inputsFolder
end

CollectionService:GetInstanceAddedSignal(tagName):Connect(onVehicleAdded)
CollectionService:GetInstanceRemovedSignal(tagName):Connect(onVehicleRemoved)

Players.PlayerAdded:Connect(onPlayerAdded)

for i, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

for i, v in CollectionService:GetTagged(tagName) do
	if not v:IsDescendantOf(workspace) then
		return
	end

	onVehicleAdded(v)
end
