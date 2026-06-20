extends RefCounted
class_name GateTravelService

const StableRng = preload("res://scripts/core/StableRng.gd")
const WorldGraph = preload("res://scripts/core/WorldGraph.gd")
const MAX_ROUTE_MAPS: int = 32


static func resolve_gate_transition(
	world_seed: int,
	current_map_id: String,
	gate_index: int,
	world: Dictionary,
	new_map_id_fn: Callable,
	water_route_chance: float = 0.12,
	arctic_route_chance: float = 0.10,
	floating_route_chance: float = 0.10,
	cave_route_chance: float = 0.18,
	nexus_route_chance: float = 0.0
) -> Dictionary:
	var maps: Dictionary = world.get("maps", {})
	var raw_record = maps.get(current_map_id, {})
	if typeof(raw_record) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"error": "map_record_not_dictionary",
		}

	var map_record: Dictionary = raw_record
	var gates: Dictionary = map_record.get("gates", {})
	var target_map_id: String = str(gates.get(str(gate_index), ""))
	var map_type: String = str(map_record.get("type", WorldGraph.MAP_NORMAL))
	var gate_rng := StableRng.new(StableRng.mix_string(world_seed, "gate_" + str(gate_index)))
	var changed: bool = false
	var is_water_route: bool = false

	# Heal stale/corrupt gate links from older saves or interrupted generation:
	# if the gate points at a map id that no longer exists, treat it as uninitialized.
	if target_map_id != "" and not maps.has(target_map_id):
		gates[str(gate_index)] = ""
		map_record["gates"] = gates
		maps[current_map_id] = map_record
		world["maps"] = maps
		target_map_id = ""
		changed = true

	if target_map_id == "":
		var seed_val: int = _preview_gate_seed(world_seed, gate_index)
		# Roll the destination type through the shared helper so Gate Sight's
		# predict_gate_target_type() previews the exact same outcome. The helper
		# consumes gate_rng identically to the old inline code, leaving its state
		# intact for the reroute paths below.
		var target_type: String = _roll_route_target_type(
			gate_rng, map_type, water_route_chance, arctic_route_chance,
			floating_route_chance, cave_route_chance, nexus_route_chance,
		)
		is_water_route = target_type == WorldGraph.MAP_WATER
		if _is_route_map_type(target_type) and _route_map_count(maps) >= MAX_ROUTE_MAPS:
			var reroute_id: String = _pick_existing_route_target(current_map_id, maps, gate_rng)
			if reroute_id != "":
				target_map_id = reroute_id
				gates[str(gate_index)] = target_map_id
				map_record["gates"] = gates
				maps[current_map_id] = map_record
				world["maps"] = maps
				changed = true
				return {
					"ok": true,
					"inert": false,
					"changed": changed,
					"target_map_id": target_map_id,
					"is_water_route": is_water_route,
					"world": world,
				}
			return {
				"ok": true,
				"inert": true,
				"changed": false,
			}

		target_map_id = str(new_map_id_fn.call("map"))
		maps[target_map_id] = WorldGraph.create_map_record(seed_val, target_type).to_dict()
		changed = true

		gates[str(gate_index)] = target_map_id
		map_record["gates"] = gates
		maps[current_map_id] = map_record
		world["maps"] = maps
		changed = true
	elif typeof(maps.get(target_map_id, null)) != TYPE_DICTIONARY:
		# If the linked map record exists but is malformed, rebuild it in place.
		var repaired_seed: int = _preview_gate_seed(world_seed, gate_index)
		maps[target_map_id] = WorldGraph.create_map_record(repaired_seed, WorldGraph.MAP_NORMAL).to_dict()
		world["maps"] = maps
		changed = true

	# A gate that resolves to the same map appears "dead" to players.
	# Repair by regenerating a fresh target map link.
	if target_map_id == current_map_id:
		var replacement_map_id: String = _pick_existing_route_target(current_map_id, maps, gate_rng)
		if replacement_map_id == "":
			var replacement_seed: int = _preview_gate_seed(world_seed, gate_index)
			replacement_map_id = str(new_map_id_fn.call("map"))
			maps[replacement_map_id] = WorldGraph.create_map_record(replacement_seed, WorldGraph.MAP_NORMAL).to_dict()
		gates[str(gate_index)] = replacement_map_id
		map_record["gates"] = gates
		maps[current_map_id] = map_record
		world["maps"] = maps
		target_map_id = replacement_map_id
		changed = true

	return {
		"ok": true,
		"inert": false,
		"changed": changed,
		"target_map_id": target_map_id,
		"is_water_route": is_water_route,
		"world": world,
	}


static func gate_target_seed(world_seed: int, current_map_id: String, world: Dictionary, gate_index: int) -> int:
	if current_map_id == "":
		return _preview_gate_seed(world_seed, gate_index)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var gates: Dictionary = map_record.get("gates", {})
	var target_map_id: String = str(gates.get(str(gate_index), ""))
	if target_map_id != "" and maps.has(target_map_id):
		var target_record: Dictionary = maps[target_map_id]
		return int(target_record.get("seed", _preview_gate_seed(world_seed, gate_index)))
	return _preview_gate_seed(world_seed, gate_index)


# Side-effect-free preview of the world type behind a gate, used by Gate Sight.
# For an already-charted gate it reports the linked map's real type; otherwise it
# rolls the same route logic resolve_gate_transition() uses (pass the same chances
# the caller passes to resolve so the preview matches reality). Note: in a fully
# saturated world (>= MAX_ROUTE_MAPS) resolve may reroute to an existing map, which
# this prediction does not model.
static func predict_gate_target_type(
	world_seed: int,
	current_map_id: String,
	gate_index: int,
	world: Dictionary,
	water_route_chance: float = 0.12,
	arctic_route_chance: float = 0.10,
	floating_route_chance: float = 0.10,
	cave_route_chance: float = 0.18,
	nexus_route_chance: float = 0.0
) -> String:
	var maps: Dictionary = world.get("maps", {})
	var map_type: String = WorldGraph.MAP_NORMAL
	var raw_record = maps.get(current_map_id, null)
	if typeof(raw_record) == TYPE_DICTIONARY:
		map_type = str(raw_record.get("type", WorldGraph.MAP_NORMAL))
		var gates: Dictionary = raw_record.get("gates", {})
		var target_map_id: String = str(gates.get(str(gate_index), ""))
		if target_map_id != "" and maps.has(target_map_id):
			var target_record = maps[target_map_id]
			if typeof(target_record) == TYPE_DICTIONARY:
				return str(target_record.get("type", WorldGraph.MAP_NORMAL))
	var gate_rng := StableRng.new(StableRng.mix_string(world_seed, "gate_" + str(gate_index)))
	return _roll_route_target_type(
		gate_rng, map_type, water_route_chance, arctic_route_chance,
		floating_route_chance, cave_route_chance, nexus_route_chance,
	)


static func resolve_gate_room_slot(
	world_seed: int,
	current_world_id: String,
	current_map_id: String,
	slot_index: int,
	worlds: Dictionary,
	current_map_record: Dictionary,
	new_id_fn: Callable,
	create_world_record_fn: Callable
) -> Dictionary:
	var slots: Dictionary = current_map_record.get("gate_room_slots", {})
	var slot_key: String = str(slot_index)
	var target_world_id: String = str(slots.get(slot_key, ""))
	if target_world_id != "" and worlds.has(target_world_id):
		var existing_world: Dictionary = worlds[target_world_id]
		return {
			"ok": true,
			"changed": false,
			"target_world_id": target_world_id,
			"target_map_id": str(existing_world.get("root_map", "")),
			"message": "Returning to " + str(existing_world.get("name", target_world_id)),
			"worlds": worlds,
			"current_map_record": current_map_record,
		}

	var map_seed: int = int((world_seed ^ ((slot_index + 1) * 747796405) ^ 912839201) & 0x7fffffff)
	if map_seed == 0:
		map_seed = 12345 + slot_index
	var root_map_id: String = str(new_id_fn.call("map"))
	target_world_id = str(new_id_fn.call("world"))
	var world_name: String = "World " + str(slot_index + 1)
	var world_record: Dictionary = create_world_record_fn.call(world_name, root_map_id, map_seed)
	world_record["gate_room_source_world"] = current_world_id
	world_record["gate_room_source_map"] = current_map_id

	slots[slot_key] = target_world_id
	current_map_record["gate_room_slots"] = slots

	var target_maps: Dictionary = world_record.get("maps", {})
	var target_map_record: Dictionary = target_maps.get(root_map_id, {})
	target_map_record["gate_room_slot_gate_0"] = current_world_id
	target_map_record["gate_room_slot_gate_1"] = current_map_id
	target_map_record["gate_room_slot_gate_2"] = str(slot_index)
	target_maps[root_map_id] = target_map_record
	world_record["maps"] = target_maps
	worlds[target_world_id] = world_record

	return {
		"ok": true,
		"changed": true,
		"target_world_id": target_world_id,
		"target_map_id": root_map_id,
		"message": "World " + world_name + " unfolded from the Gate Room.",
		"worlds": worlds,
		"current_map_record": current_map_record,
	}


static func resolve_nexus_slot(
	world_seed: int,
	current_world_id: String,
	_current_map_id: String,
	slot_index: int,
	current_map_record: Dictionary,
	universe_worlds: Dictionary
) -> Dictionary:
	var slots: Dictionary = current_map_record.get("nexus_slots", {})
	var slot_key: String = str(slot_index)
	var target_world_id: String = str(slots.get(slot_key, ""))
	if target_world_id != "" and universe_worlds.has(target_world_id):
		var target_world_existing: Dictionary = universe_worlds[target_world_id]
		return {
			"ok": true,
			"changed": false,
			"target_world_id": target_world_id,
			"target_map_id": str(target_world_existing.get("root_map", "")),
			"message": "Nexus -> " + str(target_world_existing.get("name", target_world_id)),
			"current_map_record": current_map_record,
		}

	var rng := StableRng.new(StableRng.mix_string(world_seed, "nexus_gate_" + str(slot_index)))
	var candidate_world_ids: Array[String] = []
	for world_key in universe_worlds.keys():
		var wid: String = str(world_key)
		if wid != current_world_id:
			candidate_world_ids.append(wid)
	if candidate_world_ids.is_empty():
		return {"ok": true, "skip": true, "changed": false}
	candidate_world_ids.sort()
	target_world_id = candidate_world_ids[rng.randi_range(0, candidate_world_ids.size() - 1)]
	var target_world: Dictionary = universe_worlds[target_world_id]
	var root_map_id: String = str(target_world.get("root_map", ""))
	if root_map_id == "":
		return {"ok": true, "skip": true, "changed": false}

	slots[slot_key] = target_world_id
	current_map_record["nexus_slots"] = slots
	return {
		"ok": true,
		"changed": true,
		"target_world_id": target_world_id,
		"target_map_id": root_map_id,
		"message": "Nexus -> " + str(target_world.get("name", target_world_id)),
		"current_map_record": current_map_record,
	}


static func resolve_gate_room_return(current_map_record: Dictionary) -> Dictionary:
	var return_world: String = str(current_map_record.get("gate_room_return_world", ""))
	var return_map: String = str(current_map_record.get("gate_room_return_map", ""))
	if return_world == "" or return_map == "":
		return {"ok": true, "has_return": false}
	return {
		"ok": true,
		"has_return": true,
		"target_world_id": return_world,
		"target_map_id": return_map,
		"message": "Returning from Gate Room.",
	}


static func with_updated_map_record(world: Dictionary, map_id: String, map_record: Dictionary) -> Dictionary:
	var updated_world: Dictionary = world.duplicate(true)
	var maps: Dictionary = updated_world.get("maps", {})
	maps[map_id] = map_record
	updated_world["maps"] = maps
	return updated_world


static func with_updated_world(worlds: Dictionary, world_id: String, world_record: Dictionary) -> Dictionary:
	var updated_worlds: Dictionary = worlds.duplicate(true)
	updated_worlds[world_id] = world_record
	return updated_worlds


static func _preview_gate_seed(world_seed: int, gate_index: int) -> int:
	var value: int = int((world_seed ^ ((gate_index + 1) * 747796405) ^ 2891336453) & 0x7fffffff)
	if value == 0:
		value = 12345 + gate_index
	return value


# Deterministic route-type roll shared by resolve_gate_transition() (which passes
# its live gate_rng so the later reroute draws stay aligned) and the pure
# predict_gate_target_type() (which passes a fresh same-seed rng). Consumes gate_rng
# exactly: water, then arctic, then floating, then cave, then nexus, each guarded.
static func _roll_route_target_type(
	gate_rng: StableRng,
	map_type: String,
	water_route_chance: float,
	arctic_route_chance: float,
	floating_route_chance: float,
	cave_route_chance: float,
	nexus_route_chance: float
) -> String:
	var target_type: String = WorldGraph.MAP_NORMAL
	var is_water_route: bool = false
	var is_arctic_route: bool = false
	var is_floating_route: bool = false
	var is_cave_route: bool = false
	var from_cave: bool = map_type == WorldGraph.MAP_CAVE
	if not from_cave and map_type != WorldGraph.MAP_WATER:
		is_water_route = gate_rng.chance(water_route_chance)
		if is_water_route:
			target_type = WorldGraph.MAP_WATER
	if not from_cave and not is_water_route:
		is_arctic_route = gate_rng.chance(arctic_route_chance)
		if is_arctic_route:
			target_type = WorldGraph.MAP_ARCTIC
	if not from_cave and not is_water_route and not is_arctic_route:
		is_floating_route = gate_rng.chance(floating_route_chance)
		if is_floating_route:
			target_type = WorldGraph.MAP_FLOATING_ISLAND
	if not from_cave and not is_water_route and not is_arctic_route and not is_floating_route:
		is_cave_route = gate_rng.chance(cave_route_chance)
		if is_cave_route:
			target_type = WorldGraph.MAP_CAVE
	if not from_cave and not is_water_route and not is_arctic_route and not is_floating_route and not is_cave_route and map_type == WorldGraph.MAP_NORMAL:
		if gate_rng.chance(nexus_route_chance):
			target_type = WorldGraph.MAP_NEXUS
	return target_type


static func _is_route_map_type(map_type: String) -> bool:
	return map_type == WorldGraph.MAP_NORMAL or map_type == WorldGraph.MAP_WATER or map_type == WorldGraph.MAP_ARCTIC or map_type == WorldGraph.MAP_FLOATING_ISLAND or map_type == WorldGraph.MAP_CAVE


static func _route_map_count(maps: Dictionary) -> int:
	var count: int = 0
	for map_id in maps.keys():
		var raw = maps[map_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var t: String = str(raw.get("type", WorldGraph.MAP_NORMAL))
		if _is_route_map_type(t):
			count += 1
	return count


static func _pick_existing_route_target(current_map_id: String, maps: Dictionary, gate_rng: StableRng) -> String:
	var candidates: Array[String] = []
	for map_id in maps.keys():
		var mid: String = str(map_id)
		if mid == current_map_id:
			continue
		var raw = maps[mid]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var t: String = str(raw.get("type", WorldGraph.MAP_NORMAL))
		if _is_route_map_type(t):
			candidates.append(mid)
	if candidates.is_empty():
		return ""
	candidates.sort()
	var idx: int = gate_rng.randi_range(0, candidates.size() - 1)
	return candidates[idx]
