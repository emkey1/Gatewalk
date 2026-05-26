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


func _setup_noise() -> void:
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.020
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 1.9
	noise.fractal_gain = 0.45


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
	if map_type == WorldGraph.MAP_FLOATING_ISLAND:
		return 999.0
	var curve: float = sin(wx * 0.025) * 22.0 + noise.get_noise_2d(wx * 0.2 + 3200.0, 410.0) * 16.0
	return abs(wz - curve)


func height_at_world(wx: float, wz: float) -> float:
	if map_type == WorldGraph.MAP_GATE_ROOM or map_type == WorldGraph.MAP_CAVE or map_type == WorldGraph.MAP_NEXUS:
		return 0.0

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

	var broad: float = noise.get_noise_2d(wx * 0.35 + 1200.0, wz * 0.35 - 800.0) * height_scale
	var hills: float = noise.get_noise_2d(wx, wz) * 5.5
	var details: float = noise.get_noise_2d(wx * 2.1 + 900.0, wz * 2.1 - 900.0) * 1.1
	var river_dist: float = river_distance(wx, wz)
	var river_carve: float = _smooth_falloff(river_dist, 0.0, 16.0) * 5.5
	var height: float = broad + hills + details - river_carve

	if river_dist < 6.0:
		height = min(height, water_level - 0.45 + abs(river_dist) * 0.05)

	return height


func _smooth_falloff(value: float, edge0: float, edge1: float) -> float:
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)
