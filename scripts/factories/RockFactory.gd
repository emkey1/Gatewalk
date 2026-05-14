extends RefCounted
class_name RockFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const ROCK_COUNT_BASE: int = 260

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func scatter_rocks(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> void:
	_scatter_rocks_internal(
		parent,
		world_seed,
		density_level,
		context.water_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_rocks_internal(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "rocks"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(ROCK_COUNT_BASE) * dmult)

	var root := Node3D.new()
	root.name = "Rocks"
	parent.add_child(root)

	var rseg: int = [12, 18, 28][clampi(density_level, 0, 2)]
	var rrings: int = [6, 10, 16][clampi(density_level, 0, 2)]
	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, water_level, height_fn)
		if pos.distance_to(Vector3.ZERO) < 6.0:
			continue

		var rock := Node3D.new()
		rock.name = "Rock_" + str(i)
		rock.position = pos

		var visual := MeshInstance3D.new()
		visual.name = "RockVisual"
		var rock_radius: float = rng.randf_range(0.4, 1.2)
		var rock_height: float = rock_radius * rng.randf_range(0.65, 1.1)
		var rock_mesh := _get_sphere_mesh(rock_radius, rock_height, rseg, rrings)
		visual.mesh = rock_mesh
		visual.position.y = rock_mesh.height * 0.25
		visual.scale = Vector3(rng.randf_range(1.0, 1.8), rng.randf_range(0.55, 1.0), rng.randf_range(1.0, 1.8))
		visual.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 360.0), rng.randf_range(-12.0, 12.0))

		var gray: float = rng.randf_range(0.25, 0.50)
		var rock_mat := _get_rock_material(gray)
		visual.material_override = rock_mat

		rock.add_child(visual)
		root.add_child(rock)


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
		if y >= water_level + 0.2:
			return Vector3(x, y, z)
	var x: float = rng.randf_range(-half, half)
	var z: float = rng.randf_range(-half, half)
	return Vector3(x, height_fn.call(x, z), z)


static func _qf(value: float) -> float:
	return round(value * 1000.0) / 1000.0


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


static func _get_rock_material(gray: float) -> StandardMaterial3D:
	var key: String = "mat|%s" % [_qf(gray)]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(gray, gray, gray)
	mat.roughness = 1.0
	_material_cache[key] = mat
	return mat
