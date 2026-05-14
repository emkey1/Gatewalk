extends RefCounted
class_name FlowerFactory

const FLOWER_COUNT_BASE: int = 520


static func scatter_flowers(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, grid_size: int, cell_size: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "flowers"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(FLOWER_COUNT_BASE) * dmult)

	var root := Node3D.new()
	root.name = "Flowers"
	parent.add_child(root)

	var half: float = float(grid_size) * cell_size * 0.44
	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, water_level, height_fn)
		if pos.distance_to(Vector3.ZERO) < 7.0 or pos.y > 9.0:
			continue

		var flower := Node3D.new()
		flower.name = "WildflowerPatch_" + str(i)
		flower.position = pos
		flower.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		var stem_mat := StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.12, 0.35, 0.09)

		var blossom_mat := StandardMaterial3D.new()
		var palette: Array[Color] = [Color(0.95, 0.78, 0.18), Color(0.8, 0.25, 0.75), Color(0.95, 0.35, 0.25), Color(0.85, 0.9, 1.0)]
		blossom_mat.albedo_color = palette[rng.randi_range(0, palette.size() - 1)]

		var stem_count: int = rng.randi_range(3, 7)
		for j in range(stem_count):
			var stem := MeshInstance3D.new()
			var stem_mesh := CylinderMesh.new()
			stem_mesh.top_radius = 0.025
			stem_mesh.bottom_radius = 0.035
			stem_mesh.height = rng.randf_range(0.25, 0.55)
			stem.mesh = stem_mesh
			stem.material_override = stem_mat
			stem.position = Vector3(rng.randf_range(-0.35, 0.35), stem_mesh.height * 0.5, rng.randf_range(-0.35, 0.35))

			var blossom := MeshInstance3D.new()
			var blossom_mesh := SphereMesh.new()
			blossom_mesh.radius = rng.randf_range(0.07, 0.13)
			blossom_mesh.height = blossom_mesh.radius * 0.6
			blossom.mesh = blossom_mesh
			blossom.material_override = blossom_mat
			blossom.position = stem.position + Vector3(0.0, stem_mesh.height * 0.55, 0.0)

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
