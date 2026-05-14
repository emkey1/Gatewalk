extends RefCounted
class_name MoonSkyFactory


static func create_moon_sky(parent: Node3D, world_seed: int, graphics_level: int) -> Node3D:
	var sky := Node3D.new()
	sky.name = "MoonSkyDetails"
	parent.add_child(sky)

	var earth := Node3D.new()
	earth.name = "DistantBlueWorld"
	earth.position = Vector3(500.0, 115.0, -440.0)

	var star_rng := StableRng.new(StableRng.mix_string(world_seed, "moon_stars"))
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(0.78, 0.88, 1.0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.62, 0.78, 1.0)
	star_mat.emission_energy_multiplier = 1.8
	star_mat.no_depth_test = true
	var star_count: int = 180 if graphics_level >= 1 else 90
	for star_index in range(star_count):
		var star_angle: float = star_rng.randf_range(0.0, TAU)
		var star_elev: float = star_rng.randf_range(10.0, 82.0)
		var star_dist: float = star_rng.randf_range(700.0, 1250.0)
		var star := MeshInstance3D.new()
		star.name = "MoonStar"
		var star_mesh := SphereMesh.new()
		var radius: float = star_rng.randf_range(0.45, 1.2)
		star_mesh.radius = radius
		star_mesh.height = radius * 2.0
		star_mesh.radial_segments = 6
		star_mesh.rings = 3
		star.mesh = star_mesh
		star.material_override = star_mat
		star.position = Vector3(
			cos(star_angle) * cos(deg_to_rad(star_elev)) * star_dist,
			sin(deg_to_rad(star_elev)) * star_dist,
			sin(star_angle) * cos(deg_to_rad(star_elev)) * star_dist,
		)
		sky.add_child(star)

	var planet_radius: float = 80.0
	var earth_surf := SurfaceTool.new()
	earth_surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lat in range(16):
		var theta1: float = float(lat) / 16.0 * PI
		var theta2: float = float(lat + 1) / 16.0 * PI
		for lon in range(32):
			var phi1: float = float(lon) / 32.0 * TAU
			var phi2: float = float(lon + 1) / 32.0 * TAU
			var p1 := _sphere_point(planet_radius, theta1, phi1)
			var p2 := _sphere_point(planet_radius, theta2, phi1)
			var p3 := _sphere_point(planet_radius, theta2, phi2)
			var p4 := _sphere_point(planet_radius, theta1, phi2)
			_add_planet_vertex(earth_surf, p1, world_seed)
			_add_planet_vertex(earth_surf, p2, world_seed)
			_add_planet_vertex(earth_surf, p3, world_seed)
			_add_planet_vertex(earth_surf, p1, world_seed)
			_add_planet_vertex(earth_surf, p3, world_seed)
			_add_planet_vertex(earth_surf, p4, world_seed)
	earth_surf.generate_normals()
	var sphere_mi := MeshInstance3D.new()
	sphere_mi.name = "PlanetSurface"
	sphere_mi.mesh = earth_surf.commit()
	var planet_mat := StandardMaterial3D.new()
	planet_mat.vertex_color_use_as_albedo = true
	planet_mat.roughness = 0.85
	sphere_mi.material_override = planet_mat
	earth.add_child(sphere_mi)

	var glow_mat_earth := StandardMaterial3D.new()
	glow_mat_earth.albedo_color = Color(0.30, 0.60, 1.0, 0.12)
	glow_mat_earth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat_earth.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mat_earth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var glow_mi := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = planet_radius * 1.04
	glow_mesh.height = planet_radius * 2.08
	glow_mesh.radial_segments = 48
	glow_mesh.rings = 24
	glow_mi.mesh = glow_mesh
	glow_mi.material_override = glow_mat_earth
	earth.add_child(glow_mi)

	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.25)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var planet_rng := StableRng.new(StableRng.mix_string(world_seed, "moon_planet_clouds"))
	for cb in range(8):
		var cloud_theta: float = planet_rng.randf_range(0.0, TAU)
		var cloud_phi: float = planet_rng.randf_range(-PI * 0.35, PI * 0.35)
		var cloud_dir: Vector3 = _sphere_point(planet_radius + 2.5, cloud_phi, cloud_theta).normalized()
		var cloud_blob := MeshInstance3D.new()
		var cbm := SphereMesh.new()
		var cr: float = planet_rng.randf_range(4.0, 12.0)
		cbm.radius = cr
		cbm.height = cr * planet_rng.randf_range(0.3, 0.6)
		cloud_blob.mesh = cbm
		cloud_blob.material_override = cloud_mat
		cloud_blob.position = cloud_dir * planet_rng.randf_range(planet_radius * 0.62, planet_radius * 0.86)
		cloud_blob.rotation_degrees = Vector3(
			planet_rng.randf_range(-20, 20),
			planet_rng.randf_range(0, 360),
			planet_rng.randf_range(-10, 10),
		)
		earth.add_child(cloud_blob)

	sky.add_child(earth)

	var rim := MeshInstance3D.new()
	rim.name = "MoonHorizonGlow"
	var rim_mesh := TorusMesh.new()
	rim_mesh.outer_radius = 600.0
	rim_mesh.inner_radius = 598.0
	rim.mesh = rim_mesh
	rim.position = Vector3(0.0, -6.0, -900.0)
	rim.rotation_degrees.x = 90.0
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.18, 0.45, 0.95, 0.20)
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.08, 0.22, 0.65)
	rim_mat.emission_energy_multiplier = 0.8
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.material_override = rim_mat
	sky.add_child(rim)

	return sky


static func _sphere_point(r: float, theta: float, phi: float) -> Vector3:
	return Vector3(
		r * sin(theta) * cos(phi),
		r * cos(theta),
		r * sin(theta) * sin(phi),
	)


static func _earth_color(p: Vector3, seed: int) -> Color:
	var n: Vector3 = p.normalized()
	var lon := atan2(n.z, n.x)
	var lat := acos(n.y)
	var sx := cos(lat) * 3.5 + 1000.0
	var sz := sin(lat) * 2.8 + float(seed) * 0.1
	var noise_val := sin(lon * 3.0 + sx) * 0.5 + sin(lon * 7.0 + sx * 1.3) * 0.25 + sin(lon * 13.0 + sx * 0.7) * 0.15
	noise_val += sin(lat * 4.0 + sz) * 0.3 + sin(lat * 8.0 + sz * 1.5) * 0.15
	var land: float = clamp((noise_val + 1.0) * 0.5, 0.0, 1.0)
	if land > 0.52:
		var green: float = 0.45 + sin(noise_val * 17.0) * 0.10
		return Color(0.12, green, 0.08)
	elif land > 0.44:
		return Color(0.72, 0.68, 0.52)
	elif land > 0.38:
		return Color(0.30, 0.38, 0.48)
	return Color(0.08, 0.22, 0.55)


static func _add_planet_vertex(surface: SurfaceTool, point: Vector3, world_seed: int) -> void:
	surface.set_uv(Vector2(0.0, 0.0))
	surface.set_color(_earth_color(point, world_seed))
	surface.set_normal(point.normalized())
	surface.add_vertex(point)
