extends RefCounted
class_name MapContext

const WorldGraph = preload("res://scripts/core/WorldGraph.gd")

var world_seed: int = 12345
var map_type: String = WorldGraph.MAP_NORMAL
var grid_size: int = 224
var cell_size: float = 2.0
var water_level: float = -1.7
var height_scale: float = 15.0
var moon_grid_scale: int = 1
var noise: FastNoiseLite = FastNoiseLite.new()
var _lakes: Array = []   # normal-map lake basins: {x, z, r, depth}


func _init(config: Dictionary = {}) -> void:
	world_seed = int(config.get("world_seed", world_seed))
	map_type = str(config.get("map_type", map_type))
	grid_size = int(config.get("grid_size", grid_size))
	cell_size = float(config.get("cell_size", cell_size))
	water_level = float(config.get("water_level", water_level))
	height_scale = float(config.get("height_scale", height_scale))
	moon_grid_scale = int(config.get("moon_grid_scale", moon_grid_scale))
	if moon_grid_scale <= 0:
		moon_grid_scale = 1
	if map_type == WorldGraph.MAP_MOON and moon_grid_scale == 1:
		moon_grid_scale = 2
	_setup_noise()
	_setup_lakes()


func _setup_noise() -> void:
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.020
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 1.9
	noise.fractal_gain = 0.45


# The bare land height (no river/lake carving) — used both for the terrain and to decide
# where lakes sit.
func _base_land_height(wx: float, wz: float) -> float:
	var broad: float = noise.get_noise_2d(wx * 0.35 + 1200.0, wz * 0.35 - 800.0) * height_scale
	var hills: float = noise.get_noise_2d(wx, wz) * 5.5
	var details: float = noise.get_noise_2d(wx * 2.1 + 900.0, wz * 2.1 - 900.0) * 1.1
	return broad + hills + details


# Lakes placed in genuine basins — a hollow whose rim rises above the pool on every side
# — so each is a contained body at its own level above the sea. No artificial lip to run
# into; the natural rim holds the water and the shore steepening (below) stops it being a
# shelf you can stand on.
func _setup_lakes() -> void:
	_lakes = []
	if map_type != WorldGraph.MAP_NORMAL:
		return
	var lr := StableRng.new(StableRng.mix_string(world_seed, "lakes", 0))
	var target: int = lr.randi_range(2, 4)
	var half: float = world_half_size() * 0.72
	var tries: int = 0
	while _lakes.size() < target and tries < 60:
		tries += 1
		var cxx: float = lr.randf_range(-half, half)
		var czz: float = lr.randf_range(-half, half)
		var rad: float = lr.randf_range(14.0, 22.0)
		# Keep clear of the river — its carve drops part of the rim and the pool drains in.
		if river_distance(cxx, czz) < rad + 18.0:
			continue
		# Keep lakes apart — an overlapping neighbour's bowl eats into this rim and the pool
		# spills where the rim test (which samples bare land) can't see it.
		var clear := true
		for ex in _lakes:
			if Vector2(cxx - float(ex["x"]), czz - float(ex["z"])).length() < rad + float(ex["r"]) + 14.0:
				clear = false
				break
		if not clear:
			continue
		var rim_min: float = 1.0e9
		var rim_max: float = -1.0e9
		for a in range(16):
			var ang: float = TAU * float(a) / 16.0
			var rh: float = _base_land_height(cxx + cos(ang) * rad, czz + sin(ang) * rad)
			rim_min = minf(rim_min, rh)
			rim_max = maxf(rim_max, rh)
		# An above-sea spot that isn't a steep hillside: the carve digs the basin and the
		# natural rim (its lowest point, less a margin) sets a contained fill level.
		if rim_min < -0.5 or rim_max - rim_min > 12.0:
			continue
		_lakes.append({
			"x": cxx, "z": czz, "r": rad,
			"depth": lr.randf_range(5.0, 9.0),
			"level": rim_min - 1.5,
		})


# Bowl depth from every lake at a point (0 outside), plus a GENTLE raised lip at the rim
# (~14 deg slope) that guarantees the pool stays contained whatever the natural ground
# does — a soft rise you walk over, not the steep wall from before.
func _lake_carve(wx: float, wz: float) -> float:
	var c: float = 0.0
	for lake in _lakes:
		var r: float = lake["r"]
		var d: float = Vector2(wx - float(lake["x"]), wz - float(lake["z"])).length()
		if d < r:
			c += smoothstep(0.0, 1.0, 1.0 - d / r) * float(lake["depth"])
		var lip: float = 1.0 - clampf(absf(d - r) / (r * 0.4), 0.0, 1.0)
		c -= lip * 1.8
	return c


# The water surface height at a point: the global sea, raised to a lake's own level
# wherever the point falls inside that lake (so you swim/drown at the right height).
func water_level_at(wx: float, wz: float) -> float:
	var lvl: float = water_level
	for lake in _lakes:
		if Vector2(wx - float(lake["x"]), wz - float(lake["z"])).length() < float(lake["r"]):
			lvl = maxf(lvl, float(lake["level"]))
	return lvl


func effective_grid_size() -> int:
	if map_type == WorldGraph.MAP_MOON:
		return grid_size * moon_grid_scale
	return grid_size


func world_half_size() -> float:
	return float(effective_grid_size()) * cell_size * 0.5


func grid_to_world_x(x: int) -> float:
	var g: float = float(effective_grid_size())
	return (float(x) - g * 0.5) * cell_size


func grid_to_world_z(z: int) -> float:
	var g: float = float(effective_grid_size())
	return (float(z) - g * 0.5) * cell_size


func biome_value(wx: float, wz: float) -> float:
	return noise.get_noise_2d(wx * 0.28 - 2500.0, wz * 0.28 + 1700.0)


func river_distance(wx: float, wz: float) -> float:
	if map_type == WorldGraph.MAP_FLOATING_ISLAND or map_type == WorldGraph.MAP_RUINED_CITY:
		return 999.0
	# Two sines of different wavelength + noise so the river snakes naturally instead of
	# tracing one predictable curve.
	var curve: float = sin(wx * 0.025) * 20.0 + sin(wx * 0.011 + 2.1) * 16.0 + noise.get_noise_2d(wx * 0.2 + 3200.0, 410.0) * 14.0
	return abs(wz - curve)


# --- Ruined-city basements: a shared, deterministic decision so the terrain (which
# punches a real hole under the building) and CityFactory (which builds the basement
# into that hole) always agree on which cells have one. ---
const CITY_CELL: float = 34.0           # must match CityFactory.CELL
const CITY_BASEMENT_HALF: float = 8.0   # half-footprint of a basement building (grid-aligned)

func _city_extent() -> float:
	return minf(world_half_size() * 0.7, 145.0)


func city_cell_has_basement(i: int, j: int) -> bool:
	if map_type != WorldGraph.MAP_RUINED_CITY:
		return false
	if absi(i) <= 1 and absi(j) <= 1:
		return false   # central plaza is kept clear of buildings
	if Vector2(float(i) * CITY_CELL, float(j) * CITY_CELL).length() > _city_extent():
		return false
	return StableRng.new(StableRng.mix_string(world_seed, "city_basement", i * 1000 + j)).randf() < 0.33


# True if the world point sits under a basement building's footprint (so the terrain
# mesh/collision should be holed there).
func city_point_in_basement(wx: float, wz: float) -> bool:
	var i: int = roundi(wx / CITY_CELL)
	var j: int = roundi(wz / CITY_CELL)
	if not city_cell_has_basement(i, j):
		return false
	return absf(wx - float(i) * CITY_CELL) < CITY_BASEMENT_HALF and absf(wz - float(j) * CITY_CELL) < CITY_BASEMENT_HALF


func height_at_world(wx: float, wz: float) -> float:
	if map_type == WorldGraph.MAP_GATE_ROOM or map_type == WorldGraph.MAP_CAVE or map_type == WorldGraph.MAP_NEXUS:
		return 0.0

	if map_type == WorldGraph.MAP_RUINED_CITY:
		# Graded street level: only a faint heave, so building floors sit flush and
		# doorways stay a single step above grade (no terrain poking through floors).
		return noise.get_noise_2d(wx * 0.55 + 700.0, wz * 0.55 - 300.0) * 0.07

	if map_type == WorldGraph.MAP_MOON:
		var scale: float = 1.0 / float(moon_grid_scale)
		var lunar_broad: float = noise.get_noise_2d(wx * 0.45 * scale + 600.0, wz * 0.45 * scale - 1200.0) * 5.0
		var lunar_craters: float = noise.get_noise_2d(wx * 2.8 * scale - 400.0, wz * 2.8 * scale + 700.0) * 1.4
		var crater_bowls: float = abs(noise.get_noise_2d(wx * 0.12 * scale + 330.0, wz * 0.12 * scale - 510.0)) * -4.2
		return lunar_broad + lunar_craters + crater_bowls

	if map_type == WorldGraph.MAP_ARCTIC:
		var broad: float = noise.get_noise_2d(wx * 0.35 + 1200.0, wz * 0.35 - 800.0) * height_scale
		var hills: float = noise.get_noise_2d(wx, wz) * 5.5
		var details: float = noise.get_noise_2d(wx * 2.1 + 900.0, wz * 2.1 - 900.0) * 1.1
		return broad + hills + details

	if map_type == WorldGraph.MAP_WATER:
		var islands: float = noise.get_noise_2d(wx * 0.12, wz * 0.12) * 15.0
		var detail_islands: float = noise.get_noise_2d(wx * 0.4 + 500.0, wz * 0.4 + 1000.0) * 5.0
		return islands + detail_islands - 7.0

	if map_type == WorldGraph.MAP_FLOATING_ISLAND:
		var half_extent: float = world_half_size() * 0.92
		var best_height: float = water_level - 34.0
		for i in range(18):
			var angle: float = TAU * float(i) / 18.0 + noise.get_noise_2d(float(i) * 17.0 + 400.0, float(i) * 9.0 - 120.0) * 0.45
			var dist: float = half_extent * 0.78 + noise.get_noise_2d(float(i) * 23.0 + 1000.0, float(i) * 13.0 - 700.0) * (half_extent * 0.22)
			dist = clamp(dist, half_extent * 0.45, half_extent)
			var cx: float = cos(angle) * dist
			var cz: float = sin(angle) * dist
			var radius: float = 21.0 + noise.get_noise_2d(float(i) * 19.0 + 300.0, float(i) * 31.0 - 800.0) * 5.2
			var top_y: float = 25.0 + noise.get_noise_2d(float(i) * 27.0 + 1400.0, float(i) * 21.0 - 900.0) * 8.0
			var d: float = Vector2(wx - cx, wz - cz).length()
			if d > radius:
				continue
			var rim: float = 1.0 - (d / radius)
			var island_y: float = top_y - (1.0 - rim) * 2.2 + noise.get_noise_2d(wx * 0.35 + float(i) * 71.0, wz * 0.35 - float(i) * 43.0) * 0.6
			if island_y > best_height:
				best_height = island_y
		for i in range(12):
			var angle_low: float = TAU * float(i) / 12.0 + 0.35 + noise.get_noise_2d(float(i) * 29.0 + 1800.0, float(i) * 17.0 - 500.0) * 0.5
			var dist_low: float = half_extent * 0.62 + noise.get_noise_2d(float(i) * 31.0 + 900.0, float(i) * 7.0 - 1400.0) * (half_extent * 0.26)
			dist_low = clamp(dist_low, half_extent * 0.28, half_extent * 0.92)
			var cx_low: float = cos(angle_low) * dist_low
			var cz_low: float = sin(angle_low) * dist_low
			var radius_low: float = 13.5 + noise.get_noise_2d(float(i) * 13.0 + 500.0, float(i) * 41.0 + 1100.0) * 3.6
			var top_y_low: float = 4.0 + noise.get_noise_2d(float(i) * 21.0 + 2000.0, float(i) * 15.0 - 600.0) * 3.5
			var d_low: float = Vector2(wx - cx_low, wz - cz_low).length()
			if d_low > radius_low:
				continue
			var rim_low: float = 1.0 - (d_low / radius_low)
			var island_low_y: float = top_y_low - (1.0 - rim_low) * 1.8 + noise.get_noise_2d(wx * 0.42 + float(i) * 53.0, wz * 0.42 - float(i) * 37.0) * 0.45
			if island_low_y > best_height:
				best_height = island_low_y
		var center_d: float = Vector2(wx, wz).length()
		if center_d <= 22.0:
			var center_rim: float = 1.0 - (center_d / 22.0)
			best_height = max(best_height, 19.0 - (1.0 - center_rim) * 2.0 + noise.get_noise_2d(wx * 0.30 + 2200.0, wz * 0.30 - 1700.0) * 0.55)
		return best_height

	var river_dist: float = river_distance(wx, wz)
	var river_carve: float = _smooth_falloff(river_dist, 0.0, 16.0) * 5.5
	var height: float = _base_land_height(wx, wz) - river_carve - _lake_carve(wx, wz)

	if river_dist < 6.0:
		height = min(height, water_level - 0.45 + abs(river_dist) * 0.05)

	# Steepen the shore: anything near or below the local water line drops to clearly
	# submerged, so you wade in and sink rather than walk a flat shelf at the surface.
	var lw: float = water_level_at(wx, wz)
	if height < lw + 0.2:
		height = lw - 0.5 - maxf(0.0, lw - height) * 1.8

	return height


func _smooth_falloff(value: float, edge0: float, edge1: float) -> float:
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)
