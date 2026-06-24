extends SceneTree

# Throwaway render harness: build the liner over a water plane and snapshot it from several
# angles to /tmp, to eyeball massing/overhang without booting the whole game. Run WINDOWED:
#   /Users/mke/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/validation/_shot.gd

func _init() -> void:
	var root := get_root()
	root.size = Vector2i(1600, 820)
	var world := Node3D.new()
	root.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	sun.light_energy = 1.25
	world.add_child(sun)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.67, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.76)
	env.ambient_light_energy = 0.65
	we.environment = env
	world.add_child(we)

	var wl := -1.7
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.16, 0.29, 0.42)
	wm.metallic = 0.2
	wm.roughness = 0.25
	water.material_override = wm
	water.position = Vector3(0.0, wl, 0.0)
	world.add_child(water)

	var Liner := load("res://scripts/factories/LinerFactory.gd")
	var gates: Array = Liner.build(world, 12345, wl)
	# Mark the returned gate positions (the real gates are built by Main, not the factory) so the
	# top-down shows whether they sit cleanly on the deck.
	for g in gates:
		var mk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 4.0, 1.0)
		mk.mesh = bm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(1.0, 0.1, 0.9)
		mk.material_override = mm
		mk.position = g + Vector3(0.0, 2.0, 0.0)
		world.add_child(mk)

	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	cam.current = true
	await process_frame   # let the camera enter the tree before look_at

	var shots := [
		["t48_smoking", Vector3(5.0, 16.35, -55.0), Vector3(-1.0, 15.6, -67.5), Vector3.UP],
		["t48_library", Vector3(4.0, 16.35, 47.5), Vector3(-1.0, 15.8, 39.0), Vector3.UP],
		["t48_ballroom", Vector3(7.0, 16.35, -18.5), Vector3(-1.0, 15.6, -37.0), Vector3.UP],
		["t48_shops", Vector3(7.5, 16.35, 19.5), Vector3(-2.0, 15.7, 27.0), Vector3.UP],
	]
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2], s[3])
		for i in range(5):
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("/tmp/liner_%s.png" % s[0])
		print("shot %s saved" % s[0])
	quit()
