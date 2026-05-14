extends RefCounted
class_name RockFactory

const ROCK_COUNT_BASE: int = 260


static func scatter_rocks(parent: Node3D, world_seed: int, density_level: int, water_level: float, height_fn: Callable, grid_size: int, cell_size: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "rocks"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(ROCK_COUNT_BASE) * dmult)

	var root := Node3D.new()
	root.name = "Rocks"
	parent.add_child(root)

	var half: float = float(grid_size) * cell_size * 0.44
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
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = rng.randf_range(0.4, 1.2)
		rock_mesh.height = rock_mesh.radius * rng.randf_range(0.65, 1.1)
		rock_mesh.radial_segments = rseg
		rock_mesh.rings = rrings
		visual.mesh = rock_mesh
		visual.position.y = rock_mesh.height * 0.25
		visual.scale = Vector3(rng.randf_range(1.0, 1.8), rng.randf_range(0.55, 1.0), rng.randf_range(1.0, 1.8))
		visual.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 360.0), rng.randf_range(-12.0, 12.0))

		var rock_mat := StandardMaterial3D.new()
		var gray: float = rng.randf_range(0.25, 0.50)
		rock_mat.albedo_color = Color(gray, gray, gray)
		rock_mat.roughness = 1.0
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
