extends RefCounted
class_name FlowerFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")
const FLOWER_COUNT_BASE: int = 520

const PALETTE: Array[Color] = [
	Color(0.95, 0.78, 0.18), Color(0.8, 0.25, 0.75), Color(0.95, 0.35, 0.25), Color(0.85, 0.9, 1.0)
]

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func clear_cache() -> void:
	_mesh_cache.clear()
	_material_cache.clear()


static func scatter_flowers(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> void:
	_scatter_flowers_internal(
		parent,
		world_seed,
		density_level,
		context.water_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_flowers_internal(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "flowers"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(FLOWER_COUNT_BASE) * dmult)

	# One MultiMesh for all stems (shared green) and one for all blossoms (per-instance
	# palette color), replacing ~5000 individual MeshInstance3D nodes.
	var stem_transforms: Array[Transform3D] = []
	var blossom_transforms: Array[Transform3D] = []
	var blossom_colors: Array[Color] = []

	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, water_level, height_fn)
		if pos.distance_to(Vector3.ZERO) < 7.0 or pos.y > 9.0:
			continue

		# Draw order preserved from the original per-node version for determinism.
		var rot_y: float = rng.randf_range(0.0, 360.0)
		var patch_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(rot_y), 0.0))
		var blossom_color: Color = PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
		var stem_count: int = rng.randi_range(3, 7)
		for j in range(stem_count):
			var stem_height: float = rng.randf_range(0.25, 0.55)
			var lx: float = rng.randf_range(-0.35, 0.35)
			var lz: float = rng.randf_range(-0.35, 0.35)
			var blossom_radius: float = rng.randf_range(0.07, 0.13)

			var stem_local := Vector3(lx, stem_height * 0.5, lz)
			var stem_origin: Vector3 = pos + patch_basis * stem_local
			stem_transforms.append(Transform3D(patch_basis.scaled(Vector3(1.0, stem_height, 1.0)), stem_origin))

			var blossom_local := stem_local + Vector3(0.0, stem_height * 0.55, 0.0)
			var blossom_origin: Vector3 = pos + patch_basis * blossom_local
			var blossom_basis := patch_basis.scaled(Vector3(blossom_radius, blossom_radius * 0.3, blossom_radius))
			blossom_transforms.append(Transform3D(blossom_basis, blossom_origin))
			blossom_colors.append(blossom_color)

	var root := Node3D.new()
	root.name = "Flowers"
	parent.add_child(root)
	if stem_transforms.is_empty():
		return

	MultiMeshScatter.build(root, "FlowerStems", _get_unit_stem_mesh(), _get_flower_material(Color(0.12, 0.35, 0.09)), stem_transforms)
	MultiMeshScatter.build(root, "FlowerBlossoms", _get_unit_blossom_mesh(), MultiMeshScatter.instance_color_material(0.6), blossom_transforms, blossom_colors)


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
		if y >= water_level + 0.45:
			return Vector3(x, y, z)
	var x: float = rng.randf_range(-half, half)
	var z: float = rng.randf_range(-half, half)
	return Vector3(x, height_fn.call(x, z), z)


static func _color_key(color: Color) -> String:
	return "%d,%d,%d" % [int(round(color.r * 1000.0)), int(round(color.g * 1000.0)), int(round(color.b * 1000.0))]


static func _get_flower_material(color: Color) -> StandardMaterial3D:
	var key: String = "mat|" + _color_key(color)
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_material_cache[key] = mat
	return mat


static func _get_unit_stem_mesh() -> CylinderMesh:
	const KEY := "unit_stem"
	if _mesh_cache.has(KEY):
		return _mesh_cache[KEY] as CylinderMesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.035
	mesh.height = 1.0
	mesh.radial_segments = 8
	_mesh_cache[KEY] = mesh
	return mesh


static func _get_unit_blossom_mesh() -> SphereMesh:
	const KEY := "unit_blossom"
	if _mesh_cache.has(KEY):
		return _mesh_cache[KEY] as SphereMesh
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 6
	_mesh_cache[KEY] = mesh
	return mesh
