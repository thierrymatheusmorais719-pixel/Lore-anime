-- Formas de ataque no plano XZ. As mesmas formas geram o indicador visual (telegraph)
-- e o teste de acerto — garantindo que o aviso corresponde ao ataque executado.

local AttackShapes = {}

local function unit(dx: number, dz: number): (number, number)
	local m = math.sqrt(dx * dx + dz * dz)
	if m < 1e-6 then
		return 0, 1
	end
	return dx / m, dz / m
end
AttackShapes.unit = unit

-- pad: raio do alvo (studs) — conta como acerto se a borda do alvo encostar na área.
function AttackShapes.contains(shape, px: number, pz: number, pad: number?): boolean
	pad = pad or 0
	local t = shape.type
	if t == "circle" then
		local dx, dz = px - shape.x, pz - shape.z
		return dx * dx + dz * dz <= (shape.r + pad) ^ 2
	elseif t == "ring" then
		local d = math.sqrt((px - shape.x) ^ 2 + (pz - shape.z) ^ 2)
		return d >= shape.inner - pad and d <= shape.outer + pad
	elseif t == "cone" then
		local dx, dz = px - shape.x, pz - shape.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d > shape.length + pad then
			return false
		end
		if d < 1e-3 then
			return true
		end
		local cos = (dx * shape.dx + dz * shape.dz) / d
		local half = math.rad(shape.angle / 2)
		-- tolerância angular equivalente ao raio do alvo
		local angPad = math.atan(pad / math.max(d, 1))
		return math.acos(math.clamp(cos, -1, 1)) <= half + angPad
	elseif t == "rect" then
		local dx, dz = px - shape.x, pz - shape.z
		local along = dx * shape.dx + dz * shape.dz
		local side = -dx * shape.dz + dz * shape.dx
		return along >= -pad and along <= shape.length + pad and math.abs(side) <= shape.width / 2 + pad
	elseif t == "safezones" then
		local dArena = math.sqrt((px - shape.x) ^ 2 + (pz - shape.z) ^ 2)
		if dArena > shape.r + pad then
			return false
		end
		for _, s in ipairs(shape.safe) do
			-- precisa estar INTEIRO dentro da zona segura
			local d = math.sqrt((px - s.x) ^ 2 + (pz - s.z) ^ 2)
			if d + pad * 0.5 <= s.r then
				return false
			end
		end
		return true
	elseif t == "multi" then
		for _, p in ipairs(shape.parts) do
			if AttackShapes.contains(p, px, pz, pad) then
				return true
			end
		end
		return false
	end
	return false
end

-- Constrói as formas de um ataque de boss.
-- ctx = { bx, bz (boss), tx, tz (alvo principal), targets = { {x,z} }, ax, az, ar (arena), rng }
-- Retorna uma lista de formas (cada uma vira um indicador e um teste de acerto).
function AttackShapes.build(atk, ctx)
	local shape = atk.shape
	local list = {}
	if shape == "slam" then
		table.insert(list, { type = "circle", x = ctx.bx, z = ctx.bz, r = atk.radius })
	elseif shape == "target_circles" then
		for i, p in ipairs(ctx.targets) do
			if i > (atk.max or 6) then
				break
			end
			table.insert(list, { type = "circle", x = p.x, z = p.z, r = atk.radius })
		end
	elseif shape == "random_circles" then
		for _ = 1, atk.count do
			local ang = ctx.rng() * math.pi * 2
			local dist = math.sqrt(ctx.rng()) * (ctx.ar - atk.radius)
			table.insert(list, { type = "circle", x = ctx.ax + math.cos(ang) * dist, z = ctx.az + math.sin(ang) * dist, r = atk.radius })
		end
	elseif shape == "ring" then
		table.insert(list, { type = "ring", x = ctx.bx, z = ctx.bz, inner = atk.inner, outer = atk.outer })
	elseif shape == "cone" then
		local dx, dz = unit(ctx.tx - ctx.bx, ctx.tz - ctx.bz)
		table.insert(list, { type = "cone", x = ctx.bx, z = ctx.bz, dx = dx, dz = dz, angle = atk.angle, length = atk.length })
	elseif shape == "line" then
		local dx, dz = unit(ctx.tx - ctx.bx, ctx.tz - ctx.bz)
		table.insert(list, { type = "rect", x = ctx.bx, z = ctx.bz, dx = dx, dz = dz, length = atk.length, width = atk.width })
	elseif shape == "cross" then
		local dx, dz = unit(ctx.tx - ctx.bx, ctx.tz - ctx.bz)
		local half = atk.length / 2
		table.insert(list, { type = "rect", x = ctx.bx - dx * half, z = ctx.bz - dz * half, dx = dx, dz = dz, length = atk.length, width = atk.width })
		local px, pz = -dz, dx
		table.insert(list, { type = "rect", x = ctx.bx - px * half, z = ctx.bz - pz * half, dx = px, dz = pz, length = atk.length, width = atk.width })
	elseif shape == "safezones" then
		local safe = {}
		local base = ctx.rng() * math.pi * 2
		for i = 1, atk.count do
			local ang = base + (i - 1) * (math.pi * 2 / atk.count)
			local dist = ctx.ar * (0.35 + ctx.rng() * 0.3)
			table.insert(safe, { x = ctx.ax + math.cos(ang) * dist, z = ctx.az + math.sin(ang) * dist, r = atk.radius })
		end
		table.insert(list, { type = "safezones", x = ctx.ax, z = ctx.az, r = ctx.ar + 6, safe = safe })
	end
	return list
end

-- Algum dos pontos é atingido por alguma forma?
function AttackShapes.hitsAny(shapes, px: number, pz: number, pad: number?): boolean
	for _, s in ipairs(shapes) do
		if AttackShapes.contains(s, px, pz, pad) then
			return true
		end
	end
	return false
end

return AttackShapes
