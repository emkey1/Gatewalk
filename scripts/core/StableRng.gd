extends RefCounted
class_name StableRng

var state: int = 1


func _init(seed_value: int) -> void:
	state = int(seed_value & 0xffffffff)
	if state == 0:
		state = 0x6d2b79f5


func next_u32() -> int:
	state = int((1664525 * state + 1013904223) & 0xffffffff)
	return state


func randf() -> float:
	return float(next_u32()) / 4294967296.0


func randf_range(min_value: float, max_value: float) -> float:
	# self. is required: an unqualified randf() binds to the global (per-process,
	# non-deterministic) randf, silently breaking seed reproducibility.
	return lerp(min_value, max_value, self.randf())


func randi_range(min_value: int, max_value: int) -> int:
	var lo: int = min(min_value, max_value)
	var hi: int = max(min_value, max_value)
	return lo + int(next_u32() % int(hi - lo + 1))


func chance(probability: float) -> bool:
	# self. is required: an unqualified randf() binds to the global (per-process,
	# non-deterministic) randf, silently breaking seed reproducibility.
	return self.randf() < probability


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[randi_range(0, items.size() - 1)]


static func mix_seed(base_seed: int, x: int, z: int = 0, salt: int = 0) -> int:
	var h: int = 2166136261
	h = _fnv_step(h, base_seed)
	h = _fnv_step(h, x)
	h = _fnv_step(h, z)
	h = _fnv_step(h, salt)
	if h == 0:
		h = 0x6d2b79f5
	return h


static func mix_string(base_seed: int, label: String, salt: int = 0) -> int:
	var h: int = mix_seed(base_seed, salt, label.length(), 0x5354524d)
	for i in range(label.length()):
		h = _fnv_step(h, label.unicode_at(i))
	if h == 0:
		h = 0x6d2b79f5
	return h


static func _fnv_step(h: int, value: int) -> int:
	h = int((h ^ (value & 0xffffffff)) & 0xffffffff)
	return int((h * 16777619) & 0xffffffff)
