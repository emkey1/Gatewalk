class_name BirdFlock
extends Node3D

const StableRng = preload("res://scripts/core/StableRng.gd")

var bird_count: int = 10
var mesh_quality: int = 0
var rng_seed: int = 1

var _bird_nodes: Array[Node3D] = []
var _phases: Array[float] = []
var _y_offsets: Array[float] = []
var _speeds: Array[float] = []
var _radii: Array[float] = []
var _wing_phases: Array[float] = []
var _time: float = 0.0


func _ready() -> void:
	var rng := StableRng.new(rng_seed)
	var mesh: ArrayMesh = _create_bird_mesh() if mesh_quality < 2 else _create_bird_mesh_detailed()
	for i in bird_count:
		var bird := Node3D.new()
		add_child(bird)
		_bird_nodes.append(bird)
		_phases.append(rng.randf_range(0.0, TAU))
		_y_offsets.append(rng.randf_range(-2.0, 2.0))
		_speeds.append(rng.randf_range(0.4, 0.8))
		_radii.append(rng.randf_range(7.0, 16.0))
		_wing_phases.append(rng.randf_range(0.0, TAU))

		var body := MeshInstance3D.new()
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.10 if mesh_quality < 2 else 0.14
		body_mesh.height = body_mesh.radius * 1.5
		body.mesh = body_mesh
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.18, 0.12, 0.10)
		body_mat.roughness = 0.9
		body.material_override = body_mat
		body.scale = Vector3(rng.randf_range(1.0, 1.4), rng.randf_range(0.8, 1.1), rng.randf_range(1.4, 1.9))
		bird.add_child(body)

		var wing_mat := StandardMaterial3D.new()
		wing_mat.albedo_color = Color(0.15, 0.10, 0.08)
		wing_mat.roughness = 0.95

		var left_wing := MeshInstance3D.new()
		var right_wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(0.28, 0.02, 0.62)
		left_wing.mesh = wing_mesh
		right_wing.mesh = wing_mesh
		left_wing.material_override = wing_mat
		right_wing.material_override = wing_mat
		left_wing.position = Vector3(-0.16, 0.0, 0.0)
		right_wing.position = Vector3(0.16, 0.0, 0.0)
		left_wing.rotation_degrees.z = -32.0
		right_wing.rotation_degrees.z = 32.0
		bird.add_child(left_wing)
		bird.add_child(right_wing)


func _process(delta: float) -> void:
	_time += delta
	for i in bird_count:
		var angle: float = _phases[i] + _time * _speeds[i]
		var r: float = _radii[i]
		var pos := Vector3(cos(angle) * r, _y_offsets[i], sin(angle) * r)
		var vel_dir := Vector3(-sin(angle), 0.0, cos(angle)).normalized()
		_bird_nodes[i].position = pos
		_bird_nodes[i].look_at(pos + vel_dir, Vector3.UP)
		_bird_nodes[i].rotation_degrees.z = sin(_time * 8.0 + _wing_phases[i]) * 6.0


static func _tri(st: SurfaceTool, normal: Vector3, color: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_color(color)
	st.set_normal(normal)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _paddle(st: SurfaceTool, color: Color, nu: Vector3, nd: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	_tri(st, nu, color, a, b, c)
	_tri(st, nd, color, a, c, b)


static func _create_bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.15, 0.1, 0.08)
	var ws := 0.35
	var bl := 0.25
	var nu := Vector3.UP
	var nd := Vector3.DOWN

	_paddle(st, c, nu, nd, Vector3(0.0, 0.0, -bl), Vector3(-ws, 0.0, 0.0), Vector3(0.0, 0.0, bl))
	_paddle(st, c, nu, nd, Vector3(0.0, 0.0, -bl), Vector3(0.0, 0.0, bl), Vector3(ws, 0.0, 0.0))

	return st.commit()


static func _create_bird_mesh_detailed() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.15, 0.1, 0.08)

	var body: Array[Vector3] = [
		Vector3(0.0, 0.0, -0.32), Vector3(-0.04, 0.0, -0.22), Vector3(0.04, 0.0, -0.22),
		Vector3(-0.04, 0.0, -0.22), Vector3(-0.07, 0.0, -0.08), Vector3(0.04, 0.0, -0.22),
		Vector3(-0.07, 0.0, -0.08), Vector3(0.07, 0.0, -0.08), Vector3(0.04, 0.0, -0.22),
		Vector3(-0.07, 0.0, -0.08), Vector3(-0.09, 0.0, 0.08), Vector3(0.07, 0.0, -0.08),
		Vector3(-0.09, 0.0, 0.08), Vector3(0.09, 0.0, 0.08), Vector3(0.07, 0.0, -0.08),
		Vector3(-0.09, 0.0, 0.08), Vector3(-0.05, 0.0, 0.18), Vector3(0.09, 0.0, 0.08),
		Vector3(-0.05, 0.0, 0.18), Vector3(0.05, 0.0, 0.18), Vector3(0.09, 0.0, 0.08),
		Vector3(-0.05, 0.0, 0.18), Vector3(-0.12, 0.0, 0.30), Vector3(0.0, 0.0, 0.36),
		Vector3(-0.05, 0.0, 0.18), Vector3(0.0, 0.0, 0.36), Vector3(0.05, 0.0, 0.18),
		Vector3(0.05, 0.0, 0.18), Vector3(0.0, 0.0, 0.36), Vector3(0.12, 0.0, 0.30),
	]
	for i in range(0, body.size(), 3):
		_paddle(st, c, Vector3.UP, Vector3.DOWN, body[i], body[i + 1], body[i + 2])

	var ws: float = 0.28
	_paddle(st, c, Vector3.UP, Vector3.DOWN, Vector3(-0.06, 0.0, -0.04), Vector3(-ws, 0.0, 0.02), Vector3(-0.08, 0.0, 0.08))
	_paddle(st, c, Vector3.UP, Vector3.DOWN, Vector3(0.06, 0.0, -0.04), Vector3(0.08, 0.0, 0.08), Vector3(ws, 0.0, 0.02))

	return st.commit()
