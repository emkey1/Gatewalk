extends RefCounted
class_name CityFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")

# A ruined, overgrown city: a grid of streets between blocks of multistory buildings
# (hollow shells you can walk into through a doorway, with window facades), parks
# gone wild with vegetation, and rubble lots. Returns the world positions where the
# objective "data cores" should be hidden (inside buildings).

const CELL: float = 34.0     # block-to-block pitch (block + street)
const BLOCK: float = 25.0    # block footprint
const STREET_W: float = 8.0
const STORY_H: float = 3.6
const TARGET_CORES: int = 6


static func scatter_city(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> Array:
	var height_fn := Callable(context, "height_at_world")
	var extent: float = minf(context.world_half_size() * 0.7, 145.0)
	var n: int = int(extent / CELL)

	var root := Node3D.new()
	root.name = "City"
	parent.add_child(root)

	var win_t: Array = []
	var win_c: Array = []
	var building_positions: Array = []

	var street_mat := _street_material()
	var streets := Node3D.new()
	streets.name = "Streets"
	root.add_child(streets)
	var span: float = (float(n) + 1.0) * CELL * 2.0
	for i in range(-n, n + 1):
		var line: float = (float(i) + 0.5) * CELL
		_street_slab(streets, Vector3(line, 0.0, 0.0), Vector3(STREET_W, 0.12, span), street_mat, height_fn)
		_street_slab(streets, Vector3(0.0, 0.0, line), Vector3(span, 0.12, STREET_W), street_mat, height_fn)

	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var bx: float = float(i) * CELL
			var bz: float = float(j) * CELL
			if Vector2(bx, bz).length() > extent:
				continue
			if absi(i) <= 1 and absi(j) <= 1:
				continue  # open plaza at the centre so the player spawns in the clear
			var cell_rng := StableRng.new(StableRng.mix_string(world_seed, "city_cell", i * 1000 + j))
			var gy: float = float(height_fn.call(bx, bz))
			var roll: float = cell_rng.randf()
			if roll < 0.34:
				_build_park(root, Vector3(bx, gy, bz), cell_rng, height_fn)
			elif roll < 0.66:
				var bw: float = cell_rng.randf_range(12.0, BLOCK - 2.0)
				var bd: float = cell_rng.randf_range(12.0, BLOCK - 2.0)
				var stories: int = cell_rng.randi_range(1, 5)
				var bpos := Vector3(bx, gy, bz)
				_build_building(root, bpos, bw, bd, stories, cell_rng, win_t, win_c)
				building_positions.append(bpos)
			else:
				_build_rubble(root, Vector3(bx, gy, bz), cell_rng)

	if not win_t.is_empty():
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		MultiMeshScatter.build(root, "CityWindows", quad, _window_material(), win_t, win_c)

	# Spread the objective cores across the city's buildings.
	var cores: Array = []
	if not building_positions.is_empty():
		var step: int = maxi(1, building_positions.size() / TARGET_CORES)
		var idx: int = 0
		while idx < building_positions.size() and cores.size() < TARGET_CORES:
			cores.append((building_positions[idx] as Vector3) + Vector3(0.0, 1.1, 0.0))
			idx += step
	return cores


# --- Buildings ---------------------------------------------------------------

# A walkable multistory building: solid floor slabs per storey, a switchback ramp
# stairwell in the back shaft, room dividers with doorways, and an optional basement.
static func _build_building(parent: Node3D, pos: Vector3, w: float, d: float, stories: int, rng: StableRng, win_t: Array, win_c: Array) -> void:
	var b := Node3D.new()
	b.position = pos
	parent.add_child(b)
	var mat := _concrete_material(rng)
	var floor_mat := _floor_material(rng)
	var sh: float = STORY_H
	var th: float = 0.3
	var stair_w: float = minf(5.0, w - 5.0)     # stairwell (two half-flights wide) in the back-left corner
	var stair_run: float = minf(5.5, d - 3.0)
	var hx1: float = -w * 0.5 + stair_w         # stairwell occupies x in [-w/2, hx1]
	var hz1: float = -d * 0.5 + stair_run       # ...and z in [-d/2, hz1]
	var has_basement: bool = rng.randf() < 0.45
	var base_level: int = -1 if has_basement else 0
	var base_y: float = float(base_level) * sh
	var height: float = float(stories) * sh
	var door_w: float = 2.4
	var door_h: float = 2.8

	# --- Exterior shell (extends down to the basement floor if present) ---
	var ext_h: float = height - base_y
	var ext_cy: float = (height + base_y) * 0.5
	_wall(b, Vector3(0.0, ext_cy, -d * 0.5), Vector3(w, ext_h, th), mat)
	_wall(b, Vector3(-w * 0.5, ext_cy, 0.0), Vector3(th, ext_h, d), mat)
	_wall(b, Vector3(w * 0.5, ext_cy, 0.0), Vector3(th, ext_h, d), mat)
	if has_basement:
		_wall(b, Vector3(0.0, base_y * 0.5, d * 0.5), Vector3(w, -base_y, th), mat)
	var seg: float = (w - door_w) * 0.5
	if seg > 0.4:
		_wall(b, Vector3(-(door_w * 0.5 + seg * 0.5), height * 0.5, d * 0.5), Vector3(seg, height, th), mat)
		_wall(b, Vector3(door_w * 0.5 + seg * 0.5, height * 0.5, d * 0.5), Vector3(seg, height, th), mat)
	_wall(b, Vector3(0.0, (height + door_h) * 0.5, d * 0.5), Vector3(door_w, height - door_h, th), mat)
	_decor_box(b, Vector3(0.0, height + 0.15, 0.0), Vector3(w + 0.4, 0.3, d + 0.4), mat)

	# --- Walkable floors (stairwell hole + solid landing strip) + rooms ---
	var land_d: float = 1.5
	for lvl in range(base_level, stories):
		var fy: float = float(lvl) * sh
		if lvl == base_level:
			_wall(b, Vector3(0.0, fy - 0.1, 0.0), Vector3(w, 0.2, d), floor_mat)  # solid base
		else:
			# Footprint minus the stairwell hole, keeping a landing strip at the near edge.
			_wall(b, Vector3((hx1 + w * 0.5) * 0.5, fy - 0.1, 0.0), Vector3(w * 0.5 - hx1, 0.2, d), floor_mat)
			_wall(b, Vector3((-w * 0.5 + hx1) * 0.5, fy - 0.1, -d * 0.5 + land_d * 0.5), Vector3(stair_w, 0.2, land_d), floor_mat)
			_wall(b, Vector3((-w * 0.5 + hx1) * 0.5, fy - 0.1, (hz1 + d * 0.5) * 0.5), Vector3(stair_w, 0.2, d * 0.5 - hz1), floor_mat)
		if w - stair_w > 6.0 and rng.randf() < 0.6:
			_room_divider(b, rng.randf_range(hx1 + 1.5, w * 0.5 - 1.5), fy, -d * 0.5, d * 0.5, sh, door_h, mat, rng)

	# --- U-shaped half-landing stair per level (two short flights + a landing) ---
	for lvl in range(base_level, stories - 1):
		_build_ustair(b, -w * 0.5, hx1, -d * 0.5, hz1, float(lvl) * sh, float(lvl + 1) * sh, land_d, mat, floor_mat)

	# --- Window facades (above-ground only) ---
	var c := Vector3(pos.x, pos.y + height * 0.5, pos.z)
	_face_windows(c + Vector3(0.0, 0.0, -d * 0.5), Vector3(0.0, 0.0, -1.0), w, height, win_t, win_c, rng, false)
	_face_windows(c + Vector3(0.0, 0.0, d * 0.5), Vector3(0.0, 0.0, 1.0), w, height, win_t, win_c, rng, true)
	_face_windows(c + Vector3(-w * 0.5, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), d, height, win_t, win_c, rng, false)
	_face_windows(c + Vector3(w * 0.5, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), d, height, win_t, win_c, rng, false)


# A U-shaped half-landing stair for one storey: flight A climbs the left half to a
# mid-landing at the far end, then flight B climbs the right half back to the floor
# above. Readable, connects cleanly, keeps head height. Solid steps the capsule
# rounds into a smooth ~25 deg slope.
static func _build_ustair(parent: Node3D, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, land_d: float, mat: Material, floor_mat: Material) -> void:
	var x_mid: float = (x0 + x1) * 0.5
	var mid_y: float = (y0 + y1) * 0.5
	var run_z1: float = z1 - land_d
	_wall(parent, Vector3((x0 + x1) * 0.5, mid_y - 0.1, (run_z1 + z1) * 0.5), Vector3(x1 - x0, 0.2, z1 - run_z1), floor_mat)
	_build_flight(parent, x0, x_mid, z0, run_z1, y0, mid_y, true, mat)
	_build_flight(parent, x_mid, x1, z0, run_z1, mid_y, y1, false, mat)


# One straight flight of solid steps. ascend_pos: climb runs toward +z; otherwise -z.
static func _build_flight(parent: Node3D, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, ascend_pos: bool, mat: Material) -> void:
	var n: int = 5
	var rise: float = (y1 - y0) / float(n)
	var depth: float = (z1 - z0) / float(n)
	var cx: float = (x0 + x1) * 0.5
	var sw: float = x1 - x0
	for j in range(n):
		var z: float = (z0 + (float(j) + 0.5) * depth) if ascend_pos else (z1 - (float(j) + 0.5) * depth)
		var fill_h: float = float(j + 1) * rise
		_wall(parent, Vector3(cx, y0 + fill_h * 0.5, z), Vector3(sw - 0.3, fill_h, depth + 0.05), mat)


# An interior wall splitting the room area, with a doorway gap.
static func _room_divider(parent: Node3D, x: float, fy: float, z0: float, z1: float, sh: float, door_h: float, mat: Material, rng: StableRng) -> void:
	var th: float = 0.2
	var door_w: float = 1.6
	var door_z: float = rng.randf_range(z0 + door_w, z1 - door_w)
	var lo_d: float = (door_z - door_w * 0.5) - z0
	var hi_d: float = z1 - (door_z + door_w * 0.5)
	if lo_d > 0.3:
		_wall(parent, Vector3(x, fy + sh * 0.5, z0 + lo_d * 0.5), Vector3(th, sh, lo_d), mat)
	if hi_d > 0.3:
		_wall(parent, Vector3(x, fy + sh * 0.5, z1 - hi_d * 0.5), Vector3(th, sh, hi_d), mat)
	_wall(parent, Vector3(x, fy + (sh + door_h) * 0.5, door_z), Vector3(th, sh - door_h, door_w), mat)


static func _floor_material(rng: StableRng) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tone: float = rng.randf_range(0.28, 0.40)
	mat.albedo_color = Color(tone, tone * 0.98, tone * 0.92)
	mat.roughness = 1.0
	return mat


static func _face_windows(center: Vector3, normal: Vector3, face_w: float, face_h: float, win_t: Array, win_c: Array, rng: StableRng, has_door: bool) -> void:
	var tangent := Vector3(normal.z, 0.0, -normal.x)
	var cols: int = maxi(1, int(face_w / 3.0))
	var rows: int = maxi(1, int(face_h / 3.5))
	var basis := Basis.looking_at(-normal, Vector3.UP).scaled(Vector3(1.5, 1.9, 1.0))
	for col in range(cols):
		for row in range(rows):
			var fx: float = (float(col) + 0.5) / float(cols) * face_w - face_w * 0.5
			var fy: float = (float(row) + 0.5) / float(rows) * face_h - face_h * 0.5
			if has_door and absf(fx) < 1.8 and fy < -face_h * 0.5 + 3.2:
				continue  # leave the doorway clear
			var wpos := center + tangent * fx + Vector3(0.0, fy, 0.0) + normal * 0.08
			win_t.append(Transform3D(basis, wpos))
			# A few windows still glow; most are dark and broken.
			if rng.randf() < 0.16:
				win_c.append(Color(0.95, 0.82, 0.45))
			else:
				win_c.append(Color(0.07, 0.08, 0.12))


static func _wall(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


static func _decor_box(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)


# --- Parks (run wild) --------------------------------------------------------

static func _build_park(parent: Node3D, pos: Vector3, rng: StableRng, height_fn: Callable) -> void:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.32, 0.24, 0.16)
	trunk_mat.roughness = 1.0
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.18, 0.34, 0.16)
	leaf_mat.roughness = 1.0

	var count: int = rng.randi_range(7, 13)
	for k in range(count):
		var ox: float = rng.randf_range(-BLOCK * 0.45, BLOCK * 0.45)
		var oz: float = rng.randf_range(-BLOCK * 0.45, BLOCK * 0.45)
		var gy: float = float(height_fn.call(pos.x + ox, pos.z + oz)) - pos.y
		if rng.randf() < 0.6:
			var s: float = rng.randf_range(0.8, 1.5)
			var trunk := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.18 * s
			tm.bottom_radius = 0.26 * s
			tm.height = 2.2 * s
			trunk.mesh = tm
			trunk.material_override = trunk_mat
			trunk.position = Vector3(ox, gy + 1.1 * s, oz)
			p.add_child(trunk)
			var canopy := MeshInstance3D.new()
			var cm := SphereMesh.new()
			cm.radius = rng.randf_range(1.4, 2.4) * s
			cm.height = cm.radius * 1.8
			canopy.mesh = cm
			canopy.material_override = leaf_mat
			canopy.position = Vector3(ox, gy + 2.6 * s, oz)
			p.add_child(canopy)
		else:
			var bush := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = rng.randf_range(0.7, 1.3)
			bm.height = bm.radius * 1.4
			bush.mesh = bm
			bush.material_override = leaf_mat
			bush.position = Vector3(ox, gy + bm.radius * 0.5, oz)
			bush.scale = Vector3(1.0, rng.randf_range(0.7, 1.0), 1.0)
			p.add_child(bush)


# --- Rubble lots -------------------------------------------------------------

static func _build_rubble(parent: Node3D, pos: Vector3, rng: StableRng) -> void:
	var r := Node3D.new()
	r.position = pos
	parent.add_child(r)
	var mat := _concrete_material(rng)
	for k in range(rng.randi_range(4, 9)):
		var chunk := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.4, 1.4), rng.randf_range(0.6, 2.2))
		chunk.mesh = cm
		chunk.material_override = mat
		chunk.position = Vector3(rng.randf_range(-BLOCK * 0.4, BLOCK * 0.4), cm.size.y * 0.35, rng.randf_range(-BLOCK * 0.4, BLOCK * 0.4))
		chunk.rotation_degrees = Vector3(rng.randf_range(-18.0, 18.0), rng.randf_range(0.0, 360.0), rng.randf_range(-18.0, 18.0))
		r.add_child(chunk)


# --- Materials & ground ------------------------------------------------------

static func _street_slab(parent: Node3D, center: Vector3, size: Vector3, mat: Material, height_fn: Callable) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = Vector3(center.x, float(height_fn.call(center.x, center.z)) + 0.02, center.z)
	parent.add_child(mi)


static func _concrete_material(rng: StableRng) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tone: float = rng.randf_range(0.38, 0.56)
	var stain: float = rng.randf_range(-0.04, 0.02)
	mat.albedo_color = Color(tone, tone + stain, tone + stain * 0.5)
	mat.roughness = rng.randf_range(0.88, 1.0)
	return mat


static func _street_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.18)
	mat.roughness = 1.0
	return mat


static func _window_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
