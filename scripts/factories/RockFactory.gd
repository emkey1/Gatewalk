extends RefCounted
class_name RockFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")
const ROCK_COUNT_BASE: int = 260

static var _mesh_cache: Dictionary = {}


static func clear_cache() -> void:
	_mesh_cache.clear()


static func scatter_rocks(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> void:
	_scatter_rocks_internal(
		parent,
		world_seed,
		density_level,
		context.map_type,
		context.water_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_rocks_internal(parent: Node3D, world_seed: int, density_level: int, map_type: String, water_level: float, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "rocks"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(ROCK_COUNT_BASE) * dmult)

	var rseg: int = [12, 18, 28][clampi(density_level, 0, 2)]
	var rrings: int = [6, 10, 16][clampi(density_level, 0, 2)]

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var collider_positions: Array[Vector3] = []
	var collider_radii: Array[float] = []

	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, water_level, height_fn)
		if map_type == "floating_island" and not _is_floating_spot_valid(pos, water_level, height_fn, 2.2):
			continue
		if pos.distance_to(Vector3.ZERO) < 6.0:
			continue

		# Draw order preserved from the original per-node version so the seed produces
		# the identical layout — only the render container changes (MultiMesh).
		var rock_radius: float = rng.randf_range(0.4, 1.2)
		var rock_height: float = rock_radius * rng.randf_range(0.65, 1.1)
		var sx: float = rng.randf_range(1.0, 1.8)
		var sy: float = rng.randf_range(0.55, 1.0)
		var sz: float = rng.randf_range(1.0, 1.8)
		var rx: float = rng.randf_range(-12.0, 12.0)
		var ry: float = rng.randf_range(0.0, 360.0)
		var rz: float = rng.randf_range(-12.0, 12.0)
		var gray: float = rng.randf_range(0.25, 0.50)

		# A unit sphere (radius 1, height 2) scaled to (radius, height/2, radius) and
		# the per-rock visual scale reproduces the old SphereMesh(radius, height) * scale.
		var scale_v := Vector3(rock_radius * sx, rock_height * 0.5 * sy, rock_radius * sz)
		var basis := Basis.from_euler(Vector3(deg_to_rad(rx), deg_to_rad(ry), deg_to_rad(rz))).scaled(scale_v)
		var origin := Vector3(pos.x, pos.y + rock_height * 0.25, pos.z)
		transforms.append(Transform3D(basis, origin))
		colors.append(Color(gray, gray, gray))
		collider_positions.append(origin)
		collider_radii.append(maxf(rock_radius * sx, rock_radius * sz))

	var root := Node3D.new()
	root.name = "Rocks"
	parent.add_child(root)
	if transforms.is_empty():
		return

	MultiMeshScatter.build(root, "RockMesh", _get_unit_sphere_mesh(rseg, rrings), MultiMeshScatter.instance_color_material(1.0), transforms, colors)
	_build_colliders(root, collider_positions, collider_radii)


static func _build_colliders(root: Node3D, positions: Array[Vector3], radii: Array[float]) -> void:
	var body := StaticBody3D.new()
	body.name = "RockColliders"
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)
	for i in range(positions.size()):
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = maxf(radii[i], 0.25)
		cs.shape = shape
		cs.position = positions[i]
		body.add_child(cs)


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
	return (max_h - min_h) <= 1.6


static func _get_unit_sphere_mesh(radial_segments: int, rings: int) -> SphereMesh:
	var key: String = "unit|%d|%d" % [radial_segments, rings]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as SphereMesh
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	_mesh_cache[key] = mesh
	return mesh
