class_name BirdFlock
extends Node3D

const StableRng = preload("res://scripts/core/StableRng.gd")

var bird_count: int = 10
var mesh_quality: int = 0  # kept for spawn-API compatibility; unused
var rng_seed: int = 1

var _bird_nodes: Array[Node3D] = []
var _left_wings: Array[MeshInstance3D] = []
var _right_wings: Array[MeshInstance3D] = []
var _phases: Array[float] = []
var _y_offsets: Array[float] = []
var _speeds: Array[float] = []
var _radii: Array[float] = []
var _wing_phases: Array[float] = []
var _flap_speeds: Array[float] = []
var _scales: Array[float] = []
var _time: float = 0.0


func _ready() -> void:
	var rng := StableRng.new(rng_seed)

	# Shared resources: a streamlined body and two flat, swept-back wings that flap.
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.075
	body_mesh.height = 0.15
	body_mesh.radial_segments = 8
	body_mesh.rings = 5
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.34, 0.28, 0.22)
	body_mat.roughness = 0.95
	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.40, 0.36, 0.32)
	wing_mat.roughness = 0.95
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var left_wing_mesh := _wing_mesh(-1.0)
	var right_wing_mesh := _wing_mesh(1.0)

	for i in bird_count:
		var bird := Node3D.new()
		add_child(bird)
		_bird_nodes.append(bird)
		_phases.append(rng.randf_range(0.0, TAU))
		_y_offsets.append(rng.randf_range(-2.0, 2.0))
		_speeds.append(rng.randf_range(0.4, 0.8))
		_radii.append(rng.randf_range(7.0, 16.0))
		_wing_phases.append(rng.randf_range(0.0, TAU))
		_flap_speeds.append(rng.randf_range(8.0, 12.0))

		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = body_mat
		body.scale = Vector3(0.8, 0.7, 2.3)  # torpedo body along the flight axis (-z)
		bird.add_child(body)

		var left_wing := MeshInstance3D.new()
		left_wing.mesh = left_wing_mesh
		left_wing.material_override = wing_mat
		bird.add_child(left_wing)
		_left_wings.append(left_wing)

		var right_wing := MeshInstance3D.new()
		right_wing.mesh = right_wing_mesh
		right_wing.material_override = wing_mat
		bird.add_child(right_wing)
		_right_wings.append(right_wing)

		_scales.append(rng.randf_range(0.8, 1.3))


func _process(delta: float) -> void:
	_time += delta
	for i in bird_count:
		var angle: float = _phases[i] + _time * _speeds[i]
		var r: float = _radii[i]
		var pos := Vector3(cos(angle) * r, _y_offsets[i], sin(angle) * r)
		var vel_dir := Vector3(-sin(angle), 0.0, cos(angle)).normalized()
		var bird: Node3D = _bird_nodes[i]
		bird.position = pos
		# Orient along the local flight direction (look_at would use a global target).
		bird.basis = Basis.looking_at(vel_dir, Vector3.UP).scaled(Vector3.ONE * _scales[i])
		# Symmetric flap about the local forward (z) axis: both wingtips rise together.
		var flap: float = sin(_time * _flap_speeds[i] + _wing_phases[i]) * 38.0
		_right_wings[i].rotation_degrees.z = flap
		_left_wings[i].rotation_degrees.z = -flap


# Flat, swept-back, tapered wing in the bird's XZ plane, pivoting at the shoulder
# (origin) so a roll about local z flaps it. tip_sign +1 = right wing (+x), -1 = left.
static func _wing_mesh(tip_sign: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root_front := Vector3(0.0, 0.0, -0.07)
	var root_back := Vector3(0.0, 0.0, 0.11)
	var mid := Vector3(tip_sign * 0.26, 0.0, 0.0)
	var tip := Vector3(tip_sign * 0.52, 0.0, 0.17)
	for tri: Array in [[root_front, mid, root_back], [mid, tip, root_back]]:
		for v: Vector3 in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()
