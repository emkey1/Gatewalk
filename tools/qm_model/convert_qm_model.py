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

# --- Make the triangle winding consistent: every face normal points OUTWARD from the hull. ---
# The source print mesh has MIXED winding (some regions wound inward). Backface culling then either
# draws internal faces as white "fin" clutter (cull off) OR punches see-through holes in the hull
# where the outer faces happen to face inward (cull on). A ship's cross-section is ~star-convex about
# its vertical centreline, so "outward" at a face = away from the centreline point at that face's
# length/height. Flip any triangle whose geometric normal opposes that. End-cap (bow/stern) faces,
# whose normals are mostly fore-aft (small horizontal component), are left as-is — the radial test
# can't judge them and they're already consistent.
_zc_dz = 8.0
_zlo = min(v[2] for v in GV)
_nzc = int((max(v[2] for v in GV) - _zlo) / _zc_dz) + 1
_ymin = [1e9] * _nzc
_ymax = [-1e9] * _nzc
for _gx, _gy, _gz in GV:
    if _gy >= WL + 15.8:           # HULL band only (exclude the superstructure/funnels, which would
        continue                   # pull the radial centre too high and mis-orient sloped hull sides)
    _b = int((_gz - _zlo) / _zc_dz)
    if _gy < _ymin[_b]:
        _ymin[_b] = _gy
    if _gy > _ymax[_b]:
        _ymax[_b] = _gy
_yc = [(_ymin[i] + _ymax[i]) * 0.5 if _ymax[i] > -1e8 else WL + 6.0 for i in range(_nzc)]
def _ycz(gz):
    return _yc[max(0, min(_nzc - 1, int((gz - _zlo) / _zc_dz)))]
_flipped = 0
_TR = []
for a, b, c in TR:
    ax, ay, az = GV[a]; bx, by, bz = GV[b]; cx, cy, cz = GV[c]
    nx = (by - ay) * (cz - az) - (bz - az) * (cy - ay)
    ny = (bz - az) * (cx - ax) - (bx - ax) * (cz - az)
    nz = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    ox = (ax + bx + cx) / 3.0; oy = (ay + by + cy) / 3.0; oz = (az + bz + cz) / 3.0
    horiz2 = nx * nx + ny * ny
    if horiz2 > 0.05 * (horiz2 + nz * nz):                  # skip near-fore/aft end-cap faces
        if nx * ox + ny * (oy - _ycz(oz)) < 0.0:            # normal faces inward -> flip winding
            b, c = c, b
            _flipped += 1
    _TR.append((a, b, c))
TR = _TR
print(f"winding: flipped {_flipped}/{len(TR)} triangles to face outward")

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
