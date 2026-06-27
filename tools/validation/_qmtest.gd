extends SceneTree

# Throwaway: load the translated QM.3mf mesh (res://assets/qm_model.bin) over water and snapshot it,
# to verify scale / orientation / placement before wiring it into the factory.
#   /Users/mke/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/validation/_qmtest.gd

func _load_qm() -> ArrayMesh:
	var f := FileAccess.open("res://assets/qm_model.bin", FileAccess.READ)
	var nv := f.get_32()
	var vf := f.get_buffer(nv * 12).to_float32_array()
	var nf := f.get_buffer(nv * 12).to_float32_array()
	var verts := PackedVector3Array(); verts.resize(nv)
	var norms := PackedVector3Array(); norms.resize(nv)
	for i in nv:
		verts[i] = Vector3(vf[i * 3], vf[i * 3 + 1], vf[i * 3 + 2])
		norms[i] = Vector3(nf[i * 3], nf[i * 3 + 1], nf[i * 3 + 2])
	var ns := f.get_32()
	var mesh := ArrayMesh.new()
	for s in ns:
		var ni := f.get_32()
		if ni == 0:
			continue
		var idx := f.get_buffer(ni * 4).to_int32_array()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _init() -> void:
	var root := get_root()
	root.size = Vector2i(1600, 900)
	var world := Node3D.new(); root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 38.0, 0.0); sun.light_energy = 0.6
	world.add_child(sun)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.55, 0.67, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.76); env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 0.9
	we.environment = env; world.add_child(we)
	var wl := -1.7
	var water := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(1400, 1400)
	water.mesh = pm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.16, 0.29, 0.42)
	wm.metallic = 0.2; wm.roughness = 0.25; water.material_override = wm
	water.position = Vector3(0.0, wl, 0.0); world.add_child(water)

	var mesh := _load_qm()
	print("surfaces=%d" % mesh.get_surface_count())
	var cols := [Color(0.07, 0.07, 0.08), Color(0.88, 0.88, 0.85), Color(0.80, 0.27, 0.10), Color(0.05, 0.05, 0.06), Color(0.55, 0.15, 0.13)]
	for s in mesh.get_surface_count():
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[s] if s < cols.size() else Color(1, 0, 1)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.8
		mesh.surface_set_material(s, m)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; world.add_child(mi)

	var cam := Camera3D.new(); cam.fov = 55.0; world.add_child(cam); cam.current = true
	await process_frame
	var shots := [
		["qm_profile", Vector3(-250.0, 42.0, 8.0), Vector3(0.0, 20.0, 8.0), Vector3.UP],
		["qm_bow", Vector3(-55.0, 16.0, 195.0), Vector3(6.0, 10.0, 150.0), Vector3.UP],
		["qm_stern", Vector3(-60.0, 18.0, -200.0), Vector3(4.0, 10.0, -150.0), Vector3.UP],
		["qm_quarter", Vector3(-150.0, 60.0, 150.0), Vector3(0.0, 15.0, 0.0), Vector3.UP],
	]
	for sh in shots:
		cam.position = sh[1]; cam.look_at(sh[2], sh[3])
		for i in range(6): await process_frame
		root.get_texture().get_image().save_png("/tmp/liner_%s.png" % sh[0])
		print("shot %s" % sh[0])
	quit()
