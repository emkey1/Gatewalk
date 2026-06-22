extends RefCounted
class_name MapGenerator

const MapContext = preload("res://scripts/core/MapContext.gd")

const GRID_SIZE: int = 224
const CELL_SIZE: float = 2.0
const HEIGHT_SCALE: float = 15.0
const WATER_LEVEL: float = -1.7

var world_seed: int
var graphics_level: int
var density_level: int
var map_type: String
var moon_grid_scale: int = 1
var map_context: MapContext

var noise: FastNoiseLite
var height_values: PackedFloat32Array
var generated_root: Node3D
var _terrain_mesh: Mesh   # kept so RUINED_CITY can build a trimesh collider matching the holed mesh


func _init(config: Dictionary) -> void:
	map_context = config.get("map_context", null)
	world_seed = int(config.get("world_seed", 12345))
	graphics_level = int(config.get("graphics_level", 0))
	density_level = int(config.get("density_level", 2))
	map_type = str(config.get("map_type", WorldGraph.MAP_NORMAL))
	if map_context != null:
		world_seed = map_context.world_seed
		map_type = map_context.map_type
		moon_grid_scale = map_context.moon_grid_scale


func generate(root: Node3D) -> void:
	generated_root = root
	noise = FastNoiseLite.new()
	if map_context == null:
		map_context = MapContext.new({
			"world_seed": world_seed,
			"map_type": map_type,
			"grid_size": GRID_SIZE,
			"cell_size": CELL_SIZE,
			"water_level": WATER_LEVEL,
			"height_scale": HEIGHT_SCALE,
			"moon_grid_scale": moon_grid_scale,
		})
	noise = map_context.noise

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
	elif map_type == WorldGraph.MAP_FLOATING_ISLAND:
		_create_floating_island_terrain()
		_create_world_bounds()
		_create_water()
		_create_sky_clouds()
	elif map_type == WorldGraph.MAP_SKYSCRAPER:
		pass   # no terrain/water — the sealed tower (built in Main's scatter) is the whole world
	else:
		_build_height_values()
		_create_terrain_mesh()
		_create_terrain_collision()
		_create_world_bounds()
		_place_rivers()
		_create_water()
		_create_lakes()

		if map_type == WorldGraph.MAP_MOON:
			_create_moon_sky()
		elif map_type != WorldGraph.MAP_WATER and map_type != WorldGraph.MAP_ARCTIC:
			_create_sky_clouds()


func _effective_grid_size() -> int:
	return _ensure_context().effective_grid_size()


func _world_half_size() -> float:
	return _ensure_context().world_half_size()


func _height_index(x: int, z: int) -> int:
	var g: int = GRID_SIZE + 1
	if map_type == WorldGraph.MAP_MOON:
		g = (GRID_SIZE * moon_grid_scale) + 1
	return z * g + x


func _grid_to_world_x(x: int) -> float:
	return _ensure_context().grid_to_world_x(x)


func _grid_to_world_z(z: int) -> float:
	return _ensure_context().grid_to_world_z(z)


func _height_at_world(wx: float, wz: float) -> float:
	return _ensure_context().height_at_world(wx, wz)


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

	if map_type == WorldGraph.MAP_ARCTIC:
		var ridge: float = clamp((_biome_value(pos.x, pos.z) + 1.0) * 0.5, 0.0, 1.0)
		var packed_snow: Color = Color(0.86, 0.90, 0.96)
		var icy_blue: Color = Color(0.70, 0.80, 0.92)
		var exposed_rock: Color = Color(0.62, 0.70, 0.82)
		if pos.y > 12.0:
			return packed_snow.lerp(icy_blue, ridge * 0.20)
		if pos.y > 7.0:
			return packed_snow.lerp(icy_blue, ridge * 0.35)
		if pos.y > 3.0:
			return icy_blue.lerp(exposed_rock, ridge * 0.40)
		return exposed_rock.lerp(Color(0.56, 0.64, 0.76), ridge * 0.30)

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
	return _ensure_context().biome_value(wx, wz)


func _river_distance(wx: float, wz: float) -> float:
	return _ensure_context().river_distance(wx, wz)


func _ensure_context() -> MapContext:
	if map_context == null:
		map_context = MapContext.new({
			"world_seed": world_seed,
			"map_type": map_type,
			"grid_size": GRID_SIZE,
			"cell_size": CELL_SIZE,
			"water_level": WATER_LEVEL,
			"height_scale": HEIGHT_SCALE,
			"moon_grid_scale": moon_grid_scale,
		})
		noise = map_context.noise
	return map_context


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
	var hole_city: bool = map_type == WorldGraph.MAP_RUINED_CITY
	for z in range(g):
		for x in range(g):
			var p00: Vector3 = Vector3(_grid_to_world_x(x), height_values[_height_index(x, z)], _grid_to_world_z(z))
			var p10: Vector3 = Vector3(_grid_to_world_x(x + 1), height_values[_height_index(x + 1, z)], _grid_to_world_z(z))
			var p01: Vector3 = Vector3(_grid_to_world_x(x), height_values[_height_index(x, z + 1)], _grid_to_world_z(z + 1))
			var p11: Vector3 = Vector3(_grid_to_world_x(x + 1), height_values[_height_index(x + 1, z + 1)], _grid_to_world_z(z + 1))

			# Punch a real hole in the ground under basement buildings so you can descend in.
			if hole_city and map_context.city_point_in_basement((p00.x + p10.x) * 0.5, (p00.z + p01.z) * 0.5):
				continue

			_add_triangle(st, p00, p10, p11, _terrain_color(p00), _terrain_color(p10), _terrain_color(p11))
			_add_triangle(st, p00, p11, p01, _terrain_color(p00), _terrain_color(p11), _terrain_color(p01))

	st.generate_normals()
	var terrain_mesh := st.commit()
	_terrain_mesh = terrain_mesh

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

	var collision := CollisionShape3D.new()
	if map_type == WorldGraph.MAP_RUINED_CITY and _terrain_mesh != null:
		# Trimesh collider so the collision has the SAME hole as the mesh (a heightmap
		# can't be holed). Vertices are already in world space, so no scale.
		collision.name = "TerrainTrimeshCollision"
		collision.shape = _terrain_mesh.create_trimesh_shape()
	else:
		var shape := HeightMapShape3D.new()
		var g: int = _effective_grid_size()
		shape.map_width = g + 1
		shape.map_depth = g + 1
		shape.map_data = height_values
		collision.name = "TerrainHeightMapCollision"
		collision.shape = shape
		collision.scale = Vector3(CELL_SIZE, 1.0, CELL_SIZE)

	body.add_child(collision)
	generated_root.add_child(body)


func _create_gate_room_terrain() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.07, 0.08, 0.12)
	floor_mat.roughness = 0.82
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.21, 0.24, 0.32)
	trim_mat.roughness = 0.62
	trim_mat.emission_enabled = true
	trim_mat.emission = Color(0.12, 0.16, 0.25)
	trim_mat.emission_energy_multiplier = 0.22
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.12, 0.14, 0.20)
	pillar_mat.roughness = 0.86

	var floor := MeshInstance3D.new()
	floor.name = "GateRoomFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 34.0
	floor_mesh.bottom_radius = 34.0
	floor_mesh.height = 0.8
	floor_mesh.radial_segments = 56
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.position.y = -0.4
	generated_root.add_child(floor)

	var floor_body := StaticBody3D.new()
	floor_body.name = "GateRoomFloorBody"
	var floor_col := CollisionShape3D.new()
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = 34.0
	floor_shape.height = 0.8
	floor_col.shape = floor_shape
	floor_col.position.y = -0.4
	floor_body.add_child(floor_col)
	generated_root.add_child(floor_body)

	var ring_walk := MeshInstance3D.new()
	ring_walk.name = "GateRoomRingWalk"
	var ring_mesh := TorusMesh.new()
	ring_mesh.outer_radius = 22.0
	ring_mesh.inner_radius = 20.0
	ring_walk.mesh = ring_mesh
	ring_walk.material_override = trim_mat
	ring_walk.position = Vector3(0.0, 0.28, 0.0)
	ring_walk.rotation_degrees.x = 90.0
	generated_root.add_child(ring_walk)

	var center_dais := MeshInstance3D.new()
	center_dais.name = "GateRoomCenterDais"
	var dais_mesh := CylinderMesh.new()
	dais_mesh.top_radius = 7.0
	dais_mesh.bottom_radius = 7.6
	dais_mesh.height = 1.2
	dais_mesh.radial_segments = 24
	center_dais.mesh = dais_mesh
	center_dais.material_override = trim_mat
	center_dais.position = Vector3(0.0, 0.6, 0.0)
	generated_root.add_child(center_dais)

	var cardinal_angles: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	for ci in range(cardinal_angles.size()):
		var angle: float = cardinal_angles[ci]
		var gate_anchor := MeshInstance3D.new()
		gate_anchor.name = "GateRoomAnchor_" + str(ci)
		var anchor_mesh := BoxMesh.new()
		anchor_mesh.size = Vector3(7.0, 1.0, 7.0)
		gate_anchor.mesh = anchor_mesh
		gate_anchor.material_override = trim_mat
		gate_anchor.position = Vector3(cos(angle) * 24.0, 0.5, sin(angle) * 24.0)
		generated_root.add_child(gate_anchor)

		var bridge := MeshInstance3D.new()
		bridge.name = "GateRoomBridge_" + str(ci)
		var bridge_mesh := BoxMesh.new()
		bridge_mesh.size = Vector3(4.0, 0.4, 12.0)
		bridge.mesh = bridge_mesh
		bridge.material_override = floor_mat
		var bridge_pos := Vector3(cos(angle) * 15.5, 0.2, sin(angle) * 15.5)
		bridge.position = bridge_pos
		bridge.rotation_degrees.y = -rad_to_deg(angle)
		generated_root.add_child(bridge)

	var wall_count: int = 28
	for i in range(wall_count):
		var angle: float = TAU * float(i) / float(wall_count)
		var wall := MeshInstance3D.new()
		wall.name = "GateRoomWall_" + str(i)
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(2.8, 10.0, 0.9)
		wall.mesh = wall_mesh
		wall.material_override = pillar_mat
		wall.position = Vector3(cos(angle) * 33.2, 5.0, sin(angle) * 33.2)
		wall.rotation_degrees.y = -rad_to_deg(angle) + 90.0
		generated_root.add_child(wall)

	var buttress_count: int = 12
	for bi in range(buttress_count):
		var angle_b: float = TAU * float(bi) / float(buttress_count)
		var buttress := MeshInstance3D.new()
		buttress.name = "GateRoomButtress_" + str(bi)
		var butt_mesh := CylinderMesh.new()
		butt_mesh.top_radius = 1.1
		butt_mesh.bottom_radius = 1.3
		butt_mesh.height = 9.0
		butt_mesh.radial_segments = 12
		buttress.mesh = butt_mesh
		buttress.material_override = pillar_mat
		buttress.position = Vector3(cos(angle_b) * 27.5, 4.5, sin(angle_b) * 27.5)
		generated_root.add_child(buttress)

	var room_light := OmniLight3D.new()
	room_light.name = "GateRoomAmbientLight"
	room_light.position = Vector3(0.0, 6.0, 0.0)
	room_light.omni_range = 60.0
	room_light.light_energy = 1.8
	room_light.light_color = Color(0.46, 0.58, 0.78)
	generated_root.add_child(room_light)

	for li in range(cardinal_angles.size()):
		var a: float = cardinal_angles[li]
		var lamp := OmniLight3D.new()
		lamp.name = "GateRoomRimLight_" + str(li)
		lamp.position = Vector3(cos(a) * 23.5, 3.2, sin(a) * 23.5)
		lamp.omni_range = 18.0
		lamp.light_energy = 1.35
		lamp.light_color = Color(0.34, 0.50, 0.76)
		generated_root.add_child(lamp)


func _create_cave_terrain() -> void:
	var rng := StableRng.new(StableRng.mix_string(world_seed, "dungeon"))
	var unit: float = 5.0
	var wall_h: float = 5.0
	var cells_x: int = 44
	var cells_z: int = 44
	var gw: int = cells_x * 2 + 1
	var gh: int = cells_z * 2 + 1

	var grid: Array = []
	for z in range(gh):
		var row: Array = []
		row.resize(gw)
		row.fill(true)
		grid.append(row)

	for cz in range(cells_z):
		for cx in range(cells_x):
			grid[cz * 2 + 1][cx * 2 + 1] = false

	var visited: Dictionary = {}
	var stack: Array = []
	var start := Vector2i(rng.randi_range(0, cells_x - 1), rng.randi_range(0, cells_z - 1))
	stack.append(start)
	visited[start] = true

	while not stack.is_empty():
		var cur: Vector2i = stack[-1]
		var ns: Array[Vector2i] = []
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < cells_x and n.y >= 0 and n.y < cells_z and not visited.has(n):
				ns.append(n)
		if ns.is_empty():
			stack.pop_back()
		else:
			var next_cell: Vector2i = ns[rng.randi_range(0, ns.size() - 1)]
			var wgx: int = cur.x * 2 + 1 + (next_cell.x - cur.x)
			var wgz: int = cur.y * 2 + 1 + (next_cell.y - cur.y)
			grid[wgz][wgx] = false
			visited[next_cell] = true
			stack.append(next_cell)

	var gate_chambers: Array[Dictionary] = [
		{"gx0": 64, "gx1": 82, "gz0": 42, "gz1": 46},
		{"gx0": 5, "gx1": 23, "gz0": 42, "gz1": 46},
		{"gx0": 42, "gx1": 46, "gz0": 64, "gz1": 82},
		{"gx0": 42, "gx1": 46, "gz0": 5, "gz1": 23},
	]
	for ch in gate_chambers:
		for gz in range(ch.gz0, ch.gz1 + 1):
			for gx in range(ch.gx0, ch.gx1 + 1):
				if gx >= 0 and gx < gw and gz >= 0 and gz < gh:
					if not (gx == 0 or gx == gw - 1 or gz == 0 or gz == gh - 1):
						grid[gz][gx] = false
	for ch in gate_chambers:
		for gz in range(ch.gz0, ch.gz1 + 1):
			for gx in range(ch.gx0, ch.gx1 + 1):
				if gx >= 0 and gx < gw and gz >= 0 and gz < gh:
					if not (gx == 0 or gx == gw - 1 or gz == 0 or gz == gh - 1):
						grid[gz][gx] = false

	var wall_mat := _cave_brick_material(world_seed)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.16, 0.13, 0.12)
	floor_mat.roughness = 0.9

	var ceiling_mat := StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.05, 0.04, 0.03)
	ceiling_mat.roughness = 1.0
	ceiling_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var ws := SurfaceTool.new()
	ws.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = float(gw) * unit * 0.5
	var hh: float = float(gh) * unit * 0.5

	for gz in range(gh):
		for gx in range(gw):
			if not grid[gz][gx]:
				continue
			var wx: float = float(gx) * unit - hw
			var wz: float = float(gz) * unit - hh
			var x0 := wx
			var x1 := wx + unit
			var z0 := wz
			var z1 := wz + unit
			var y0 := 0.0
			var y1 := wall_h

			var vis: Array[bool] = [false, false, false, false]
			vis[0] = gz == 0 or (gz > 0 and not grid[gz - 1][gx])
			vis[1] = gz == gh - 1 or (gz < gh - 1 and not grid[gz + 1][gx])
			vis[2] = gx == 0 or (gx > 0 and not grid[gz][gx - 1])
			vis[3] = gx == gw - 1 or (gx < gw - 1 and not grid[gz][gx + 1])

			if vis[0]:
				ws.add_vertex(Vector3(x0, y0, z0)); ws.add_vertex(Vector3(x1, y1, z0)); ws.add_vertex(Vector3(x1, y0, z0))
				ws.add_vertex(Vector3(x0, y0, z0)); ws.add_vertex(Vector3(x0, y1, z0)); ws.add_vertex(Vector3(x1, y1, z0))
			if vis[1]:
				ws.add_vertex(Vector3(x0, y0, z1)); ws.add_vertex(Vector3(x1, y0, z1)); ws.add_vertex(Vector3(x1, y1, z1))
				ws.add_vertex(Vector3(x0, y0, z1)); ws.add_vertex(Vector3(x1, y1, z1)); ws.add_vertex(Vector3(x0, y1, z1))
			if vis[2]:
				ws.add_vertex(Vector3(x0, y0, z0)); ws.add_vertex(Vector3(x0, y0, z1)); ws.add_vertex(Vector3(x0, y1, z1))
				ws.add_vertex(Vector3(x0, y0, z0)); ws.add_vertex(Vector3(x0, y1, z1)); ws.add_vertex(Vector3(x0, y1, z0))
			if vis[3]:
				ws.add_vertex(Vector3(x1, y0, z0)); ws.add_vertex(Vector3(x1, y1, z0)); ws.add_vertex(Vector3(x1, y0, z1))
				ws.add_vertex(Vector3(x1, y1, z0)); ws.add_vertex(Vector3(x1, y1, z1)); ws.add_vertex(Vector3(x1, y0, z1))

	ws.generate_normals()
	var wall_mesh := ws.commit()

	var walls := MeshInstance3D.new()
	walls.name = "DungeonWalls"
	walls.mesh = wall_mesh
	walls.material_override = wall_mat
	generated_root.add_child(walls)

	var wall_body := StaticBody3D.new()
	wall_body.name = "DungeonWallCollision"
	# Use merged box strips instead of one concave collider to avoid corner snagging.
	var collision_inset: float = unit * 0.04
	for gz in range(gh):
		var gx: int = 0
		while gx < gw:
			if not bool(grid[gz][gx]):
				gx += 1
				continue
			var start_x: int = gx
			while gx < gw and bool(grid[gz][gx]):
				gx += 1
			var end_x: int = gx - 1
			var run_len: int = end_x - start_x + 1
			var run_center_x: float = (float(start_x + end_x + 1) * unit * 0.5) - hw
			var run_center_z: float = float(gz) * unit - hh + unit * 0.5
			var run_col := CollisionShape3D.new()
			var run_shape := BoxShape3D.new()
			run_shape.size = Vector3(
				max(float(run_len) * unit - collision_inset, unit * 0.88),
				wall_h,
				max(unit - collision_inset, unit * 0.88)
			)
			run_col.shape = run_shape
			run_col.position = Vector3(run_center_x, wall_h * 0.5, run_center_z)
			wall_body.add_child(run_col)
	generated_root.add_child(wall_body)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "DungeonFloor"
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(float(gw) * unit, 0.3, float(gh) * unit)
	floor_mesh.mesh = floor_box
	floor_mesh.material_override = floor_mat
	floor_mesh.position.y = -0.15
	generated_root.add_child(floor_mesh)

	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(float(gw) * unit, 0.3, float(gh) * unit)
	floor_col.shape = floor_shape
	floor_col.position.y = -0.15
	floor_body.add_child(floor_col)
	generated_root.add_child(floor_body)

	var ceil_mesh := MeshInstance3D.new()
	ceil_mesh.name = "DungeonCeiling"
	var ceil_box := BoxMesh.new()
	ceil_box.size = Vector3(float(gw) * unit, 0.2, float(gh) * unit)
	ceil_mesh.mesh = ceil_box
	ceil_mesh.material_override = ceiling_mat
	ceil_mesh.position.y = wall_h + 0.1
	generated_root.add_child(ceil_mesh)

	var torch_mat := StandardMaterial3D.new()
	torch_mat.albedo_color = Color(1.0, 0.55, 0.15)
	torch_mat.emission_enabled = true
	torch_mat.emission = Color(1.0, 0.45, 0.10)
	torch_mat.emission_energy_multiplier = 4.0

	var torch_count: int = int(rng.randf_range(60.0, 100.0))
	for i in range(torch_count):
		var tx: int = rng.randi_range(0, gw - 1)
		var tz: int = rng.randi_range(0, gh - 1)
		if grid[tz][tx]:
			continue
		var wx: float = float(tx) * unit - hw
		var wz: float = float(tz) * unit - hh
		var flame := MeshInstance3D.new()
		flame.name = "Torch_" + str(i)
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.3, 0.6)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 6
		flame.mesh = sphere
		flame.material_override = torch_mat
		flame.position = Vector3(wx, wall_h - 0.3, wz)
		generated_root.add_child(flame)

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.18, 0.15, 0.14)
	accent_mat.roughness = 0.9
	var accent_count: int = int(rng.randf_range(20.0, 40.0))
	for i in range(accent_count):
		var ax: int = rng.randi_range(0, gw - 1)
		var az: int = rng.randi_range(0, gh - 1)
		if not grid[az][ax]:
			continue
		var wx: float = float(ax) * unit - hw
		var wz: float = float(az) * unit - hh
		var accent := MeshInstance3D.new()
		accent.name = "Accent_" + str(i)
		var box := BoxMesh.new()
		var bw: float = rng.randf_range(0.3, 0.8)
		box.size = Vector3(bw, rng.randf_range(1.0, 3.0), bw)
		accent.mesh = box
		accent.material_override = accent_mat
		accent.position = Vector3(wx, rng.randf_range(0.5, 3.0), wz)
		generated_root.add_child(accent)


func _create_world_bounds() -> void:
	var half: float = _world_half_size()
	if map_type == WorldGraph.MAP_GATE_ROOM:
		half = 36.0
	elif map_type == WorldGraph.MAP_NEXUS:
		half = 44.0
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
	if map_type == WorldGraph.MAP_MOON or map_type == WorldGraph.MAP_WATER or map_type == WorldGraph.MAP_ARCTIC:
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


func _water_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.15, 0.40, 0.50, 0.34);
uniform vec4 deep_color : source_color = vec4(0.05, 0.15, 0.30, 0.44);
uniform vec3 sky_tint : source_color = vec3(0.34, 0.56, 0.82);
uniform float wave_strength : hint_range(0.0, 1.0) = 0.08;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.12;
uniform float wave_scale : hint_range(0.1, 20.0) = 4.0;
uniform float normal_strength : hint_range(0.0, 5.0) = 0.85;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.32;
uniform float alpha_boost : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_normal;
varying vec3 v_world_position;

float wave_value(vec2 p, float t) {
	float a = sin(p.x * wave_scale + t * wave_speed);
	float b = sin(p.y * wave_scale * 1.37 + t * wave_speed * 1.11);
	float c = sin((p.x + p.y) * wave_scale * 0.71 + t * wave_speed * 0.63);
	return (a + b + c * 0.65) / 2.65;
}

void vertex() {
	float t = TIME;
	vec2 p = VERTEX.xz * 0.08;
	float h = wave_value(p, t) * wave_strength;
	VERTEX.y += h;

	float e = 0.08;
	float hx = wave_value(p + vec2(e, 0.0), t) * wave_strength;
	float hz = wave_value(p + vec2(0.0, e), t) * wave_strength;
	vec3 local_normal = normalize(vec3(
		-(hx - h) * normal_strength,
		1.0,
		-(hz - h) * normal_strength
	));
	NORMAL = local_normal;
	v_normal = normalize((MODEL_MATRIX * vec4(local_normal, 0.0)).xyz);
	v_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(v_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_position);
	float fresnel = pow(1.0 - clamp(dot(n, view_dir), 0.0, 1.0), 3.0);
	float ripple = sin(v_world_position.x * 0.32 + TIME * wave_speed * 1.4)
		* sin(v_world_position.z * 0.25 - TIME * wave_speed * 1.0);
	ripple = ripple * 0.5 + 0.5;

	vec3 base_color = mix(shallow_color.rgb, deep_color.rgb, 0.45);
	base_color += vec3(ripple * 0.018);
	float sheen = clamp(fresnel * sheen_strength, 0.0, 0.35);
	ALBEDO = mix(base_color, sky_tint, sheen);
	ALPHA = clamp(mix(shallow_color.a, deep_color.a, 0.45) + fresnel * 0.08 + alpha_boost, 0.24, 0.62);
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
"""
	return shader


func _cave_brick_material(seed: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.93
	mat.metallic = 0.0
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(1.7, 1.7, 1.7)
	var tex: ImageTexture = _generate_cave_brick_texture(seed)
	mat.albedo_texture = tex
	return mat


func _generate_cave_brick_texture(seed: int) -> ImageTexture:
	var w: int = 256
	var h: int = 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := StableRng.new(StableRng.mix_string(seed, "cave_brick_tex"))
	var seed_tint: float = float(abs(seed % 17)) / 17.0
	var brick_a := Color(0.18 + seed_tint * 0.05, 0.13 + seed_tint * 0.03, 0.10 + seed_tint * 0.02, 1.0)
	var brick_b := Color(0.30 + seed_tint * 0.03, 0.22 + seed_tint * 0.02, 0.16 + seed_tint * 0.02, 1.0)
	var mortar := Color(0.09, 0.085, 0.08, 1.0)
	var brick_h: int = 16
	var brick_w: int = 32
	var mortar_w: int = 2
	for y in range(h):
		var row: int = y / brick_h
		var offset: int = (brick_w / 2) if (row % 2 == 1) else 0
		for x in range(w):
			var xx: int = (x + offset) % brick_w
			var yy: int = y % brick_h
			var is_mortar: bool = xx < mortar_w or yy < mortar_w
			if is_mortar:
				img.set_pixel(x, y, mortar)
			else:
				var n: float = rng.randf_range(-0.07, 0.07)
				var t: float = float((x / brick_w + y / brick_h) % 2)
				var c: Color = brick_a.lerp(brick_b, t * 0.65 + 0.2)
				c.r = clamp(c.r + n, 0.0, 1.0)
				c.g = clamp(c.g + n * 0.8, 0.0, 1.0)
				c.b = clamp(c.b + n * 0.6, 0.0, 1.0)
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _create_water() -> void:
	if map_type == WorldGraph.MAP_MOON or map_type == WorldGraph.MAP_CAVE:
		return
	if map_type == WorldGraph.MAP_GATE_ROOM or map_type == WorldGraph.MAP_NEXUS:
		return
	if map_type == WorldGraph.MAP_RUINED_CITY:
		return   # a ruined city is drained — no standing water to flood basements/streets

	var water_size: float = float(_effective_grid_size()) * CELL_SIZE * 0.94

	var water := MeshInstance3D.new()
	water.name = "RiverAndLakeWater"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(water_size, water_size)
	if graphics_level <= 0:
		water_mesh.subdivide_width = 32
		water_mesh.subdivide_depth = 32
	elif graphics_level == 1:
		water_mesh.subdivide_width = 64
		water_mesh.subdivide_depth = 64
	else:
		water_mesh.subdivide_width = 128
		water_mesh.subdivide_depth = 128
	water.mesh = water_mesh
	water.position.y = WATER_LEVEL

	if map_type == WorldGraph.MAP_ARCTIC:
		var ice_mat := StandardMaterial3D.new()
		ice_mat.albedo_color = Color(0.82, 0.90, 0.97, 0.90)
		ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice_mat.roughness = 0.18
		ice_mat.metallic = 0.0
		ice_mat.clearcoat_enabled = true
		ice_mat.clearcoat = 0.65
		ice_mat.clearcoat_roughness = 0.12
		water.material_override = ice_mat
	else:
		var mat := ShaderMaterial.new()
		mat.shader = _water_shader()
		if map_type == WorldGraph.MAP_WATER:
			mat.set_shader_parameter("shallow_color", Color(0.08, 0.30, 0.50, 0.44))
			mat.set_shader_parameter("deep_color", Color(0.02, 0.13, 0.30, 0.54))
			mat.set_shader_parameter("alpha_boost", 0.08)
		else:
			mat.set_shader_parameter("shallow_color", Color(0.10, 0.36, 0.56, 0.38))
			mat.set_shader_parameter("deep_color", Color(0.03, 0.18, 0.36, 0.48))
			mat.set_shader_parameter("alpha_boost", 0.04)
		water.material_override = mat
	generated_root.add_child(water)

	var water_collision := StaticBody3D.new()
	water_collision.name = "WaterCollision"
	water_collision.collision_layer = 1 if map_type == WorldGraph.MAP_ARCTIC else 4
	water_collision.collision_mask = 0

	var water_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(water_size, 0.4 if map_type == WorldGraph.MAP_ARCTIC else 0.2, water_size)
	water_shape.shape = box

	water_collision.add_child(water_shape)
	if map_type == WorldGraph.MAP_ARCTIC:
		# Keep the top face just above the visual ice sheet so foot placement feels solid.
		water_collision.position.y = WATER_LEVEL - 0.18
	else:
		water_collision.position.y = WATER_LEVEL
	generated_root.add_child(water_collision)


# A local water plane per elevated lake, at the lake's own surface level. The terrain
# (carved bowl + raised lip) clips it to the basin, so each reads as a distinct tarn
# sitting above the sea.
func _create_lakes() -> void:
	if map_type != WorldGraph.MAP_NORMAL:
		return
	var ctx := _ensure_context()
	var idx: int = 0
	for lake in ctx._lakes:
		var r: float = float(lake["r"])
		var water := MeshInstance3D.new()
		water.name = "LakeWater%d" % idx
		idx += 1
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(r * 2.0, r * 2.0)
		mesh.subdivide_width = 16
		mesh.subdivide_depth = 16
		water.mesh = mesh
		water.position = Vector3(float(lake["x"]), float(lake["level"]), float(lake["z"]))
		var mat := ShaderMaterial.new()
		mat.shader = _water_shader()
		mat.set_shader_parameter("shallow_color", Color(0.10, 0.36, 0.56, 0.38))
		mat.set_shader_parameter("deep_color", Color(0.03, 0.18, 0.36, 0.48))
		mat.set_shader_parameter("alpha_boost", 0.04)
		water.material_override = mat
		generated_root.add_child(water)


func _create_sky_clouds() -> void:
	if map_type == WorldGraph.MAP_MOON or map_type == WorldGraph.MAP_CAVE:
		return
	if graphics_level == 0:
		return

	var cloud_root := Node3D.new()
	cloud_root.name = "SkyClouds"

	var cloud_shader := Shader.new()
	cloud_shader.code = """
shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform float time_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float time_scale : hint_range(0.0, 1.0) = 0.025;
uniform float density : hint_range(0.0, 1.0) = 0.38;
uniform float coverage : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.0, 1.0) = 0.25;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.92);
uniform vec3 cloud_shadow_color : source_color = vec3(0.70, 0.74, 0.78);

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise2(p);
		p = p * 2.05 + vec2(13.2, 7.1);
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	float t = TIME * time_scale + time_offset;
	vec2 p = UV * 5.0;
	p += vec2(t * 0.35, t * 0.10);
	float large = fbm(p);
	float detail = fbm(p * 2.7 + vec2(31.7, 19.4));
	float cloud = large * 0.75 + detail * 0.25;
	float threshold = 1.0 - coverage;
	float alpha = smoothstep(threshold, threshold + softness, cloud) * density;
	vec2 centered = UV * 2.0 - 1.0;
	float edge = max(abs(centered.x), abs(centered.y));
	alpha *= 1.0 - smoothstep(0.72, 1.0, edge);
	vec3 color = mix(cloud_shadow_color, cloud_color, clamp(cloud + 0.12, 0.0, 1.0));
	ALBEDO = color;
	ALPHA = alpha;
}
"""

	var near_clouds := MeshInstance3D.new()
	near_clouds.name = "CloudLayerNear"
	var near_mesh := PlaneMesh.new()
	near_mesh.size = Vector2(900.0, 900.0)
	near_clouds.mesh = near_mesh
	near_clouds.position = Vector3(0.0, 115.0, 0.0)

	var mat := ShaderMaterial.new()
	mat.shader = cloud_shader
	mat.set_shader_parameter("time_offset", float(world_seed % 1000))
	mat.set_shader_parameter("time_scale", 0.025)
	mat.set_shader_parameter("density", (0.30 if graphics_level >= 2 else 0.20) if map_type == WorldGraph.MAP_ARCTIC else (0.42 if graphics_level >= 2 else 0.28))
	mat.set_shader_parameter("coverage", 0.56)
	mat.set_shader_parameter("softness", 0.25)
	mat.set_shader_parameter("cloud_color", Color(0.90, 0.94, 0.99) if map_type == WorldGraph.MAP_ARCTIC else Color(1.0, 0.98, 0.92))
	mat.set_shader_parameter("cloud_shadow_color", Color(0.62, 0.70, 0.80) if map_type == WorldGraph.MAP_ARCTIC else Color(0.70, 0.74, 0.78))
	near_clouds.material_override = mat
	cloud_root.add_child(near_clouds)

	var far_clouds := MeshInstance3D.new()
	far_clouds.name = "CloudLayerFar"
	var far_mesh := PlaneMesh.new()
	far_mesh.size = Vector2(1300.0, 1300.0)
	far_clouds.mesh = far_mesh
	far_clouds.position = Vector3(0.0, 170.0, 0.0)

	var mat2 := ShaderMaterial.new()
	mat2.shader = cloud_shader
	mat2.set_shader_parameter("time_offset", float(world_seed % 1000) + 250.0)
	mat2.set_shader_parameter("time_scale", 0.014)
	mat2.set_shader_parameter("density", (0.15 if graphics_level >= 2 else 0.08) if map_type == WorldGraph.MAP_ARCTIC else (0.22 if graphics_level >= 2 else 0.12))
	mat2.set_shader_parameter("coverage", 0.62)
	mat2.set_shader_parameter("softness", 0.35)
	mat2.set_shader_parameter("cloud_color", Color(0.92, 0.96, 1.0) if map_type == WorldGraph.MAP_ARCTIC else Color(1.0, 0.98, 0.94))
	mat2.set_shader_parameter("cloud_shadow_color", Color(0.64, 0.72, 0.82) if map_type == WorldGraph.MAP_ARCTIC else Color(0.72, 0.76, 0.82))
	far_clouds.material_override = mat2
	cloud_root.add_child(far_clouds)

	generated_root.add_child(cloud_root)


func _earth_color(p: Vector3, seed: int) -> Color:
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


func _create_moon_sky() -> void:
	var sky := Node3D.new()
	sky.name = "MoonSkyDetails"
	generated_root.add_child(sky)

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
		star.position = Vector3(cos(star_angle) * cos(deg_to_rad(star_elev)) * star_dist, sin(deg_to_rad(star_elev)) * star_dist, sin(star_angle) * cos(deg_to_rad(star_elev)) * star_dist)
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
			_add_planet_vertex(earth_surf, p1)
			_add_planet_vertex(earth_surf, p2)
			_add_planet_vertex(earth_surf, p3)
			_add_planet_vertex(earth_surf, p1)
			_add_planet_vertex(earth_surf, p3)
			_add_planet_vertex(earth_surf, p4)
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
		cloud_blob.rotation_degrees = Vector3(planet_rng.randf_range(-20, 20), planet_rng.randf_range(0, 360), planet_rng.randf_range(-10, 10))
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


func _add_planet_vertex(surface: SurfaceTool, point: Vector3) -> void:
	surface.set_uv(Vector2(0.0, 0.0))
	surface.set_color(_earth_color(point, world_seed))
	surface.set_normal(point.normalized())
	surface.add_vertex(point)


static func _sphere_point(r: float, theta: float, phi: float) -> Vector3:
	return Vector3(r * sin(theta) * cos(phi), r * cos(theta), r * sin(theta) * sin(phi))


func _create_map_nexus_terrain() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.11, 0.16)
	floor_mat.roughness = 0.78
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.18, 0.28, 0.40)
	trim_mat.roughness = 0.50
	trim_mat.emission_enabled = true
	trim_mat.emission = Color(0.10, 0.22, 0.35)
	trim_mat.emission_energy_multiplier = 0.28

	var floor := MeshInstance3D.new()
	floor.name = "MapNexusFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 50.0
	floor_mesh.bottom_radius = 50.0
	floor_mesh.height = 0.8
	floor_mesh.radial_segments = 56
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.position.y = -0.4
	generated_root.add_child(floor)

	var body := StaticBody3D.new()
	body.name = "MapNexusFloorBody"
	var col_shape := CollisionShape3D.new()
	var col_cyl := CylinderShape3D.new()
	col_cyl.radius = 50.0
	col_cyl.height = 0.8
	col_shape.shape = col_cyl
	col_shape.position.y = -0.4
	body.add_child(col_shape)
	generated_root.add_child(body)

	var inner_ring := MeshInstance3D.new()
	inner_ring.name = "MapNexusInnerRing"
	var inner_mesh := TorusMesh.new()
	inner_mesh.outer_radius = 13.0
	inner_mesh.inner_radius = 11.5
	inner_ring.mesh = inner_mesh
	inner_ring.material_override = trim_mat
	inner_ring.position = Vector3(0.0, 0.3, 0.0)
	inner_ring.rotation_degrees.x = 90.0
	generated_root.add_child(inner_ring)

	var outer_ring := MeshInstance3D.new()
	outer_ring.name = "MapNexusOuterRing"
	var outer_mesh := TorusMesh.new()
	outer_mesh.outer_radius = 36.0
	outer_mesh.inner_radius = 34.2
	outer_ring.mesh = outer_mesh
	outer_ring.material_override = trim_mat
	outer_ring.position = Vector3(0.0, 0.22, 0.0)
	outer_ring.rotation_degrees.x = 90.0
	generated_root.add_child(outer_ring)

	var center_plinth := MeshInstance3D.new()
	center_plinth.name = "MapNexusCenterPlinth"
	var center_mesh := CylinderMesh.new()
	center_mesh.top_radius = 6.0
	center_mesh.bottom_radius = 6.8
	center_mesh.height = 1.4
	center_mesh.radial_segments = 24
	center_plinth.mesh = center_mesh
	center_plinth.material_override = trim_mat
	center_plinth.position = Vector3(0.0, 0.7, 0.0)
	generated_root.add_child(center_plinth)
	var plinth_body := StaticBody3D.new()
	plinth_body.name = "MapNexusCenterPlinthBody"
	var plinth_col := CollisionShape3D.new()
	var plinth_shape := CylinderShape3D.new()
	plinth_shape.radius = 6.4
	plinth_shape.height = 1.4
	plinth_col.shape = plinth_shape
	plinth_col.position = center_plinth.position
	plinth_body.add_child(plinth_col)
	generated_root.add_child(plinth_body)

	for si in range(4):
		var angle: float = TAU * float(si) / 4.0
		var bridge := MeshInstance3D.new()
		bridge.name = "MapNexusBridge_" + str(si)
		var bridge_mesh := BoxMesh.new()
		bridge_mesh.size = Vector3(6.0, 0.45, 19.0)
		bridge.mesh = bridge_mesh
		bridge.material_override = floor_mat
		bridge.position = Vector3(cos(angle) * 22.0, 0.20, sin(angle) * 22.0)
		bridge.rotation_degrees.y = -rad_to_deg(angle)
		generated_root.add_child(bridge)
		var bridge_body := StaticBody3D.new()
		bridge_body.name = "MapNexusBridgeBody_" + str(si)
		var bridge_col := CollisionShape3D.new()
		var bridge_shape := BoxShape3D.new()
		bridge_shape.size = Vector3(6.0, 0.45, 19.0)
		bridge_col.shape = bridge_shape
		bridge_col.position = bridge.position
		bridge_col.rotation_degrees = bridge.rotation_degrees
		bridge_body.add_child(bridge_col)
		generated_root.add_child(bridge_body)

	var ambient := OmniLight3D.new()
	ambient.name = "MapNexusAmbientLight"
	ambient.position = Vector3(0.0, 7.0, 0.0)
	ambient.omni_range = 74.0
	ambient.light_energy = 2.0
	ambient.light_color = Color(0.34, 0.56, 0.74)
	generated_root.add_child(ambient)


func _create_floating_island_terrain() -> void:
	var half_extent: float = _world_half_size() * 0.92
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.34, 0.38, 0.44)
	stone_mat.roughness = 0.86
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.32, 0.62, 0.34)
	grass_mat.roughness = 0.78
	var waterfall_mat := StandardMaterial3D.new()
	waterfall_mat.albedo_color = Color(0.55, 0.82, 0.98, 0.52)
	waterfall_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	waterfall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	waterfall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	waterfall_mat.emission_enabled = true
	waterfall_mat.emission = Color(0.40, 0.72, 0.95)
	waterfall_mat.emission_energy_multiplier = 0.65

	for i in range(18):
		var angle: float = TAU * float(i) / 18.0 + noise.get_noise_2d(float(i) * 17.0 + 400.0, float(i) * 9.0 - 120.0) * 0.45
		var dist: float = half_extent * 0.78 + noise.get_noise_2d(float(i) * 23.0 + 1000.0, float(i) * 13.0 - 700.0) * (half_extent * 0.22)
		dist = clamp(dist, half_extent * 0.45, half_extent)
		var cx: float = cos(angle) * dist
		var cz: float = sin(angle) * dist
		var radius: float = 21.0 + noise.get_noise_2d(float(i) * 19.0 + 300.0, float(i) * 31.0 - 800.0) * 5.2
		var top_y: float = 25.0 + noise.get_noise_2d(float(i) * 27.0 + 1400.0, float(i) * 21.0 - 900.0) * 8.0

		var top := MeshInstance3D.new()
		top.name = "FloatingIslandTop_" + str(i)
		var top_mesh := CylinderMesh.new()
		top_mesh.top_radius = radius
		top_mesh.bottom_radius = radius * 0.92
		top_mesh.height = 2.0
		top_mesh.radial_segments = 28
		top.mesh = top_mesh
		top.material_override = grass_mat
		top.position = Vector3(cx, top_y - 1.0, cz)
		generated_root.add_child(top)

		var under := MeshInstance3D.new()
		under.name = "FloatingIslandUnder_" + str(i)
		var under_mesh := CylinderMesh.new()
		under_mesh.top_radius = radius * 0.90
		under_mesh.bottom_radius = max(radius * 0.24, 3.0)
		under_mesh.height = 16.0
		under_mesh.radial_segments = 24
		under.mesh = under_mesh
		under.material_override = stone_mat
		under.position = Vector3(cx, top_y - 9.0, cz)
		generated_root.add_child(under)

		var body := StaticBody3D.new()
		body.name = "FloatingIslandBody_" + str(i)
		body.collision_layer = 1
		body.collision_mask = 1

		var top_col := CollisionShape3D.new()
		var top_shape := CylinderShape3D.new()
		top_shape.radius = radius
		top_shape.height = 2.0
		top_col.shape = top_shape
		top_col.position = Vector3(cx, top_y - 1.0, cz)
		body.add_child(top_col)

		var under_col := CollisionShape3D.new()
		var under_shape := CylinderShape3D.new()
		under_shape.radius = radius * 0.62
		under_shape.height = 12.0
		under_col.shape = under_shape
		under_col.position = Vector3(cx, top_y - 8.4, cz)
		body.add_child(under_col)

		generated_root.add_child(body)

		if i < 3 or noise.get_noise_2d(float(i) * 37.0 + 2200.0, float(i) * 13.0 - 1700.0) > 0.15:
			var fall_angle: float = angle + noise.get_noise_2d(float(i) * 11.0 + 800.0, float(i) * 5.0 + 1400.0) * 0.6
			var fx: float = cx + cos(fall_angle) * (radius * 0.82)
			var fz: float = cz + sin(fall_angle) * (radius * 0.82)
			var fall_height: float = 16.0 + max(0.0, noise.get_noise_2d(float(i) * 17.0 + 600.0, float(i) * 29.0 + 400.0)) * 10.0
			var waterfall := MeshInstance3D.new()
			waterfall.name = "FloatingWaterfall_" + str(i)
			var fall_mesh := PlaneMesh.new()
			fall_mesh.size = Vector2(max(2.8, radius * 0.18), fall_height)
			waterfall.mesh = fall_mesh
			waterfall.material_override = waterfall_mat
			waterfall.position = Vector3(fx, top_y - fall_height * 0.5 - 0.1, fz)
			waterfall.rotation_degrees = Vector3(0.0, -rad_to_deg(fall_angle), 0.0)
			generated_root.add_child(waterfall)

	for i in range(12):
		var angle_low: float = TAU * float(i) / 12.0 + 0.35 + noise.get_noise_2d(float(i) * 29.0 + 1800.0, float(i) * 17.0 - 500.0) * 0.5
		var dist_low: float = half_extent * 0.62 + noise.get_noise_2d(float(i) * 31.0 + 900.0, float(i) * 7.0 - 1400.0) * (half_extent * 0.26)
		dist_low = clamp(dist_low, half_extent * 0.28, half_extent * 0.92)
		var cx_low: float = cos(angle_low) * dist_low
		var cz_low: float = sin(angle_low) * dist_low
		var radius_low: float = 13.5 + noise.get_noise_2d(float(i) * 13.0 + 500.0, float(i) * 41.0 + 1100.0) * 3.6
		var top_y_low: float = 4.0 + noise.get_noise_2d(float(i) * 21.0 + 2000.0, float(i) * 15.0 - 600.0) * 3.5

		var top_low := MeshInstance3D.new()
		top_low.name = "FloatingIslandTop_Low_" + str(i)
		var top_low_mesh := CylinderMesh.new()
		top_low_mesh.top_radius = radius_low
		top_low_mesh.bottom_radius = radius_low * 0.92
		top_low_mesh.height = 1.8
		top_low_mesh.radial_segments = 24
		top_low.mesh = top_low_mesh
		top_low.material_override = grass_mat
		top_low.position = Vector3(cx_low, top_y_low - 0.9, cz_low)
		generated_root.add_child(top_low)

		var under_low := MeshInstance3D.new()
		under_low.name = "FloatingIslandUnder_Low_" + str(i)
		var under_low_mesh := CylinderMesh.new()
		under_low_mesh.top_radius = radius_low * 0.90
		under_low_mesh.bottom_radius = max(radius_low * 0.30, 2.8)
		under_low_mesh.height = 9.0
		under_low_mesh.radial_segments = 20
		under_low.mesh = under_low_mesh
		under_low.material_override = stone_mat
		under_low.position = Vector3(cx_low, top_y_low - 5.2, cz_low)
		generated_root.add_child(under_low)

		var body_low := StaticBody3D.new()
		body_low.name = "FloatingIslandBody_Low_" + str(i)
		body_low.collision_layer = 1
		body_low.collision_mask = 1
		var top_low_col := CollisionShape3D.new()
		var top_low_shape := CylinderShape3D.new()
		top_low_shape.radius = radius_low
		top_low_shape.height = 1.8
		top_low_col.shape = top_low_shape
		top_low_col.position = Vector3(cx_low, top_y_low - 0.9, cz_low)
		body_low.add_child(top_low_col)
		var under_low_col := CollisionShape3D.new()
		var under_low_shape := CylinderShape3D.new()
		under_low_shape.radius = radius_low * 0.58
		under_low_shape.height = 7.4
		under_low_col.shape = under_low_shape
		under_low_col.position = Vector3(cx_low, top_y_low - 4.7, cz_low)
		body_low.add_child(under_low_col)
		generated_root.add_child(body_low)

	var center_top := MeshInstance3D.new()
	center_top.name = "FloatingIslandTop_Center"
	var center_top_mesh := CylinderMesh.new()
	center_top_mesh.top_radius = 22.0
	center_top_mesh.bottom_radius = 20.4
	center_top_mesh.height = 2.2
	center_top_mesh.radial_segments = 30
	center_top.mesh = center_top_mesh
	center_top.material_override = grass_mat
	center_top.position = Vector3(0.0, 18.6, 0.0)
	generated_root.add_child(center_top)

	var center_under := MeshInstance3D.new()
	center_under.name = "FloatingIslandUnder_Center"
	var center_under_mesh := CylinderMesh.new()
	center_under_mesh.top_radius = 19.8
	center_under_mesh.bottom_radius = 3.8
	center_under_mesh.height = 13.0
	center_under_mesh.radial_segments = 26
	center_under.mesh = center_under_mesh
	center_under.material_override = stone_mat
	center_under.position = Vector3(0.0, 11.3, 0.0)
	generated_root.add_child(center_under)

	var center_body := StaticBody3D.new()
	center_body.name = "FloatingIslandBody_Center"
	center_body.collision_layer = 1
	center_body.collision_mask = 1
	var center_top_col := CollisionShape3D.new()
	var center_top_shape := CylinderShape3D.new()
	center_top_shape.radius = 22.0
	center_top_shape.height = 2.2
	center_top_col.shape = center_top_shape
	center_top_col.position = Vector3(0.0, 18.6, 0.0)
	center_body.add_child(center_top_col)
	var center_under_col := CollisionShape3D.new()
	var center_under_shape := CylinderShape3D.new()
	center_under_shape.radius = 11.4
	center_under_shape.height = 9.0
	center_under_col.shape = center_under_shape
	center_under_col.position = Vector3(0.0, 11.3, 0.0)
	center_body.add_child(center_under_col)
	generated_root.add_child(center_body)
