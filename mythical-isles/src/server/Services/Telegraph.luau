-- Indicadores de ataque (telegraphs) criados no SERVIDOR a partir das mesmas formas
-- (Logic/AttackShapes) usadas no teste de acerto. O cliente só anima o preenchimento
-- (atributos Start/Duration) — a geometria é a verdade do servidor.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Make = require(Shared.Util.Make)

local Telegraph = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local DANGER = Color3.fromRGB(255, 70, 60)
local SAFE = Color3.fromRGB(90, 255, 140)

local function flat(name, size: Vector3, cf: CFrame, color: Color3, transparency: number, parent: Instance, fill: boolean?)
	local p = Make("Part", {
		Name = name, Size = size, CFrame = cf, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Material = Enum.Material.Neon, Color = color, Transparency = transparency, CastShadow = false, Parent = parent,
	})
	if fill then
		p:SetAttribute("TelegraphFill", true)
	end
	return p
end

local function disc(name, x, y, z, r, color, transparency, parent, fill)
	return flat(name, V(0.2, r * 2, r * 2), CF(x, y, z) * ANG(0, 0, math.rad(90)), color, transparency, parent, fill)
end

-- shapes: lista de AttackShapes; y: altura do chão; duration: segundos até o impacto
function Telegraph.show(shapes, y: number, duration: number, label: string?, color: Color3?)
	local model = Make("Model", { Name = "Telegraph", Parent = workspace:FindFirstChild("Telegraphs") })
	model:SetAttribute("Start", workspace:GetServerTimeNow())
	model:SetAttribute("Duration", duration)
	model:SetAttribute("Label", label or "")
	local c = color or DANGER
	local yy = y + 0.25
	for _, s in ipairs(shapes) do
		if s.type == "circle" then
			local edge = disc("Edge", s.x, yy, s.z, s.r, c, 0.55, model)
			edge.Shape = Enum.PartType.Cylinder
			local fill = disc("Fill", s.x, yy + 0.05, s.z, s.r, c, 0.35, model, true)
			fill.Shape = Enum.PartType.Cylinder
		elseif s.type == "ring" then
			local n = 28
			local mid = (s.inner + s.outer) / 2
			local width = s.outer - s.inner
			for i = 1, n do
				local a = (i - 0.5) / n * math.pi * 2
				local seg = 2 * math.pi * mid / n + 0.6
				local cf = CF(s.x + math.cos(a) * mid, yy, s.z + math.sin(a) * mid) * ANG(0, -a, 0)
				flat("Edge", V(width, 0.2, seg), cf, c, 0.55, model)
				flat("Fill", V(width, 0.25, seg), cf, c, 0.35, model, true)
			end
		elseif s.type == "rect" then
			local cf = CF(V(s.x, yy, s.z) + V(s.dx, 0, s.dz) * (s.length / 2), V(s.x, yy, s.z) + V(s.dx, 0, s.dz) * s.length)
			flat("Edge", V(s.width, 0.2, s.length), cf, c, 0.55, model)
			flat("Fill", V(s.width, 0.25, s.length), cf, c, 0.35, model, true)
		elseif s.type == "cone" then
			local slices = 9
			local half = math.rad(s.angle / 2)
			local base = math.atan2(s.dz, s.dx)
			for i = 1, slices do
				local a = base - half + (i - 0.5) / slices * (2 * half)
				local dir = V(math.cos(a), 0, math.sin(a))
				local width = 2 * s.length * math.tan(half / slices) + 0.4
				local cf = CF(V(s.x, yy, s.z) + dir * (s.length / 2), V(s.x, yy, s.z) + dir * s.length)
				-- fatias retangulares em leque (cobrem o cone; ligeiramente maiores perto da origem)
				flat("Fill", V(width, 0.2, s.length), cf, c, 0.45, model, true)
			end
		elseif s.type == "safezones" then
			local danger = disc("Danger", s.x, yy, s.z, s.r, c, 0.6, model, true)
			danger.Shape = Enum.PartType.Cylinder
			for _, z in ipairs(s.safe) do
				local safe = disc("Safe", z.x, yy + 0.15, z.z, z.r, SAFE, 0.25, model)
				safe.Shape = Enum.PartType.Cylinder
				Make("PointLight", { Color = SAFE, Range = z.r * 1.5, Brightness = 2, Parent = safe })
			end
		end
	end
	return model
end

-- Indicador pequeno para inimigos comuns (golpes em área / investidas).
function Telegraph.simple(shapes, y: number, duration: number)
	return Telegraph.show(shapes, y, duration, nil, Color3.fromRGB(255, 140, 60))
end

function Telegraph.clear(model: Instance?)
	if model then
		model:Destroy()
	end
end

return Telegraph
