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
			if roll < 0.22:
				_build_park(root, Vector3(bx, gy, bz), cell_rng, height_fn)
			elif roll < 0.90:
				var bw: float = cell_rng.randf_range(12.0, BLOCK - 2.0)
				var bd: float = cell_rng.randf_range(12.0, BLOCK - 2.0)
				var stories: int = cell_rng.randi_range(1, 6)
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

static func _build_building(parent: Node3D, pos: Vector3, w: float, d: float, stories: int, rng: StableRng, win_t: Array, win_c: Array) -> void:
	var b := Node3D.new()
	b.position = pos
	parent.add_child(b)
	var height: float = float(stories) * STORY_H
	var mat := _concrete_material(rng)
	var th: float = 0.3

	# Back and side walls (solid).
	_wall(b, Vector3(0.0, height * 0.5, -d * 0.5), Vector3(w, height, th), mat)
	_wall(b, Vector3(-w * 0.5, height * 0.5, 0.0), Vector3(th, height, d), mat)
	_wall(b, Vector3(w * 0.5, height * 0.5, 0.0), Vector3(th, height, d), mat)

	# Front wall (+z) with a doorway gap so the player can walk in.
	var door_w: float = 2.4
	var door_h: float = 2.8
	var seg: float = (w - door_w) * 0.5
	if seg > 0.4:
		_wall(b, Vector3(-(door_w * 0.5 + seg * 0.5), height * 0.5, d * 0.5), Vector3(seg, height, th), mat)
		_wall(b, Vector3(door_w * 0.5 + seg * 0.5, height * 0.5, d * 0.5), Vector3(seg, height, th), mat)
	_wall(b, Vector3(0.0, (height + door_h) * 0.5, d * 0.5), Vector3(door_w, height - door_h, th), mat)

	# Roof cap.
	_decor_box(b, Vector3(0.0, height + 0.15, 0.0), Vector3(w + 0.4, 0.3, d + 0.4), mat)

	# Window facades (appended to the city-wide MultiMesh, in world space).
	var c := Vector3(pos.x, pos.y + height * 0.5, pos.z)
	_face_windows(c + Vector3(0.0, 0.0, -d * 0.5), Vector3(0.0, 0.0, -1.0), w, height, win_t, win_c, rng, false)
	_face_windows(c + Vector3(0.0, 0.0, d * 0.5), Vector3(0.0, 0.0, 1.0), w, height, win_t, win_c, rng, true)
	_face_windows(c + Vector3(-w * 0.5, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), d, height, win_t, win_c, rng, false)
	_face_windows(c + Vector3(w * 0.5, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), d, height, win_t, win_c, rng, false)


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
