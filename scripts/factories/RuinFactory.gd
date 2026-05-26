extends RefCounted
class_name RuinFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const RUIN_COUNT_BASE: int = 14


static func scatter_ruins(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> void:
	_scatter_ruins_internal(
		parent,
		world_seed,
		density_level,
		context.map_type,
		context.water_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_ruins_internal(parent: Node3D, world_seed: int, density_level: int, map_type: String, water_level: float, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "ruins"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(RUIN_COUNT_BASE) * dmult)

	var root := Node3D.new()
	root.name = "Ruins"
	parent.add_child(root)

	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, water_level, height_fn)
		if map_type == "floating_island" and not _is_floating_spot_valid(pos, water_level, height_fn, 3.0):
			continue
		if pos.distance_to(Vector3.ZERO) < 30.0:
			continue

		var ruin := Node3D.new()
		ruin.name = "AncientRuin_" + str(i)
		ruin.position = pos
		ruin.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		var mat := StandardMaterial3D.new()
		var tone: float = rng.randf_range(0.38, 0.52)
		mat.albedo_color = Color(tone, tone * 0.95, tone * 0.85)
		mat.roughness = 1.0

		var pillar_count: int = rng.randi_range(3, 6)
		for j in range(pillar_count):
			var angle: float = TAU * float(j) / float(pillar_count)
			var radius: float = rng.randf_range(2.2, 3.8)
			var height: float = rng.randf_range(1.2, 3.6)

			var pillar := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(rng.randf_range(0.45, 0.75), height, rng.randf_range(0.45, 0.75))
			pillar.mesh = mesh
			pillar.material_override = mat
			pillar.position = Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius)
			pillar.rotation_degrees = Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(0.0, 360.0), rng.randf_range(-5.0, 5.0))
			ruin.add_child(pillar)

		var platform := MeshInstance3D.new()
		var platform_mesh := CylinderMesh.new()
		platform_mesh.top_radius = rng.randf_range(3.0, 4.5)
		platform_mesh.bottom_radius = platform_mesh.top_radius * 1.05
		platform_mesh.height = 0.25
		platform.mesh = platform_mesh
		platform.material_override = mat
		platform.position.y = 0.12
		ruin.add_child(platform)

		root.add_child(ruin)


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
		if y >= water_level + 1.0:
			return Vector3(x, y, z)
	var x: float = rng.randf_range(-half, half)
	var z: float = rng.randf_range(-half, half)
	return Vector3(x, height_fn.call(x, z), z)


static func _is_floating_spot_valid(pos: Vector3, water_level: float, height_fn: Callable, sample_radius: float) -> bool:
	if pos.y < water_level + 0.35:
		return false
	var sample_offsets: Array[Vector2] = [
		Vector2(sample_radius, 0.0), Vector2(-sample_radius, 0.0),
		Vector2(0.0, sample_radius), Vector2(0.0, -sample_radius)
	]
	var min_h: float = pos.y
	var max_h: float = pos.y
	for off in sample_offsets:
		var sy: float = float(height_fn.call(pos.x + off.x, pos.z + off.y))
		if sy < water_level + 0.2:
			return false
		min_h = min(min_h, sy)
		max_h = max(max_h, sy)
	return (max_h - min_h) <= 1.3
