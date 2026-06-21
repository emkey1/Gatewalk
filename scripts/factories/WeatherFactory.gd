extends RefCounted
class_name WeatherFactory

# Procedural weather particle systems. The returned Node3D is meant to be repositioned
# to follow the player horizontally (particles emit from a wide box well above them and
# fall past, in world space, so the storm feels continuous as you move).

const CLEAR := "clear"
const RAIN := "rain"
const SNOW := "snow"
const BLIZZARD := "blizzard"


# Returns a particle root for the weather type, or null for clear/unknown.
static func build(weather_type: String) -> Node3D:
	match weather_type:
		RAIN:
			return _build_rain()
		SNOW:
			return _build_snow(false)
		BLIZZARD:
			return _build_snow(true)
		_:
			return null


static func label_for(weather_type: String) -> String:
	match weather_type:
		RAIN:
			return "Rain"
		SNOW:
			return "Snowfall"
		BLIZZARD:
			return "Blizzard"
		_:
			return "Clear"


static func _build_rain() -> Node3D:
	var root := Node3D.new()
	root.name = "Weather_Rain"

	var particles := GPUParticles3D.new()
	# Dense field in a tighter column centred on the player so the rain reads when you
	# look straight ahead, not only straight up.
	particles.amount = 2000
	particles.lifetime = 1.0
	particles.preprocess = 1.0
	particles.local_coords = false
	particles.position = Vector3(0.0, 15.0, 0.0)

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(15.0, 0.5, 15.0)
	process.direction = Vector3(0.05, -1.0, 0.0)
	process.spread = 5.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(0.0, -22.0, 0.0)
	process.scale_min = 0.7
	process.scale_max = 1.2
	particles.process_material = process

	# Longer streaks so a drop overlaps itself between frames (a short streak moving fast
	# strobes into sparse dots — readable along the fall axis, not across it).
	var streak := QuadMesh.new()
	streak.size = Vector2(0.05, 1.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.76, 0.92, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.material = mat
	particles.draw_pass_1 = streak

	root.add_child(particles)
	return root


static func _build_snow(heavy: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Weather_Blizzard" if heavy else "Weather_Snow"

	var particles := GPUParticles3D.new()
	particles.amount = 900 if heavy else 450
	particles.lifetime = 5.0 if heavy else 6.5
	particles.preprocess = 5.0
	particles.local_coords = false
	particles.position = Vector3(0.0, 16.0, 0.0)

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(28.0, 0.5, 28.0)
	# A blizzard drives sideways; gentle snow drifts down.
	process.direction = Vector3(0.8, -1.0, 0.2) if heavy else Vector3(0.1, -1.0, 0.05)
	process.spread = 25.0 if heavy else 12.0
	process.initial_velocity_min = 6.0 if heavy else 1.2
	process.initial_velocity_max = 11.0 if heavy else 2.6
	process.gravity = Vector3(0.0, -3.0 if heavy else -1.2, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.1
	particles.process_material = process

	var flake := QuadMesh.new()
	flake.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.97, 1.0, 0.85 if heavy else 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.material = mat
	particles.draw_pass_1 = flake

	root.add_child(particles)
	return root
