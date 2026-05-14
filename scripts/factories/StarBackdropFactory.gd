extends RefCounted
class_name StarBackdropFactory

const StableRng = preload("res://scripts/core/StableRng.gd")


static func create_star_backdrop(parent: Node3D, world_seed: int, graphics_level: int, variant: String) -> Node3D:
	var backdrop := Node3D.new()
	backdrop.name = variant.capitalize() + "StarBackdrop"
	parent.add_child(backdrop)

	var rng := StableRng.new(StableRng.mix_string(world_seed, variant + "_stars"))
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(0.80, 0.87, 1.0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.60, 0.75, 1.0)
	star_mat.emission_energy_multiplier = 1.6
	star_mat.no_depth_test = true

	var star_count: int = 120 if graphics_level >= 1 else 60
	if variant == "map_nexus":
		star_count = 180 if graphics_level >= 1 else 90

	for i in range(star_count):
		var angle: float = rng.randf_range(0.0, TAU)
		var elev: float = rng.randf_range(8.0, 82.0)
		var dist: float = rng.randf_range(520.0, 1300.0)
		var star := MeshInstance3D.new()
		star.name = "BackdropStar"
		var star_mesh := SphereMesh.new()
		var radius: float = rng.randf_range(0.25, 0.9)
		star_mesh.radius = radius
		star_mesh.height = radius * 2.0
		star_mesh.radial_segments = 5
		star_mesh.rings = 3
		star.mesh = star_mesh
		star.material_override = star_mat
		star.position = Vector3(
			cos(angle) * cos(deg_to_rad(elev)) * dist,
			sin(deg_to_rad(elev)) * dist,
			sin(angle) * cos(deg_to_rad(elev)) * dist,
		)
		backdrop.add_child(star)

	if variant == "map_nexus":
		var glow_mat := StandardMaterial3D.new()
		glow_mat.albedo_color = Color(0.15, 0.18, 0.35, 0.12)
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(0.12, 0.16, 0.30)
		glow_mat.emission_energy_multiplier = 0.5

		var ring := MeshInstance3D.new()
		ring.name = "NexusBackdropGlow"
		var ring_mesh := TorusMesh.new()
		ring_mesh.outer_radius = 680.0
		ring_mesh.inner_radius = 676.5
		ring.mesh = ring_mesh
		ring.rotation_degrees.x = 90.0
		ring.position = Vector3(0.0, -5.0, -980.0)
		ring.material_override = glow_mat
		backdrop.add_child(ring)

	return backdrop
