// Executa os testes de lógica pura em um VM Luau real (WASM), fora do Roblox.
//   npm i luau-web   (em qualquer pasta)   e   node tests/run.mjs [caminho/para/node_modules/luau-web]
// Também compila (verificação de sintaxe) TODOS os .luau de src/ — só compila, não executa.
import fs from "node:fs";
import path from "node:path";
import url from "node:url";

const here = path.dirname(url.fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const lib = process.argv[2] ?? path.join(process.cwd(), "node_modules/luau-web");
const { LuauState } = await import(url.pathToFileURL(path.join(lib, "src/index.js")).href);

const state = await LuauState.createAsync({});
let failures = 0;

// 1) Compilação de todos os arquivos
function walk(dir) {
	return fs.readdirSync(dir, { withFileTypes: true }).flatMap((d) =>
		d.isDirectory() ? walk(path.join(dir, d.name)) : [path.join(dir, d.name)]);
}
let compiled = 0;
for (const f of walk(path.join(root, "src")).filter((f) => f.endsWith(".luau"))) {
	const res = state.loadstring(fs.readFileSync(f, "utf8"), path.relative(root, f), false);
	if (typeof res === "string") {
		console.log(`FAIL compile ${path.relative(root, f)}: ${res}`);
		failures++;
	} else compiled++;
}
console.log(`compilação: ${compiled} arquivos OK`);

// 2) Testes unitários dos módulos puros
const pure = ["Timeline", "StateMachine", "AbilityMath", "PoseDriver"];
let src = fs.readFileSync(path.join(here, "mocks.luau"), "utf8");
src += "\nlocal __src = {}\nlocal __cache = {}\n";
for (const m of pure) {
	const code = fs.readFileSync(path.join(root, "src/shared", m + ".luau"), "utf8").replace(/^--!strict\n/, "");
	src += `__src["${m}"] = function()\n${code}\nend\n`;
}
src += `local function require(name) if __cache[name] == nil then __cache[name] = __src[name]() end return __cache[name] end\n`;
// kits (JSON -> tabela Luau) para validar os dados que o ModelKit consome
const toLua = (v) => Array.isArray(v) ? "{" + v.map(toLua).join(",") + "}" : v !== null && typeof v === "object" ? "{" + Object.entries(v).map(([k, x]) => `[${JSON.stringify(k)}]=${toLua(x)}`).join(",") + "}" : JSON.stringify(v);
src += `local KITS = { obj = ${toLua(JSON.parse(fs.readFileSync(path.join(root, "src/shared/KitDataObj.json"), "utf8")))}, procedural = ${toLua(JSON.parse(fs.readFileSync(path.join(root, "src/shared/KitDataProcedural.json"), "utf8")))} }\n`;
src += `local MESH = ${toLua(JSON.parse(fs.readFileSync(path.join(root, "src/shared/MeshKitManifest.json"), "utf8")))}\n`;
src += fs.readFileSync(path.join(here, "unit.luau"), "utf8");
const fn = state.loadstring(src, "unit", false);
if (typeof fn === "string") {
	console.log("FAIL compile unit:", fn);
	process.exit(1);
}
try {
	const result = await fn();
	console.log(String(result ?? ""));
	if (!/ALL PASSED/.test(String(result))) failures++;
} catch (e) {
	console.log("FAIL runtime:", e?.message ?? e);
	failures++;
}

// 3) Simulação do servidor (serviços reais sobre um Roblox simulado)
const srv = ["Config", "Timeline", "StateMachine", "AbilityMath"].map((m) => [m, "shared"]).concat(
	[["RateLimiter", "server"], ["TransformationService", "server"], ["AbilityService", "server"]]);
let sim = "local __SIM\ndo\n" + fs.readFileSync(path.join(here, "sim_env.luau"), "utf8").replace(/^return SIM\s*$/m, "__SIM = SIM") + "\nend\n";
sim += "local os = __SIM.os\nlocal __src = {}\nlocal __cache = {}\nlocal require\n";
for (const [m, dir] of srv) {
	const code = fs.readFileSync(path.join(root, "src", dir, m + ".luau"), "utf8").replace(/^--!strict\n/, "");
	sim += `__src["${m}"] = function()\n${code}\nend\n`;
}
sim += `require = function(p) local name = type(p) == "table" and p.name or p if __cache[name] == nil then __cache[name] = __src[name]() end return __cache[name] end\n`;
sim += fs.readFileSync(path.join(here, "sim_server.luau"), "utf8");
const simFn = state.loadstring(sim, "sim_server", false);
if (typeof simFn === "string") {
	console.log("FAIL compile sim:", simFn);
	process.exit(1);
}
try {
	const r2 = await simFn();
	console.log(String(r2 ?? ""));
	if (!/ALL PASSED/.test(String(r2))) failures++;
} catch (e) {
	console.log("FAIL runtime sim:", e?.message ?? e);
	failures++;
}
process.exit(failures ? 1 : 0);
