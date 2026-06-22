extends RefCounted
class_name SkyscraperFactory

# A sealed prismatic skyscraper interior, floating in space. Form follows the prismatic
# supertall pattern (432 Park Avenue etc., per the design brief): a constant square prism
# with a CENTRAL CORE (~25% of the plan: the stairwell/services) and a usable ring around
# it, wrapped in a glass curtain wall on all four faces. The glass is collidable, so you see
# the void outside but cannot exit. Four gates are scattered through the ring (your way out).

const StableRng = preload("res://scripts/core/StableRng.gd")

const FOOTPRINT: float = 30.0      # square plan side
const STORIES: int = 28            # >= 25 stories
const STORY_H: float = 3.6
const CORE: float = 14.0           # central core side (~22% of the floor area)
const TH: float = 0.3              # slab / wall thickness
const DOOR_W: float = 2.2
const DOOR_H: float = 2.6


# Build the tower into `parent`. Returns an Array of 4 gate world-positions (in the ring,
# spread across floors).
static func build(parent: Node3D, world_seed: int) -> Array:
	var root := Node3D.new()
	root.name = "Skyscraper"
	parent.add_child(root)
	var rng := StableRng.new(StableRng.mix_string(world_seed, "skyscraper", 1))

	var half: float = FOOTPRINT * 0.5
	var ch: float = CORE * 0.5
	var top_y: float = float(STORIES) * STORY_H

	var concrete := _mat(Color(0.60, 0.60, 0.63), 0.92, 0.0)
	var floor_mat := _mat(Color(0.46, 0.47, 0.50), 0.85, 0.0)
	var core_mat := _mat(Color(0.52, 0.53, 0.56), 0.88, 0.0)
	var trim := _mat(Color(0.30, 0.31, 0.34), 0.6, 0.0)   # dark mullions
	var glass := _glass_mat()

	# --- Base + roof slabs (sealed top & bottom) ---
	_box(root, Vector3(0.0, -TH * 0.5, 0.0), Vector3(FOOTPRINT + 1.0, TH, FOOTPRINT + 1.0), concrete, true)
	_box(root, Vector3(0.0, top_y + TH * 0.5, 0.0), Vector3(FOOTPRINT + 1.0, TH, FOOTPRINT + 1.0), concrete, true)

	# --- Floor slabs (1..STORIES-1): the usable ring (footprint minus the core). Floor 0 is
	# the base slab above; the core is an open stair shaft. ---
	for f in range(1, STORIES):
		_ring_slab(root, half, ch, float(f) * STORY_H, floor_mat)

	# --- Core walls: four full-height walls enclosing the stair shaft, with a door per floor
	# on the +z face so you step out of the stairs onto each floor's ring. ---
	_core_walls(root, ch, top_y, core_mat)

	# --- Switchback stairs filling the core shaft, connecting every floor. ---
	for f in range(STORIES):
		_ustair(root, -ch, ch, -ch, ch, float(f) * STORY_H, float(f + 1) * STORY_H, core_mat)

	# --- Glass curtain wall on each face + a concrete mullion grid over it. Sealed. ---
	for sgn in [-1.0, 1.0]:
		_glass_face(root, true, sgn * half, half, top_y, glass, trim)    # front/back (z = +-half)
		_glass_face(root, false, sgn * half, half, top_y, glass, trim)   # left/right (x = +-half)

	# --- Four gates spread through the ring on different floors. ---
	var gates: Array = []
	var floors_used: Array = []
	for gi in range(4):
		var gf: int = rng.randi_range(1, STORIES - 2)
		var tries: int = 0
		while floors_used.has(gf) and tries < 12:
			gf = rng.randi_range(1, STORIES - 2)
			tries += 1
		floors_used.append(gf)
		var side: int = rng.randi_range(0, 3)
		var band: float = (half + ch) * 0.5     # mid-ring radius
		var along: float = rng.randf_range(-ch, ch)
		var gx: float = 0.0
		var gz: float = 0.0
		match side:
			0: gx = band; gz = along
			1: gx = -band; gz = along
			2: gz = band; gx = along
			_: gz = -band; gx = along
		gates.append(Vector3(gx, float(gf) * STORY_H + 0.05, gz))
	return gates


# --- Floor ring: four strips around the central core hole. -------------------------------
static func _ring_slab(parent: Node3D, half: float, ch: float, fy: float, mat: Material) -> void:
	var fcy: float = fy - TH * 0.5   # top surface at fy
	var strip: float = half - ch
	# front (+z) and back (-z) full-width strips
	_box(parent, Vector3(0.0, fcy, (ch + half) * 0.5), Vector3(FOOTPRINT, TH, strip), mat, true)
	_box(parent, Vector3(0.0, fcy, -(ch + half) * 0.5), Vector3(FOOTPRINT, TH, strip), mat, true)
	# left (-x) and right (+x) strips between them
	_box(parent, Vector3((ch + half) * 0.5, fcy, 0.0), Vector3(strip, TH, CORE), mat, true)
	_box(parent, Vector3(-(ch + half) * 0.5, fcy, 0.0), Vector3(strip, TH, CORE), mat, true)


# --- Core walls with a door per floor on the +z side. ------------------------------------
static func _core_walls(parent: Node3D, ch: float, top_y: float, mat: Material) -> void:
	# -z, -x, +x are solid full-height walls.
	_box(parent, Vector3(0.0, top_y * 0.5, -ch), Vector3(CORE, top_y, TH), mat, true)
	_box(parent, Vector3(-ch, top_y * 0.5, 0.0), Vector3(TH, top_y, CORE), mat, true)
	_box(parent, Vector3(ch, top_y * 0.5, 0.0), Vector3(TH, top_y, CORE), mat, true)
	# +z wall: per-floor doorway (a gap with a header), so you exit the stairs onto each floor.
	var seg: float = (CORE - DOOR_W) * 0.5
	for f in range(STORIES):
		var fy: float = float(f) * STORY_H
		# jambs either side of the door
		_box(parent, Vector3(-(DOOR_W + seg) * 0.5, fy + STORY_H * 0.5, ch), Vector3(seg, STORY_H, TH), mat, true)
		_box(parent, Vector3((DOOR_W + seg) * 0.5, fy + STORY_H * 0.5, ch), Vector3(seg, STORY_H, TH), mat, true)
		# header above the door
		if STORY_H - DOOR_H > 0.15:
			_box(parent, Vector3(0.0, fy + (DOOR_H + STORY_H) * 0.5, ch), Vector3(DOOR_W, STORY_H - DOOR_H, TH), mat, true)


# --- One glass face + its mullion grid. wall_is_z: face lies on z=fixed (spans x); else on
# x=fixed (spans z). ----------------------------------------------------------------------
static func _glass_face(parent: Node3D, wall_is_z: bool, fixed: float, half: float, top_y: float, glass: Material, trim: Material) -> void:
	# The collidable glass sheet (you see through it, can't pass it).
	var gth: float = 0.08
	if wall_is_z:
		_box(parent, Vector3(0.0, top_y * 0.5, fixed), Vector3(FOOTPRINT, top_y, gth), glass, true)
	else:
		_box(parent, Vector3(fixed, top_y * 0.5, 0.0), Vector3(gth, top_y, FOOTPRINT), glass, true)
	# Vertical mullions every ~2.5m, proud of the glass (decorative, no collision).
	var mw: float = 0.12
	var proud: float = 0.06
	var n: int = int(round(FOOTPRINT / 2.5))
	for i in range(n + 1):
		var t: float = -half + float(i) * (FOOTPRINT / float(n))
		if wall_is_z:
			_box(parent, Vector3(t, top_y * 0.5, fixed), Vector3(mw, top_y, gth + proud), trim, false)
		else:
			_box(parent, Vector3(fixed, top_y * 0.5, t), Vector3(gth + proud, top_y, mw), trim, false)
	# Horizontal mullion at each floor line (spandrel band).
	for f in range(STORIES + 1):
		var fy: float = float(f) * STORY_H
		if wall_is_z:
			_box(parent, Vector3(0.0, fy, fixed), Vector3(FOOTPRINT, 0.22, gth + proud), trim, false)
		else:
			_box(parent, Vector3(fixed, fy, 0.0), Vector3(gth + proud, 0.22, FOOTPRINT), trim, false)


# --- Switchback (U) stair for one storey, filling [x0,x1]x[z0,z1] from y0 to y1. ----------
static func _ustair(parent: Node3D, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, mat: Material) -> void:
	var x_mid: float = (x0 + x1) * 0.5
	var mid_y: float = (y0 + y1) * 0.5
	var land_d: float = 1.4
	var land_z1: float = z0 + land_d
	# mid landing at the back
	_box(parent, Vector3((x0 + x1) * 0.5, mid_y - 0.1, (z0 + land_z1) * 0.5), Vector3(x1 - x0, 0.2, land_z1 - z0), mat, true)
	_flight(parent, x0, x_mid, land_z1, z1, y0, mid_y, false, mat)
	_flight(parent, x_mid, x1, land_z1, z1, mid_y, y1, true, mat)


static func _flight(parent: Node3D, x0: float, x1: float, z_lo: float, z_hi: float, y0: float, y1: float, ascend_hi: bool, mat: Material) -> void:
	var n: int = 7
	var rise: float = (y1 - y0) / float(n)
	var depth: float = (z_hi - z_lo) / float(n)
	var cx: float = (x0 + x1) * 0.5
	var sw: float = x1 - x0
	for j in range(n):
		var z: float = (z_lo + (float(j) + 0.5) * depth) if ascend_hi else (z_hi - (float(j) + 0.5) * depth)
		var fill_h: float = float(j + 1) * rise
		_box(parent, Vector3(cx, y0 + fill_h * 0.5, z), Vector3(sw - 0.3, fill_h, depth + 0.05), mat, true)


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
