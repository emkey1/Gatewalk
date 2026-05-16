extends RefCounted
class_name SaveManager

const SAVE_VERSION: int = 3


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
	var seed_root: int = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())
	return {
		"name": universe_name,
		"worlds": {},
		"last_world_id": "",
		"achievements": {},
		"maps_visited": [],
		"lichen_count": 0,
		"seed_root": int(seed_root & 0x7fffffff),
		"seed_counter": 0,
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
		else:
			var current_id: String = str(normalized.get("current_universe_id", ""))
			if current_id == "" or not universes.has(current_id):
				normalized["current_universe_id"] = str(universes.keys()[0])
		_normalize_all_universes(normalized)
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


static func audit_and_repair_save_data(raw_data: Dictionary) -> Dictionary:
	var report: Dictionary = {
		"repaired_worlds": 0,
		"repaired_maps": 0,
		"repaired_fields": 0,
	}
	var normalized: Dictionary = normalize_save_data(raw_data)
	var universes: Dictionary = normalized.get("universes", {})
	var changed_worlds: int = 0
	var changed_maps: int = 0
	var changed_fields: int = 0
	for universe_id in universes.keys():
		var universe: Dictionary = universes[universe_id] as Dictionary
		var worlds: Dictionary = universe.get("worlds", {})
		for world_id in worlds.keys():
			var world: Dictionary = worlds[world_id] as Dictionary
			var world_changed: bool = false
			var maps: Dictionary = world.get("maps", {})
			if typeof(maps) != TYPE_DICTIONARY:
				maps = {}
				world["maps"] = maps
				changed_fields += 1
				world_changed = true
			var map_changed_local: bool = false
			for map_id in maps.keys():
				var raw_map = maps[map_id]
				var mr: Dictionary = raw_map if typeof(raw_map) == TYPE_DICTIONARY else {}
				var fixed: Dictionary = _sanitize_map_record(mr, str(map_id), report)
				if fixed.hash() != mr.hash() or typeof(raw_map) != TYPE_DICTIONARY:
					maps[map_id] = fixed
					map_changed_local = true
			if map_changed_local:
				changed_maps += 1
				world_changed = true
			if world.get("root_map", "") == "" or not maps.has(str(world.get("root_map", ""))):
				var map_keys: Array = maps.keys()
				world["root_map"] = str(map_keys[0]) if not map_keys.is_empty() else ""
				changed_fields += 1
				world_changed = true
			if world.get("current_map", "") == "" or not maps.has(str(world.get("current_map", ""))):
				world["current_map"] = str(world.get("root_map", ""))
				changed_fields += 1
				world_changed = true
			if world_changed:
				world["maps"] = maps
				worlds[world_id] = world
				changed_worlds += 1
		universe["worlds"] = worlds
		universes[universe_id] = universe
	normalized["universes"] = universes
	report["repaired_worlds"] = changed_worlds
	report["repaired_maps"] = changed_maps
	report["repaired_fields"] = changed_fields + int(report.get("repaired_fields", 0))
	return {"save_data": normalized, "report": report}


static func _sanitize_map_record(mr: Dictionary, map_id: String, report: Dictionary) -> Dictionary:
	var fixed: Dictionary = mr.duplicate(true)
	if not fixed.has("seed"):
		fixed["seed"] = 0
		report["repaired_fields"] = int(report.get("repaired_fields", 0)) + 1
	if not fixed.has("type"):
		fixed["type"] = "normal"
		report["repaired_fields"] = int(report.get("repaired_fields", 0)) + 1
	if not fixed.has("gates") or typeof(fixed.get("gates")) != TYPE_DICTIONARY:
		fixed["gates"] = {}
		report["repaired_fields"] = int(report.get("repaired_fields", 0)) + 1
	if not fixed.has("discoveries") or typeof(fixed.get("discoveries")) != TYPE_DICTIONARY:
		fixed["discoveries"] = {}
		report["repaired_fields"] = int(report.get("repaired_fields", 0)) + 1
	if not fixed.has("pins") or typeof(fixed.get("pins")) != TYPE_DICTIONARY:
		fixed["pins"] = {}
		report["repaired_fields"] = int(report.get("repaired_fields", 0)) + 1
	if not fixed.has("available_discoveries"):
		fixed["available_discoveries"] = 0
		report["repaired_fields"] = int(report.get("repaired_fields", 0)) + 1
	if not fixed.has("wonder_count"):
		fixed["wonder_count"] = 0
		report["repaired_fields"] = int(report.get("repaired_fields", 0)) + 1
	if not fixed.has("name") or str(fixed.get("name", "")).strip_edges() == "":
		fixed["name"] = map_id
		report["repaired_fields"] = int(report.get("repaired_fields", 0)) + 1
	return fixed


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


static func set_current_universe_id(save_data: Dictionary, universe_id: String) -> Dictionary:
	var result: Dictionary = save_data
	result["current_universe_id"] = universe_id
	return result


static func set_universe(save_data: Dictionary, universe_id: String, universe: Dictionary) -> Dictionary:
	var result: Dictionary = save_data
	var universes: Dictionary = result.get("universes", {})
	universes[universe_id] = universe
	result["universes"] = universes
	return result


static func allocate_seed_for_current_universe(save_data: Dictionary, label: String, salt: int = 0) -> Dictionary:
	var universe: Dictionary = _normalize_universe_record(current_universe(save_data).duplicate(true), SAVE_VERSION)
	var seed_root: int = int(universe.get("seed_root", 0))
	var counter: int = int(universe.get("seed_counter", 0))
	var mixed: int = int(StableRng.mix_string(seed_root, label, counter + salt) & 0x7fffffff)
	universe["seed_counter"] = counter + 1
	var updated_save: Dictionary = set_current_universe(save_data, universe)
	return {"save_data": updated_save, "seed": mixed}


static func current_settings(save_data: Dictionary) -> Dictionary:
	var universe := current_universe(save_data)
	return universe.get("settings", {})


static func new_id(prefix: String) -> String:
	var time_part := str(Time.get_unix_time_from_system())
	var tick_part := str(Time.get_ticks_usec())
	return prefix + "_" + time_part + "_" + tick_part


static func _migrate_v2_to_v3_universe(universe: Dictionary) -> Dictionary:
	var worlds: Dictionary = universe.get("worlds", {})
	for world_key in worlds.keys():
		var world: Dictionary = worlds[world_key] as Dictionary
		if world.is_empty():
			continue
		var maps: Dictionary = world.get("maps", {})
		for map_key in maps.keys():
			var mr: Dictionary = maps[map_key] as Dictionary
			if mr.is_empty():
				continue
			if not mr.has("seed"):
				mr["seed"] = 0
			if not mr.has("type"):
				mr["type"] = "normal"
			if not mr.has("gates"):
				mr["gates"] = {}
			if not mr.has("discoveries"):
				mr["discoveries"] = {}
			if not mr.has("available_discoveries"):
				mr["available_discoveries"] = 0
			if not mr.has("wonder_count"):
				mr["wonder_count"] = 0
			maps[map_key] = mr
		world["maps"] = maps
		if not world.has("root_map"):
			var map_keys: Array = maps.keys()
			world["root_map"] = str(map_keys[0]) if not map_keys.is_empty() else ""
			if not world.has("current_map"):
				world["current_map"] = world.get("root_map", "")
			worlds[world_key] = world
	universe["worlds"] = worlds
	return universe


static func _normalize_universe_record(universe: Dictionary, save_version: int) -> Dictionary:
	if save_version < 3:
		universe = _migrate_v2_to_v3_universe(universe)
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
	var normalized_seed_root: int = int(universe.get("seed_root", new_id("seed").hash()))
	universe["seed_root"] = normalized_seed_root & 0x7fffffff
	universe["seed_counter"] = int(universe.get("seed_counter", 0))
	return universe


static func _normalize_all_universes(save_data: Dictionary) -> void:
	var universes: Dictionary = save_data.get("universes", {})
	if universes.is_empty():
		return
	var version: int = int(save_data.get("version", 0))
	var normalized_universes: Dictionary = {}
	for universe_id in universes.keys():
		var universe: Dictionary = universes[universe_id]
		normalized_universes[universe_id] = _normalize_universe_record(universe, version)
	save_data["universes"] = normalized_universes
	if version < SAVE_VERSION:
		save_data["version"] = SAVE_VERSION
