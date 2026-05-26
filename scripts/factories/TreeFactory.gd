extends RefCounted
class_name TreeFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const TREE_COUNT_BASE: int = 720

static var _material_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func clear_cache() -> void:
	_material_cache.clear()
	_mesh_cache.clear()


static func scatter_trees(parent: Node3D, world_seed: int, density_level: int, graphics_level: int, context: MapContext, density_scale: float = 1.0) -> void:
	_scatter_trees_internal(
		parent,
		world_seed,
		density_level,
		graphics_level,
		context.map_type,
		density_scale,
		context.water_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_trees_internal(parent: Node3D, world_seed: int, density_level: int, graphics_level: int, map_type: String, density_scale: float, water_level: float, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "trees"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(TREE_COUNT_BASE) * dmult * clamp(density_scale, 0.02, 2.0))

	var root := Node3D.new()
	root.name = "Trees"
	parent.add_child(root)

	var trunk_seg: int = [8, 14, 22, 32][clampi(graphics_level, 0, 3)]
	var leaf_seg: int = [12, 18, 28, 40][clampi(graphics_level, 0, 3)]
	var leaf_rings: int = [6, 10, 16, 24][clampi(graphics_level, 0, 3)]
	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, water_level, height_fn)
		if map_type == "floating_island" and not _is_floating_tree_spot_valid(pos, water_level, height_fn):
			continue
		if pos.distance_to(Vector3.ZERO) < 8.0:
			continue

		var kind: String = _tree_kind_for_position(world_seed, pos, map_type, rng)

		var tree := Node3D.new()
		tree.name = "Tree_" + str(i)
		var y_offset: float = -0.15
		if map_type == "floating_island":
			y_offset = 0.06
		tree.position = Vector3(pos.x, pos.y + y_offset, pos.z)
		tree.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)

		root.add_child(tree)
		_build_tree_visual(tree, kind, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos, map_type)


static func _density_mult(level: int) -> float:
	match level:
		0: return 0.4
		1: return 0.7
		_: return 1.0


static func _random_land_position(rng: StableRng, half: float, water_level: float, height_fn: Callable) -> Vector3:
	for attempt in range(18):
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = height_fn.call(x, z)
		if y >= water_level + 0.35:
			return Vector3(x, y, z)
	var x: float = rng.randf_range(-half, half)
	var z: float = rng.randf_range(-half, half)
	return Vector3(x, height_fn.call(x, z), z)


static func _is_floating_tree_spot_valid(pos: Vector3, water_level: float, height_fn: Callable) -> bool:
	if pos.y < water_level + 0.35:
		return false
	var sample_offsets: Array[Vector2] = [
		Vector2(1.8, 0.0), Vector2(-1.8, 0.0),
		Vector2(0.0, 1.8), Vector2(0.0, -1.8)
	]
	var min_h: float = pos.y
	var max_h: float = pos.y
	for off in sample_offsets:
		var sy: float = float(height_fn.call(pos.x + off.x, pos.z + off.y))
		if sy < water_level + 0.20:
			return false
		min_h = min(min_h, sy)
		max_h = max(max_h, sy)
	return (max_h - min_h) <= 1.4


static func _tree_kind_for_position(world_seed: int, pos: Vector3, map_type: String, rng: StableRng) -> String:
	if map_type == "arctic":
		if pos.y > 6.0:
			return "pine"
		return "sparse" if rng.randf() < 0.35 else "pine"
	var biome_seed: int = StableRng.mix_seed(world_seed, int(pos.x * 10.0), int(pos.z * 10.0), 0x3151)
	var biome_rng := StableRng.new(biome_seed)
	var biome: float = biome_rng.randf() * 2.0 - 1.0
	if pos.y > 9.0:
		return "pine"
	if biome > 0.35:
		return "broadleaf"
	if biome < -0.35:
		return "sparse"
	return "round"


static func _build_tree_visual(tree: Node3D, kind: String, trunk_seg: int, leaf_seg: int, leaf_rings: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3, map_type: String) -> void:
	match kind:
		"pine": _build_pine_tree(tree, trunk_seg, leaf_seg, density_level, graphics_level, rng, world_seed, pos, map_type)
		"broadleaf": _build_broadleaf_tree(tree, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos, map_type)
		"round": _build_round_tree(tree, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos, map_type)
		"sparse": _build_sparse_tree(tree, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos, map_type)
		_: _build_round_tree(tree, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos, map_type)


static func _get_tree_material(key: String, color: Color) -> StandardMaterial3D:
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	_material_cache[key] = mat
	return mat


static func _build_pine_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3, map_type: String) -> void:
	var trunk_height: float = rng.randf_range(2.5, 4.0)
	var trunk_mat: StandardMaterial3D = _get_tree_material("pine_trunk", Color(0.38, 0.22, 0.10))
	var leaf_color: Color = Color.from_hsv(0.30, rng.randf_range(0.50, 0.75), rng.randf_range(0.35, 0.55))
	if map_type == "arctic":
		leaf_color = Color.from_hsv(0.50, rng.randf_range(0.25, 0.45), rng.randf_range(0.45, 0.62))
	var leaf_mat: StandardMaterial3D = _get_tree_material("pine_leaf_" + _color_key(leaf_color), leaf_color)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := _get_cylinder_mesh(0.18, 0.30, trunk_height, [6, 8, 12, 18][clampi(graphics_level, 0, 3)])
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	var layer_count: int = [4, 5, 6][clampi(density_level, 0, 2)]
	var cone_seg: int = [8, 12, 18, 26][clampi(graphics_level, 0, 3)]
	for i in range(layer_count):
		var cone_radius: float = rng.randf_range(0.8, 1.4) * (1.0 - float(i) * 0.10)
		var cone := MeshInstance3D.new()
		var cone_mesh := _get_cylinder_mesh(0.0, cone_radius, rng.randf_range(1.0, 1.6), cone_seg)
		cone.mesh = cone_mesh
		cone.material_override = leaf_mat
		cone.position.y = trunk_height * 0.5 + float(i) * 0.7
		tree.add_child(cone)


static func _build_broadleaf_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3, map_type: String) -> void:
	var trunk_height: float = rng.randf_range(2.8, 4.0)
	var trunk_mat: StandardMaterial3D = _get_tree_material("broad_trunk", Color(0.35, 0.20, 0.08))
	var leaf_color: Color = _build_leaf_color(world_seed, pos, rng)
	leaf_color.s = rng.randf_range(0.75, 1.0)
	leaf_color.v = rng.randf_range(0.60, 0.90)
	var leaf_mat: StandardMaterial3D = _get_tree_material("broad_leaf_" + _color_key(leaf_color), leaf_color)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := _get_cylinder_mesh(0.18, 0.30, trunk_height, [6, 8, 12, 18][clampi(graphics_level, 0, 3)])
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	_build_branches(tree, trunk_height, trunk_seg, trunk_mat, density_level, graphics_level, rng)

	var blob_count: int = [4, 6, 9][clampi(density_level, 0, 2)]
	for ri in range(blob_count):
		var blob := MeshInstance3D.new()
		var br: float = rng.randf_range(0.75, 1.35)
		var blob_mesh := _get_sphere_mesh(br, br * rng.randf_range(1.1, 1.7), [8, 10, 14, 18][clampi(graphics_level, 0, 3)], [6, 8, 10, 14][clampi(graphics_level, 0, 3)])
		blob.mesh = blob_mesh
		blob.material_override = leaf_mat
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(0.8, 1.35)
		var elev: float = rng.randf_range(-0.2, 1.0)
		blob.position = Vector3(cos(angle) * dist, trunk_height * 0.925 + 0.25 + elev, sin(angle) * dist)
		blob.scale = Vector3(rng.randf_range(0.8, 1.35), rng.randf_range(0.7, 1.15), rng.randf_range(0.8, 1.35))
		tree.add_child(blob)


static func _build_round_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3, map_type: String) -> void:
	var trunk_height: float = rng.randf_range(2.0, 3.3)
	var trunk_mat: StandardMaterial3D = _get_tree_material("round_trunk", Color(0.32, 0.19, 0.09))
	var leaf_color: Color = _build_leaf_color(world_seed, pos, rng)
	var leaf_mat: StandardMaterial3D = _get_tree_material("round_leaf_" + _color_key(leaf_color), leaf_color)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := _get_cylinder_mesh(0.18, 0.30, trunk_height, [6, 8, 12, 18][clampi(graphics_level, 0, 3)])
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	_build_branches(tree, trunk_height, trunk_seg, trunk_mat, density_level, graphics_level, rng)

	var blob_count: int = [3, 5, 7][clampi(density_level, 0, 2)]
	var ball_radius: float = rng.randf_range(1.0, 1.7)
	var ball := MeshInstance3D.new()
	var ball_mesh := _get_sphere_mesh(ball_radius, ball_radius * rng.randf_range(1.1, 1.7), [8, 10, 14, 18][clampi(graphics_level, 0, 3)], [6, 8, 10, 14][clampi(graphics_level, 0, 3)])
	ball.mesh = ball_mesh
	ball.material_override = leaf_mat
	ball.position.y = trunk_height + ball_radius * 0.4
	tree.add_child(ball)

	_build_leaf_blobs(tree, blob_count, trunk_height * 0.925 + 0.25, 1.0, leaf_seg, leaf_rings, leaf_mat, graphics_level, rng)


static func _build_sparse_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3, map_type: String) -> void:
	var trunk_height: float = rng.randf_range(3.0, 4.5)
	var trunk_mat: StandardMaterial3D = _get_tree_material("sparse_trunk", Color(0.35, 0.22, 0.10))
	var leaf_color: Color = _build_leaf_color(world_seed, pos, rng)
	leaf_color.s *= 0.6
	leaf_color.v *= 0.7
	var leaf_mat: StandardMaterial3D = _get_tree_material("sparse_leaf_" + _color_key(leaf_color), leaf_color)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := _get_cylinder_mesh(0.18, 0.30, trunk_height, [6, 8, 12, 18][clampi(graphics_level, 0, 3)])
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	_build_branches(tree, trunk_height, trunk_seg, trunk_mat, density_level, graphics_level, rng)
	var blob_count: int = [3, 5, 7][clampi(density_level, 0, 2)]
	_build_leaf_blobs(tree, blob_count, trunk_height * 0.925 + 0.25, 0.7, leaf_seg, leaf_rings, leaf_mat, graphics_level, rng)


static func _build_branches(tree: Node3D, trunk_height: float, trunk_seg: int, trunk_mat: StandardMaterial3D, density_level: int, graphics_level: int, rng: StableRng) -> void:
	var branch_count: int = [4, 6, 9][clampi(density_level, 0, 2)]
	var branch_seg: int = [6, 8, 10, 14][clampi(graphics_level, 0, 3)]
	for bi in range(branch_count):
		var branch := MeshInstance3D.new()
		var branch_mesh := _get_cylinder_mesh(0.04, 0.10, rng.randf_range(0.8, 1.8), branch_seg)
		branch.mesh = branch_mesh
		branch.material_override = trunk_mat
		var angle: float = rng.randf_range(0.0, TAU)
		var y_frac: float = rng.randf_range(0.35, 0.85)
		var tilt: float = deg_to_rad(rng.randf_range(25.0, 50.0))
		var dir: Vector3 = Vector3(cos(angle) * cos(tilt), sin(tilt), sin(angle) * cos(tilt))
		var half_len: float = branch_mesh.height * 0.5
		branch.position = Vector3(cos(angle) * 0.19 + dir.x * half_len, trunk_height * y_frac + dir.y * half_len, sin(angle) * 0.19 + dir.z * half_len)
		branch.quaternion = Quaternion(Vector3(0.0, 1.0, 0.0), dir)
		tree.add_child(branch)


static func _build_leaf_blobs(tree: Node3D, count: int, center_y: float, spread: float, leaf_seg: int, leaf_rings: int, leaf_mat: StandardMaterial3D, graphics_level: int, rng: StableRng) -> void:
	for bi in range(count):
		var blob := MeshInstance3D.new()
		var br: float = rng.randf_range(0.75, 1.35) * spread
		var blob_mesh := _get_sphere_mesh(br, br * rng.randf_range(1.1, 1.7), leaf_seg, leaf_rings)
		blob.mesh = blob_mesh
		blob.material_override = leaf_mat
		blob.position = Vector3(rng.randf_range(-0.5, 0.5), center_y + rng.randf_range(-0.2, 1.0), rng.randf_range(-0.5, 0.5))
		blob.scale = Vector3(rng.randf_range(0.8, 1.35), rng.randf_range(0.7, 1.15), rng.randf_range(0.8, 1.35))
		tree.add_child(blob)


static func _build_leaf_color(world_seed: int, pos: Vector3, rng: StableRng) -> Color:
	var biome_seed: int = StableRng.mix_seed(world_seed, int(pos.x * 10.0), int(pos.z * 10.0), 0x3177)
	var biome_rng := StableRng.new(biome_seed)
	var biome: float = biome_rng.randf() * 2.0 - 1.0
	var hue_shift: float = rng.randf_range(-0.035, 0.035)
	var sat: float = rng.randf_range(0.65, 0.95)
	var val: float = rng.randf_range(0.55, 0.85)
	if pos.y > 8.0:
		return Color.from_hsv(0.30 + hue_shift, sat * 0.8, val * 0.7)
	if biome > 0.25:
		return Color.from_hsv(0.28 + hue_shift, sat, val)
	return Color.from_hsv(0.32 + hue_shift, sat * 0.8, val * 0.8)


static func _qf(value: float) -> float:
	return round(value * 1000.0) / 1000.0


static func _color_key(color: Color) -> String:
	return "%s,%s,%s,%s" % [_qf(color.r), _qf(color.g), _qf(color.b), _qf(color.a)]


static func _mesh_key(parts: Array) -> String:
	var out := PackedStringArray()
	for p in parts:
		out.append(str(p))
	return "|".join(out)


static func _get_cylinder_mesh(top_radius: float, bottom_radius: float, height: float, radial_segments: int) -> CylinderMesh:
	var key: String = _mesh_key(["cyl", _qf(top_radius), _qf(bottom_radius), _qf(height), radial_segments])
	if _mesh_cache.has(key):
		return _mesh_cache[key] as CylinderMesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	_mesh_cache[key] = mesh
	return mesh


static func _get_sphere_mesh(radius: float, height: float, radial_segments: int, rings: int) -> SphereMesh:
	var key: String = _mesh_key(["sph", _qf(radius), _qf(height), radial_segments, rings])
	if _mesh_cache.has(key):
		return _mesh_cache[key] as SphereMesh
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	_mesh_cache[key] = mesh
	return mesh
