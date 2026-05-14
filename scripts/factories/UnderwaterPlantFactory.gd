extends RefCounted
class_name UnderwaterPlantFactory


static func scatter_plants(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, grid_size: int, cell_size: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "underwater_plants"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(520.0 * 0.3 * dmult)

	var root := Node3D.new()
	root.name = "WaterPlants"
	parent.add_child(root)

	var half: float = float(grid_size) * cell_size * 0.44
	for i in range(count):
		var pos: Vector3 = _random_underwater_position(rng, half, water_level, height_fn)
		if pos.y < water_level - 7.0:
			continue

		var stem_height: float = rng.randf_range(0.3, 1.8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(rng.randf_range(0.06, 0.20), rng.randf_range(0.20, 0.40), rng.randf_range(0.04, 0.12))

		var stem := MeshInstance3D.new()
		stem.name = "WaterPlant_" + str(i)
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.02
		stem_mesh.bottom_radius = 0.04
		stem_mesh.height = stem_height
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
