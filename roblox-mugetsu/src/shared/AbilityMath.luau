--!strict
-- Regras puras da habilidade: cooldown, sanitização de direção e teste de acerto em caixa orientada.
-- Usadas pelo servidor (autoridade) e pelo cliente (apenas para o telegraph).

local AbilityMath = {}

-- Cooldown: guarda o instante em que a habilidade volta a ficar disponível.
function AbilityMath.isReady(readyAt: number?, now: number): boolean
	return readyAt == nil or now >= readyAt
end

function AbilityMath.remaining(readyAt: number?, now: number): number
	if readyAt == nil then
		return 0
	end
	return math.max(0, readyAt - now)
end

-- Aceita apenas direção horizontal finita. Retorna nil se inválida.
function AbilityMath.sanitizeDirection(dir: any): Vector3?
	if typeof(dir) ~= "Vector3" then
		return nil
	end
	local d = dir :: Vector3
	if d.X ~= d.X or d.Y ~= d.Y or d.Z ~= d.Z then -- NaN
		return nil
	end
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude < 1e-3 or flat.Magnitude == math.huge then
		return nil
	end
	return flat.Unit
end

-- Se o cliente enviar uma mira muito diferente da direção do personagem, usa a do personagem.
function AbilityMath.clampAim(sent: Vector3, facing: Vector3, tolerance: number): Vector3
	if sent:Dot(facing) >= 1 - tolerance * 5 then -- tolerance 0.2 => dot >= 0 (<= 90°)
		return sent
	end
	return facing
end

-- Ponto dentro da caixa orientada (origem, direção, comprimento, largura, altura).
function AbilityMath.insideBeam(
	point: Vector3,
	origin: Vector3,
	dir: Vector3,
	length: number,
	width: number,
	height: number
): boolean
	local rel = point - origin
	local along = rel:Dot(dir)
	if along < 0 or along > length then
		return false
	end
	local side = Vector3.new(-dir.Z, 0, dir.X)
	if math.abs(rel:Dot(side)) > width / 2 then
		return false
	end
	return math.abs(rel.Y) <= height
end

return AbilityMath
