extends RefCounted
class_name CrystalFactory

const MapContext = preload("res://scripts/core/MapContext.gd")
const MultiMeshScatter = preload("res://scripts/factories/MultiMeshScatter.gd")
const CRYSTAL_COUNT_BASE: int = 42
# Representative taper for the shared MultiMesh mesh. Per-crystal bottom_radius is
# baked into the horizontal scale; the top/bottom ratio is fixed (a tiny visual
# approximation — imperceptible on glowing spike clusters).
const REF_BOTTOM_RADIUS: float = 0.32
const REF_TOP_RADIUS: float = 0.07

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func clear_cache() -> void:
	_mesh_cache.clear()
	_material_cache.clear()


static func scatter_crystals(parent: Node3D, world_seed: int, density_level: int, context: MapContext) -> void:
	_scatter_crystals_internal(
		parent,
		world_seed,
		density_level,
		context.map_type,
		context.water_level,
		Callable(context, "height_at_world"),
		context.world_half_size() * 0.88
	)


static func _scatter_crystals_internal(parent: Node3D, world_seed: int, density_level: int, map_type: String, water_level: float, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "crystals"))
	var dmult: float = _density_mult(density_level)
	var count: int = int(float(CRYSTAL_COUNT_BASE) * dmult)
	var cseg: int = [6, 10, 16][clampi(density_level, 0, 2)]

	var transforms: Array[Transform3D] = []
	var collider_origins: Array[Vector3] = []
	var collider_radii: Array[float] = []
	var collider_heights: Array[float] = []

	for i in range(count):
		var pos: Vector3 = _random_land_position(rng, half, height_fn)
		if map_type == "floating_island" and not _is_floating_spot_valid(pos, water_level, height_fn, 2.0):
			continue
		if pos.distance_to(Vector3.ZERO) < 15.0:
			continue

		var cluster_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(rng.randf_range(0.0, 360.0)), 0.0))
		var crystal_count: int = rng.randi_range(3, 6)
		for j in range(crystal_count):
			# Draw order preserved from the original per-node version for determinism.
			var _top_radius: float = rng.randf_range(0.04, 0.10)
			var bottom_radius: float = rng.randf_range(0.22, 0.42)
			var height: float = rng.randf_range(1.0, 2.4)
			var lx: float = rng.randf_range(-1.0, 1.0)
			var lz: float = rng.randf_range(-1.0, 1.0)
			var rx: float = rng.randf_range(-8.0, 8.0)
			var ry: float = rng.randf_range(0.0, 360.0)
			var rz: float = rng.randf_range(-8.0, 8.0)

			var hscale: float = bottom_radius / REF_BOTTOM_RADIUS
			var crystal_rot := Basis.from_euler(Vector3(deg_to_rad(rx), deg_to_rad(ry), deg_to_rad(rz)))
			var basis := cluster_basis * crystal_rot.scaled(Vector3(hscale, height, hscale))
			var origin: Vector3 = pos + cluster_basis * Vector3(lx, height * 0.5, lz)
			transforms.append(Transform3D(basis, origin))
			collider_origins.append(origin)
			collider_radii.append(bottom_radius)
			collider_heights.append(height)

	var root := Node3D.new()
	root.name = "Crystals"
	parent.add_child(root)
	if transforms.is_empty():
		return

	MultiMeshScatter.build(root, "CrystalMesh", _get_unit_crystal_mesh(cseg), _get_crystal_material(), transforms)

	var body := StaticBody3D.new()
	body.name = "CrystalColliders"
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)
	for i in range(collider_origins.size()):
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = collider_radii[i]
		shape.height = collider_heights[i]
		cs.shape = shape
		cs.position = collider_origins[i]
		body.add_child(cs)


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
	return (max_h - min_h) <= 1.5


static func _get_unit_crystal_mesh(radial_segments: int) -> CylinderMesh:
	var key: String = "unit_crystal|%d" % radial_segments
	if _mesh_cache.has(key):
		return _mesh_cache[key] as CylinderMesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = REF_TOP_RADIUS
	mesh.bottom_radius = REF_BOTTOM_RADIUS
	mesh.height = 1.0
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
