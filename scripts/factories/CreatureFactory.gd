extends RefCounted
class_name CreatureFactory


static func scatter_birds(parent: Node3D, world_seed: int, height_fn: Callable, grid_size: int, cell_size: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "birds"))
	var half: float = float(grid_size) * cell_size * 0.44

	var placed := 0
	var attempts := 0
	while placed < 4 and attempts < 60:
		attempts += 1
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = height_fn.call(x, z)
		if y < -1.2:
			continue
		if Vector3(x, y, z).distance_to(Vector3.ZERO) < 60.0:
			continue

		var flock := preload("res://scripts/BirdFlock.gd").new()
		flock.name = "BirdFlock_" + str(placed)
		flock.position = Vector3(x, rng.randf_range(8.0, 18.0), z)
		flock.set("rng_seed", rng.next_u32())
		flock.set("bird_count", rng.randi_range(8, 15))
		parent.add_child(flock)
		placed += 1


static func scatter_fish(parent: Node3D, world_seed: int, height_fn: Callable, grid_size: int, cell_size: float, water_level: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "fish"))
	var half: float = float(grid_size) * cell_size * 0.44

	var placed := 0
	var target: int = 3
	var attempts := 0
	while placed < target and attempts < target * 15:
		attempts += 1
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var ground_y: float = height_fn.call(x, z)
		if ground_y > water_level - 0.2:
			continue
		if ground_y < water_level - 8.0:
			continue

		var school := preload("res://scripts/FishSchool.gd").new()
		school.name = "FishSchool_" + str(placed)
		var water_depth: float = water_level - ground_y
		var height_offset: float = rng.randf_range(0.3, 0.7)
		school.position = Vector3(x, ground_y + water_depth * height_offset, z)
		school.set("rng_seed", rng.next_u32())
		school.set("fish_count", rng.randi_range(10, 18))
		parent.add_child(school)
		placed += 1
