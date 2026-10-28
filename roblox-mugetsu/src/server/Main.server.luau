--!strict
-- Ponto de entrada do servidor.
local ArenaBuilder = require(script.Parent:WaitForChild("ArenaBuilder"))
local TransformationService = require(script.Parent:WaitForChild("TransformationService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))

ArenaBuilder.build()
TransformationService.init()
AbilityService.init()
