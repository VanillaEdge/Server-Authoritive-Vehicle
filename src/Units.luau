--!strict

local Units = {}

-- https://create.roblox.com/docs/physics/units

Units.StudToMetres = 0.28
Units.RmuToKilograms = 21.952

Units.EarthGravityStuds = 9.8 / Units.StudToMetres -- 35 studs/s²

Units.RowtonsToNewtons = Units.RmuToKilograms * Units.StudToMetres
Units.NewtonsToRowtons = 1 / Units.RowtonsToNewtons

Units.RowtonStudsToNewtonMetres = Units.RowtonsToNewtons * Units.StudToMetres
Units.NewtonMetresToRowtonStuds = 1 / Units.RowtonStudsToNewtonMetres

Units.Tau = math.pi * 2

return Units
