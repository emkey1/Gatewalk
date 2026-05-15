extends RefCounted
class_name UnderwaterPlantFactory

const MapContext = preload("res://scripts/core/MapContext.gd")

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}

static func clear_cache() -> void:
	_mesh_cache.clear()
	_material_cache.clear()

static func scatter_plants(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> void:
	_scatter_plants_internal(
		parent,
		world_seed,
		density_level,
		context.water_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_plants_internal(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "underwater_plants"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(520.0 * 0.3 * dmult)

	var root := Node3D.new()
	root.name = "WaterPlants"
	parent.add_child(root)

	for i in range(count):
		var pos: Vector3 = _random_underwater_position(rng, half, water_level, height_fn)
		if pos.y < water_level - 7.0:
			continue

		var stem_height: float = rng.randf_range(0.3, 1.8)
		var stem_color := Color(rng.randf_range(0.06, 0.20), rng.randf_range(0.20, 0.40), rng.randf_range(0.04, 0.12))
		var mat := _get_plant_material(stem_color)

		var stem := MeshInstance3D.new()
		stem.name = "WaterPlant_" + str(i)
		var stem_mesh := _get_cylinder_mesh(0.02, 0.04, stem_height, 8)
		stem.mesh = stem_mesh
		stem.material_override = mat
		stem.position = pos + Vector3(0.0, stem_height * 0.5, 0.0)
		root.add_child(stem)


static func _density_mult(level: int) -> float:
	match level:
		0: return 0.4
		1: return 0.7
		_: return 1.0


static func _random_underwater_position(rng: StableRng, half: float, water_level: float, height_fn: Callable) -> Vector3:
	for attempt in range(30):
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = height_fn.call(x, z)
		if y <= water_level - 0.2:
			return Vector3(x, y, z)
	var x: float = rng.randf_range(-half, half)
	var z: float = rng.randf_range(-half, half)
	return Vector3(x, height_fn.call(x, z), z)


static func _qf(value: float) -> float:
	return round(value * 1000.0) / 1000.0


static func _color_key(color: Color) -> String:
	return "%s,%s,%s,%s" % [_qf(color.r), _qf(color.g), _qf(color.b), _qf(color.a)]


static func _get_plant_material(color: Color) -> StandardMaterial3D:
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
