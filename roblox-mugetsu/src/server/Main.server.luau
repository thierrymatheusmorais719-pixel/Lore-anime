--!strict
-- Ponto de entrada do servidor.
local ArenaBuilder = require(script.Parent:WaitForChild("ArenaBuilder"))
local TransformationService = require(script.Parent:WaitForChild("TransformationService"))
local AbilityService = require(script.Parent:WaitForChild("AbilityService"))

local ModelKit = require(script.Parent:WaitForChild("ModelKit"))

ArenaBuilder.build()
ModelKit.adoptImportedMesh() -- modelo 3D importado no Studio: é encontrado e guardado sozinho
TransformationService.init()
AbilityService.init()
print("[Mugetsu] servidor pronto")
