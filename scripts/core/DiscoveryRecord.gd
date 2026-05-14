extends RefCounted
class_name DiscoveryRecord

var title: String
var kind: String
var found_at: int
var x: float
var z: float


func _init(p_title: String, p_kind: String, p_found_at: int, p_x: float, p_z: float) -> void:
	title = p_title
	kind = p_kind
	found_at = p_found_at
	x = p_x
	z = p_z


func to_dict() -> Dictionary:
	return {
		"title": title,
		"kind": kind,
		"found_at": found_at,
		"x": x,
		"z": z,
	}


static func from_dict(d: Dictionary) -> DiscoveryRecord:
	return DiscoveryRecord.new(
		str(d.get("title", "")),
		str(d.get("kind", "")),
		int(d.get("found_at", 0)),
		float(d.get("x", 0.0)),
		float(d.get("z", 0.0)),
	)
