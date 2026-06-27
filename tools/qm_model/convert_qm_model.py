#!/usr/bin/env python3
"""Translate the user's QM.3mf scale model into assets/qm_model.bin for LinerFactory.

The game's visible ocean-liner shell is the actual 1:1 RMS Queen Mary, translated 100% from
this 3D model (rather than approximated procedurally). Re-run this only if the source model
changes:

    python3 tools/qm_model/convert_qm_model.py [path/to/QM.3mf]   # default: ~/Downloads/QM.3mf

It reads object 3 (the ship; objects 1 & 2 are stand-pins), maps the flat-bottom WATERLINE model
into game coordinates (x=beam, y=up with the waterline at wl, z=length with the bow at +z; scaled
to LOA 310.7 m), computes per-vertex normals, and segments triangles into 5 material surfaces by
region (hull / superstructure / funnel-barrel / funnel-cap / boot-topping). Output binary layout
(little-endian): u32 nv; nv*3 f32 verts; nv*3 f32 normals; u32 nsurf; per surf {u32 nidx; nidx*u32}.
"""
import os, re, sys, math, struct, zipfile

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/Downloads/QM.3mf')
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'qm_model.bin')
WL = -1.7            # game water-plane y (must match the factory)
LOA = 310.7          # Queen Mary length overall (m)
FUNNEL_Z = [60.0, 15.0, -30.0]   # game z of the 3 funnels, used to paint the barrels red

# Pull the largest <object>'s mesh out of the 3mf (a zip of XML .model parts).
def load_ship(path):
    with zipfile.ZipFile(path) as z:
        best = None
        for name in z.namelist():
            if name.endswith('.model'):
                txt = z.read(name).decode('utf-8', 'replace')
                for blk in re.findall(r'<object\s+id="\d+".*?</object>', txt, flags=re.S):
                    nv = blk.count('<vertex ')
                    if best is None or nv > best[0]:
                        best = (nv, blk)
    return best[1]

blk = load_ship(SRC)
MV = [(float(a), float(b), float(c)) for a, b, c in
      re.findall(r'<vertex x="([-\d.eE]+)" y="([-\d.eE]+)" z="([-\d.eE]+)"', blk)]
TR = [(int(a), int(b), int(c)) for a, b, c in
      re.findall(r'<triangle v1="(\d+)" v2="(\d+)" v3="(\d+)"', blk)]
ys = [v[1] for v in MV]
zmin = min(v[2] for v in MV)
S = LOA / (max(ys) - min(ys))
print(f"verts={len(MV)} tris={len(TR)} scale={S:.5f} zmin={zmin:.5f}")

# model (x=half-beam, y=length[bow=-y], z=height[bottom=zmin]) -> game (x, y-up, z-length[bow=+z])
GV = [(mx * S, (mz - zmin) * S + WL, -my * S) for mx, my, mz in MV]

# --- Orient every triangle to face OUTWARD via a ray-parity (point-in-solid) test. ---
# The source print mesh has MIXED winding. Backface culling then either draws internal faces as white
# "fin" clutter (cull off) OR punches see-through holes in the hull (cull on). A simple radial test
# can't orient the CONCAVE deck-edge overhangs (the outer face and its underside share a position with
# opposite winding). So instead: for each face take a point just off its front (centroid + normal*eps)
# and cast a ray along +x — an ODD number of triangle crossings means that point is INSIDE the solid,
# so +N points inward and the winding is flipped. This is topology-agnostic and orients every face out
# of the solid, letting the factory backface-cull cleanly (solid hull, no fins, no see-through).
# Accelerated by a 2-D (y,z) bucket grid, since the cast ray runs along x (only same-(y,z) tris matter).
EPS = 0.03
CELL = 1.5
_ys = [v[1] for v in GV]; _zs = [v[2] for v in GV]
_YMIN = min(_ys); _ZMIN = min(_zs)
_NY = int((max(_ys) - _YMIN) / CELL) + 2
_NZ = int((max(_zs) - _ZMIN) / CELL) + 2
def _cell(y, z):
    iy = int((y - _YMIN) / CELL); iz = int((z - _ZMIN) / CELL)
    iy = 0 if iy < 0 else (_NY - 1 if iy >= _NY else iy)
    iz = 0 if iz < 0 else (_NZ - 1 if iz >= _NZ else iz)
    return iy, iz
_grid = [[] for _ in range(_NY * _NZ)]
_tv = []                                   # per-tri: (A, B, C, xmax, ylo, yhi, zlo, zhi)
for _ti, (_a, _b, _c) in enumerate(TR):
    _A = GV[_a]; _B = GV[_b]; _C = GV[_c]
    _ylo = min(_A[1], _B[1], _C[1]); _yhi = max(_A[1], _B[1], _C[1])
    _zlo = min(_A[2], _B[2], _C[2]); _zhi = max(_A[2], _B[2], _C[2])
    _tv.append((_A, _B, _C, max(_A[0], _B[0], _C[0]), _ylo, _yhi, _zlo, _zhi))
    _iy0, _iz0 = _cell(_ylo, _zlo); _iy1, _iz1 = _cell(_yhi, _zhi)
    for _iy in range(_iy0, _iy1 + 1):
        _row = _iy * _NZ
        for _iz in range(_iz0, _iz1 + 1):
            _grid[_row + _iz].append(_ti)
def _inside(px, py, pz):
    iy, iz = _cell(py, pz)
    cnt = 0
    for ti in _grid[iy * _NZ + iz]:
        A, B, C, xmax, ylo, yhi, zlo, zhi = _tv[ti]
        if xmax <= px or py < ylo or py > yhi or pz < zlo or pz > zhi:
            continue
        ay = A[1]; az = A[2]
        v0y = B[1] - ay; v0z = B[2] - az
        v1y = C[1] - ay; v1z = C[2] - az
        v2y = py - ay; v2z = pz - az
        d00 = v0y * v0y + v0z * v0z
        d01 = v0y * v1y + v0z * v1z
        d11 = v1y * v1y + v1z * v1z
        den = d00 * d11 - d01 * d01
        if den == 0.0:
            continue
        d20 = v2y * v0y + v2z * v0z
        d21 = v2y * v1y + v2z * v1z
        v = (d11 * d20 - d01 * d21) / den
        w = (d00 * d21 - d01 * d20) / den
        if v < 0.0 or w < 0.0 or v + w > 1.0:
            continue
        u = 1.0 - v - w
        if u * A[0] + v * B[0] + w * C[0] > px:
            cnt += 1
    return (cnt & 1) == 1
_flipped = 0
_TR = []
_JY = 1.7e-4; _JZ = 1.1e-4                  # tiny oblique ray offset to avoid grazing shared edges
for a, b, c in TR:
    A = GV[a]; B = GV[b]; C = GV[c]
    nx = (B[1] - A[1]) * (C[2] - A[2]) - (B[2] - A[2]) * (C[1] - A[1])
    ny = (B[2] - A[2]) * (C[0] - A[0]) - (B[0] - A[0]) * (C[2] - A[2])
    nz = (B[0] - A[0]) * (C[1] - A[1]) - (B[1] - A[1]) * (C[0] - A[0])
    ln = (nx * nx + ny * ny + nz * nz) ** 0.5 or 1.0
    px = (A[0] + B[0] + C[0]) / 3.0 + nx / ln * EPS
    py = (A[1] + B[1] + C[1]) / 3.0 + ny / ln * EPS + _JY
    pz = (A[2] + B[2] + C[2]) / 3.0 + nz / ln * EPS + _JZ
    if _inside(px, py, pz):                 # +N side is interior -> flip so the normal points OUT
        _TR.append((a, c, b)); _flipped += 1
    else:
        _TR.append((a, b, c))
TR = _TR
print(f"winding: flipped {_flipped}/{len(TR)} triangles to face outward (ray-parity)")

nrm = [[0.0, 0.0, 0.0] for _ in GV]
for a, b, c in TR:
    ax, ay, az = GV[a]; bx, by, bz = GV[b]; cx, cy, cz = GV[c]
    ux, uy, uz = bx - ax, by - ay, bz - az
    vx, vy, vz = cx - ax, cy - ay, cz - az
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    for i in (a, b, c):
        nrm[i][0] += nx; nrm[i][1] += ny; nrm[i][2] += nz
for n in nrm:
    l = math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]) or 1.0
    n[0] /= l; n[1] /= l; n[2] /= l

def near_funnel(gz, gx):
    return any(abs(gz - cz) < 8.5 and abs(gx) < 9.0 for cz in FUNNEL_Z)

def mat_of(a, b, c):
    ax, ay, az = GV[a]; bx, by, bz = GV[b]; cx, cy, cz = GV[c]
    gx = (ax + bx + cx) / 3.0; gy = (ay + by + cy) / 3.0; gz = (az + bz + cz) / 3.0
    h = gy - WL
    if h >= 28.0 and near_funnel(gz, gx):
        return 3 if h >= 41.5 else 2
    if h < 0.85:
        return 4
    if h < 15.8:
        return 0
    # Superstructure: the near-HORIZONTAL faces are the walkable decks -> teak; the rest (walls) -> white.
    # |normal.y| (winding is mixed, so use abs): deck tops show outside, undersides are hidden inside.
    nx = (by - ay) * (cz - az) - (bz - az) * (cy - ay)
    ny = (bz - az) * (cx - ax) - (bx - ax) * (cz - az)
    nz = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    ln = (nx * nx + ny * ny + nz * nz) ** 0.5 or 1.0
    nyl = abs(ny) / ln
    # Window bands -> transparent GLASS (near-vertical side faces, so the spaces behind see the sea):
    #  - the enclosed PROMENADE band (~20-24 m), full length;
    #  - the MAIN-deck STATEROOM band (~16-18 m) along the deckhouse z -78..92 only (not the open
    #    forecastle/after-deck bulwarks, which sit at the same height but outside the cabin run).
    if abs(gx) > 12.0 and nyl < 0.35 and (
            (20.0 <= h <= 24.5) or (16.3 <= h <= 18.3 and -78.0 <= gz <= 92.0)):
        return 6
    return 5 if nyl > 0.85 else 1

groups = {m: [] for m in range(7)}
for a, b, c in TR:
    groups[mat_of(a, b, c)].extend((a, b, c))

# Drop the bow/stern open-deck "fin" clutter: the model's forecastle/poop bulwark caps + mooring-bitt
# tops are low-poly and read as a white sawtooth + spiky crowns. They're FRONT-facing (not cullable) and
# fused to the deck by height, but they classify as SUPERSTRUCTURE (white) — and the OPEN weather decks
# forward of the forecastle break / abaft the poop break carry no real superstructure. So removing every
# super-classified face out there cleanly strips the clutter while the teak deck + hull stay. A clean
# deck fit-out (bulwark, mooring fittings, railings) is added procedurally in the factory.
_g1 = groups[1]; _new1 = []; _drop = 0
for _k in range(0, len(_g1), 3):
    a, b, c = _g1[_k], _g1[_k + 1], _g1[_k + 2]
    _cz = (GV[a][2] + GV[b][2] + GV[c][2]) / 3.0
    if _cz > 114.0 or _cz < -108.0:
        _drop += 1
        continue
    _new1.extend((a, b, c))
groups[1] = _new1
print(f"bow/stern: dropped {_drop} open-deck super (bulwark/fitting) faces")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'wb') as f:
    f.write(struct.pack('<I', len(GV)))
    for v in GV:
        f.write(struct.pack('<3f', *v))
    for n in nrm:
        f.write(struct.pack('<3f', n[0], n[1], n[2]))
    f.write(struct.pack('<I', 7))
    for m in range(7):
        idx = groups[m]
        f.write(struct.pack('<I', len(idx)))
        if idx:
            f.write(struct.pack('<%dI' % len(idx), *idx))
print("wrote", os.path.normpath(OUT), "surfaces(tris):", {m: len(groups[m]) // 3 for m in groups})
