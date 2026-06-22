extends RefCounted
class_name SkyscraperFactory

# A sealed Empire-State-scale tower, floating in space: a tall square prism with big open
# office floors, a compact central stairwell connecting every storey, structural columns on a
# grid, and a glass curtain wall on all four faces. The glass is collidable, so you can see the
# void outside but not leave it. Four gates are scattered across the floors (your way out); one
# is always low so you can leave without a marathon climb.

const StableRng = preload("res://scripts/core/StableRng.gd")

const FOOTPRINT: float = 120.0     # square plan side (~Empire State base)
const STORIES: int = 50            # 50 storeys -> ~200 m tall: clearly a tower at 120 m wide
const STORY_H: float = 4.0         # commercial floor-to-floor; clears the switchback headroom
const TH: float = 0.3              # slab / wall thickness

const STAIR_HALF: float = 2.5      # central stairwell is 5 m x 5 m
const STAIR_LAND_D: float = 1.4    # depth of the half-landing
const STAIR_STEPS: int = 6         # steps per flight -> ~0.33 m rise, ~0.45 m run (a real stair)

const COL_SIZE: float = 0.7        # structural column side
const COL_GRID: float = 20.0       # column spacing


# Build the tower into `parent`. Returns an Array of 4 gate world-positions (scattered across
# the floors; gate 0 is on a low storey near the arrival point).
static func build(parent: Node3D, world_seed: int) -> Array:
	var root := Node3D.new()
	root.name = "Skyscraper"
	parent.add_child(root)
	var rng := StableRng.new(StableRng.mix_string(world_seed, "skyscraper", 1))

	var half: float = FOOTPRINT * 0.5
	var top_y: float = float(STORIES) * STORY_H

	var concrete := _mat(Color(0.60, 0.60, 0.63), 0.92, 0.0)
	var floor_mat := _mat(Color(0.46, 0.47, 0.50), 0.85, 0.0)
	var core_mat := _mat(Color(0.52, 0.53, 0.56), 0.88, 0.0)
	var col_mat := _mat(Color(0.40, 0.41, 0.45), 0.8, 0.05)
	var trim := _mat(Color(0.30, 0.31, 0.34), 0.6, 0.0)   # dark mullions
	var glass := _glass_mat()

	# --- Base + roof slabs (sealed top & bottom; base is solid under the stair) ---
	_box(root, Vector3(0.0, -TH * 0.5, 0.0), Vector3(FOOTPRINT + 1.0, TH, FOOTPRINT + 1.0), concrete, true)
	_box(root, Vector3(0.0, top_y + TH * 0.5, 0.0), Vector3(FOOTPRINT + 1.0, TH, FOOTPRINT + 1.0), concrete, true)

	# --- Office floor slabs (1..STORIES-1): full plate minus the central stairwell opening. ---
	for f in range(1, STORIES):
		_floor_slab(root, half, float(f) * STORY_H, floor_mat)

	# --- Three-sided stairwell shaft (open on the +z entry side) so you don't wander off the
	# opening, then a compact switchback per storey climbing through the openings. ---
	_stair_walls(root, top_y, core_mat)
	for f in range(STORIES):
		_ustair(root, float(f) * STORY_H, float(f + 1) * STORY_H, core_mat)

	# --- Structural columns on a grid (skip the central stairwell). ---
	_columns(root, half, top_y, col_mat)

	# --- Glass curtain wall on each face + a mullion grid. Sealed. ---
	for sgn in [-1.0, 1.0]:
		_glass_face(root, true, sgn * half, half, top_y, glass, trim)
		_glass_face(root, false, sgn * half, half, top_y, glass, trim)

	# --- Four gates scattered across the floors. Gate 0 sits low (near the arrival spot) so the
	# player can always leave without a marathon climb; the rest are spread higher. ---
	var gates: Array = []
	var floors_used: Array = []
	for gi in range(4):
		var gf: int = rng.randi_range(1, 4) if gi == 0 else rng.randi_range(5, STORIES - 2)
		var tries: int = 0
		while floors_used.has(gf) and tries < 16:
			gf = rng.randi_range(1, STORIES - 2)
			tries += 1
		floors_used.append(gf)
		var r: float = rng.randf_range(half * 0.32, half * 0.82)   # clear of the core and the glass
		var ang: float = rng.randf_range(0.0, TAU)
		gates.append(Vector3(r * cos(ang), float(gf) * STORY_H + 0.05, r * sin(ang)))
	return gates


# --- Full floor plate minus the central stairwell hole: four strips around it. ------------
static func _floor_slab(parent: Node3D, half: float, fy: float, mat: Material) -> void:
	var fcy: float = fy - TH * 0.5   # top surface at fy
	var sh: float = STAIR_HALF
	var span: float = half - sh
	# front (+z) and back (-z) full-width strips
	_box(parent, Vector3(0.0, fcy, (sh + half) * 0.5), Vector3(FOOTPRINT, TH, span), mat, true)
	_box(parent, Vector3(0.0, fcy, -(sh + half) * 0.5), Vector3(FOOTPRINT, TH, span), mat, true)
	# left (-x) and right (+x) strips spanning the stairwell's depth
	_box(parent, Vector3((sh + half) * 0.5, fcy, 0.0), Vector3(span, TH, sh * 2.0), mat, true)
	_box(parent, Vector3(-(sh + half) * 0.5, fcy, 0.0), Vector3(span, TH, sh * 2.0), mat, true)


# --- Stairwell shaft walls: back (-z) and the two sides (+-x), full height. Front (+z) is the
# open entry; you approach the stair from the office floor on that side. ------------------
static func _stair_walls(parent: Node3D, top_y: float, mat: Material) -> void:
	var sh: float = STAIR_HALF
	_box(parent, Vector3(0.0, top_y * 0.5, -sh), Vector3(sh * 2.0, top_y, TH), mat, true)
	_box(parent, Vector3(-sh, top_y * 0.5, 0.0), Vector3(TH, top_y, sh * 2.0), mat, true)
	_box(parent, Vector3(sh, top_y * 0.5, 0.0), Vector3(TH, top_y, sh * 2.0), mat, true)


# --- Structural column grid (full height), skipping the central stairwell. ---------------
static func _columns(parent: Node3D, half: float, top_y: float, mat: Material) -> void:
	var reach: float = floorf((half - COL_GRID) / COL_GRID) * COL_GRID
	var c: float = -reach
	while c <= reach + 0.01:
		var d: float = -reach
		while d <= reach + 0.01:
			if absf(c) > STAIR_HALF + 1.0 or absf(d) > STAIR_HALF + 1.0:
				_box(parent, Vector3(c, top_y * 0.5, d), Vector3(COL_SIZE, top_y, COL_SIZE), mat, true)
			d += COL_GRID
		c += COL_GRID


# --- Compact switchback for one storey in the central stairwell (real-proportioned solid
# steps the capsule rounds into a slope, like the city building stairs). ------------------
static func _ustair(parent: Node3D, y0: float, y1: float, mat: Material) -> void:
	var sh: float = STAIR_HALF
	var mid_y: float = (y0 + y1) * 0.5
	var land_z1: float = -sh + STAIR_LAND_D
	# mid landing across the back
	_box(parent, Vector3(0.0, mid_y - 0.1, (-sh + land_z1) * 0.5), Vector3(sh * 2.0, 0.2, land_z1 + sh), mat, true)
	_flight(parent, -sh, 0.0, land_z1, sh, y0, mid_y, false, mat)   # left: enter at +z, climb to back landing
	_flight(parent, 0.0, sh, land_z1, sh, mid_y, y1, true, mat)     # right: back landing up to +z exit


static func _flight(parent: Node3D, x0: float, x1: float, z_lo: float, z_hi: float, y0: float, y1: float, ascend_hi: bool, mat: Material) -> void:
	var n: int = STAIR_STEPS
	var rise: float = (y1 - y0) / float(n)
	var depth: float = (z_hi - z_lo) / float(n)
	var cx: float = (x0 + x1) * 0.5
	var sw: float = x1 - x0
	for j in range(n):
		var z: float = (z_lo + (float(j) + 0.5) * depth) if ascend_hi else (z_hi - (float(j) + 0.5) * depth)
		var fill_h: float = float(j + 1) * rise
		_box(parent, Vector3(cx, y0 + fill_h * 0.5, z), Vector3(sw - 0.25, fill_h, depth + 0.05), mat, true)


# --- One glass face + its mullion grid. wall_is_z: face lies on z=fixed (spans x); else on
# x=fixed (spans z). ----------------------------------------------------------------------
static func _glass_face(parent: Node3D, wall_is_z: bool, fixed: float, half: float, top_y: float, glass: Material, trim: Material) -> void:
	var gth: float = 0.08
	if wall_is_z:
		_box(parent, Vector3(0.0, top_y * 0.5, fixed), Vector3(FOOTPRINT, top_y, gth), glass, true)
	else:
		_box(parent, Vector3(fixed, top_y * 0.5, 0.0), Vector3(gth, top_y, FOOTPRINT), glass, true)
	# Vertical mullions every ~5 m, proud of the glass (decorative, no collision).
	var mw: float = 0.14
	var proud: float = 0.06
	var n: int = int(round(FOOTPRINT / 5.0))
	for i in range(n + 1):
		var t: float = -half + float(i) * (FOOTPRINT / float(n))
		if wall_is_z:
			_box(parent, Vector3(t, top_y * 0.5, fixed), Vector3(mw, top_y, gth + proud), trim, false)
		else:
			_box(parent, Vector3(fixed, top_y * 0.5, t), Vector3(gth + proud, top_y, mw), trim, false)
	# Horizontal spandrel band at each floor line.
	for f in range(STORIES + 1):
		var fy: float = float(f) * STORY_H
		if wall_is_z:
			_box(parent, Vector3(0.0, fy, fixed), Vector3(FOOTPRINT, 0.24, gth + proud), trim, false)
		else:
			_box(parent, Vector3(fixed, fy, 0.0), Vector3(gth + proud, 0.24, FOOTPRINT), trim, false)


# --- Primitives --------------------------------------------------------------------------
static func _box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, collide: bool) -> void:
	if collide:
		var body := StaticBody3D.new()
		body.position = center
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = size
		cs.shape = sh
		body.add_child(cs)
		parent.add_child(body)
	else:
		var mi2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new(); bm2.size = size
		mi2.mesh = bm2
		mi2.material_override = mat
		mi2.position = center
		parent.add_child(mi2)


static func _mat(color: Color, rough: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m


static func _glass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.68, 0.78, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # visible from inside and outside
	return m
