extends RefCounted
class_name GateFactory

const StableRng = preload("res://scripts/core/StableRng.gd")
const MapContext = preload("res://scripts/core/MapContext.gd")

const GATE_DIRECTIONS: Array[Vector3] = [
	Vector3(1.0, 0.0, 0.0),
	Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 1.0),
	Vector3(0.0, 0.0, -1.0),
]


static func create_gates(
	parent: Node3D, world_seed: int, target_seeds: Array[int],
	context: MapContext,
	on_body_entered: Callable
) -> void:
	var gate_root := Node3D.new()
	gate_root.name = "Gates"
	parent.add_child(gate_root)

	var gate_mat := _gate_material()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.22
	post_mesh.bottom_radius = 0.28
	post_mesh.height = 4.0
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(2.8, 0.35, 0.5)
	var gate_area_box := BoxShape3D.new()
	gate_area_box.size = Vector3(3.5, 5.0, 3.5)

	for gate_index in range(GATE_DIRECTIONS.size()):
		var dir: Vector3 = GATE_DIRECTIONS[gate_index]
		var gate_pos: Vector3 = _find_gate_position(
			dir,
			Callable(context, "height_at_world"),
			Callable(context, "river_distance"),
			context.water_level,
			context.world_half_size() * 0.72
		)

		var gate := Node3D.new()
		gate.name = "Gate_" + str(gate_index)
		gate.position = gate_pos
		gate.rotation.y = atan2(-dir.x, -dir.z)
		gate_root.add_child(gate)

		var left_post := MeshInstance3D.new()
		left_post.mesh = post_mesh
		left_post.position = Vector3(-1.1, 2.0, 0.0)
		left_post.material_override = gate_mat
		gate.add_child(left_post)

		var right_post := MeshInstance3D.new()
		right_post.mesh = post_mesh
		right_post.position = Vector3(1.1, 2.0, 0.0)
		right_post.material_override = gate_mat
		gate.add_child(right_post)

		var arch := MeshInstance3D.new()
		arch.mesh = arch_mesh
		arch.position = Vector3(0.0, 4.0, 0.0)
		arch.material_override = gate_mat
		gate.add_child(arch)

		var glow := MeshInstance3D.new()
		glow.name = "GateGlow_" + str(gate_index)
		var glow_mesh := PlaneMesh.new()
		glow_mesh.size = Vector2(1.6, 2.7)
		glow.mesh = glow_mesh
		var target_seed: int = target_seeds[gate_index] if gate_index < target_seeds.size() else _preview_gate_seed(world_seed, gate_index)
		glow.material_override = _gate_glow_material(target_seed)
		glow.position = Vector3(0.0, 2.0, 0.03)
		glow.rotation_degrees.x = 90.0
		gate.add_child(glow)

		var area := Area3D.new()
		area.name = "GateArea_" + str(gate_index)
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		area.monitorable = true
		var area_shape := CollisionShape3D.new()
		area_shape.shape = gate_area_box
		area_shape.position = Vector3(0.0, 1.8, 0.0)
		area.add_child(area_shape)
		area.position = gate_pos
		area.body_entered.connect(on_body_entered.bind(gate_index))
		gate_root.add_child(area)


static func scatter_gate_room_gates(parent: Node3D, slot_count: int, on_body_entered: Callable) -> void:
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.30, 0.24, 0.42)
	gate_mat.roughness = 0.72
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(1.2, 4.0, 1.2)
	var slot_area_box := BoxShape3D.new()
	slot_area_box.size = Vector3(3.0, 3.0, 3.0)

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.42, 0.30, 0.58)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.22, 0.12, 0.32)
	core_mat.emission_energy_multiplier = 0.4
	core_mat.roughness = 0.55

	var core := MeshInstance3D.new()
	core.name = "GateRoomCore"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 1.1
	core_mesh.bottom_radius = 1.3
	core_mesh.height = 6.0
	core_mesh.radial_segments = 16
	core.mesh = core_mesh
	core.material_override = core_mat
	core.position = Vector3(0.0, 3.0, 0.0)
	parent.add_child(core)

	for si in range(slot_count):
		var angle: float = TAU * float(si) / float(slot_count)
		var slot_pos: Vector3 = Vector3(cos(angle) * 24.0, 0.0, sin(angle) * 24.0)

		var arch := MeshInstance3D.new()
		arch.name = "GateRoomGate_" + str(si)
		arch.mesh = arch_mesh
		arch.material_override = gate_mat
		arch.position = slot_pos
		parent.add_child(arch)

		var area := Area3D.new()
		area.name = "GateRoomSlot_" + str(si)
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		var area_shape := CollisionShape3D.new()
		area_shape.shape = slot_area_box
		area.add_child(area_shape)
		area.position = slot_pos
		area.body_entered.connect(on_body_entered.bind(si))
		parent.add_child(area)


static func scatter_map_nexus_gates(parent: Node3D, slot_count: int, on_body_entered: Callable) -> void:
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.18, 0.28, 0.40)
	gate_mat.roughness = 0.68
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(1.5, 4.0, 1.5)
	var slot_area_box := BoxShape3D.new()
	slot_area_box.size = Vector3(4.0, 4.0, 4.0)

	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.18, 0.45, 0.60, 0.18)
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.12, 0.30, 0.42)
	core_mat.emission_energy_multiplier = 0.7

	var core := MeshInstance3D.new()
	core.name = "MapNexusCore"
	var core_mesh := TorusMesh.new()
	core_mesh.outer_radius = 2.8
	core_mesh.inner_radius = 2.5
	core.mesh = core_mesh
	core.material_override = core_mat
	core.position = Vector3(0.0, 2.0, 0.0)
	core.rotation_degrees.x = 90.0
	parent.add_child(core)

	for si in range(slot_count):
		var angle: float = TAU * float(si) / float(slot_count)
		var slot_pos: Vector3 = Vector3(cos(angle) * 38.0, 0.0, sin(angle) * 38.0)

		var arch := MeshInstance3D.new()
		arch.name = "MapNexusGate_" + str(si)
		arch.mesh = arch_mesh
		arch.material_override = gate_mat
		arch.position = slot_pos
		parent.add_child(arch)

		var area := Area3D.new()
		area.name = "MapNexusSlot_" + str(si)
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		var area_shape := CollisionShape3D.new()
		area_shape.shape = slot_area_box
		area.add_child(area_shape)
		area.position = slot_pos
		area.body_entered.connect(on_body_entered.bind(si))
		parent.add_child(area)


static func scatter_cave_items(parent: Node3D, world_seed: int) -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "cave_items"))
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.20, 0.70, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.10, 0.50, 0.90)
	glow_mat.emission_energy_multiplier = 1.5

	var crystal_count: int = 36
	for i in range(crystal_count):
		var angle: float = TAU * float(i) / float(crystal_count)
		var dist: float = 40.0 + rng.randf_range(1.0, 5.0)
		var crystal := MeshInstance3D.new()
		crystal.name = "CaveCrystal_" + str(i)
		var crystal_mesh := BoxMesh.new()
		crystal_mesh.size = Vector3(rng.randf_range(0.1, 0.3), rng.randf_range(0.4, 1.6), rng.randf_range(0.1, 0.3))
		crystal.mesh = crystal_mesh
		crystal.material_override = glow_mat
		crystal.position = Vector3(cos(angle) * dist, rng.randf_range(0.0, 6.0), sin(angle) * dist)
		crystal.rotation = Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))
		parent.add_child(crystal)


static func _gate_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.24, 0.30)
	mat.roughness = 0.95
	return mat


static func _gate_glow_material(target_seed: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _seed_color(target_seed, 0.50)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b)
	mat.emission_energy_multiplier = 1.6
	return mat


static func _preview_gate_seed(world_seed: int, gate_index: int) -> int:
	var value: int = int((world_seed ^ ((gate_index + 1) * 747796405) ^ 2891336453) & 0x7fffffff)
	if value == 0:
		value = 12345 + gate_index
	return value


static func _seed_color(seed_value: int, alpha: float = 1.0) -> Color:
	var hue: float = float(abs(seed_value) % 360) / 360.0
	return Color.from_hsv(hue, 0.72, 1.0, alpha)


static func _find_gate_position(
	direction: Vector3, height_fn: Callable, river_distance_fn: Callable,
	water_level: float, max_distance: float
) -> Vector3:
	for step in range(8):
		var distance: float = max_distance - float(step) * 12.0
		var x: float = direction.x * distance
		var z: float = direction.z * distance
		var pos: Vector3 = Vector3(x, height_fn.call(x, z) + 0.65, z)
		if pos.y > water_level + 0.5 and river_distance_fn.call(x, z) > 9.0:
			return pos

	var fallback_x: float = direction.x * max_distance
	var fallback_z: float = direction.z * max_distance
	return Vector3(fallback_x, height_fn.call(fallback_x, fallback_z) + 0.65, fallback_z)
