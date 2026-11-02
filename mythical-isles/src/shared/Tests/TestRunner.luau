-- Mini framework de testes. Funciona no Studio (Server/TestBoot) e no CLI (tools/run_tests.py).

local TestRunner = {}

-- PRNG determinístico (LCG 48 bits dividido em duas partes para caber em double sem perda).
function TestRunner.rng(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function fmt(v)
	if type(v) == "number" then
		return string.format("%.6g", v)
	end
	return tostring(v)
end

function TestRunner.run(specs, out)
	out = out or print
	local passed, failed = 0, 0
	local failures = {}
	for _, spec in ipairs(specs) do
		local current = ""
		local t = {}
		t.rng = TestRunner.rng
		function t.ok(cond, msg)
			if not cond then
				error("esperado verdadeiro: " .. tostring(msg or ""), 2)
			end
		end
		function t.eq(a, b, msg)
			if a ~= b then
				error(string.format("esperado %s, obtido %s %s", fmt(b), fmt(a), msg or ""), 2)
			end
		end
		function t.near(a, b, tol, msg)
			if math.abs(a - b) > tol then
				error(string.format("esperado %s ± %s, obtido %s %s", fmt(b), fmt(tol), fmt(a), msg or ""), 2)
			end
		end
		function t.test(name, fn)
			current = name
			local ok, err = pcall(fn)
			if ok then
				passed += 1
			else
				failed += 1
				table.insert(failures, string.format("[%s] %s: %s", spec.name, current, tostring(err)))
			end
		end
		local ok, err = pcall(spec.mod, t)
		if not ok then
			failed += 1
			table.insert(failures, string.format("[%s] erro ao carregar: %s", spec.name, tostring(err)))
		end
	end
	for _, f in ipairs(failures) do
		out("FALHOU " .. f)
	end
	out(string.format("Testes: %d passaram, %d falharam", passed, failed))
	return failed == 0, passed, failed
end

return TestRunner
