extends RefCounted
class_name WorldRecord

var name: String
var root_map: String
var current_map: String
var maps: Dictionary

var gate_room_source_world: String = ""
var gate_room_source_map: String = ""


func _init(p_name: String, p_root_map: String, p_root_map_record: MapRecord) -> void:
	name = p_name
	root_map = p_root_map
	current_map = p_root_map
	maps = {p_root_map: p_root_map_record}


func get_map(map_id: String) -> MapRecord:
	var mr: Variant = maps.get(map_id, null)
	return mr as MapRecord if mr != null else null


func add_map(map_id: String, map_record: MapRecord) -> void:
	maps[map_id] = map_record


func remove_map(map_id: String) -> void:
	maps.erase(map_id)


func map_count() -> int:
	return maps.size()


func to_dict() -> Dictionary:
	var maps_dict: Dictionary = {}
	for key in maps.keys():
		var mr: MapRecord = maps[key] as MapRecord
		maps_dict[key] = mr.to_dict() if mr != null else {}

	var d: Dictionary = {
		"name": name,
		"root_map": root_map,
		"current_map": current_map,
		"maps": maps_dict,
	}
	if gate_room_source_world != "":
		d["gate_room_source_world"] = gate_room_source_world
	if gate_room_source_map != "":
		d["gate_room_source_map"] = gate_room_source_map
	return d


static func from_dict(d: Dictionary) -> WorldRecord:
	var maps_dict: Dictionary = d.get("maps", {})
	var map_ids: Array = maps_dict.keys()
	var first_map_id: String = str(d.get("root_map", map_ids[0] if not map_ids.is_empty() else ""))

	var first_record: MapRecord
	if first_map_id != "" and maps_dict.has(first_map_id):
		var raw: Dictionary = maps_dict[first_map_id] as Dictionary
		first_record = MapRecord.from_dict(raw)
	else:
		first_record = MapRecord.new(0)

	var record := WorldRecord.new(
		str(d.get("name", first_map_id)),
		first_map_id,
		first_record,
	)
	record.current_map = str(d.get("current_map", first_map_id))

	for map_key in map_ids:
		var mid: String = str(map_key)
		if mid != first_map_id:
			var raw: Dictionary = maps_dict[mid] as Dictionary
			record.maps[mid] = MapRecord.from_dict(raw)

	record.gate_room_source_world = str(d.get("gate_room_source_world", ""))
	record.gate_room_source_map = str(d.get("gate_room_source_map", ""))
	return record


static func to_dict_map(worlds: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in worlds.keys():
		var wr: WorldRecord = worlds[key] as WorldRecord
		result[key] = wr.to_dict() if wr != null else {}
	return result


static func from_dict_map(d: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in d.keys():
		var raw: Dictionary = d[key] as Dictionary
		result[str(key)] = WorldRecord.from_dict(raw)
	return result
