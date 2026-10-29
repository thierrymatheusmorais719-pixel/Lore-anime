#!/usr/bin/env python3
"""Gera assets/models/guerreiro_cutscene.obj (+ .mtl): busto de guerreiro
com cabelo longo e espada serrilhada. Eixo Y para cima, base em y=0, unidades ~ metros."""
import numpy as np, os

rng = np.random.default_rng(7)
V, F, groups = [], [], []

def add(name, verts, faces):
    off = len(V)
    V.extend(verts.tolist())
    F_local = [[i + off for i in f] for f in faces]
    groups.append((name, F_local))

def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v

def ellipsoid(c, r, lat=14, lon=20):
    v, f = [], []
    for i in range(lat + 1):
        t = np.pi * i / lat
        for j in range(lon):
            p = 2 * np.pi * j / lon
            v.append([c[0] + r[0]*np.sin(t)*np.cos(p), c[1] + r[1]*np.cos(t), c[2] + r[2]*np.sin(t)*np.sin(p)])
    for i in range(lat):
        for j in range(lon):
            a = i*lon + j; b = i*lon + (j+1) % lon
            f.append([a, b, b+lon]); f.append([a, b+lon, a+lon])
    return np.array(v), f

def tube(path, w, h=None, seg=8, jag=0.0):
    """Tubo ao longo de 'path' com secao elipse (w por ponto, h opcional)."""
    path = np.asarray(path, float); n = len(path)
    def fit(x):
        x = np.atleast_1d(np.asarray(x, float))
        return np.full(n, x[0]) if len(x) == 1 else np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(x)), x)
    w = fit(w); h = w if h is None else fit(h)
    v, f = [], []
    t0 = norm(path[1] - path[0]); ref = np.array([0, 0, 1.0]) if abs(t0[2]) < .9 else np.array([1.0, 0, 0])
    nrm = norm(np.cross(t0, ref))
    for i in range(n):
        t = norm(path[min(i+1, n-1)] - path[max(i-1, 0)])
        nrm = norm(nrm - t*np.dot(nrm, t)); bi = np.cross(t, nrm)
        for k in range(seg):
            a = 2*np.pi*k/seg
            j = 1 + jag*rng.uniform(-1, 1) if jag else 1
            v.append(path[i] + (np.cos(a)*nrm*w[i] + np.sin(a)*bi*h[i]) * j)
    for i in range(n-1):
        for k in range(seg):
            a = i*seg + k; b = i*seg + (k+1) % seg
            f.append([a, b, b+seg]); f.append([a, b+seg, a+seg])
    for end, idx in ((0, 0), (n-1, n-1)):
        v.append(path[end]); c = len(v)-1
        for k in range(seg):
            a = idx*seg + k; b = idx*seg + (k+1) % seg
            f.append([c, b, a] if end == 0 else [c, a, b])
    return np.array(v), f

def bez(p0, p1, p2, n=12):
    t = np.linspace(0, 1, n)[:, None]
    return (1-t)**2*np.array(p0) + 2*(1-t)*t*np.array(p1) + t**2*np.array(p2)

# --- base / saia rasgada (revolucao com barra irregular) ---
def skirt():
    rings, lon = 10, 40; v, f = [], []
    for i in range(rings + 1):
        t = i / rings
        for j in range(lon):
            a = 2*np.pi*j/lon
            hem = 0.18*abs(np.sin(a*7)) + 0.10*abs(np.sin(a*13 + 1)) + 0.05*rng.random()
            y = 1.02 - t*(0.92 - hem*t)
            r = (0.30 + 0.38*t**1.3) * (1 + 0.06*np.sin(a*9)*t)
            v.append([r*np.cos(a)*1.05, y, r*np.sin(a)*0.9])
    for i in range(rings):
        for j in range(lon):
            a = i*lon+j; b = i*lon+(j+1) % lon
            f.append([a, b, b+lon]); f.append([a, b+lon, a+lon])
    v.append([0, 0.10, 0]); c = len(v)-1
    for j in range(lon):
        f.append([c, rings*lon+j, rings*lon+(j+1) % lon])
    return np.array(v), f

add("saia", *skirt())
# pedestal circular
ped = ellipsoid([0, 0.04, 0], [0.78, 0.07, 0.70], 6, 36); add("base", *ped)
# faixa (anel)
ang = np.linspace(0, 2*np.pi, 25)
add("faixa", *tube([[0.31*np.cos(a), 1.04, 0.27*np.sin(a)] for a in ang], 0.045, 0.06, 8))
# torso, peitoral, abdomen
add("torso", *ellipsoid([0, 1.27, 0], [0.34, 0.30, 0.22]))
add("peitoral_e", *ellipsoid([-0.15, 1.42, 0.14], [0.17, 0.12, 0.10], 10, 14))
add("peitoral_d", *ellipsoid([0.15, 1.42, 0.14], [0.17, 0.12, 0.10], 10, 14))
for i, yy in enumerate((1.28, 1.17, 1.07)):
    add(f"abdomen_e{i}", *ellipsoid([-0.075, yy, 0.17], [0.07, 0.05, 0.05], 8, 10))
    add(f"abdomen_d{i}", *ellipsoid([0.075, yy, 0.17], [0.07, 0.05, 0.05], 8, 10))
# ombros, pescoco, cabeca
add("ombro_e", *ellipsoid([-0.40, 1.50, 0.0], [0.15, 0.13, 0.14]))
add("ombro_d", *ellipsoid([0.40, 1.50, 0.0], [0.15, 0.13, 0.14]))
add("pescoco", *tube([[0,1.50,0],[0,1.70,0.02]], 0.085, seg=12))
add("cabeca", *ellipsoid([0, 1.84, 0.03], [0.14, 0.18, 0.15], 14, 20))
# braco direito (do personagem = +x), caido, dobrado
add("braco_d", *tube(bez([0.42,1.48,0],[0.55,1.25,0.06],[0.42,1.10,0.20]), [0.11,0.10,0.085,0.075], seg=10))
add("antebraco_d", *tube(bez([0.42,1.10,0.20],[0.40,1.05,0.28],[0.30,1.12,0.34]), [0.075,0.07,0.06], seg=10))
# braco esquerdo (-x), erguido segurando a espada
add("braco_e", *tube(bez([-0.42,1.48,0],[-0.62,1.60,0.10],[-0.60,1.80,0.20]), [0.11,0.10,0.085,0.07], seg=10))
add("mao_e", *ellipsoid([-0.60, 1.82, 0.20], [0.07, 0.08, 0.07], 8, 10))

# --- cabelo: franja + mechas longas fluindo para +x / tras ---
hair_top = lambda a, r: np.array([r*np.cos(a)*0.95, 1.84 + 0.17*np.sqrt(max(0, 1-r*r/0.0225))*0 + 0.13, 0.03 + r*np.sin(a)*1.0])
add("cabelo_volume", *ellipsoid([0.0, 1.90, -0.01], [0.17, 0.17, 0.18], 10, 18))
for i in range(70):
    a = rng.uniform(0, 2*np.pi); r = rng.uniform(0.05, 0.16)
    start = np.array([r*np.cos(a), 1.99 - 0.35*(r/0.16)**2 + rng.uniform(-.02, .02), 0.0 + r*np.sin(a)])
    side = 1 if np.cos(a) + rng.uniform(-.6, .6) > 0 else -0.35
    L = rng.uniform(0.7, 1.35)
    end = start + np.array([side*L*rng.uniform(.5, .95), -L*rng.uniform(.35, .75), -L*rng.uniform(.1, .4)])
    mid = start + np.array([side*0.25*L, 0.04, -0.12*L + 0.2*np.sin(a)])
    p = bez(start, mid, end, 9)
    add(f"mecha{i}", *tube(p, np.linspace(0.028, 0.0, 9), seg=4, jag=0.15))
for i in range(14):  # franja cobrindo o rosto
    x = -0.14 + 0.28*i/13
    s = np.array([x, 1.98, 0.14]); e = np.array([x*1.5 + rng.uniform(-.03, .03), 1.68 + rng.uniform(0, .1), 0.20])
    add(f"franja{i}", *tube(bez(s, [x*1.2, 1.90, 0.24], e, 6), np.linspace(0.03, 0.0, 6), seg=4))

# --- espada serrilhada: lamina curva em arco, cabo na mao esquerda ---
blade = np.vstack([bez([-0.95, 0.10, 0.10], [-0.75, 0.8, 0.12], [-0.60, 1.82, 0.20], 14),
                   bez([-0.60, 1.82, 0.20], [-0.45, 2.55, 0.18], [0.25, 2.55, 0.08], 12)[1:],
                   bez([0.25, 2.55, 0.08], [0.60, 2.55, 0.0], [0.80, 2.05, -0.05], 8)[1:]])
n = len(blade); u = np.linspace(0, 1, n)
width = 0.07 + 0.05*np.sin(np.pi*np.clip(u*1.25, 0, 1)) * (1 - u*0.5)
width[-1] = 0.005
add("espada", *tube(blade, width, width*0.35, seg=8, jag=0.22))
# espinhos / galhos da lamina
for k in range(18):
    i = int(rng.integers(3, n-3)); p = blade[i]; t = norm(blade[i+1] - blade[i-1])
    side = np.cross(t, [0, 0, 1]) * rng.choice([-1, 1])
    L = rng.uniform(0.12, 0.32)
    tip = p + norm(side*0.8 + t*0.5)*L
    add(f"espinho{k}", *tube([p, (p+tip)/2 + [0, 0, .02], tip], [0.03, 0.018, 0.0], seg=4))

# --- exporta ---
V = np.array(V)
fn = {}
Fall = [f for _, fs in groups for f in fs]
N = np.zeros_like(V)
for a, b, c in Fall:
    nn = np.cross(V[b]-V[a], V[c]-V[a]); N[a] += nn; N[b] += nn; N[c] += nn
N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models")
os.makedirs(root, exist_ok=True)
with open(os.path.join(root, "guerreiro_cutscene.mtl"), "w") as m:
    m.write("newmtl pedra\nKa 0.8 0.8 0.8\nKd 0.78 0.78 0.80\nKs 0.05 0.05 0.05\nNs 10\nd 1.0\nillum 2\n")
with open(os.path.join(root, "guerreiro_cutscene.obj"), "w") as o:
    o.write("# Guerreiro (busto) - gerado por tools/gen_guerreiro_obj.py\n# Y para cima, base em y=0\nmtllib guerreiro_cutscene.mtl\nusemtl pedra\n")
    for x, y, z in V: o.write(f"v {x:.4f} {y:.4f} {z:.4f}\n")
    for x, y, z in N: o.write(f"vn {x:.4f} {y:.4f} {z:.4f}\n")
    for name, fs in groups:
        o.write(f"g {name}\ns 1\n")
        for a, b, c in fs: o.write(f"f {a+1}//{a+1} {b+1}//{b+1} {c+1}//{c+1}\n")
print(len(V), "vertices,", len(Fall), "faces")
