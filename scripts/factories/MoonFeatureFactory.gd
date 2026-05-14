extends RefCounted
class_name MoonFeatureFactory

const MapContext = preload("res://scripts/core/MapContext.gd")

static func scatter_lichen(parent: Node3D, world_seed: int, context: MapContext) -> void:
	_scatter_lichen_internal(parent, world_seed, Callable(context, "height_at_world"), context.world_half_size() * 0.88)


static func _scatter_lichen_internal(parent: Node3D, world_seed: int, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "moon_lichen"))

	var root := Node3D.new()
	root.name = "MoonLichens"
	parent.add_child(root)

	for i in range(180):
		var pos: Vector3 = _random_position(rng, half, height_fn)
		if pos.distance_to(Vector3.ZERO) < 10.0:
			continue

		var body := preload("res://scripts/FloatingLichen.gd").new() as RigidBody3D
		body.name = "MoonLichen_" + str(i)
		body.collision_layer = 1
		body.collision_mask = 1 | 2 | 4
		body.gravity_scale = 0.0
		body.linear_damp = 0.25
		body.angular_damp = 0.4
		body.mass = 0.2
		body.can_sleep = false
		body.sleeping = false
		body.add_to_group("floating_lichen")

		var phys_mat := PhysicsMaterial.new()
		phys_mat.bounce = 0.75
		phys_mat.friction = 0.1
		body.physics_material_override = phys_mat

		var visual := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.45, 1.0)
		mesh.height = mesh.radius * rng.randf_range(0.55, 0.9)
		visual.mesh = mesh
		visual.scale = Vector3(rng.randf_range(1.0, 1.8), rng.randf_range(0.45, 0.8), rng.randf_range(1.0, 1.8))

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.48, 0.82, 0.64)
		mat.emission_enabled = true
		mat.emission = Color(0.12, 0.42, 0.24)
		mat.emission_energy_multiplier = 0.85
		visual.material_override = mat
		body.add_child(visual)

		var shape_node := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = mesh.radius
		shape_node.shape = shape
		body.add_child(shape_node)

		body.position = pos + Vector3(0.0, rng.randf_range(1.4, 5.5), 0.0)
		body.apply_impulse(Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.15, 0.15), rng.randf_range(-0.8, 0.8)))
		root.add_child(body)


static func scatter_glass_craters(parent: Node3D, world_seed: int, context: MapContext) -> void:
	_scatter_glass_craters_internal(parent, world_seed, Callable(context, "height_at_world"), context.world_half_size() * 0.44)


static func _scatter_glass_craters_internal(parent: Node3D, world_seed: int, height_fn: Callable, half: float) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "moon_craters"))
	var root := Node3D.new()
	root.name = "MoonGlassCraters"
	parent.add_child(root)

	for i in range(32):
		var pos: Vector3 = _random_position(rng, half, height_fn)
		_try_place_glass_crater(root, i, pos, rng)


static func _random_position(rng: StableRng, half: float, height_fn: Callable) -> Vector3:
	for attempt in range(18):
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = height_fn.call(x, z)
		if y >= -10.0:
			return Vector3(x, y, z)
	var x: float = rng.randf_range(-half, half)
	var z: float = rng.randf_range(-half, half)
	return Vector3(x, height_fn.call(x, z), z)


static func _try_place_glass_crater(parent: Node3D, index: int, pos: Vector3, rng: StableRng) -> void:
	var outer_radius: float = rng.randf_range(0.6, 2.4)
	var depth_scale: float = outer_radius * rng.randf_range(0.12, 0.28)
	var crater_seed: int = int(StableRng.mix_string(int(pos.x * 100.0 + pos.z * 37.0), "crater"))

	var crater_rng := StableRng.new(crater_seed)
	var segments: int = crater_rng.randi_range(6, 12)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(pos.x, pos.y - depth_scale * 0.5, pos.z)
	st.add_vertex(center)
	for s in range(segments + 1):
		var angle: float = TAU * float(s) / float(segments)
		var rim_y: float = pos.y + crater_rng.randf_range(-0.05, 0.08)
		var rim_x: float = pos.x + cos(angle) * outer_radius
		var rim_z: float = pos.z + sin(angle) * outer_radius
		st.add_vertex(Vector3(rim_x, rim_y, rim_z))
	for s in range(segments):
		st.add_index(0)
		st.add_index(1 + s)
		st.add_index(2 + s)

	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(
		crater_rng.randf_range(0.30, 0.70),
		crater_rng.randf_range(0.40, 0.80),
		crater_rng.randf_range(0.50, 0.90),
	)
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.08, 0.15, 0.30) * 0.15
	glass_mat.metallic = 0.5
	glass_mat.roughness = 0.12
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mi := MeshInstance3D.new()
	mi.name = "GlassCrater_" + str(index)
	mi.mesh = st.commit()
	mi.material_override = glass_mat
	parent.add_child(mi)
