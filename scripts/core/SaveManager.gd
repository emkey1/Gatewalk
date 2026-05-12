extends RefCounted
class_name SaveManager

const SAVE_VERSION: int = 2


static func default_save_data() -> Dictionary:
	var universe_id := new_id("universe")
	var universes := {}
	universes[universe_id] = create_universe_record("Universe 1")
	return {
		"version": SAVE_VERSION,
		"universes": universes,
		"current_universe_id": universe_id
	}


static func create_universe_record(universe_name: String) -> Dictionary:
	return {
		"name": universe_name,
		"worlds": {},
		"last_world_id": "",
		"achievements": {},
		"maps_visited": [],
		"lichen_count": 0,
		"settings": {
			"cycle_speed_multiplier": 1.0,
			"start_fullscreen": true,
			"graphics_level": 0,
			"density_level": 2
		}
	}


static func normalize_save_data(raw_data: Dictionary) -> Dictionary:
	if raw_data.has("universes"):
		var normalized: Dictionary = raw_data.duplicate(true)
		normalized["version"] = int(normalized.get("version", SAVE_VERSION))
		var universes: Dictionary = normalized.get("universes", {})
		if universes.is_empty():
			var universe_id := new_id("universe")
			universes[universe_id] = create_universe_record("Universe 1")
			normalized["universes"] = universes
			normalized["current_universe_id"] = universe_id
		elif str(normalized.get("current_universe_id", "")) == "":
			normalized["current_universe_id"] = str(universes.keys()[0])
		_normalize_current_universe(normalized)
		return normalized

	var migrated := default_save_data()
	var universe_id: String = str(migrated["current_universe_id"])
	var migrated_universes: Dictionary = migrated.get("universes", {})
	var universe: Dictionary = migrated_universes[universe_id]
	universe["worlds"] = raw_data.get("worlds", {})
	universe["last_world_id"] = str(raw_data.get("last_world_id", ""))
	universe["achievements"] = raw_data.get("achievements", {})
	universe["maps_visited"] = raw_data.get("maps_visited", [])
	universe["lichen_count"] = int(raw_data.get("lichen_count", 0))
	var settings: Dictionary = universe.get("settings", {})
	settings["cycle_speed_multiplier"] = float(raw_data.get("cycle_speed_multiplier", 1.0))
	settings["start_fullscreen"] = bool(raw_data.get("start_fullscreen", true))
	settings["graphics_level"] = int(raw_data.get("graphics_level", 0))
	settings["density_level"] = int(raw_data.get("density_level", 2))
	universe["settings"] = settings
	migrated_universes[universe_id] = universe
	migrated["universes"] = migrated_universes
	return migrated


static func current_universe_id(save_data: Dictionary) -> String:
	return str(save_data.get("current_universe_id", ""))


static func current_universe(save_data: Dictionary) -> Dictionary:
	var universes: Dictionary = save_data.get("universes", {})
	var universe_id := current_universe_id(save_data)
	return universes.get(universe_id, {})


static func set_current_universe(save_data: Dictionary, universe: Dictionary) -> Dictionary:
	var result: Dictionary = save_data
	var universe_id := current_universe_id(result)
	var universes: Dictionary = result.get("universes", {})
	if universe_id == "":
		universe_id = new_id("universe")
		result["current_universe_id"] = universe_id
	universes[universe_id] = universe
	result["universes"] = universes
	return result


static func current_settings(save_data: Dictionary) -> Dictionary:
	var universe := current_universe(save_data)
	return universe.get("settings", {})


static func new_id(prefix: String) -> String:
	var time_part := str(Time.get_unix_time_from_system())
	var tick_part := str(Time.get_ticks_usec())
	return prefix + "_" + time_part + "_" + tick_part


static func _normalize_current_universe(save_data: Dictionary) -> void:
	var universe := current_universe(save_data)
	if universe.is_empty():
		return
	if not universe.has("settings"):
		universe["settings"] = {}
	var settings: Dictionary = universe.get("settings", {})
	settings["cycle_speed_multiplier"] = float(settings.get("cycle_speed_multiplier", universe.get("cycle_speed_multiplier", 1.0)))
	settings["start_fullscreen"] = bool(settings.get("start_fullscreen", universe.get("start_fullscreen", true)))
	settings["graphics_level"] = int(settings.get("graphics_level", universe.get("graphics_level", 0)))
	settings["density_level"] = int(settings.get("density_level", universe.get("density_level", 2)))
	universe["settings"] = settings
	universe["worlds"] = universe.get("worlds", {})
	universe["last_world_id"] = str(universe.get("last_world_id", ""))
	universe["achievements"] = universe.get("achievements", {})
	universe["maps_visited"] = universe.get("maps_visited", [])
	universe["lichen_count"] = int(universe.get("lichen_count", 0))
	set_current_universe(save_data, universe)
