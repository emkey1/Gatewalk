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
static var _cached_gate_material: StandardMaterial3D
static var _cached_gate_post_mesh: CylinderMesh
static var _cached_gate_arch_mesh: BoxMesh


static func clear_cache() -> void:
	_cached_gate_material = null
	_cached_gate_post_mesh = null
	_cached_gate_arch_mesh = null


# Regular gates carry no trigger Area3D: activation is detected by Main's
# warmup/cooldown-guarded proximity polling (_poll_primary_gate_activation), the
# single authoritative path. (The post meshes keep their own solid collision.)
static func create_gates(
	parent: Node3D, world_seed: int, target_seeds: Array[int],
	context: MapContext
) -> void:
	var gate_root := Node3D.new()
	gate_root.name = "Gates"
	parent.add_child(gate_root)

	var gate_mat := _gate_material()
	var post_mesh := _gate_post_mesh()
	var arch_mesh := _gate_arch_mesh()

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


static func scatter_gate_room_gates(parent: Node3D, slot_count: int, on_body_entered: Callable) -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.18, 0.21, 0.29)
	stone_mat.roughness = 0.74
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.36, 0.46, 0.64)
	trim_mat.roughness = 0.40
	trim_mat.emission_enabled = true
	trim_mat.emission = Color(0.26, 0.44, 0.70)
	trim_mat.emission_energy_multiplier = 0.55

	var arch_post_mesh := BoxMesh.new()
	arch_post_mesh.size = Vector3(1.0, 4.8, 1.1)
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(3.7, 0.8, 1.0)
	var gate_plane_mesh := PlaneMesh.new()
	gate_plane_mesh.size = Vector2(2.8, 3.6)
	var slot_area_box := BoxShape3D.new()
	slot_area_box.size = Vector3(4.2, 3.2, 4.2)

	var core := MeshInstance3D.new()
	core.name = "GateRoomCore"
	var core_mesh := TorusMesh.new()
	core_mesh.outer_radius = 2.8
	core_mesh.inner_radius = 2.45
	core.mesh = core_mesh
	core.material_override = trim_mat
	core.position = Vector3(0.0, 2.6, 0.0)
	core.rotation_degrees.x = 90.0
	parent.add_child(core)

	for si in range(slot_count):
		var angle: float = TAU * float(si) / float(slot_count)
		var dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var slot_pos: Vector3 = dir * 24.0
		var yaw_deg: float = -rad_to_deg(angle) + 90.0

		var gate_root := Node3D.new()
		gate_root.name = "GateRoomGate_" + str(si)
		gate_root.position = slot_pos
		gate_root.rotation_degrees.y = yaw_deg
		parent.add_child(gate_root)

		var left_post := MeshInstance3D.new()
		left_post.mesh = arch_post_mesh
		left_post.material_override = stone_mat
		left_post.position = Vector3(-1.35, 2.4, 0.0)
		gate_root.add_child(left_post)

		var right_post := MeshInstance3D.new()
		right_post.mesh = arch_post_mesh
		right_post.material_override = stone_mat
		right_post.position = Vector3(1.35, 2.4, 0.0)
		gate_root.add_child(right_post)

		var lintel := MeshInstance3D.new()
		lintel.mesh = lintel_mesh
		lintel.material_override = stone_mat
		lintel.position = Vector3(0.0, 4.8, 0.0)
		gate_root.add_child(lintel)

		var gate_plane := MeshInstance3D.new()
		gate_plane.mesh = gate_plane_mesh
		gate_plane.position = Vector3(0.0, 2.6, 0.04)
		gate_plane.rotation_degrees.x = 90.0
		var plane_mat := StandardMaterial3D.new()
		var slot_color: Color = _seed_color(1000 + si * 593, 0.35)
		plane_mat.albedo_color = slot_color
		plane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plane_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		plane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plane_mat.emission_enabled = true
		plane_mat.emission = Color(slot_color.r, slot_color.g, slot_color.b)
		plane_mat.emission_energy_multiplier = 1.2
		gate_plane.material_override = plane_mat
		gate_root.add_child(gate_plane)

		var gate_light := OmniLight3D.new()
		gate_light.name = "GateRoomSlotLight_" + str(si)
		gate_light.position = Vector3(0.0, 2.6, 0.0)
		gate_light.omni_range = 13.0
		gate_light.light_energy = 1.6
		gate_light.light_color = slot_color
		gate_root.add_child(gate_light)

		var sigil := MeshInstance3D.new()
		sigil.name = "GateRoomSlotSigil_" + str(si)
		var sigil_mesh := TorusMesh.new()
		sigil_mesh.outer_radius = 0.7
		sigil_mesh.inner_radius = 0.58
		sigil.mesh = sigil_mesh
		var sigil_mat := StandardMaterial3D.new()
		sigil_mat.albedo_color = slot_color
		sigil_mat.emission_enabled = true
		sigil_mat.emission = Color(slot_color.r, slot_color.g, slot_color.b)
		sigil_mat.emission_energy_multiplier = 1.8
		sigil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sigil.material_override = sigil_mat
		sigil.position = Vector3(0.0, 0.14, 0.0)
		sigil.rotation_degrees.x = 90.0
		gate_root.add_child(sigil)

		var area := Area3D.new()
		area.name = "GateRoomSlot_" + str(si)
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		var area_shape := CollisionShape3D.new()
		area_shape.shape = slot_area_box
		area.add_child(area_shape)
		area.position = slot_pos
		area.body_entered.connect(on_body_entered.bind(si), CONNECT_DEFERRED)
		parent.add_child(area)


static func scatter_gate_room_return_portal(parent: Node3D, on_body_entered: Callable) -> void:
	var portal_mat := StandardMaterial3D.new()
	portal_mat.albedo_color = Color(0.30, 0.78, 1.00, 0.46)
	portal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	portal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	portal_mat.emission_enabled = true
	portal_mat.emission = Color(0.20, 0.70, 1.00)
	portal_mat.emission_energy_multiplier = 1.25

	var altar_mat := StandardMaterial3D.new()
	altar_mat.albedo_color = Color(0.16, 0.22, 0.32)
	altar_mat.roughness = 0.60

	var portal := MeshInstance3D.new()
	portal.name = "GateRoomReturnPortal"
	var portal_mesh := CylinderMesh.new()
	portal_mesh.top_radius = 1.9
	portal_mesh.bottom_radius = 1.9
	portal_mesh.height = 3.4
	portal_mesh.radial_segments = 20
	portal.mesh = portal_mesh
	portal.material_override = portal_mat
	portal.position = Vector3(0.0, 1.8, -24.0)
	parent.add_child(portal)

	var altar := MeshInstance3D.new()
	altar.name = "GateRoomReturnAltar"
	var altar_mesh := CylinderMesh.new()
	altar_mesh.top_radius = 3.2
	altar_mesh.bottom_radius = 3.7
	altar_mesh.height = 1.0
	altar_mesh.radial_segments = 20
	altar.mesh = altar_mesh
	altar.material_override = altar_mat
	altar.position = Vector3(0.0, 0.5, -24.0)
	parent.add_child(altar)

	var return_light := OmniLight3D.new()
	return_light.name = "GateRoomReturnLight"
	return_light.position = Vector3(0.0, 2.4, -24.0)
	return_light.omni_range = 14.0
	return_light.light_energy = 1.9
	return_light.light_color = Color(0.34, 0.78, 1.0)
	parent.add_child(return_light)

	var area := Area3D.new()
	area.name = "GateRoomReturnArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = true
	var area_shape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.8
	shape.height = 4.0
	area_shape.shape = shape
	area.add_child(area_shape)
	area.position = portal.position
	area.body_entered.connect(on_body_entered, CONNECT_DEFERRED)
	parent.add_child(area)


static func scatter_map_nexus_gates(parent: Node3D, slot_count: int, on_body_entered: Callable) -> void:
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.18, 0.28, 0.40)
	gate_mat.roughness = 0.68
	var arch_post_mesh := BoxMesh.new()
	arch_post_mesh.size = Vector3(1.1, 4.6, 1.2)
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(4.1, 0.9, 1.1)
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(3.3, 3.9)
	var slot_area_box := BoxShape3D.new()
	slot_area_box.size = Vector3(5.8, 4.2, 5.8)

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
		var yaw_deg: float = -rad_to_deg(angle) + 90.0
		var slot_color: Color = _seed_color(2200 + si * 733, 0.40)

		var gate_root := Node3D.new()
		gate_root.name = "MapNexusGate_" + str(si)
		gate_root.position = slot_pos
		gate_root.rotation_degrees.y = yaw_deg
		parent.add_child(gate_root)

		var left_post := MeshInstance3D.new()
		left_post.mesh = arch_post_mesh
		left_post.material_override = gate_mat
		left_post.position = Vector3(-1.45, 2.3, 0.0)
		gate_root.add_child(left_post)

		var right_post := MeshInstance3D.new()
		right_post.mesh = arch_post_mesh
		right_post.material_override = gate_mat
		right_post.position = Vector3(1.45, 2.3, 0.0)
		gate_root.add_child(right_post)

		var lintel := MeshInstance3D.new()
		lintel.mesh = lintel_mesh
		lintel.material_override = gate_mat
		lintel.position = Vector3(0.0, 4.6, 0.0)
		gate_root.add_child(lintel)

		var plane := MeshInstance3D.new()
		plane.mesh = plane_mesh
		plane.position = Vector3(0.0, 2.6, 0.04)
		plane.rotation_degrees.x = 90.0
		var plane_mat := StandardMaterial3D.new()
		plane_mat.albedo_color = slot_color
		plane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plane_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		plane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plane_mat.emission_enabled = true
		plane_mat.emission = Color(slot_color.r, slot_color.g, slot_color.b)
		plane_mat.emission_energy_multiplier = 1.55
		plane.material_override = plane_mat
		gate_root.add_child(plane)

		var light := OmniLight3D.new()
		light.name = "MapNexusSlotLight_" + str(si)
		light.position = Vector3(0.0, 2.8, 0.0)
		light.omni_range = 16.0
		light.light_energy = 1.9
		light.light_color = slot_color
		gate_root.add_child(light)

		var gate_body := StaticBody3D.new()
		gate_body.name = "MapNexusGateBody_" + str(si)
		var col_left := CollisionShape3D.new()
		var shape_left := BoxShape3D.new()
		shape_left.size = Vector3(1.1, 4.6, 1.2)
		col_left.shape = shape_left
		col_left.position = Vector3(-1.45, 2.3, 0.0)
		gate_body.add_child(col_left)
		var col_right := CollisionShape3D.new()
		var shape_right := BoxShape3D.new()
		shape_right.size = Vector3(1.1, 4.6, 1.2)
		col_right.shape = shape_right
		col_right.position = Vector3(1.45, 2.3, 0.0)
		gate_body.add_child(col_right)
		var col_lintel := CollisionShape3D.new()
		var shape_lintel := BoxShape3D.new()
		shape_lintel.size = Vector3(4.1, 0.9, 1.1)
		col_lintel.shape = shape_lintel
		col_lintel.position = Vector3(0.0, 4.6, 0.0)
		gate_body.add_child(col_lintel)
		gate_root.add_child(gate_body)

		var area := Area3D.new()
		area.name = "MapNexusSlot_" + str(si)
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		var area_shape := CollisionShape3D.new()
		area_shape.shape = slot_area_box
		area.add_child(area_shape)
		area.position = slot_pos
		area.body_entered.connect(on_body_entered.bind(si), CONNECT_DEFERRED)
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
	if _cached_gate_material != null:
		return _cached_gate_material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.24, 0.30)
	mat.roughness = 0.95
	_cached_gate_material = mat
	return _cached_gate_material


static func _gate_post_mesh() -> CylinderMesh:
	if _cached_gate_post_mesh != null:
		return _cached_gate_post_mesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.28
	mesh.height = 4.0
	_cached_gate_post_mesh = mesh
	return _cached_gate_post_mesh


static func _gate_arch_mesh() -> BoxMesh:
	if _cached_gate_arch_mesh != null:
		return _cached_gate_arch_mesh
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.8, 0.35, 0.5)
	_cached_gate_arch_mesh = mesh
	return _cached_gate_arch_mesh




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
