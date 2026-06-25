extends SceneTree

# Throwaway render harness: build the liner over a water plane and snapshot it from several
# angles to /tmp, to eyeball massing/overhang without booting the whole game. Run WINDOWED:
#   /Users/mke/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/validation/_shot.gd

func _init() -> void:
	var root := get_root()
	root.size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	sun.light_energy = 0.5
	world.add_child(sun)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.67, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.76)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
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
	Liner.build(world, 12345, wl)

	var cam := Camera3D.new()
	cam.fov = 60.0
	world.add_child(cam)
	cam.current = true
	await process_frame   # let the camera enter the tree before look_at

	var shots := [
		# Image 1 repro: player on A-deck (y_main 11.86, eye ~13.5) at z~81 looking aft+down into pool well
		["i1_pool_well", Vector3(5.0, 13.5, 81.0), Vector3(-2.0, 7.5, 71.0), Vector3.UP],
		# Pool well from inside, aft-looking, to see stair + cream well walls
		["pool_aft2", Vector3(9.0, 8.6, 48.0), Vector3(2.0, 6.0, 72.0), Vector3.UP],
		# Image 2 repro: player in the Verandah Grill (floor 18.04, eye ~19.7) looking aft across the floor
		["i2_grill_eye", Vector3(8.0, 19.7, -68.0), Vector3(-2.0, 18.2, -77.0), Vector3.UP],
		# After boat deck (open) — confirm the cowl vents landed out here, not in the grill
		["after_deck", Vector3(0.0, 22.0, -78.0), Vector3(0.0, 18.0, -100.0), Vector3.UP],
		# Image 3 repro: player in the promenade gallery (floor 14.7, eye ~16.35) looking fwd + aft
		["i3_prom_fwd", Vector3(14.0, 16.35, -66.0), Vector3(14.0, 16.0, 40.0), Vector3.UP],
		["i3_prom_aft", Vector3(14.0, 16.35, -66.0), Vector3(14.0, 16.0, -110.0), Vector3.UP],
	]
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2], s[3])
		for i in range(6):
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("/tmp/liner_%s.png" % s[0])
		print("shot %s saved" % s[0])
	quit()
