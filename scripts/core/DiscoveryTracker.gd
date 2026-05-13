extends RefCounted
class_name DiscoveryTracker

var get_world: Callable
var set_world: Callable
var get_current_universe: Callable
var set_current_universe: Callable
var save_world_data: Callable
var get_map_record: Callable

var current_world_id: String = ""
var current_map_id: String = ""
var last_discovery_text: String = ""

var on_orb_discovered: Callable
var on_message: Callable  # func(msg: String) — called when discovery/achievement text changes

const ACHIEVEMENT_DEFS := {
	"first_wonder": {"name": "First Discovery", "desc": "Find your first wonder on any map"},
	"all_wonders_map": {"name": "Map Scholar", "desc": "Find all wonders on a single map"},
	"all_wonders_world": {"name": "World Scholar", "desc": "Find all wonders across a whole world"},
	"lichen_catcher": {"name": "Frisbee Catcher", "desc": "Catch a thrown lichen"},
	"moon_visitor": {"name": "Moon Visitor", "desc": "Travel to the moon"},
	"gate_room_finder": {"name": "Gate Room Discoverer", "desc": "Find a gate room"},
	"world_traveler": {"name": "World Traveler", "desc": "Visit 5 different maps"},
	"cavern_explorer": {"name": "Cavern Explorer", "desc": "Discover a cave map"},
	"island_hopper": {"name": "Island Hopper", "desc": "Discover a water map"},
	"collector_50": {"name": "Lichensmith", "desc": "Collect 50 lichen"},
	"moon_pilgrim": {"name": "Moon Pilgrim", "desc": "Complete all 9 moon shrines"},
	"gate_crasher": {"name": "Gate Crasher", "desc": "Travel through your first gate"},
}


func record_discovery(discovery_id: String, title: String, kind: String, discovery_position: Vector3) -> void:
	if current_world_id == "" or current_map_id == "":
		return

	var world: Dictionary = get_world.call(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	if discoveries.has(discovery_id):
		return

	discoveries[discovery_id] = {
		"title": title,
		"kind": kind,
		"found_at": Time.get_unix_time_from_system(),
		"x": discovery_position.x,
		"z": discovery_position.z
	}
	map_record["discoveries"] = discoveries
	maps[current_map_id] = map_record
	world["maps"] = maps
	set_world.call(current_world_id, world)
	save_world_data.call()
	last_discovery_text = "New discovery: " + title
	if on_message.is_valid():
		on_message.call(last_discovery_text)
	print("Atlas discovery: ", title, " [", kind, "]")
	if kind == "wonder":
		award_achievement("first_wonder")
		check_map_wonders_complete()
		check_world_wonders_complete()
	if kind == "orb":
		if on_orb_discovered.is_valid():
			on_orb_discovered.call()


func award_achievement(id: String) -> void:
	var universe: Dictionary = get_current_universe.call()
	var achievements: Dictionary = universe.get("achievements", {})
	if achievements.has(id):
		return
	achievements[id] = Time.get_unix_time_from_system()
	universe["achievements"] = achievements
	set_current_universe.call(universe)
	save_world_data.call()
	var defn: Dictionary = ACHIEVEMENT_DEFS.get(id, {})
	var name: String = defn.get("name", id)
	last_discovery_text = "Achievement: " + name + "!"
	if on_message.is_valid():
		on_message.call(last_discovery_text)
	print("Achievement unlocked: ", name)


func check_map_wonders_complete() -> void:
	if current_world_id == "" or current_map_id == "":
		return
	var world: Dictionary = get_world.call(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var wonder_count: int = int(map_record.get("wonder_count", 0))
	if wonder_count <= 0:
		return
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var wonder_found := 0
	for key in discoveries.keys():
		if discoveries[key].get("kind", "") == "wonder":
			wonder_found += 1
	if wonder_found >= wonder_count:
		award_achievement("all_wonders_map")


func check_world_wonders_complete() -> void:
	if current_world_id == "":
		return
	var world: Dictionary = get_world.call(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var total_wonders := 0
	var total_found := 0
	for map_key in maps.keys():
		var mr: Dictionary = maps[map_key]
		total_wonders += int(mr.get("wonder_count", 0))
		var disc: Dictionary = mr.get("discoveries", {})
		for dk in disc.keys():
			if disc[dk].get("kind", "") == "wonder":
				total_found += 1
	if total_wonders > 0 and total_found >= total_wonders:
		award_achievement("all_wonders_world")


func check_map_visit_achievements() -> void:
	var universe: Dictionary = get_current_universe.call()
	var visited: Array = universe.get("maps_visited", [])
	if current_map_id != "" and not visited.has(current_map_id):
		visited.append(current_map_id)
		universe["maps_visited"] = visited
		set_current_universe.call(universe)
		save_world_data.call()
	if visited.size() >= 5:
		award_achievement("world_traveler")


func current_map_discovery_count() -> int:
	if current_world_id == "" or current_map_id == "":
		return 0

	var world: Dictionary = get_world.call(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	return discoveries.size()


func current_world_map_count() -> int:
	if current_world_id == "":
		return 0
	var world: Dictionary = get_world.call(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	return maps.size()


func map_type(world_id: String, map_id: String) -> String:
	var map_record: Dictionary = get_map_record.call(world_id, map_id)
	return str(map_record.get("type", "normal"))
