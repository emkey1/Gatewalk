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
    return 5 if abs(ny) / ln > 0.85 else 1

groups = {m: [] for m in range(6)}
for a, b, c in TR:
    groups[mat_of(a, b, c)].extend((a, b, c))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'wb') as f:
    f.write(struct.pack('<I', len(GV)))
    for v in GV:
        f.write(struct.pack('<3f', *v))
    for n in nrm:
        f.write(struct.pack('<3f', n[0], n[1], n[2]))
    f.write(struct.pack('<I', 6))
    for m in range(6):
        idx = groups[m]
        f.write(struct.pack('<I', len(idx)))
        if idx:
            f.write(struct.pack('<%dI' % len(idx), *idx))
print("wrote", os.path.normpath(OUT), "surfaces(tris):", {m: len(groups[m]) // 3 for m in groups})
