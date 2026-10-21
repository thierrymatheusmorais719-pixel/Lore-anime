-- Aplicação de impulsos com LinearVelocity temporário (vence o atrito do Humanoid).
-- Usado pelo servidor (NPCs) e pelo cliente (próprio personagem).
local Debris = game:GetService("Debris")

local Physics = {}

local function getAttachment(root: BasePart): Attachment
	local attachment = root:FindFirstChild("ImpulseAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "ImpulseAttachment"
		attachment.Parent = root
	end
	return attachment :: Attachment
end

-- Aplica `velocity` por `duration` segundos; substitui impulsos anteriores.
function Physics.impulse(root: BasePart, velocity: Vector3, duration: number)
	local existing = root:FindFirstChild("ImpulseVelocity")
	if existing then
		existing:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ImpulseVelocity"
	lv.Attachment0 = getAttachment(root)
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = velocity
	lv.Parent = root
	Debris:AddItem(lv, duration)
	root.AssemblyLinearVelocity = velocity
end

-- Anula a gravidade por `duration` (flutuar durante combos aéreos).
function Physics.hover(root: BasePart, duration: number)
	local existing = root:FindFirstChild("HoverForce")
	if existing then
		existing:Destroy()
	end
	local force = Instance.new("VectorForce")
	force.Name = "HoverForce"
	force.Attachment0 = getAttachment(root)
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * 0.92, 0)
	force.Parent = root
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, math.max(v.Y, 0) * 0.2, v.Z * 0.3)
	Debris:AddItem(force, duration)
end

function Physics.clear(root: BasePart)
	for _, name in { "ImpulseVelocity", "HoverForce" } do
		local existing = root:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

-- Direção horizontal normalizada (fallback para `fallback`).
function Physics.flat(v: Vector3, fallback: Vector3?): Vector3
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 1e-3 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

return Physics
