extends RefCounted
class_name FlowerFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const FLOWER_COUNT_BASE: int = 520

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

	var root := Node3D.new()
	root.name = "Flowers"
	parent.add_child(root)

	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, water_level, height_fn)
		if pos.distance_to(Vector3.ZERO) < 7.0 or pos.y > 9.0:
			continue

		var flower := Node3D.new()
		flower.name = "WildflowerPatch_" + str(i)
		flower.position = pos
		flower.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		var palette: Array[Color] = [Color(0.95, 0.78, 0.18), Color(0.8, 0.25, 0.75), Color(0.95, 0.35, 0.25), Color(0.85, 0.9, 1.0)]
		var stem_mat := _get_flower_material(Color(0.12, 0.35, 0.09))
		var blossom_mat := _get_flower_material(palette[rng.randi_range(0, palette.size() - 1)])

		var stem_count: int = rng.randi_range(3, 7)
		for j in range(stem_count):
			var stem := MeshInstance3D.new()
			var stem_height: float = rng.randf_range(0.25, 0.55)
			var stem_mesh := _get_cylinder_mesh(0.025, 0.035, stem_height, 8)
			stem.mesh = stem_mesh
			stem.material_override = stem_mat
			stem.position = Vector3(rng.randf_range(-0.35, 0.35), stem_height * 0.5, rng.randf_range(-0.35, 0.35))

			var blossom := MeshInstance3D.new()
			var blossom_radius: float = rng.randf_range(0.07, 0.13)
			var blossom_mesh := _get_sphere_mesh(blossom_radius, blossom_radius * 0.6, 8, 6)
			blossom.mesh = blossom_mesh
			blossom.material_override = blossom_mat
			blossom.position = stem.position + Vector3(0.0, stem_height * 0.55, 0.0)

			flower.add_child(stem)
			flower.add_child(blossom)

		root.add_child(flower)


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


static func _qf(value: float) -> float:
	return round(value * 1000.0) / 1000.0


static func _color_key(color: Color) -> String:
	return "%s,%s,%s,%s" % [_qf(color.r), _qf(color.g), _qf(color.b), _qf(color.a)]


static func _get_flower_material(color: Color) -> StandardMaterial3D:
	var key: String = "mat|" + _color_key(color)
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_material_cache[key] = mat
	return mat


static func _get_cylinder_mesh(top_radius: float, bottom_radius: float, height: float, radial_segments: int) -> CylinderMesh:
	var key: String = "cyl|%s|%s|%s|%d" % [_qf(top_radius), _qf(bottom_radius), _qf(height), radial_segments]
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
	var key: String = "sph|%s|%s|%d|%d" % [_qf(radius), _qf(height), radial_segments, rings]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as SphereMesh
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	_mesh_cache[key] = mesh
	return mesh
