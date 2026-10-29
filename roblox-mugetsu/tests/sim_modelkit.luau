-- Roda o ModelKit REAL sobre um personagem simulado para verificar a sequência que apagava a skin:
-- kit do Ichigo (esconde roupa/acessórios, repinta) -> resetBody -> "ApplyDescription" (novos itens)
-- -> refresh na forma com skin. A skin precisa continuar visível.

-- Mocks ------------------------------------------------------------------------------------------
local function mt_typeof(tag)
	return function(self) return tag end
end
local C3 = {}
C3.__index = C3
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r, G = g, B = b, __t = "Color3" }, C3) end }
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
local V3 = {}
V3.__index = V3
Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z, __t = "Vector3" }, V3) end }
Vector3.zero = Vector3.new(0, 0, 0)
V3.__mul = function(a, k) return Vector3.new(a.X * k, a.Y * k, a.Z * k) end
local CFm = {}
CFm.__index = CFm
local function cfnew() return setmetatable({ __t = "CFrame", Position = Vector3.zero }, CFm) end
CFm.__mul = function(a, b) return cfnew() end
CFm.Inverse = function(self) return cfnew() end
CFrame = { new = function() return cfnew() end, Angles = function() return cfnew() end, identity = cfnew() }
function typeof(v)
	if type(v) == "table" and rawget(v, "__t") then return rawget(v, "__t") end
	if type(v) == "table" and rawget(v, "__inst") then return "Instance" end
	return type(v)
end
local function enumProxy(path)
	return setmetatable({ _p = path, Name = path }, { __index = function(t, k) return enumProxy(path .. "." .. k) end })
end
Enum = enumProxy("Enum")

local CLASS_IS = {
	Part = { BasePart = true }, WedgePart = { BasePart = true }, MeshPart = { BasePart = true },
}
local function Inst(class, name)
	local i = { __inst = true, ClassName = class, Name = name or class, _children = {}, _attrs = {} }
	local mt = {}
	mt.__index = function(t, k)
		if k == "Parent" then return rawget(t, "_parent") end
		-- como no Roblox: instancia.NomeDoFilho
		for _, c in ipairs(rawget(t, "_children")) do if rawget(c, "Name") == k then return c end end
		return nil
	end
	mt.__newindex = function(t, k, v)
		if k == "Parent" then
			local old = rawget(t, "_parent")
			if old then
				for idx, c in ipairs(old._children) do if c == t then table.remove(old._children, idx) break end end
			end
			rawset(t, "_parent", v)
			if v then table.insert(v._children, t) end
		else
			rawset(t, k, v)
		end
	end
	setmetatable(i, mt)
	function i:IsA(c) return self.ClassName == c or (CLASS_IS[self.ClassName] or {})[c] == true end
	function i:SetAttribute(k, v) self._attrs[k] = v end
	function i:GetAttribute(k) return self._attrs[k] end
	function i:GetChildren() local o = {} for _, c in ipairs(self._children) do table.insert(o, c) end return o end
	function i:GetDescendants()
		local o = {}
		local function rec(n) for _, c in ipairs(n._children) do table.insert(o, c); rec(c) end end
		rec(self)
		return o
	end
	function i:FindFirstChild(n, recursive)
		for _, c in ipairs(self._children) do if c.Name == n then return c end end
		if recursive then for _, c in ipairs(self._children) do local r = c:FindFirstChild(n, true) if r then return r end end end
		return nil
	end
	function i:FindFirstChildOfClass(cn) for _, c in ipairs(self._children) do if c.ClassName == cn then return c end end return nil end
	function i:Destroy() self.Parent = nil; self.Destroyed = true end
	return i
end
Instance = { new = function(c) return Inst(c) end }
workspace = Inst("Workspace")
local services = {
	CollectionService = { AddTag = function() end },
	ServerStorage = Inst("ServerStorage"),
	TweenService = { Create = function() return { Play = function() end } end },
	ReplicatedStorage = Inst("ReplicatedStorage"),
}
game = { GetService = function(_, n) return services[n] end }
task = { spawn = function(f, ...) f(...) end, delay = function() end, defer = function(f, ...) f(...) end }

-- módulos compartilhados como filhos de ReplicatedStorage.Mugetsu
local Shared = Inst("Folder", "Mugetsu")
Shared.Parent = services.ReplicatedStorage
local MODS = {}
local function addMod(name, value)
	local m = Inst("ModuleScript", name)
	m.Parent = Shared
	MODS[m] = value
end
function Shared:WaitForChild(n) return self:FindFirstChild(n) end
local realRequire = require
function require(m)
	if MODS[m] ~= nil then
		if type(MODS[m]) == "function" then MODS[m] = MODS[m]() end
		return MODS[m]
	end
	return realRequire(m)
end
services.ReplicatedStorage.WaitForChild = function(self, n) return self:FindFirstChild(n) end

addMod("AssetManifest", { CustomKitPath = { "MugetsuAssets", "MugetsuKit" } })
addMod("KitDataObj", KITS.obj)
addMod("KitDataProcedural", KITS.procedural)
addMod("MeshKitManifest", MESH)
addMod("Config", function() return __CONFIG() end)

-- personagem R15 com roupa, acessório e rosto
local LIMBS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
	"RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }
local function newChar()
	local c = Inst("Model", "Char")
	local hum = Inst("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.Parent = c
	local hrp = Inst("Part", "HumanoidRootPart")
	hrp.Parent = c
	for _, n in ipairs(LIMBS) do
		local p = Inst("Part", n)
		p.Color = Color3.fromRGB(100, 100, 100)
		p.Transparency = 0
		p.Parent = c
	end
	local face = Inst("Decal", "face")
	face.Transparency = 0
	face.Parent = c:FindFirstChild("Head")
	local shirt = Inst("Shirt", "Shirt")
	shirt.Parent = c
	local pants = Inst("Pants", "Pants")
	pants.Parent = c
	local acc = Inst("Accessory", "OldHair")
	local h = Inst("Part", "Handle")
	h.Transparency = 0
	h.Parent = acc
	acc.Parent = c
	return c
end

return function(test, eq)
	local ModelKit = __MODELKIT()

	test("modelkit real: kit do Ichigo esconde roupa/acessório e resetBody devolve tudo", function()
		local c = newChar()
		ModelKit.build(c)
		eq(c:FindFirstChild("Shirt"), nil, "camisa guardada durante o kit do Ichigo")
		eq(c:FindFirstChild("OldHair").Handle.Transparency, 1, "acessório oculto")
		assert(not (c:FindFirstChild("Head").Color == Color3.fromRGB(100, 100, 100)), "cabeça repintada pelo kit")
		ModelKit.resetBody(c)
		assert(c:FindFirstChild("Shirt"), "camisa de volta")
		assert(c:FindFirstChild("Pants"), "calça de volta")
		eq(c:FindFirstChild("OldHair").Handle.Transparency, 0, "acessório visível de novo")
		assert(c:FindFirstChild("Head").Color == Color3.fromRGB(100, 100, 100), "cor original de volta")
		eq(c:FindFirstChild("Head"):FindFirstChild("face").Transparency, 0, "rosto de volta")
	end)

	test("modelkit real: skin aplicada NÃO é apagada pela remontagem do kit (bug relatado)", function()
		local c = newChar()
		ModelKit.build(c) -- Ichigo (kit): esconde/repinta
		-- o TransformationService faz isto no flash branco:
		ModelKit.resetBody(c)
		-- "ApplyDescription" da skin do Mugetsu: troca roupa e acessórios
		c:FindFirstChild("Shirt"):Destroy()
		local newShirt = Inst("Shirt", "Shirt")
		newShirt.Parent = c
		local mask = Inst("Accessory", "MugetsuMask")
		local mh = Inst("Part", "Handle")
		mh.Transparency = 0
		mh.Parent = mask
		mask.Parent = c
		c:FindFirstChild("Head").Color = Color3.fromRGB(230, 200, 170)
		-- MorphSwap já aconteceu (forma Mugetsu) e a remontagem roda depois da skin
		ModelKit.setForm(c, "Mugetsu", 0)
		ModelKit.refresh(c)
		eq(ModelKit.currentForm(c), "Mugetsu")
		assert(c:FindFirstChild("Shirt") == newShirt, "camisa da skin continua no personagem")
		eq(mask.Handle.Transparency, 0, "máscara da skin visível")
		assert(c:FindFirstChild("Head").Color == Color3.fromRGB(230, 200, 170), "cor da skin preservada")
		for _, n in ipairs(LIMBS) do eq(c:FindFirstChild(n).Transparency, 0, n .. " visível") end
		local kit = c:FindFirstChild("MugetsuKits"):FindFirstChild("Mugetsu")
		assert(kit:FindFirstChild("Blade"), "espada do jogo presente na forma com skin")
		local onlyHand = true
		for _, p in ipairs(kit:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "Blade" and p.Name ~= "SwordHandle" and not p.Name:match("^P%d") and not p.Name:match("^S%d") then onlyHand = false end
		end
		assert(onlyHand, "forma com skin só recebe peças da espada")
	end)

	test("modelkit real: restaurar a aparência e voltar ao Ichigo reaplica o kit do Ichigo", function()
		local c = newChar()
		ModelKit.build(c)
		ModelKit.resetBody(c)
		ModelKit.setForm(c, "Mugetsu", 0)
		ModelKit.refresh(c)
		-- fim da forma: volta ao Ichigo e restaura a aparência
		ModelKit.setForm(c, "Ichigo", 0)
		ModelKit.resetBody(c)
		ModelKit.refresh(c)
		eq(ModelKit.currentForm(c), "Ichigo")
		eq(c:FindFirstChild("Shirt"), nil, "kit do Ichigo ativo de novo")
	end)
end
