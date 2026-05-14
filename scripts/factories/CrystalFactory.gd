extends RefCounted
class_name CrystalFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const CRYSTAL_COUNT_BASE: int = 42

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func scatter_crystals(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> void:
	_scatter_crystals_internal(
		parent,
		world_seed,
		density_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_crystals_internal(parent: Node3D, world_seed: int, density_level: int, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "crystals"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(CRYSTAL_COUNT_BASE) * dmult)

	var root := Node3D.new()
	root.name = "Crystals"
	parent.add_child(root)

	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, height_fn)
		if pos.distance_to(Vector3.ZERO) < 15.0:
			continue

		var cluster := Node3D.new()
		cluster.name = "CrystalCluster_" + str(i)
		cluster.position = pos
		cluster.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		var mat := _get_crystal_material()

		var cseg: int = [6, 10, 16][clampi(density_level, 0, 2)]
		var crystal_count: int = rng.randi_range(3, 6)
		for j in range(crystal_count):
			var crystal := MeshInstance3D.new()
			var top_radius: float = rng.randf_range(0.04, 0.10)
			var bottom_radius: float = rng.randf_range(0.22, 0.42)
			var height: float = rng.randf_range(1.0, 2.4)
			var mesh := _get_cylinder_mesh(top_radius, bottom_radius, height, cseg)
			crystal.mesh = mesh
			crystal.material_override = mat
			crystal.position = Vector3(rng.randf_range(-1.0, 1.0), mesh.height * 0.5, rng.randf_range(-1.0, 1.0))
			crystal.rotation_degrees = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 360.0), rng.randf_range(-8.0, 8.0))
			cluster.add_child(crystal)

		root.add_child(cluster)


static func _density_mult(level: int) -> float:
	match level:
		0: return 0.4
		1: return 0.7
		_: return 1.0


static func _random_land_position(rng: StableRng, half: float, height_fn: Callable) -> Vector3:
	for attempt in range(18):
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = height_fn.call(x, z)
		if y >= 1.5:
			return Vector3(x, y, z)
	var x: float = rng.randf_range(-half, half)
	var z: float = rng.randf_range(-half, half)
	return Vector3(x, height_fn.call(x, z), z)


static func _qf(value: float) -> float:
	return round(value * 1000.0) / 1000.0


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


static func _get_crystal_material() -> StandardMaterial3D:
	const KEY := "crystal_default"
	if _material_cache.has(KEY):
		return _material_cache[KEY] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.45, 0.75)
	mat.roughness = 0.25
	_material_cache[KEY] = mat
	return mat
