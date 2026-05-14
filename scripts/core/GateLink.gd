extends RefCounted
class_name GateLink

var gate_index: int
var target_map_id: String


func _init(p_gate_index: int, p_target_map_id: String) -> void:
	gate_index = p_gate_index
	target_map_id = p_target_map_id


func to_dict_key() -> String:
	return str(gate_index)


func to_dict_value() -> String:
	return target_map_id


static func from_dict(key: String, value: String) -> GateLink:
	return GateLink.new(int(key), value)
