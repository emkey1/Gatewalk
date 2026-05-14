extends RefCounted
class_name CrystalFactory

const CRYSTAL_COUNT_BASE: int = 42


static func scatter_crystals(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, grid_size: int, cell_size: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "crystals"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(CRYSTAL_COUNT_BASE) * dmult)

	var root := Node3D.new()
	root.name = "Crystals"
	parent.add_child(root)

	var half: float = float(grid_size) * cell_size * 0.44
	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, height_fn)
		if pos.distance_to(Vector3.ZERO) < 15.0:
			continue

		var cluster := Node3D.new()
		cluster.name = "CrystalCluster_" + str(i)
		cluster.position = pos
		cluster.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.85, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.08, 0.45, 0.75)
		mat.roughness = 0.25

		var cseg: int = [6, 10, 16][clampi(density_level, 0, 2)]
		var crystal_count: int = rng.randi_range(3, 6)
		for j in range(crystal_count):
			var crystal := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = rng.randf_range(0.04, 0.10)
			mesh.bottom_radius = rng.randf_range(0.22, 0.42)
			mesh.height = rng.randf_range(1.0, 2.4)
			mesh.radial_segments = cseg
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
