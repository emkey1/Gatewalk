extends RefCounted
class_name MapGenerator

const GRID_SIZE: int = 224
const CELL_SIZE: float = 2.0
const HEIGHT_SCALE: float = 15.0
const WATER_LEVEL: float = -1.7

var world_seed: int
var graphics_level: int
var density_level: int
var map_type: String
var moon_grid_scale: int = 1

var noise: FastNoiseLite
var height_values: PackedFloat32Array
var generated_root: Node3D


func _init(config: Dictionary) -> void:
	world_seed = int(config.get("world_seed", 12345))
	graphics_level = int(config.get("graphics_level", 0))
	density_level = int(config.get("density_level", 2))
	map_type = str(config.get("map_type", WorldGraph.MAP_NORMAL))


func generate(root: Node3D) -> void:
	generated_root = root
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.020
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 1.9
	noise.fractal_gain = 0.45

	if map_type == WorldGraph.MAP_MOON:
		moon_grid_scale = 2

	if map_type == WorldGraph.MAP_GATE_ROOM:
		_create_gate_room_terrain()
		_create_world_bounds()
	elif map_type == WorldGraph.MAP_CAVE:
		_create_cave_terrain()
		_create_world_bounds()
	elif map_type == WorldGraph.MAP_NEXUS:
		_create_map_nexus_terrain()
		_create_world_bounds()
	else:
		_build_height_values()
		_create_terrain_mesh()
		_create_terrain_collision()
		_create_world_bounds()
		_place_rivers()
		_create_water()

		if map_type == WorldGraph.MAP_MOON:
			_create_moon_sky()
		elif map_type != WorldGraph.MAP_WATER:
			_create_sky_clouds()


func _effective_grid_size() -> int:
	if map_type == WorldGraph.MAP_MOON:
		return GRID_SIZE * moon_grid_scale
	return GRID_SIZE


func _world_half_size() -> float:
	return float(_effective_grid_size()) * CELL_SIZE * 0.5


func _height_index(x: int, z: int) -> int:
	var g: int = GRID_SIZE + 1
	if map_type == WorldGraph.MAP_MOON:
		g = (GRID_SIZE * moon_grid_scale) + 1
	return z * g + x


func _grid_to_world_x(x: int) -> float:
	var g: float = float(GRID_SIZE)
	var c: float = float(CELL_SIZE)
	if map_type == WorldGraph.MAP_MOON:
		g = float(GRID_SIZE * moon_grid_scale)
		c = float(CELL_SIZE)
	return (float(x) - g * 0.5) * c


func _grid_to_world_z(z: int) -> float:
	var g: float = float(GRID_SIZE)
	var c: float = float(CELL_SIZE)
	if map_type == WorldGraph.MAP_MOON:
		g = float(GRID_SIZE * moon_grid_scale)
		c = float(CELL_SIZE)
	return (float(z) - g * 0.5) * c


func _height_at_world(wx: float, wz: float) -> float:
	if map_type == WorldGraph.MAP_GATE_ROOM or map_type == WorldGraph.MAP_CAVE or map_type == WorldGraph.MAP_NEXUS:
		return 0.0

	if map_type == WorldGraph.MAP_MOON:
		var scale: float = 1.0 / float(moon_grid_scale)
		var lunar_broad: float = noise.get_noise_2d(wx * 0.45 * scale + 600.0, wz * 0.45 * scale - 1200.0) * 5.0
		var lunar_craters: float = noise.get_noise_2d(wx * 2.8 * scale - 400.0, wz * 2.8 * scale + 700.0) * 1.4
		var crater_bowls: float = abs(noise.get_noise_2d(wx * 0.12 * scale + 330.0, wz * 0.12 * scale - 510.0)) * -4.2
		return lunar_broad + lunar_craters + crater_bowls

	if map_type == WorldGraph.MAP_WATER:
		var islands: float = noise.get_noise_2d(wx * 0.12, wz * 0.12) * 15.0
		var detail_islands: float = noise.get_noise_2d(wx * 0.4 + 500.0, wz * 0.4 + 1000.0) * 5.0
		return islands + detail_islands - 7.0

	var broad: float = noise.get_noise_2d(wx * 0.35 + 1200.0, wz * 0.35 - 800.0) * HEIGHT_SCALE
	var hills: float = noise.get_noise_2d(wx, wz) * 5.5
	var details: float = noise.get_noise_2d(wx * 2.1 + 900.0, wz * 2.1 - 900.0) * 1.1
	var river_carve: float = _smooth_falloff(_river_distance(wx, wz), 0.0, 16.0) * 5.5
	var height: float = broad + hills + details - river_carve

	if _river_distance(wx, wz) < 6.0:
		height = min(height, WATER_LEVEL - 0.45 + abs(_river_distance(wx, wz)) * 0.05)

	return height


func _raw_height_at_grid(x: int, z: int) -> float:
	var wx: float = _grid_to_world_x(x)
	var wz: float = _grid_to_world_z(z)
	return _height_at_world(wx, wz)


func _build_height_values() -> void:
	var g: int = _effective_grid_size()
	height_values.clear()
	height_values.resize((g + 1) * (g + 1))

	for z in range(g + 1):
		for x in range(g + 1):
			height_values[_height_index(x, z)] = _raw_height_at_grid(x, z)


func _terrain_color(pos: Vector3) -> Color:
	if map_type == WorldGraph.MAP_GATE_ROOM or map_type == WorldGraph.MAP_NEXUS:
		return Color(0.10, 0.11, 0.14)

	if map_type == WorldGraph.MAP_CAVE:
		return Color(0.12, 0.10, 0.08)

	if map_type == WorldGraph.MAP_MOON:
		if pos.y > 4.0:
			return Color(0.34, 0.36, 0.43)
		if pos.y < -2.0:
			return Color(0.16, 0.17, 0.21)
		return Color(0.25, 0.26, 0.31)

	if map_type == WorldGraph.MAP_WATER:
		if pos.y > WATER_LEVEL + 0.25:
			return Color(0.62, 0.55, 0.34)
		return Color(0.28, 0.25, 0.18)

	var river: float = _river_distance(pos.x, pos.z)
	if pos.y <= WATER_LEVEL + 0.25 or river < 7.5:
		return Color(0.42, 0.34, 0.18)
	if pos.y > 12.0:
		return Color(0.48, 0.48, 0.44)
	if pos.y > 7.5:
		return Color(0.30, 0.38, 0.22)
	if _biome_value(pos.x, pos.z) > 0.28:
		return Color(0.18, 0.47, 0.17)
	return Color(0.24, 0.43, 0.18)


func _biome_value(wx: float, wz: float) -> float:
	return noise.get_noise_2d(wx * 0.28 - 2500.0, wz * 0.28 + 1700.0)


func _river_distance(wx: float, wz: float) -> float:
	var curve: float = sin(wx * 0.025) * 22.0 + noise.get_noise_2d(wx * 0.2 + 3200.0, 410.0) * 16.0
	return abs(wz - curve)


func _smooth_falloff(value: float, edge0: float, edge1: float) -> float:
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color_a: Color, color_b: Color, color_c: Color) -> void:
	st.set_color(color_a)
	st.add_vertex(a)
	st.set_color(color_b)
	st.add_vertex(b)
	st.set_color(color_c)
	st.add_vertex(c)


func _create_terrain_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g: int = _effective_grid_size()
	for z in range(g):
		for x in range(g):
			var p00: Vector3 = Vector3(_grid_to_world_x(x), height_values[_height_index(x, z)], _grid_to_world_z(z))
			var p10: Vector3 = Vector3(_grid_to_world_x(x + 1), height_values[_height_index(x + 1, z)], _grid_to_world_z(z))
			var p01: Vector3 = Vector3(_grid_to_world_x(x), height_values[_height_index(x, z + 1)], _grid_to_world_z(z + 1))
			var p11: Vector3 = Vector3(_grid_to_world_x(x + 1), height_values[_height_index(x + 1, z + 1)], _grid_to_world_z(z + 1))

			_add_triangle(st, p00, p10, p11, _terrain_color(p00), _terrain_color(p10), _terrain_color(p11))
			_add_triangle(st, p00, p11, p01, _terrain_color(p00), _terrain_color(p11), _terrain_color(p01))

	st.generate_normals()
	var terrain_mesh := st.commit()

	var terrain := MeshInstance3D.new()
	terrain.name = "GeneratedTerrain"
	terrain.mesh = terrain_mesh

	var terrain_mat := StandardMaterial3D.new()
	terrain_mat.vertex_color_use_as_albedo = true
	if graphics_level >= 2:
		terrain_mat.roughness = 0.75
		terrain_mat.normal_enabled = true
		terrain_mat.normal_scale = 0.25
		var terrain_noise := FastNoiseLite.new()
		terrain_noise.seed = world_seed
		terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		terrain_noise.frequency = 0.015
		var noise_tex := NoiseTexture2D.new()
		noise_tex.noise = terrain_noise
		noise_tex.normalize = true
		terrain_mat.normal_texture = noise_tex
	else:
		terrain_mat.roughness = 1.0
	terrain.material_override = terrain_mat

	generated_root.add_child(terrain)


func _create_terrain_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := HeightMapShape3D.new()
	var g: int = _effective_grid_size()
	shape.map_width = g + 1
	shape.map_depth = g + 1
	shape.map_data = height_values

	var collision := CollisionShape3D.new()
	collision.name = "TerrainHeightMapCollision"
	collision.shape = shape
	collision.scale = Vector3(CELL_SIZE, 1.0, CELL_SIZE)

	body.add_child(collision)
	generated_root.add_child(body)


func _create_gate_room_terrain() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.09, 0.12)
	floor_mat.roughness = 0.80

	var floor := MeshInstance3D.new()
	floor.name = "GateRoomFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 32.0
	floor_mesh.bottom_radius = 32.0
	floor_mesh.height = 0.6
	floor_mesh.radial_segments = 32
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.position.y = -0.3
	generated_root.add_child(floor)

	var body := StaticBody3D.new()
	body.name = "GateRoomFloorBody"
	var col_shape := CollisionShape3D.new()
	var col_cyl := CylinderShape3D.new()
	col_cyl.radius = 32.0
	col_cyl.height = 0.6
	col_shape.shape = col_cyl
	col_shape.position.y = -0.3
	body.add_child(col_shape)
	generated_root.add_child(body)

	for i in range(24):
		var angle: float = TAU * float(i) / 24.0
		var wall_mat := StandardMaterial3D.new()
		wall_mat.albedo_color = Color(0.12, 0.13, 0.18)
		wall_mat.roughness = 0.9
		var wall := MeshInstance3D.new()
		wall.name = "GateRoomWall_" + str(i)
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(2.5, 8.0, 0.6)
		wall.mesh = wall_mesh
		wall.material_override = wall_mat
		wall.position = Vector3(cos(angle) * 31.5, 4.0, sin(angle) * 31.5)
		wall.rotation_degrees.y = -rad_to_deg(angle) + 90.0
		generated_root.add_child(wall)


func _create_cave_terrain() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.12, 0.10, 0.08)
	stone_mat.roughness = 0.95
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.20, 0.70, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.10, 0.50, 0.90)
	glow_mat.emission_energy_multiplier = 1.5

	var floor := MeshInstance3D.new()
	floor.name = "CaveFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 45.0
	floor_mesh.bottom_radius = 45.0
	floor_mesh.height = 0.8
	floor_mesh.radial_segments = 32
	floor.mesh = floor_mesh
	floor.material_override = stone_mat
	floor.position.y = -0.4
	generated_root.add_child(floor)

	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_cyl := CylinderShape3D.new()
	floor_cyl.radius = 45.0
	floor_cyl.height = 0.8
	floor_col.shape = floor_cyl
	floor_col.position.y = -0.4
	floor_body.add_child(floor_col)
	generated_root.add_child(floor_body)

	var ceiling_mat := StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.10, 0.08, 0.06)
	ceiling_mat.roughness = 1.0
	var ceiling := MeshInstance3D.new()
	ceiling.name = "CaveCeiling"
	var ceiling_mesh := CylinderMesh.new()
	ceiling_mesh.top_radius = 44.0
	ceiling_mesh.bottom_radius = 44.0
	ceiling_mesh.height = 0.5
	ceiling_mesh.radial_segments = 32
	ceiling.mesh = ceiling_mesh
	ceiling.material_override = ceiling_mat
	ceiling.position.y = 8.0
	generated_root.add_child(ceiling)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.14, 0.11, 0.09)
	wall_mat.roughness = 1.0
	for i in range(32):
		var angle: float = TAU * float(i) / 32.0
		var wall := MeshInstance3D.new()
		wall.name = "CaveWall_" + str(i)
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(3.0, 9.0, 0.8)
		wall.mesh = wall_mesh
		wall.material_override = wall_mat
		wall.position = Vector3(cos(angle) * 44.5, 4.0, sin(angle) * 44.5)
		wall.rotation_degrees.y = -rad_to_deg(angle) + 90.0
		generated_root.add_child(wall)


func _create_world_bounds() -> void:
	var half: float = _world_half_size()
	var wall_height: float = 80.0
	var wall_thickness: float = 4.0
	var wall_center_y: float = 18.0
	var wall_length: float = float(_effective_grid_size()) * CELL_SIZE + wall_thickness * 2.0

	var bounds := Node3D.new()
	bounds.name = "WorldEdgeBarriers"
	generated_root.add_child(bounds)
	CollisionFactory.add_box(bounds, Vector3(half, wall_center_y, 0.0), Vector3(wall_thickness, wall_height, wall_length))
	CollisionFactory.add_box(bounds, Vector3(-half, wall_center_y, 0.0), Vector3(wall_thickness, wall_height, wall_length))
	CollisionFactory.add_box(bounds, Vector3(0.0, wall_center_y, half), Vector3(wall_length, wall_height, wall_thickness))
	CollisionFactory.add_box(bounds, Vector3(0.0, wall_center_y, -half), Vector3(wall_length, wall_height, wall_thickness))
	CollisionFactory.add_box(bounds, Vector3(0.0, -45.0, 0.0), Vector3(wall_length * 2.0, 0.2, wall_length * 2.0))


func _place_rivers() -> void:
	if map_type == WorldGraph.MAP_MOON or map_type == WorldGraph.MAP_WATER:
		return
	var g: int = _effective_grid_size()
	var river_mat := StandardMaterial3D.new()
	river_mat.albedo_color = Color(0.32, 0.28, 0.18)
	for z in range(g):
		for x in range(g):
			var wx: float = _grid_to_world_x(x)
			var wz: float = _grid_to_world_z(z)
			if _river_distance(wx, wz) < 5.5:
				var p: Vector3 = Vector3(wx, WATER_LEVEL - 0.5, wz)
				var bed := MeshInstance3D.new()
				var bed_mesh := BoxMesh.new()
				bed_mesh.size = Vector3(CELL_SIZE, 0.15, CELL_SIZE)
				bed.mesh = bed_mesh
				bed.material_override = river_mat
				bed.position = Vector3(wx + CELL_SIZE * 0.5, p.y, wz + CELL_SIZE * 0.5)
				generated_root.add_child(bed)


func _create_water() -> void:
	if map_type == WorldGraph.MAP_MOON or map_type == WorldGraph.MAP_CAVE:
		return
	if map_type == WorldGraph.MAP_GATE_ROOM or map_type == WorldGraph.MAP_NEXUS:
		return

	var water_size: float = float(_effective_grid_size()) * CELL_SIZE

	var water := MeshInstance3D.new()
	water.name = "RiverAndLakeWater"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(water_size, water_size)
	water_mesh.subdivide_depth = 8
	water_mesh.subdivide_width = 8
	water.mesh = water_mesh
	water.position.y = WATER_LEVEL
	water.rotation_degrees.x = 90.0

	var mat: ShaderMaterial
	if graphics_level >= 1 and not (map_type == WorldGraph.MAP_GATE_ROOM or map_type == WorldGraph.MAP_NEXUS):
		mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/water.gdshader")
		mat.set_shader_parameter("wave_strength", 0.10)
		mat.set_shader_parameter("wave_speed", 0.15)
		mat.set_shader_parameter("deep_color", Color(0.05, 0.15, 0.30))
		mat.set_shader_parameter("shallow_color", Color(0.15, 0.40, 0.50))
		mat.set_shader_parameter("sheen_strength", 0.32)
		mat.set_shader_parameter("alpha_boost", 0.0)
	else:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/water.gdshader")
		mat.set_shader_parameter("wave_strength", 0.04)
		mat.set_shader_parameter("wave_speed", 0.08)
		mat.set_shader_parameter("deep_color", Color(0.05, 0.15, 0.30))
		mat.set_shader_parameter("shallow_color", Color(0.15, 0.40, 0.50))
		mat.set_shader_parameter("sheen_strength", 0.32)
		mat.set_shader_parameter("alpha_boost", 0.0)

	water.material_override = mat
	generated_root.add_child(water)

	var water_collision := StaticBody3D.new()
	water_collision.name = "WaterCollision"
	water_collision.collision_layer = 4
	water_collision.collision_mask = 0

	var water_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(water_size, 0.2, water_size)
	water_shape.shape = box

	water_collision.add_child(water_shape)
	water_collision.position.y = WATER_LEVEL
	generated_root.add_child(water_collision)


func _create_sky_clouds() -> void:
	if map_type == WorldGraph.MAP_MOON or map_type == WorldGraph.MAP_CAVE:
		return
	if graphics_level == 0:
		return

	var cloud_root := Node3D.new()
	cloud_root.name = "SkyClouds"
	generated_root.add_child(cloud_root)

	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.90, 0.92, 0.95, 0.55)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var half: float = _world_half_size() * 0.45
	for i in range(120):
		var cp := MeshInstance3D.new()
		var cm := BoxMesh.new()
		var w: float = randf_range(15.0, 50.0)
		var d: float = randf_range(10.0, 30.0)
		var h: float = randf_range(1.5, 4.5)
		cm.size = Vector3(w, h, d)
		cp.mesh = cm
		cp.material_override = cloud_mat
		cp.position = Vector3(randf_range(-half, half), randf_range(65.0, 90.0), randf_range(-half, half))
		cloud_root.add_child(cp)


func _earth_color(p: Vector3, seed: int) -> Color:
	var rng := StableRng.new(seed)
	var px: float = p.x * 0.5 + rng.randf() * 0.2
	var pz: float = p.z * 0.5 + rng.randf() * 0.2
	var land: float = noise.get_noise_2d(px * 1.5 + 50.0, pz * 1.5 + 100.0) * 0.3 + 0.3
	land += rng.randf() * 0.1
	if land < 0.38:
		return Color(0.22, 0.40, 0.70, 1.0)
	var hue: float = rng.randf_range(0.25, 0.35)
	var sat: float = rng.randf_range(0.45, 0.70)
	var val: float = rng.randf_range(0.30, 0.55)
	return Color.from_hsv(hue, sat, val, 1.0)


func _create_moon_sky() -> void:
	var sky := Node3D.new()
	sky.name = "MoonSkyDetails"
	generated_root.add_child(sky)

	var earth := Node3D.new()
	earth.name = "DistantBlueWorld"
	earth.position = Vector3(500.0, 100.0, -360.0)

	var segs: int = 18
	var rings: int = 12
	var e_verts: PackedVector3Array = []
	var e_normals: PackedVector3Array = []
	var e_colors: PackedColorArray = []
	var e_u: Array[Vector2] = []
	for lon in range(segs):
		for lat in range(rings):
			var theta1: float = float(lon) / float(segs) * TAU
			var theta2: float = float(lon + 1) / float(segs) * TAU
			var phi1: float = float(lat) / float(rings) * PI
			var phi2: float = float(lat + 1) / float(rings) * PI
			for corner in range(4):
				var theta: float = theta1 if corner % 2 == 0 else theta2
				var phi: float = phi1 if corner < 2 else phi2
				var cp: Vector3 = Vector3(sin(theta) * sin(phi), cos(phi), cos(theta) * sin(phi))
				e_verts.push_back(cp * 58.0)
				e_normals.push_back(cp)
				var seed: int = StableRng.mix_seed(world_seed, int(cp.x * 100), int(cp.z * 100))
				e_colors.push_back(_earth_color(cp, seed))
				e_u.push_back(Vector2(0, 0))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = e_verts
	arrays[Mesh.ARRAY_NORMAL] = e_normals
	arrays[Mesh.ARRAY_COLOR] = e_colors
	arrays[Mesh.ARRAY_TEX_UV] = e_u

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var sphere_mi := MeshInstance3D.new()
	sphere_mi.mesh = arr_mesh
	earth.add_child(sphere_mi)

	var glow_mesh := ArrayMesh.new()
	glow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var glow_mat_earth := StandardMaterial3D.new()
	glow_mat_earth.albedo_color = Color(0.30, 0.60, 1.0, 0.12)
	glow_mat_earth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat_earth.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mat_earth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var glow_mi := MeshInstance3D.new()
	glow_mi.mesh = glow_mesh
	glow_mi.material_override = glow_mat_earth
	glow_mi.scale = Vector3(1.0, 1.0, 1.0) * 1.05
	earth.add_child(glow_mi)

	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.25)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for cb in range(22):
		var theta: float = randf_range(0.0, TAU)
		var phi: float = randf_range(0.3, PI - 0.3)
		var dir: Vector3 = Vector3(sin(theta) * sin(phi), cos(phi), cos(theta) * sin(phi)).normalized()
		var cloud_blob := MeshInstance3D.new()
		var cbm := SphereMesh.new()
		var cr: float = randf_range(3.0, 8.0)
		cbm.radius = cr
		cbm.height = cr * 2.0
		cloud_blob.mesh = cbm
		cloud_blob.material_override = cloud_mat
		cloud_blob.position = dir * 58.5
		earth.add_child(cloud_blob)

	sky.add_child(earth)


func _create_map_nexus_terrain() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.10, 0.11, 0.14)
	floor_mat.roughness = 0.80

	var floor := MeshInstance3D.new()
	floor.name = "MapNexusFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 48.0
	floor_mesh.bottom_radius = 48.0
	floor_mesh.height = 0.6
	floor_mesh.radial_segments = 40
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.position.y = -0.3
	generated_root.add_child(floor)

	var body := StaticBody3D.new()
	body.name = "MapNexusFloorBody"
	var col_shape := CollisionShape3D.new()
	var col_cyl := CylinderShape3D.new()
	col_cyl.radius = 48.0
	col_cyl.height = 0.6
	col_shape.shape = col_cyl
	col_shape.position.y = -0.3
	body.add_child(col_shape)
	generated_root.add_child(body)
