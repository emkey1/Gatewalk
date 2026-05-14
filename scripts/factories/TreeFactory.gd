extends RefCounted
class_name TreeFactory

const TREE_COUNT_BASE: int = 720

static var _material_cache: Dictionary = {}


static func clear_cache() -> void:
	_material_cache.clear()


static func scatter_trees(parent: Node3D, world_seed: int, density_level: int, graphics_level: int, water_level: float, height_fn: Callable, grid_size: int, cell_size: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "trees"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(TREE_COUNT_BASE) * dmult)

	var root := Node3D.new()
	root.name = "Trees"
	parent.add_child(root)

	var half: float = float(grid_size) * cell_size * 0.44
	var trunk_seg: int = [8, 14, 22, 32][clampi(graphics_level, 0, 3)]
	var leaf_seg: int = [12, 18, 28, 40][clampi(graphics_level, 0, 3)]
	var leaf_rings: int = [6, 10, 16, 24][clampi(graphics_level, 0, 3)]
	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, water_level, height_fn)
		if pos.distance_to(Vector3.ZERO) < 8.0:
			continue

		var kind: String = _tree_kind_for_position(world_seed, pos, water_level, rng)

		var tree := Node3D.new()
		tree.name = "Tree_" + str(i)
		tree.position = Vector3(pos.x, pos.y - 0.15, pos.z)
		tree.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)

		root.add_child(tree)
		_build_tree_visual(tree, kind, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos)


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


static func _tree_kind_for_position(world_seed: int, pos: Vector3, water_level: float, rng: StableRng) -> String:
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


static func _build_tree_visual(tree: Node3D, kind: String, trunk_seg: int, leaf_seg: int, leaf_rings: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3) -> void:
	match kind:
		"pine": _build_pine_tree(tree, trunk_seg, leaf_seg, density_level, graphics_level, rng, world_seed, pos)
		"broadleaf": _build_broadleaf_tree(tree, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos)
		"round": _build_round_tree(tree, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos)
		"sparse": _build_sparse_tree(tree, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos)
		_: _build_round_tree(tree, trunk_seg, leaf_seg, leaf_rings, density_level, graphics_level, rng, world_seed, pos)


static func _get_tree_material(key: String, color: Color) -> StandardMaterial3D:
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	_material_cache[key] = mat
	return mat


static func _build_pine_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3) -> void:
	var trunk_height: float = rng.randf_range(2.5, 4.0)
	var trunk_mat: StandardMaterial3D = _get_tree_material("pine_trunk", Color(0.38, 0.22, 0.10))
	var leaf_color: Color = _build_leaf_color(world_seed, pos, rng)
	leaf_color = Color.from_hsv(0.30, rng.randf_range(0.50, 0.75), rng.randf_range(0.35, 0.55))
	var leaf_mat: StandardMaterial3D = _get_tree_material("pine_leaf_" + str(leaf_color), leaf_color)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.radial_segments = [6, 8, 12, 18][clampi(graphics_level, 0, 3)]
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.30
	trunk_mesh.height = trunk_height
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	var layer_count: int = [4, 5, 6][clampi(density_level, 0, 2)]
	var cone_seg: int = [8, 12, 18, 26][clampi(graphics_level, 0, 3)]
	for i in range(layer_count):
		var cone_radius: float = rng.randf_range(0.8, 1.4) * (1.0 - float(i) * 0.10)
		var cone := MeshInstance3D.new()
		var cone_mesh := CylinderMesh.new()
		cone_mesh.radial_segments = cone_seg
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = cone_radius
		cone_mesh.height = rng.randf_range(1.0, 1.6)
		cone.mesh = cone_mesh
		cone.material_override = leaf_mat
		cone.position.y = trunk_height * 0.5 + float(i) * 0.7
		tree.add_child(cone)


static func _build_broadleaf_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3) -> void:
	var trunk_height: float = rng.randf_range(2.8, 4.0)
	var trunk_mat: StandardMaterial3D = _get_tree_material("broad_trunk", Color(0.35, 0.20, 0.08))
	var leaf_color: Color = _build_leaf_color(world_seed, pos, rng)
	leaf_color.s = rng.randf_range(0.75, 1.0)
	leaf_color.v = rng.randf_range(0.60, 0.90)
	var leaf_mat: StandardMaterial3D = _get_tree_material("broad_leaf_" + str(leaf_color), leaf_color)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.radial_segments = [6, 8, 12, 18][clampi(graphics_level, 0, 3)]
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.30
	trunk_mesh.height = trunk_height
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	_build_branches(tree, trunk_height, trunk_seg, trunk_mat, density_level, graphics_level, rng)

	var blob_count: int = [4, 6, 9][clampi(density_level, 0, 2)]
	for ri in range(blob_count):
		var blob := MeshInstance3D.new()
		var blob_mesh := SphereMesh.new()
		blob_mesh.radial_segments = [8, 10, 14, 18][clampi(graphics_level, 0, 3)]
		blob_mesh.rings = [6, 8, 10, 14][clampi(graphics_level, 0, 3)]
		var br: float = rng.randf_range(0.75, 1.35)
		blob_mesh.radius = br
		blob_mesh.height = br * rng.randf_range(1.1, 1.7)
		blob.mesh = blob_mesh
		blob.material_override = leaf_mat
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(0.8, 1.35)
		var elev: float = rng.randf_range(-0.2, 1.0)
		blob.position = Vector3(cos(angle) * dist, trunk_height * 0.925 + 0.25 + elev, sin(angle) * dist)
		blob.scale = Vector3(rng.randf_range(0.8, 1.35), rng.randf_range(0.7, 1.15), rng.randf_range(0.8, 1.35))
		tree.add_child(blob)


static func _build_round_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3) -> void:
	var trunk_height: float = rng.randf_range(2.0, 3.3)
	var trunk_mat: StandardMaterial3D = _get_tree_material("round_trunk", Color(0.32, 0.19, 0.09))
	var leaf_color: Color = _build_leaf_color(world_seed, pos, rng)
	var leaf_mat: StandardMaterial3D = _get_tree_material("round_leaf_" + str(leaf_color), leaf_color)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.radial_segments = [6, 8, 12, 18][clampi(graphics_level, 0, 3)]
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.30
	trunk_mesh.height = trunk_height
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	_build_branches(tree, trunk_height, trunk_seg, trunk_mat, density_level, graphics_level, rng)

	var blob_count: int = [3, 5, 7][clampi(density_level, 0, 2)]
	var ball_radius: float = rng.randf_range(1.0, 1.7)
	var ball := MeshInstance3D.new()
	var ball_mesh := SphereMesh.new()
	ball_mesh.radial_segments = [8, 10, 14, 18][clampi(graphics_level, 0, 3)]
	ball_mesh.rings = [6, 8, 10, 14][clampi(graphics_level, 0, 3)]
	ball_mesh.radius = ball_radius
	ball_mesh.height = ball_radius * rng.randf_range(1.1, 1.7)
	ball.mesh = ball_mesh
	ball.material_override = leaf_mat
	ball.position.y = trunk_height + ball_radius * 0.4
	tree.add_child(ball)

	_build_leaf_blobs(tree, blob_count, trunk_height * 0.925 + 0.25, 1.0, leaf_seg, leaf_rings, leaf_mat, graphics_level, rng)


static func _build_sparse_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, density_level: int, graphics_level: int, rng: StableRng, world_seed: int, pos: Vector3) -> void:
	var trunk_height: float = rng.randf_range(3.0, 4.5)
	var trunk_mat: StandardMaterial3D = _get_tree_material("sparse_trunk", Color(0.35, 0.22, 0.10))
	var leaf_color: Color = _build_leaf_color(world_seed, pos, rng)
	leaf_color.s *= 0.6
	leaf_color.v *= 0.7
	var leaf_mat: StandardMaterial3D = _get_tree_material("sparse_leaf_" + str(leaf_color), leaf_color)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.radial_segments = [6, 8, 12, 18][clampi(graphics_level, 0, 3)]
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.30
	trunk_mesh.height = trunk_height
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
		var branch_mesh := CylinderMesh.new()
		branch_mesh.top_radius = 0.04
		branch_mesh.bottom_radius = 0.10
		branch_mesh.height = rng.randf_range(0.8, 1.8)
		branch_mesh.radial_segments = branch_seg
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
		var blob_mesh := SphereMesh.new()
		blob_mesh.radial_segments = leaf_seg
		blob_mesh.rings = leaf_rings
		var br: float = rng.randf_range(0.75, 1.35) * spread
		blob_mesh.radius = br
		blob_mesh.height = blob_mesh.radius * rng.randf_range(1.1, 1.7)
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
