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
		# Sports-deck companion-head from above (fwd-port) — etched-glass balustrade round the hatch
		["sports_hatch", Vector3(2.0, 23.9, -49.5), Vector3(7.0, 20.9, -57.0), Vector3.UP],
		# Step-off POV on the sports deck looking forward at the hatch + the aftmost funnel beyond
		["sports_emerge", Vector3(6.5, 22.7, -63.0), Vector3(6.5, 21.2, -54.5), Vector3.UP],
		# Inside the Verandah Grill: looking up the flight between the burl stringers to the open hatch
		["grill_stair", Vector3(6.5, 18.9, -52.7), Vector3(6.5, 20.7, -57.5), Vector3.UP],
		# The decorative Deco lift on the grill's starboard wall, head-on from inboard
		["grill_lift", Vector3(9.2, 19.3, -54.0), Vector3(12.5, 19.1, -54.0), Vector3.UP],
		# Exterior aft-3/4 — confirm the small companion-head reads on the sports deck silhouette
		["aft34", Vector3(120.0, 52.0, -235.0), Vector3(0.0, 16.0, -55.0), Vector3.UP],
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
