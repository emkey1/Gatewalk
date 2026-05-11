extends Node
class_name WonderGenerator

const DEFAULT_WONDER_CELL_SIZE: float = 256.0


class StableRng:
	var state: int = 1

	func _init(seed: int) -> void:
		state = int(seed & 0xffffffff)
		if state == 0:
			state = 0x6d2b79f5

	func next_u32() -> int:
		state = int((1664525 * state + 1013904223) & 0xffffffff)
		return state

	func randf() -> float:
		return float(next_u32()) / 4294967296.0

	func randf_range(min_value: float, max_value: float) -> float:
		return lerp(min_value, max_value, randf())

	func randi_range(min_value: int, max_value: int) -> int:
		var lo: int = min(min_value, max_value)
		var hi: int = max(min_value, max_value)
		return lo + int(next_u32() % int(hi - lo + 1))

	func chance(probability: float) -> bool:
		return randf() < probability

	func pick(items: Array) -> Variant:
		return items[randi_range(0, items.size() - 1)]


static func cell_has_wonder(world_seed: int, cell_x: int, cell_z: int, chance: float = 0.18) -> bool:
	var key: int = _mix_seed(world_seed, cell_x, cell_z, 9001)
	var rng := StableRng.new(key)
	return rng.chance(chance)


static func get_cell_wonder_position(world_seed: int, cell_x: int, cell_z: int, terrain_height_callable: Callable = Callable(), cell_size: float = DEFAULT_WONDER_CELL_SIZE) -> Vector3:
	var key: int = _mix_seed(world_seed, cell_x, cell_z, 42)
	var rng := StableRng.new(key)
	var base_x: float = float(cell_x) * cell_size
	var base_z: float = float(cell_z) * cell_size
	var x: float = base_x + rng.randf_range(cell_size * 0.25, cell_size * 0.75)
	var z: float = base_z + rng.randf_range(cell_size * 0.25, cell_size * 0.75)
	var y: float = 0.0
	if terrain_height_callable.is_valid():
		y = float(terrain_height_callable.call(x, z))
	return Vector3(x, y, z)


static func create_wonder(world_seed: int, map_position: Vector3, wonder_salt: int = 0, add_rough_collision: bool = false) -> Node3D:
	var px: int = int(round(map_position.x))
	var pz: int = int(round(map_position.z))
	var key: int = _mix_seed(world_seed, px, pz, wonder_salt)
	var rng := StableRng.new(key)
	var archetypes: Array[String] = ["moon_gate", "crystal_spire", "runestone_circle", "floating_shrine"]
	var archetype: String = str(rng.pick(archetypes))
	var palette: Dictionary = _pick_palette(rng)

	var root := Node3D.new()
	root.name = "Wonder_%s_%d_%d_%d" % [archetype, px, pz, wonder_salt]
	root.position = map_position

	match archetype:
		"moon_gate":
			_build_moon_gate(root, rng, palette)
		"crystal_spire":
			_build_crystal_spire(root, rng, palette)
		"runestone_circle":
			_build_runestone_circle(root, rng, palette)
		"floating_shrine":
			_build_floating_shrine(root, rng, palette)
		_:
			_build_runestone_circle(root, rng, palette)

	if add_rough_collision:
		_add_auto_colliders(root)

	return root


static func _build_moon_gate(root: Node3D, rng: StableRng, palette: Dictionary) -> void:
	var stone_mat: StandardMaterial3D = _mat(palette["stone"])
	var glow_mat: StandardMaterial3D = _mat(palette["glow"], palette["glow"], 1.8)
	var accent_mat: StandardMaterial3D = _mat(palette["accent"], palette["glow"], 0.4)
	var radius: float = rng.randf_range(4.5, 6.5)
	var thickness: float = rng.randf_range(0.35, 0.75)

	_add_mesh(root, "moon_gate_base", _cylinder(radius * 0.9, 0.65, 32), stone_mat, Vector3(0.0, 0.325, 0.0))

	var ring := TorusMesh.new()
	ring.outer_radius = radius
	ring.inner_radius = max(radius - thickness, 0.2)
	_add_mesh(root, "moon_gate_ring", ring, stone_mat, Vector3(0.0, radius + 0.6, 0.0), Vector3(90.0, 0.0, 0.0))

	var pillar_height: float = radius * 1.35
	var pillar_size: Vector3 = Vector3(0.9, pillar_height, 0.9)
	_add_mesh(root, "moon_gate_left_pillar", _box(pillar_size), stone_mat, Vector3(-radius * 0.85, pillar_height * 0.5, 0.0), Vector3(0.0, rng.randf_range(-5.0, 5.0), rng.randf_range(-2.0, 2.0)))
	_add_mesh(root, "moon_gate_right_pillar", _box(pillar_size), stone_mat, Vector3(radius * 0.85, pillar_height * 0.5, 0.0), Vector3(0.0, rng.randf_range(-5.0, 5.0), rng.randf_range(-2.0, 2.0)))

	var crystal_count: int = rng.randi_range(5, 9)
	for i in range(crystal_count):
		var angle: float = TAU * float(i) / float(crystal_count) + rng.randf_range(-0.18, 0.18)
		var dist: float = radius + rng.randf_range(1.2, 2.4)
		var height: float = rng.randf_range(1.2, 3.0)
		_add_mesh(root, "moon_crystal_" + str(i), _cylinder(rng.randf_range(0.25, 0.55), height, 6, 0.05), glow_mat, Vector3(cos(angle) * dist, height * 0.5, sin(angle) * dist), Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 360.0), rng.randf_range(-8.0, 8.0)))

	var rune_count: int = rng.randi_range(8, 14)
	for i in range(rune_count):
		var y: float = rng.randf_range(radius * 0.55, radius * 1.75)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * rng.randf_range(radius * 0.65, radius * 0.95)
		_add_mesh(root, "moon_rune_" + str(i), _box(Vector3(0.12, rng.randf_range(0.35, 0.9), 0.08)), accent_mat, Vector3(x, y, -0.5), Vector3(0.0, 0.0, rng.randf_range(-20.0, 20.0)))

	_add_light(root, "moon_gate_light", palette["glow"], Vector3(0.0, radius + 0.6, 0.0), 2.6, radius * 4.0)


static func _build_crystal_spire(root: Node3D, rng: StableRng, palette: Dictionary) -> void:
	var stone_mat: StandardMaterial3D = _mat(palette["stone"])
	var crystal_mat: StandardMaterial3D = _mat(palette["glow"], palette["glow"], 2.4)
	var accent_mat: StandardMaterial3D = _mat(palette["accent"], palette["glow"], 0.7)
	var base_radius: float = rng.randf_range(2.6, 4.0)
	_add_mesh(root, "spire_base", _cylinder(base_radius, 0.8, 32), stone_mat, Vector3(0.0, 0.4, 0.0))

	var spire_height: float = rng.randf_range(10.0, 17.0)
	var spire_radius: float = rng.randf_range(0.8, 1.5)
	_add_mesh(root, "central_crystal_spire", _cylinder(spire_radius, spire_height, 7, 0.08), crystal_mat, Vector3(0.0, spire_height * 0.5 + 0.6, 0.0), Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(0.0, 360.0), rng.randf_range(-3.0, 3.0)))

	var shard_count: int = rng.randi_range(8, 15)
	for i in range(shard_count):
		var angle: float = TAU * float(i) / float(shard_count) + rng.randf_range(-0.22, 0.22)
		var dist: float = rng.randf_range(base_radius + 0.7, base_radius + 4.0)
		var height: float = rng.randf_range(1.4, 5.0)
		var radius: float = rng.randf_range(0.25, 0.75)
		_add_mesh(root, "spire_shard_" + str(i), _cylinder(radius, height, 6, 0.04), crystal_mat if rng.chance(0.65) else accent_mat, Vector3(cos(angle) * dist, height * 0.5, sin(angle) * dist), Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 360.0), rng.randf_range(-12.0, 12.0)))

	var orb_count: int = rng.randi_range(3, 6)
	for i in range(orb_count):
		var angle: float = TAU * float(i) / float(orb_count) + rng.randf_range(-0.3, 0.3)
		var dist: float = rng.randf_range(2.0, 4.5)
		var y: float = rng.randf_range(spire_height * 0.45, spire_height * 0.9)
		_add_mesh(root, "floating_orb_" + str(i), _sphere(rng.randf_range(0.25, 0.55)), crystal_mat, Vector3(cos(angle) * dist, y, sin(angle) * dist))

	_add_light(root, "spire_light", palette["glow"], Vector3(0.0, spire_height * 0.6, 0.0), 3.2, spire_height * 2.2)


static func _build_runestone_circle(root: Node3D, rng: StableRng, palette: Dictionary) -> void:
	var stone_mat: StandardMaterial3D = _mat(palette["stone"])
	var rune_mat: StandardMaterial3D = _mat(palette["glow"], palette["glow"], 1.5)
	var altar_mat: StandardMaterial3D = _mat(palette["accent"])
	var count: int = rng.randi_range(7, 13)
	var radius: float = rng.randf_range(5.0, 8.5)

	for i in range(count):
		var angle: float = TAU * float(i) / float(count) + rng.randf_range(-0.08, 0.08)
		var outward: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var height: float = rng.randf_range(2.8, 6.2)
		var width: float = rng.randf_range(0.7, 1.2)
		var depth: float = rng.randf_range(0.45, 0.8)
		var pos: Vector3 = outward * radius
		pos.y = height * 0.5
		var rot: Vector3 = Vector3(rng.randf_range(-5.0, 5.0), -rad_to_deg(angle) + 90.0 + rng.randf_range(-10.0, 10.0), rng.randf_range(-5.0, 5.0))
		_add_mesh(root, "runestone_" + str(i), _box(Vector3(width, height, depth)), stone_mat, pos, rot)
		var rune_pos: Vector3 = pos - outward * 0.34
		rune_pos.y = height * rng.randf_range(0.52, 0.68)
		_add_mesh(root, "rune_glow_" + str(i), _box(Vector3(0.08, height * rng.randf_range(0.22, 0.42), 0.08)), rune_mat, rune_pos, rot)

	var altar_height: float = rng.randf_range(0.7, 1.2)
	_add_mesh(root, "central_altar", _cylinder(rng.randf_range(1.5, 2.4), altar_height, 12), altar_mat, Vector3(0.0, altar_height * 0.5, 0.0))
	_add_mesh(root, "altar_orb", _sphere(rng.randf_range(0.45, 0.85)), rune_mat, Vector3(0.0, altar_height + rng.randf_range(1.0, 1.8), 0.0))
	_add_light(root, "runestone_circle_light", palette["glow"], Vector3(0.0, 3.2, 0.0), 2.0, radius * 3.0)


static func _build_floating_shrine(root: Node3D, rng: StableRng, palette: Dictionary) -> void:
	var stone_mat: StandardMaterial3D = _mat(palette["stone"])
	var glow_mat: StandardMaterial3D = _mat(palette["glow"], palette["glow"], 2.0)
	var accent_mat: StandardMaterial3D = _mat(palette["accent"], palette["glow"], 0.5)
	var base_radius: float = rng.randf_range(2.2, 3.5)
	_add_mesh(root, "shrine_ground_base", _cylinder(base_radius, 0.7, 24), stone_mat, Vector3(0.0, 0.35, 0.0))

	var platform_y: float = rng.randf_range(3.0, 4.8)
	_add_mesh(root, "floating_platform", _cylinder(rng.randf_range(1.8, 2.8), 0.45, 16), accent_mat, Vector3(0.0, platform_y, 0.0), Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(0.0, 360.0), rng.randf_range(-2.0, 2.0)))

	var ring := TorusMesh.new()
	ring.outer_radius = rng.randf_range(2.2, 3.4)
	ring.inner_radius = ring.outer_radius - rng.randf_range(0.25, 0.45)
	_add_mesh(root, "floating_shrine_ring", ring, glow_mat, Vector3(0.0, platform_y + rng.randf_range(1.8, 2.8), 0.0), Vector3(rng.randf_range(65.0, 85.0), rng.randf_range(0.0, 360.0), rng.randf_range(-12.0, 12.0)))

	var obelisk_height: float = rng.randf_range(3.5, 6.5)
	_add_mesh(root, "floating_obelisk", _cylinder(rng.randf_range(0.45, 0.8), obelisk_height, 6, 0.04), glow_mat, Vector3(0.0, platform_y + obelisk_height * 0.5 + 0.25, 0.0), Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(0.0, 360.0), rng.randf_range(-4.0, 4.0)))

	var shard_count: int = rng.randi_range(5, 10)
	for i in range(shard_count):
		var angle: float = TAU * float(i) / float(shard_count) + rng.randf_range(-0.25, 0.25)
		var dist: float = rng.randf_range(3.8, 6.5)
		var height: float = rng.randf_range(0.7, 2.0)
		var y: float = rng.randf_range(1.4, platform_y + 1.6)
		_add_mesh(root, "floating_stone_" + str(i), _box(Vector3(rng.randf_range(0.5, 1.3), height, rng.randf_range(0.5, 1.3))), stone_mat, Vector3(cos(angle) * dist, y, sin(angle) * dist), Vector3(rng.randf_range(-35.0, 35.0), rng.randf_range(0.0, 360.0), rng.randf_range(-35.0, 35.0)))

	_add_light(root, "floating_shrine_light", palette["glow"], Vector3(0.0, platform_y + 2.5, 0.0), 3.0, 18.0)


static func _pick_palette(rng: StableRng) -> Dictionary:
	var palettes: Array[Dictionary] = [
		{"name": "moonlit_ancient", "stone": Color(0.34, 0.36, 0.42), "accent": Color(0.55, 0.50, 0.68), "glow": Color(0.35, 0.70, 1.00)},
		{"name": "emerald_fae", "stone": Color(0.23, 0.34, 0.27), "accent": Color(0.42, 0.62, 0.34), "glow": Color(0.20, 1.00, 0.62)},
		{"name": "violet_arcane", "stone": Color(0.28, 0.24, 0.34), "accent": Color(0.48, 0.32, 0.62), "glow": Color(0.85, 0.35, 1.00)},
		{"name": "sunken_gold", "stone": Color(0.42, 0.36, 0.27), "accent": Color(0.80, 0.58, 0.25), "glow": Color(1.00, 0.66, 0.20)}
	]
	return rng.pick(palettes)


static func _mat(albedo: Color, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.88
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


static func _cylinder(radius: float, height: float, radial_segments: int = 12, top_radius: float = -1.0) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	return mesh


static func _add_mesh(parent: Node3D, name: String, mesh: Mesh, material: Material, position: Vector3, rotation_degrees: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	instance.scale = scale
	parent.add_child(instance)
	return instance


static func _add_light(parent: Node3D, name: String, color: Color, position: Vector3, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.position = position
	parent.add_child(light)
	return light


static func _add_auto_colliders(root: Node3D) -> void:
	var mesh_nodes: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			mesh_nodes.append(child)

	for mesh_node in mesh_nodes:
		if mesh_node.mesh == null:
			continue
		var body := StaticBody3D.new()
		body.name = mesh_node.name + "_Collider"
		body.transform = mesh_node.transform
		body.collision_layer = 1
		body.collision_mask = 1
		var collision := CollisionShape3D.new()
		collision.shape = mesh_node.mesh.create_convex_shape(true, true)
		body.add_child(collision)
		root.add_child(body)


static func _mix_seed(world_seed: int, x: int, z: int, salt: int) -> int:
	var h: int = 2166136261
	h = _fnv_step(h, world_seed)
	h = _fnv_step(h, x)
	h = _fnv_step(h, z)
	h = _fnv_step(h, salt)
	return int(h & 0xffffffff)


static func _fnv_step(h: int, value: int) -> int:
	var v: int = int(value & 0xffffffff)
	var shifts: Array[int] = [0, 8, 16, 24]
	for shift_value in shifts:
		var byte_value: int = int((v >> shift_value) & 0xff)
		h = int((h ^ byte_value) & 0xffffffff)
		h = int((h * 16777619) & 0xffffffff)
	return h
