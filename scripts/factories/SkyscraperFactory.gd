extends RefCounted
class_name SkyscraperFactory

# A sealed Empire-State-scale tower, floating in space: a tall square prism with big open
# office floors, a compact central stairwell connecting every storey, structural columns on a
# grid, and a glass curtain wall on all four faces. The glass is collidable, so you can see the
# void outside but not leave it. Four gates are scattered across the floors (your way out); one
# is always low so you can leave without a marathon climb.

const StableRng = preload("res://scripts/core/StableRng.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")

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

	# --- Envelope: always-drawn full-height geometry (stair shaft walls, columns, glass). It's
	# few pieces and the opaque slabs occlude all but the player's storey of it anyway. ---
	var env := Node3D.new()
	env.name = "Envelope"
	root.add_child(env)
	_stair_walls(env, top_y, core_mat)
	_columns(env, half, top_y, col_mat)
	for sgn in [-1.0, 1.0]:
		_glass_face(env, true, sgn * half, half, top_y, glass, trim)
		_glass_face(env, false, sgn * half, half, top_y, glass, trim)

	# --- Per-storey groups (Floor_<n>) so Main can hide every storey except the player's: with
	# opaque windows you can never see another floor, so only one needs to draw. Floor_n carries
	# the slab at y=n*H, the stair climbing out of it, and (later) its office fit-out. ---
	var floors: Array = []
	for n in range(STORIES + 1):
		var fl := Node3D.new()
		fl.name = "Floor_" + str(n)
		root.add_child(fl)
		floors.append(fl)
	_box(floors[0], Vector3(0.0, -TH * 0.5, 0.0), Vector3(FOOTPRINT + 1.0, TH, FOOTPRINT + 1.0), concrete, true)
	_box(floors[STORIES], Vector3(0.0, top_y + TH * 0.5, 0.0), Vector3(FOOTPRINT + 1.0, TH, FOOTPRINT + 1.0), concrete, true)
	for f in range(1, STORIES):
		_floor_slab(floors[f], half, float(f) * STORY_H, floor_mat)
	for f in range(STORIES):
		_ustair(floors[f], float(f) * STORY_H, float(f + 1) * STORY_H, core_mat)
		_furnish_floor(floors[f], half, float(f) * STORY_H, world_seed, f)

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


# --- Office fit-out for one storey ---------------------------------------------------------
# All the loose furniture (desks, chairs, partitions, plants, elevator doors) renders as ONE
# per-floor MultiMesh of coloured unit cubes (scaled per instance) -> one draw call per floor,
# and Main only ever shows the player's floor. Rooms that you walk into (restrooms, conference
# rooms) and the elevator block are solid collidable boxes.
const CORE_HALF: float = 13.0      # central service-zone (stair + elevators + restrooms)
const FIT_H: float = 2.7           # interior partition / room-wall height


static func _furnish_floor(group: Node3D, half: float, fy: float, world_seed: int, f: int) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "skyfloor", f))
	var wall := _mat(Color(0.80, 0.80, 0.82), 0.9, 0.0)
	var glass := _glass_mat_clear()
	var xf: Array = []   # visual furniture instance transforms
	var cf: Array = []   # visual furniture instance colours
	var sx: Array = []   # solid-furniture colliders: [center, size, yaw]
	_fit_core(group, fy, wall, xf, cf, sx)
	var zones: Array = _fit_conference(group, half, fy, rng, glass, xf, cf, sx)
	_fit_cubicles(half, fy, rng, zones, xf, cf, sx)
	_fit_plants(half, fy, rng, xf, cf, sx)
	_ceiling_lights(group, half, fy, xf, cf)
	if xf.size() > 0:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		MultiMeshScatter.build(group, "Furniture", mesh, MultiMeshScatter.instance_color_material(0.8), xf, cf)
	_build_furn_collision(group, sx)


# One coloured unit-cube furniture instance: size + yaw + position.
static func _furn(xf: Array, cf: Array, center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(size), center))
	cf.append(color)


# Furniture that also blocks the player: the visual instance plus a box collider (built later
# into one per-floor StaticBody, so it's culled and cheap with the rest of the storey).
static func _furn_solid(xf: Array, cf: Array, sx: Array, center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	_furn(xf, cf, center, size, color, yaw)
	sx.append([center, size, yaw])


# An office chair facing `yaw` (the way the sitter looks). Wheel base + gas cylinder + seat +
# a backrest set at the BACK edge of the seat (behind the sitter, away from the desk/table).
static func _chair(xf: Array, cf: Array, base: Vector3, yaw: float) -> void:
	var c := Color(0.13, 0.14, 0.18)
	var behind: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw)) * -0.21   # toward the chair's back
	_furn(xf, cf, base + Vector3(0.0, 0.05, 0.0), Vector3(0.52, 0.07, 0.52), c, yaw)          # wheel base
	_furn(xf, cf, base + Vector3(0.0, 0.28, 0.0), Vector3(0.1, 0.42, 0.1), c, yaw)            # gas cylinder
	_furn(xf, cf, base + Vector3(0.0, 0.47, 0.0), Vector3(0.5, 0.1, 0.5), c, yaw)             # seat
	_furn(xf, cf, base + Vector3(0.0, 0.76, 0.0) + behind, Vector3(0.48, 0.52, 0.08), c, yaw)  # backrest


static func _workstation(xf: Array, cf: Array, sx: Array, base: Vector3, yaw: float) -> void:
	var fwd: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var side: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	_furn_solid(xf, cf, sx, base + Vector3(0.0, 0.37, 0.0), Vector3(1.4, 0.74, 0.62), Color(0.60, 0.56, 0.50), yaw)  # desk
	_chair(xf, cf, base - fwd * 0.55, yaw)                                                                           # chair faces the desk
	_furn_solid(xf, cf, sx, base + fwd * 0.40 + Vector3(0.0, 0.62, 0.0), Vector3(1.5, 1.24, 0.05), Color(0.44, 0.48, 0.54), yaw)  # spine partition
	_furn_solid(xf, cf, sx, base + side * 0.74 + Vector3(0.0, 0.55, 0.0), Vector3(0.05, 1.1, 1.4), Color(0.44, 0.48, 0.54), yaw)  # side partition


# Elevator car (3 solid walls + open +z front: you ride from inside it, at (0,-9)) flanked by
# visual bank doors, plus two restrooms with stall dividers. The car position is shared with
# Main (_skyscraper_elevator_xz) for the ride interaction.
static func _fit_core(group: Node3D, fy: float, wall: Material, xf: Array, cf: Array, sx: Array) -> void:
	var h: float = FIT_H
	_box(group, Vector3(0.0, fy + h * 0.5, -10.6), Vector3(5.0, h, 0.2), wall, true)    # car back wall
	_box(group, Vector3(-2.4, fy + h * 0.5, -9.3), Vector3(0.2, h, 2.8), wall, true)    # car left wall
	_box(group, Vector3(2.4, fy + h * 0.5, -9.3), Vector3(0.2, h, 2.8), wall, true)     # car right wall
	_furn(xf, cf, Vector3(0.0, fy + 0.04, -9.3), Vector3(4.6, 0.06, 2.6), Color(0.27, 0.29, 0.33))   # car floor pad
	_furn(xf, cf, Vector3(0.0, fy + h - 0.1, -9.3), Vector3(4.6, 0.12, 2.6), Color(0.30, 0.32, 0.36))  # car ceiling
	# Make the elevator a findable beacon in the dim office: a lit sign over the open front, a
	# glowing call panel beside it, and a cyan light filling the car.
	var sign := _emissive_mat(Color(0.35, 0.85, 1.0))
	_box(group, Vector3(0.0, fy + h - 0.12, -7.9), Vector3(4.6, 0.28, 0.12), sign, false)   # header sign over the door
	_box(group, Vector3(2.9, fy + 1.2, -8.0), Vector3(0.22, 0.5, 0.1), sign, false)         # call panel
	var car_lamp := OmniLight3D.new()
	car_lamp.position = Vector3(0.0, fy + h - 0.4, -9.3)
	car_lamp.light_color = Color(0.6, 0.85, 1.0)
	car_lamp.light_energy = 2.4
	car_lamp.omni_range = 9.0
	car_lamp.shadow_enabled = false
	group.add_child(car_lamp)
	# flanking visual bank doors (other shafts)
	for sgn in [-1.0, 1.0]:
		_furn_solid(xf, cf, sx, Vector3(sgn * 5.0, fy + 1.2, -7.8), Vector3(2.4, 2.4, 0.18), Color(0.50, 0.53, 0.58))
		_furn(xf, cf, Vector3(sgn * 5.0, fy + 1.2, -7.68), Vector3(0.05, 2.4, 0.12), Color(0.16, 0.18, 0.22))
	# restrooms left/right, doors facing the core lobby
	_room(group, 11.0, -9.0, 5.0, 5.0, fy, h, 3, wall)
	_room(group, -11.0, -9.0, 5.0, 5.0, fy, h, 2, wall)
	for rx in [11.0, -11.0]:
		for s in range(3):
			_furn_solid(xf, cf, sx, Vector3(rx - 1.6 + float(s) * 1.6, fy + 0.6, -10.6), Vector3(0.05, 1.2, 1.3), Color(0.72, 0.73, 0.75))


# A few glass-walled conference rooms along the perimeter. Returns keep-out rects for cubicles.
static func _fit_conference(group: Node3D, half: float, fy: float, rng: StableRng, glass: Material, xf: Array, cf: Array, sx: Array) -> Array:
	var zones: Array = []
	var n: int = rng.randi_range(2, 3)
	for i in range(n):
		var side: int = rng.randi_range(0, 3)
		var w: float = rng.randf_range(7.0, 10.0)
		var d: float = rng.randf_range(6.0, 8.0)
		var span: float = half - 1.0 - maxf(w, d)
		var cx: float = 0.0
		var cz: float = 0.0
		var door: int = 0
		match side:
			0: cz = half - 0.6 - d * 0.5; cx = rng.randf_range(-span, span); door = 1
			1: cz = -(half - 0.6 - d * 0.5); cx = rng.randf_range(-span, span); door = 0
			2: cx = half - 0.6 - w * 0.5; cz = rng.randf_range(-span, span); door = 3
			_: cx = -(half - 0.6 - w * 0.5); cz = rng.randf_range(-span, span); door = 2
		if absf(cx) < CORE_HALF + 4.0 and absf(cz) < CORE_HALF + 4.0:
			continue
		_room(group, cx, cz, w, d, fy, 2.6, door, glass, 1.4)
		_conf_table(xf, cf, sx, Vector3(cx, fy, cz), w, d)
		zones.append(Rect2(cx - w * 0.5 - 1.5, cz - d * 0.5 - 1.5, w + 3.0, d + 3.0))
	return zones


static func _conf_table(xf: Array, cf: Array, sx: Array, base: Vector3, w: float, d: float) -> void:
	var tw: float = w * 0.45
	var td: float = d * 0.4
	_furn_solid(xf, cf, sx, base + Vector3(0.0, 0.73, 0.0), Vector3(tw, 0.09, td), Color(0.30, 0.24, 0.18))   # tabletop
	_furn_solid(xf, cf, sx, base + Vector3(0.0, 0.36, 0.0), Vector3(tw * 0.5, 0.72, td * 0.5), Color(0.26, 0.21, 0.16))
	var nx: int = maxi(2, int(tw / 1.1))
	for i in range(nx):
		var x: float = base.x - tw * 0.5 + (float(i) + 0.5) * tw / float(nx)
		_chair(xf, cf, Vector3(x, base.y, base.z + td * 0.5 + 0.45), PI)
		_chair(xf, cf, Vector3(x, base.y, base.z - td * 0.5 - 0.45), 0.0)


# Cubicle neighbourhoods: a few dense grids of workstations in the open office.
static func _fit_cubicles(half: float, fy: float, rng: StableRng, zones: Array, xf: Array, cf: Array, sx: Array) -> void:
	var blocks: int = rng.randi_range(3, 4)
	for b in range(blocks):
		var w: float = rng.randf_range(9.0, 14.0)
		var d: float = rng.randf_range(9.0, 14.0)
		var lim_x: float = half - 6.0 - w * 0.5
		var lim_z: float = half - 6.0 - d * 0.5
		var cx: float = rng.randf_range(-lim_x, lim_x)
		var cz: float = rng.randf_range(-lim_z, lim_z)
		if absf(cx) < CORE_HALF + w * 0.5 + 1.0 and absf(cz) < CORE_HALF + d * 0.5 + 1.0:
			continue
		if _rect_in_zones(cx, cz, w, d, zones):
			continue
		var yaw: float = (PI * 0.5) * float(rng.randi_range(0, 3))
		var px: float = cx - w * 0.5 + 1.3
		while px <= cx + w * 0.5 - 1.0:
			var pz: float = cz - d * 0.5 + 1.3
			while pz <= cz + d * 0.5 - 1.0:
				if not _near_col(px, pz):
					_workstation(xf, cf, sx, Vector3(px, fy, pz), yaw)
				pz += 2.6
			px += 2.6


static func _fit_plants(half: float, fy: float, rng: StableRng, xf: Array, cf: Array, sx: Array) -> void:
	for i in range(8):
		var x: float = rng.randf_range(-(half - 4.0), half - 4.0)
		var z: float = rng.randf_range(-(half - 4.0), half - 4.0)
		if absf(x) < CORE_HALF and absf(z) < CORE_HALF:
			continue
		if _near_col(x, z):
			continue
		_furn_solid(xf, cf, sx, Vector3(x, fy + 0.3, z), Vector3(0.4, 0.6, 0.4), Color(0.30, 0.24, 0.18))   # pot
		_furn(xf, cf, Vector3(x, fy + 1.1, z), Vector3(0.9, 1.1, 0.9), Color(0.18, 0.42, 0.20))             # foliage


# One per-floor StaticBody holding every solid furniture piece as a box collider (no meshes;
# the visuals come from the MultiMesh). Hidden with the floor, so it costs nothing off-storey.
static func _build_furn_collision(group: Node3D, sx: Array) -> void:
	if sx.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "FurnitureColliders"
	for s in sx:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = s[1]
		cs.shape = shape
		cs.transform = Transform3D(Basis(Vector3.UP, s[2]), s[0])
		body.add_child(cs)
	group.add_child(body)


# A grid of shadowless ceiling lights + flush fixtures. They live in the floor group, so the
# culling that hides off-storey floors also switches their lights off — only the player's
# storey is ever lit, keeping a fully-lit office cheap.
static func _ceiling_lights(group: Node3D, half: float, fy: float, xf: Array, cf: Array) -> void:
	var ly: float = fy + STORY_H - 0.3
	for gx in [-42.0, -14.0, 14.0, 42.0]:
		for gz in [-42.0, -14.0, 14.0, 42.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(gx, ly, gz)
			lamp.light_color = Color(1.0, 0.96, 0.88)
			lamp.light_energy = 1.4
			lamp.omni_range = 30.0
			lamp.shadow_enabled = false
			group.add_child(lamp)
			_furn(xf, cf, Vector3(gx, ly + 0.16, gz), Vector3(1.4, 0.12, 1.4), Color(0.96, 0.96, 0.9))   # fixture


# Four walls around [cx+-w/2, cz+-d/2] with a door gap on `door_side` (0:+z 1:-z 2:+x 3:-x).
static func _room(parent: Node3D, cx: float, cz: float, w: float, d: float, fy: float, h: float, door_side: int, mat: Material, door_w: float = 1.2) -> void:
	var t: float = 0.12
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	var cy: float = fy + h * 0.5
	_door_wall(parent, Vector3(cx, cy, cz + hd), Vector3(w, h, t), door_side == 0, door_w, mat, true)
	_door_wall(parent, Vector3(cx, cy, cz - hd), Vector3(w, h, t), door_side == 1, door_w, mat, true)
	_door_wall(parent, Vector3(cx + hw, cy, cz), Vector3(t, h, d), door_side == 2, door_w, mat, false)
	_door_wall(parent, Vector3(cx - hw, cy, cz), Vector3(t, h, d), door_side == 3, door_w, mat, false)


static func _door_wall(parent: Node3D, center: Vector3, size: Vector3, has_door: bool, door_w: float, mat: Material, span_x: bool) -> void:
	if not has_door:
		_box(parent, center, size, mat, true)
		return
	var span: float = size.x if span_x else size.z
	var seg: float = (span - door_w) * 0.5
	if seg <= 0.15:
		_box(parent, center, size, mat, true)
		return
	if span_x:
		_box(parent, center + Vector3(-(door_w + seg) * 0.5, 0.0, 0.0), Vector3(seg, size.y, size.z), mat, true)
		_box(parent, center + Vector3((door_w + seg) * 0.5, 0.0, 0.0), Vector3(seg, size.y, size.z), mat, true)
	else:
		_box(parent, center + Vector3(0.0, 0.0, -(door_w + seg) * 0.5), Vector3(size.x, size.y, seg), mat, true)
		_box(parent, center + Vector3(0.0, 0.0, (door_w + seg) * 0.5), Vector3(size.x, size.y, seg), mat, true)


static func _near_col(x: float, z: float) -> bool:
	var nx: float = round(x / COL_GRID) * COL_GRID
	var nz: float = round(z / COL_GRID) * COL_GRID
	return Vector2(x - nx, z - nz).length() < 1.3


static func _rect_in_zones(cx: float, cz: float, w: float, d: float, zones: Array) -> bool:
	var r := Rect2(cx - w * 0.5, cz - d * 0.5, w, d)
	for z in zones:
		if (z as Rect2).intersects(r):
			return true
	return false


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


static func _emissive_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	return m


static func _glass_mat() -> StandardMaterial3D:
	# Opaque dark-tinted curtain wall: you can't see out (so Main can cull every other floor)
	# and it's cheaper than transparent overdraw. Reads as mirror glass inside and out.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.12, 0.17)
	m.roughness = 0.12
	m.metallic = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# Clear interior glass for conference-room partitions.
static func _glass_mat_clear() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.72, 0.80, 0.20)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
