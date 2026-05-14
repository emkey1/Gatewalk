extends RefCounted
class_name MapRecord

var seed: int
var type: String
var gates: Dictionary
var discoveries: Dictionary
var pins: Dictionary
var available_discoveries: int = 0
var wonder_count: int = 0
var gate_room_slots: Dictionary = {}
var nexus_slots: Dictionary = {}

var gate_room_return_world: String = ""
var gate_room_return_map: String = ""
var gate_room_slot_gate_0: String = ""
var gate_room_slot_gate_1: String = ""
var gate_room_slot_gate_2: String = ""


func _init(p_seed: int, p_type: String = "normal") -> void:
	seed = p_seed
	type = p_type
	gates = {}
	discoveries = {}
	pins = {}


func set_gate(gate_index: int, target_map_id: String) -> void:
	gates[str(gate_index)] = target_map_id


func get_gate(gate_index: int) -> String:
	return str(gates.get(str(gate_index), ""))


func has_gate(gate_index: int) -> bool:
	return gates.has(str(gate_index))


func gate_count() -> int:
	return gates.size()


func add_discovery(discovery_id: String, record: DiscoveryRecord) -> void:
	discoveries[discovery_id] = record


func get_discovery(discovery_id: String) -> DiscoveryRecord:
	return discoveries.get(discovery_id, null) as DiscoveryRecord


func discovery_count() -> int:
	return discoveries.size()


func discovery_kind_count(kind: String) -> int:
	var count := 0
	for key in discoveries.keys():
		var dr: DiscoveryRecord = discoveries[key] as DiscoveryRecord
		if dr != null and dr.kind == kind:
			count += 1
	return count


func add_pin(pin_id: String, record: DiscoveryRecord) -> void:
	pins[pin_id] = record


func pin_count() -> int:
	return pins.size()


func to_dict() -> Dictionary:
	var disc_dict: Dictionary = {}
	for key in discoveries.keys():
		var dr: DiscoveryRecord = discoveries[key] as DiscoveryRecord
		disc_dict[key] = dr.to_dict() if dr != null else {"title": "", "kind": "", "found_at": 0, "x": 0.0, "z": 0.0}

	var pin_dict: Dictionary = {}
	for key in pins.keys():
		var pr: DiscoveryRecord = pins[key] as DiscoveryRecord
		pin_dict[key] = pr.to_dict() if pr != null else {"title": "", "kind": "pin", "found_at": 0, "x": 0.0, "z": 0.0}

	var d: Dictionary = {
		"seed": seed,
		"type": type,
		"gates": gates.duplicate(),
		"discoveries": disc_dict,
		"pins": pin_dict,
	}
	if available_discoveries > 0:
		d["available_discoveries"] = available_discoveries
	if wonder_count > 0:
		d["wonder_count"] = wonder_count
	if not gate_room_slots.is_empty():
		d["gate_room_slots"] = gate_room_slots.duplicate()
	if not nexus_slots.is_empty():
		d["nexus_slots"] = nexus_slots.duplicate()
	if gate_room_return_world != "":
		d["gate_room_return_world"] = gate_room_return_world
	if gate_room_return_map != "":
		d["gate_room_return_map"] = gate_room_return_map
	if gate_room_slot_gate_0 != "":
		d["gate_room_slot_gate_0"] = gate_room_slot_gate_0
	if gate_room_slot_gate_1 != "":
		d["gate_room_slot_gate_1"] = gate_room_slot_gate_1
	if gate_room_slot_gate_2 != "":
		d["gate_room_slot_gate_2"] = gate_room_slot_gate_2
	return d


static func from_dict(d: Dictionary) -> MapRecord:
	var record := MapRecord.new(
		int(d.get("seed", 0)),
		str(d.get("type", "normal")),
	)

	record.available_discoveries = int(d.get("available_discoveries", 0))
	record.wonder_count = int(d.get("wonder_count", 0))

	var raw_slots: Dictionary = d.get("gate_room_slots", {})
	for k in raw_slots.keys():
		record.gate_room_slots[str(k)] = str(raw_slots[k])

	var raw_nexus: Dictionary = d.get("nexus_slots", {})
	for k in raw_nexus.keys():
		record.nexus_slots[str(k)] = str(raw_nexus[k])

	record.gate_room_return_world = str(d.get("gate_room_return_world", ""))
	record.gate_room_return_map = str(d.get("gate_room_return_map", ""))
	record.gate_room_slot_gate_0 = str(d.get("gate_room_slot_gate_0", ""))
	record.gate_room_slot_gate_1 = str(d.get("gate_room_slot_gate_1", ""))
	record.gate_room_slot_gate_2 = str(d.get("gate_room_slot_gate_2", ""))

	var raw_gates: Dictionary = d.get("gates", {})
	for key in raw_gates.keys():
		record.gates[str(key)] = str(raw_gates[key])

	var raw_discs: Dictionary = d.get("discoveries", {})
	for key in raw_discs.keys():
		var dv: Variant = raw_discs[key]
		if dv is Dictionary:
			record.discoveries[str(key)] = DiscoveryRecord.from_dict(dv as Dictionary)
		else:
			record.discoveries[str(key)] = DiscoveryRecord.from_dict({})

	var raw_pins: Dictionary = d.get("pins", {})
	for key in raw_pins.keys():
		var pv: Variant = raw_pins[key]
		if pv is Dictionary:
			record.pins[str(key)] = DiscoveryRecord.from_dict(pv as Dictionary)
		else:
			record.pins[str(key)] = DiscoveryRecord.from_dict({})

	return record
