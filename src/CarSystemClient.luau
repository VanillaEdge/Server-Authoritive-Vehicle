--!strict

local CollectionService = game:GetService("CollectionService")

local Simulation = require(script.Parent.Simulation)
local Units = require(script.Parent.Units)

local connections = {} :: { [Model]: { RBXScriptConnection } }

const tagName = "Car"

local function onOccupantChanged(vehicle: Model, seat: Seat, tune: { [string]: any })
	if seat.Occupant then
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

	local module = vehicle:FindFirstChild("Tune") :: ModuleScript ?
	if not module then
		return
	end

	local tune = require(module) :: { [string]: any }

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

CollectionService:GetInstanceAddedSignal(tagName):Connect(onVehicleAdded)
CollectionService:GetInstanceRemovedSignal(tagName):Connect(onVehicleRemoved)

for i, v in CollectionService:GetTagged(tagName) do
	if not v:IsDescendantOf(workspace) then
		continue
	end

	onVehicleAdded(v)
end
