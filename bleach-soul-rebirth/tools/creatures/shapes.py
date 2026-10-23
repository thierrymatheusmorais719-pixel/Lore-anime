"""Ajudantes de geometria para os corpos de criatura: peças entre dois pontos (chifres, cordões,
penas curvas), anéis de peças em volta de um centro, e conversão de matriz para os ângulos
[rx, ry, rz] que o jogo usa (CFrame.Angles = Rx * Ry * Rz, em graus)."""
import math


def _norm(v):
    n = math.sqrt(sum(x * x for x in v)) or 1
    return [x / n for x in v]


def _cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def euler_from_axes(x, y, z):
    """Colunas x, y, z (vetores unitários) → [rx, ry, rz] em graus para R = Rx*Ry*Rz."""
    r = [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]
    ry = math.asin(max(-1.0, min(1.0, r[0][2])))
    if abs(r[0][2]) < 0.9999:
        rx = math.atan2(-r[1][2], r[2][2])
        rz = math.atan2(-r[0][1], r[0][0])
    else:
        rx = math.atan2(r[2][1], r[1][1])
        rz = 0.0
    return [round(math.degrees(rx), 3), round(math.degrees(ry), 3), round(math.degrees(rz), 3)]


def frame_between(a, b, up=(0, 1, 0)):
    """Centro e ângulos de uma peça cujo eixo Z vai de `a` até `b`; comprimento = distância."""
    d = [b[i] - a[i] for i in range(3)]
    length = math.sqrt(sum(x * x for x in d))
    z = _norm(d)
    u = list(up)
    if abs(sum(z[i] * u[i] for i in range(3))) > 0.98:
        u = [1, 0, 0]
    x = _norm(_cross(u, z))
    y = _cross(z, x)
    center = [(a[i] + b[i]) / 2 for i in range(3)]
    return center, euler_from_axes(x, y, z), length


def seg(D, part, a, b, thickness, role, color=None, mesh="Sphere", material=None, shape="Block", up=(0, 1, 0)):
    """Peça (decoração) esticada entre os pontos a → b no espaço da peça-mãe."""
    center, ang, length = frame_between(a, b, up)
    size = [thickness, thickness, length + thickness * 0.4] if not isinstance(thickness, list) else [thickness[0], thickness[1], length]
    return D(part, size, center + ang, role, shape, material, mesh, color)


def curve(D, part, points, thickness, role, color=None, taper=1.0, material=None):
    """Cadeia de segmentos por uma lista de pontos (chifre, cordão); afina até `taper`× no fim."""
    out = []
    n = len(points) - 1
    for i in range(n):
        k = 1 - (1 - taper) * (i / max(1, n - 1))
        out.append(seg(D, part, points[i], points[i + 1], thickness * k, role, color, material=material))
    return out


def arc_points(start, end, bulge, count):
    """Pontos de `start` a `end` curvados por `bulge` (vetor somado no meio, em parábola)."""
    pts = []
    for i in range(count + 1):
        t = i / count
        w = 4 * t * (1 - t)
        pts.append([start[j] + (end[j] - start[j]) * t + bulge[j] * w for j in range(3)])
    return pts
