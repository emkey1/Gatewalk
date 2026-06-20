class_name FishSchool
extends Node3D

const StableRng = preload("res://scripts/core/StableRng.gd")

var fish_count: int = 8
var mesh_quality: int = 0
var rng_seed: int = 1

var _fish_nodes: Array[Node3D] = []
var _phases: Array[float] = []
var _y_offsets: Array[float] = []
var _speeds: Array[float] = []
var _radii: Array[float] = []
var _time: float = 0.0


func _ready() -> void:
	var rng := StableRng.new(rng_seed)
	# Always use the detailed fish mesh, with a material that reads its per-vertex
	# body/belly/fin colors — without vertex_color_use_as_albedo they render flat.
	var mesh: ArrayMesh = _create_fish_mesh_detailed()
	var fish_mat := StandardMaterial3D.new()
	fish_mat.vertex_color_use_as_albedo = true
	fish_mat.roughness = 0.4
	fish_mat.metallic = 0.15
	for i in fish_count:
		var fish := Node3D.new()
		add_child(fish)
		_fish_nodes.append(fish)
		_phases.append(rng.randf_range(0.0, TAU))
		_y_offsets.append(rng.randf_range(-0.4, 0.4))
		_speeds.append(rng.randf_range(0.3, 0.6))
		_radii.append(rng.randf_range(2.0, 5.0))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = fish_mat
		fish.add_child(mi)
		var s := rng.randf_range(0.6, 1.2)
		mi.scale = Vector3(s, s, s)


func _process(delta: float) -> void:
	_time += delta
	for i in fish_count:
		var angle: float = _phases[i] + _time * _speeds[i]
		var r: float = _radii[i]
		var bob: float = sin(_time * 1.6 + _phases[i]) * 0.12
		var pos := Vector3(cos(angle) * r, _y_offsets[i] + bob, sin(angle) * r)
		var vel_dir := Vector3(-sin(angle), 0.0, cos(angle)).normalized()
		var fish: Node3D = _fish_nodes[i]
		fish.position = pos
		# Orient along the local swim direction (look_at would use a global target).
		fish.basis = Basis.looking_at(vel_dir, Vector3.UP)
		# Gentle side-to-side wag so they read as swimming, not gliding.
		fish.rotate_object_local(Vector3.UP, sin(_time * 7.0 + _phases[i]) * 0.14)


static func _tri(st: SurfaceTool, color: Color, n: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _extrude_tri(st: SurfaceTool, color: Color, a: Vector3, b: Vector3, c: Vector3, h: float) -> void:
	var at := Vector3(a.x, h, a.z)
	var bt := Vector3(b.x, h, b.z)
	var ct := Vector3(c.x, h, c.z)
	var ab := Vector3(a.x, -h, a.z)
	var bb := Vector3(b.x, -h, b.z)
	var cb := Vector3(c.x, -h, c.z)

	_tri(st, color, Vector3.UP, at, bt, ct)
	_tri(st, color, Vector3.DOWN, ab, cb, bb)

	var n_ab := Vector3(b.z - a.z, 0.0, a.x - b.x).normalized()
	_tri(st, color, n_ab, ab, at, bt)
	_tri(st, color, n_ab, ab, bt, bb)

	var n_bc := Vector3(c.z - b.z, 0.0, b.x - c.x).normalized()
	_tri(st, color, n_bc, bb, bt, ct)
	_tri(st, color, n_bc, bb, ct, cb)

	var n_ca := Vector3(a.z - c.z, 0.0, c.x - a.x).normalized()
	_tri(st, color, n_ca, cb, ct, at)
	_tri(st, color, n_ca, cb, at, ab)


static func _create_fish_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.30, 0.35, 0.42)
	var h: float = 0.04

	_extrude_tri(st, c, Vector3(0.0, 0.0, -0.12), Vector3(-0.07, 0.0, 0.0), Vector3(0.07, 0.0, 0.0), h)
	_extrude_tri(st, c, Vector3(0.0, 0.0, 0.10), Vector3(0.07, 0.0, 0.0), Vector3(-0.07, 0.0, 0.0), h)
	_extrude_tri(st, c, Vector3(0.0, 0.0, 0.10), Vector3(-0.09, 0.0, 0.18), Vector3(0.09, 0.0, 0.18), h)

	return st.commit()


static func _fin_tri(st: SurfaceTool, color: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


static func _add_quad_fin(st: SurfaceTool, color: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_fin_tri(st, color, a, b, c)
	_fin_tri(st, color, a, c, d)


static func _create_fish_mesh_detailed() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body_c := Color(0.30, 0.35, 0.42)
	var belly_c := Color(0.32, 0.42, 0.50)
	var fin_c := Color(0.25, 0.30, 0.38)

	var segs: int = 10
	var prof: Array[Vector2] = [
		Vector2(0.0, -0.30),
		Vector2(0.035, -0.20),
		Vector2(0.070, -0.08),
		Vector2(0.090, 0.02),
		Vector2(0.085, 0.10),
		Vector2(0.050, 0.18),
		Vector2(0.015, 0.24),
	]

	for pi in range(prof.size() - 1):
		var r1 := prof[pi].x
		var z1 := prof[pi].y
		var r2 := prof[pi + 1].x
		var z2 := prof[pi + 1].y
		for si in range(segs):
			var a1 := float(si) / float(segs) * TAU
			var a2 := float(si + 1) / float(segs) * TAU
			var p1 := Vector3(cos(a1) * r1, sin(a1) * r1, z1)
			var p2 := Vector3(cos(a2) * r1, sin(a2) * r1, z1)
			var p3 := Vector3(cos(a2) * r2, sin(a2) * r2, z2)
			var p4 := Vector3(cos(a1) * r2, sin(a1) * r2, z2)

			var c1 := belly_c if p1.y < -0.02 else body_c
			var c2 := belly_c if p2.y < -0.02 else body_c
			var c3 := belly_c if p3.y < -0.02 else body_c
			var c4 := belly_c if p4.y < -0.02 else body_c

			st.set_color(c1)
			st.add_vertex(p1)
			st.set_color(c2)
			st.add_vertex(p2)
			st.set_color(c4)
			st.add_vertex(p4)

			st.set_color(c2)
			st.add_vertex(p2)
			st.set_color(c3)
			st.add_vertex(p3)
			st.set_color(c4)
			st.add_vertex(p4)

	# Caudal fin (tail) — upper lobe
	_add_quad_fin(st, fin_c,
		Vector3(-0.04, 0.04, 0.24),
		Vector3(-0.12, 0.14, 0.36),
		Vector3(0.12, 0.14, 0.36),
		Vector3(0.04, 0.04, 0.24))

	# Caudal fin — lower lobe
	_add_quad_fin(st, fin_c,
		Vector3(-0.04, -0.04, 0.24),
		Vector3(0.04, -0.04, 0.24),
		Vector3(0.12, -0.14, 0.36),
		Vector3(-0.12, -0.14, 0.36))

	# Dorsal fin (top)
	_fin_tri(st, fin_c,
		Vector3(0.0, 0.088, -0.02),
		Vector3(0.0, 0.088 + 0.065, 0.06),
		Vector3(0.0, 0.082, 0.16))

	# Anal fin (bottom, near tail)
	_fin_tri(st, fin_c,
		Vector3(0.0, -0.080, 0.10),
		Vector3(0.0, -0.080 - 0.035, 0.14),
		Vector3(0.0, -0.070, 0.17))

	# Pectoral fins (sides)
	_fin_tri(st, fin_c,
		Vector3(-0.078, -0.01, 0.02),
		Vector3(-0.14, 0.02, 0.06),
		Vector3(-0.078, 0.03, 0.08))

	_fin_tri(st, fin_c,
		Vector3(0.078, -0.01, 0.02),
		Vector3(0.078, 0.03, 0.08),
		Vector3(0.14, 0.02, 0.06))

	st.generate_normals()
	return st.commit()
