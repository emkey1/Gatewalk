class_name BirdFlock
extends Node3D

var bird_count: int = 10
var mesh_quality: int = 0

var _bird_nodes: Array[Node3D] = []
var _phases: Array[float] = []
var _y_offsets: Array[float] = []
var _speeds: Array[float] = []
var _radii: Array[float] = []
var _time: float = 0.0


func _ready() -> void:
	var mesh: ArrayMesh = _create_bird_mesh() if mesh_quality < 2 else _create_bird_mesh_detailed()
	for i in bird_count:
		var bird := Node3D.new()
		add_child(bird)
		_bird_nodes.append(bird)
		_phases.append(randf_range(0.0, TAU))
		_y_offsets.append(randf_range(-2.0, 2.0))
		_speeds.append(randf_range(0.4, 0.8))
		_radii.append(randf_range(6.0, 14.0))
		var s := randf_range(0.7, 1.3)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		bird.add_child(mi)
		mi.scale = Vector3(s, s, s)


func _process(delta: float) -> void:
	_time += delta
	for i in bird_count:
		var angle: float = _phases[i] + _time * _speeds[i]
		var r: float = _radii[i]
		var pos := Vector3(cos(angle) * r, _y_offsets[i], sin(angle) * r)
		var vel_dir := Vector3(-sin(angle), 0.0, cos(angle)).normalized()
		_bird_nodes[i].position = pos
		_bird_nodes[i].look_at(pos + vel_dir, Vector3.UP)


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
