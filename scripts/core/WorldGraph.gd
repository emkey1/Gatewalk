extends RefCounted
class_name WorldGraph

const MAP_NORMAL := "normal"
const MAP_MOON := "moon"
const MAP_WATER := "water"
const MAP_GATE_ROOM := "gate_room"
const MAP_CAVE := "cave"
const MAP_NEXUS := "map_nexus"


static func create_map_record(map_seed: int, map_type: String = MAP_NORMAL) -> MapRecord:
	var record := MapRecord.new(map_seed, map_type)
	if map_type == MAP_GATE_ROOM:
		record.gate_room_slots = {}
	elif map_type == MAP_NEXUS:
		record.nexus_slots = {}
	return record


static func create_world_record( \
	world_name: String, root_map_id: String, map_seed: int \
) -> WorldRecord:
	var root_map: MapRecord = create_map_record(map_seed)
	return WorldRecord.new(world_name, root_map_id, root_map)


static func map_type(map_record: MapRecord) -> String:
	return map_record.type


static func map_type_from_dict(map_record: Dictionary) -> String:
	return str(map_record.get("type", MAP_NORMAL))


static func opposite_gate_index(gate_index: int) -> int:
	if gate_index == 0:
		return 1
	if gate_index == 1:
		return 0
	if gate_index == 2:
		return 3
	return 2
