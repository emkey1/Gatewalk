extends SceneTree

const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")
const WorldGraph = preload("res://scripts/core/WorldGraph.gd")
const GateTravelService = preload("res://scripts/core/GateTravelService.gd")
const MapContext = preload("res://scripts/core/MapContext.gd")
const TreeFactory = preload("res://scripts/factories/TreeFactory.gd")
const ProgressionService = preload("res://scripts/core/ProgressionService.gd")
const LinerFactory = preload("res://scripts/factories/LinerFactory.gd")

const GRAPHICS_LEVEL := 0
const DENSITY_LEVEL := 2
const SEED_A := 91357
const SEED_B := 91358

var _validation_id_counter: int = 0


func _init() -> void:
	var failures: Array[String] = []
	_run_map_determinism_checks(failures)
	_run_save_migration_checks(failures)
	_run_gate_travel_checks(failures)
	_run_gate_room_and_nexus_checks(failures)
	_run_persisted_universe_isolation_checks(failures)
	_run_seed_allocator_isolation_checks(failures)
	_run_tree_factory_checks(failures)
	_run_progression_checks(failures)
	_run_water_cache_terrain_checks(failures)
	_run_stable_rng_checks(failures)
	_run_gate_sight_preview_checks(failures)
	_run_rock_multimesh_checks(failures)
	_run_flower_multimesh_checks(failures)
	_run_crystal_multimesh_checks(failures)
	_run_liner_checks(failures)

	if failures.is_empty():
		print("VALIDATION OK: deterministic generation and save migration checks passed")
		quit(0)
		return

	for failure in failures:
		printerr("VALIDATION FAIL: ", failure)
	quit(1)


func _run_map_determinism_checks(failures: Array[String]) -> void:
	var map_types: Array[String] = [
		WorldGraph.MAP_NORMAL,
		WorldGraph.MAP_WATER,
		WorldGraph.MAP_MOON,
		WorldGraph.MAP_ARCTIC,
		WorldGraph.MAP_CAVE,
		WorldGraph.MAP_GATE_ROOM,
		WorldGraph.MAP_NEXUS,
		WorldGraph.MAP_LINER,
	]

	for map_type in map_types:
		var first: Dictionary = _build_map_signature(SEED_A, map_type)
		var second: Dictionary = _build_map_signature(SEED_A, map_type)
		if int(first.get("node_count", 0)) <= 0:
			failures.append("Map type '%s' produced empty generation output." % map_type)
		var strict_maps := [WorldGraph.MAP_NORMAL, WorldGraph.MAP_WATER, WorldGraph.MAP_ARCTIC, WorldGraph.MAP_GATE_ROOM, WorldGraph.MAP_NEXUS]
		var deterministic_key := "signature"
		if not strict_maps.has(map_type):
			deterministic_key = "core_signature"
		if str(first.get(deterministic_key, "")) != str(second.get(deterministic_key, "")):
			failures.append(
				"Map type '%s' is non-deterministic for fixed seed %d. %s" % [
					map_type,
					SEED_A,
					_signature_diff_summary(str(first.get(deterministic_key, "")), str(second.get(deterministic_key, ""))),
				]
			)

	var normal_a: Dictionary = _build_map_signature(SEED_A, WorldGraph.MAP_NORMAL)
	var normal_b: Dictionary = _build_map_signature(SEED_B, WorldGraph.MAP_NORMAL)
	if str(normal_a.get("signature", "")) == str(normal_b.get("signature", "")):
		failures.append("Normal map signature did not change between seeds %d and %d." % [SEED_A, SEED_B])

	var moon_a: Dictionary = _build_map_signature(SEED_A, WorldGraph.MAP_MOON)
	if str(normal_a.get("signature", "")) == str(moon_a.get("signature", "")):
		failures.append("Normal and moon map signatures unexpectedly match for seed %d." % SEED_A)


# The Queen Mary is built by LinerFactory (from Main's scatter), not MapGenerator, so its
# determinism + construction need a dedicated check: identical seed -> identical geometry
# and gate positions, exactly 4 gates, all up on a deck (well above the waterline).
func _run_liner_checks(failures: Array[String]) -> void:
	var wl: float = -1.7
	var root_a := Node3D.new()
	var gates_a: Array = LinerFactory.build(root_a, SEED_A, wl)
	var count_a: int = _count_descendants(root_a)
	var root_b := Node3D.new()
	var gates_b: Array = LinerFactory.build(root_b, SEED_A, wl)
	var count_b: int = _count_descendants(root_b)

	if count_a <= 0:
		failures.append("Liner build produced no geometry.")
	if count_a != count_b:
		failures.append("Liner build is non-deterministic for seed %d (%d vs %d nodes)." % [SEED_A, count_a, count_b])
	if gates_a.size() != 4:
		failures.append("Liner expected 4 gate positions, got %d." % gates_a.size())
	for gi in range(gates_a.size()):
		var g: Vector3 = gates_a[gi]
		if g.y <= wl + 1.0:
			failures.append("Liner gate %d is not up on a deck (y=%.2f)." % [gi, g.y])
		if gi < gates_b.size() and g != gates_b[gi]:
			failures.append("Liner gate %d differs across identical-seed builds." % gi)

	root_a.free()
	root_b.free()


func _count_descendants(node: Node) -> int:
	var total: int = 0
	for child in node.get_children():
		total += 1 + _count_descendants(child)
	return total


func _run_save_migration_checks(failures: Array[String]) -> void:
	var legacy_save := {
		"worlds": {
			"world_a": {
				"name": "Legacy World",
				"root_map": "map_root",
				"current_map": "map_root",
				"maps": {
					"map_root": {
						"seed": 1234,
						"type": "normal",
						"gates": {},
						"discoveries": {},
					}
				}
			}
		},
		"last_world_id": "world_a",
		"achievements": {"first_wonder": 1},
		"maps_visited": ["map_root"],
		"lichen_count": 7,
		"cycle_speed_multiplier": 1.5,
		"start_fullscreen": false,
		"graphics_level": 2,
		"density_level": 1,
	}
	var migrated_legacy: Dictionary = SaveManager.normalize_save_data(legacy_save)
	var legacy_universe: Dictionary = SaveManager.current_universe(migrated_legacy)
	if int(migrated_legacy.get("version", 0)) != SaveManager.SAVE_VERSION:
		failures.append("Legacy migration did not set expected save version.")
	if legacy_universe.is_empty():
		failures.append("Legacy migration did not produce a current universe.")
	else:
		if int(legacy_universe.get("lichen_count", -1)) != 7:
			failures.append("Legacy migration lost lichen count.")
		var settings: Dictionary = legacy_universe.get("settings", {})
		if float(settings.get("cycle_speed_multiplier", -1.0)) != 1.5:
			failures.append("Legacy migration lost cycle speed setting.")
		if bool(settings.get("start_fullscreen", true)) != false:
			failures.append("Legacy migration lost fullscreen setting.")

	var v2_multi := {
		"version": 2,
		"current_universe_id": "u_a",
		"universes": {
			"u_a": {
				"name": "Universe A",
				"worlds": {
					"w_a": {
						"name": "World A",
						"maps": {"m_a": {"seed": 10}},
					}
				},
				"last_world_id": "w_a",
			},
			"u_b": {
				"name": "Universe B",
				"worlds": {
					"w_b": {
						"name": "World B",
						"maps": {"m_b": {"seed": 20}},
					}
				},
				"last_world_id": "w_b",
			},
		},
	}
	var migrated_multi: Dictionary = SaveManager.normalize_save_data(v2_multi)
	var universes: Dictionary = migrated_multi.get("universes", {})
	if universes.size() != 2:
		failures.append("Multi-universe migration changed universe count.")
	var ua: Dictionary = universes.get("u_a", {})
	var ub: Dictionary = universes.get("u_b", {})
	if ua.is_empty() or ub.is_empty():
		failures.append("Multi-universe migration lost one universe record.")
	else:
		var ua_worlds: Dictionary = ua.get("worlds", {})
		var ub_worlds: Dictionary = ub.get("worlds", {})
		if not ua_worlds.has("w_a") or ub_worlds.has("w_a"):
			failures.append("Multi-universe migration mixed world ownership between universes.")
		if not ub_worlds.has("w_b") or ua_worlds.has("w_b"):
			failures.append("Multi-universe migration mixed world ownership between universes.")
		var wa_map: Dictionary = ua_worlds.get("w_a", {}).get("maps", {}).get("m_a", {})
		var wb_map: Dictionary = ub_worlds.get("w_b", {}).get("maps", {}).get("m_b", {})
		var required_map_fields: Array[String] = ["seed", "type", "gates", "discoveries", "available_discoveries", "wonder_count"]
		for field_name in required_map_fields:
			if not wa_map.has(field_name):
				failures.append("Universe A map migration missing field '%s'." % field_name)
			if not wb_map.has(field_name):
				failures.append("Universe B map migration missing field '%s'." % field_name)
		if str(wa_map.get("type", "")) != WorldGraph.MAP_NORMAL:
			failures.append("Universe A map type migration unexpected value.")
		if str(wb_map.get("type", "")) != WorldGraph.MAP_NORMAL:
			failures.append("Universe B map type migration unexpected value.")

	var stale_id_save := {
		"version": SaveManager.SAVE_VERSION,
		"current_universe_id": "missing_universe",
		"universes": {
			"u_live": SaveManager.create_universe_record("Universe Live"),
		},
	}
	var normalized_stale: Dictionary = SaveManager.normalize_save_data(stale_id_save)
	var resolved_id: String = SaveManager.current_universe_id(normalized_stale)
	if resolved_id == "" or not normalized_stale.get("universes", {}).has(resolved_id):
		failures.append("Stale current universe id was not repaired to a valid universe.")

	var isolation_source := {
		"version": SaveManager.SAVE_VERSION,
		"current_universe_id": "u_a",
		"universes": {
			"u_a": {
				"name": "Universe A",
				"worlds": {"w_a": {"name": "World A", "maps": {"m_a": {"seed": 11, "type": "normal", "gates": {}, "discoveries": {}}}}},
				"last_world_id": "w_a",
				"achievements": {"a_only": 1},
				"maps_visited": ["m_a"],
				"lichen_count": 2,
				"settings": {"cycle_speed_multiplier": 1.0, "start_fullscreen": true, "graphics_level": 0, "density_level": 2},
			},
			"u_b": {
				"name": "Universe B",
				"worlds": {"w_b": {"name": "World B", "maps": {"m_b": {"seed": 22, "type": "normal", "gates": {}, "discoveries": {}}}}},
				"last_world_id": "w_b",
				"achievements": {"b_only": 1},
				"maps_visited": ["m_b"],
				"lichen_count": 5,
				"settings": {"cycle_speed_multiplier": 1.2, "start_fullscreen": false, "graphics_level": 1, "density_level": 1},
			},
		},
	}
	var isolated: Dictionary = SaveManager.normalize_save_data(isolation_source)
	var replace_a := SaveManager.current_universe(isolated).duplicate(true)
	replace_a["lichen_count"] = 99
	replace_a["maps_visited"] = ["m_a", "m_a2"]
	var isolated_updated: Dictionary = SaveManager.set_current_universe(isolated.duplicate(true), replace_a)
	var updated_universes: Dictionary = isolated_updated.get("universes", {})
	var after_a: Dictionary = updated_universes.get("u_a", {})
	var after_b: Dictionary = updated_universes.get("u_b", {})
	if int(after_a.get("lichen_count", -1)) != 99:
		failures.append("Current-universe update did not apply to active universe.")
	if int(after_b.get("lichen_count", -1)) != 5:
		failures.append("Current-universe update leaked into non-active universe.")
	if not after_b.get("achievements", {}).has("b_only"):
		failures.append("Current-universe update removed non-active universe achievements.")
	if after_b.get("maps_visited", []).has("m_a2"):
		failures.append("Current-universe update leaked visited-map state across universes.")


func _run_seed_allocator_isolation_checks(failures: Array[String]) -> void:
	var base: Dictionary = SaveManager.default_save_data()
	var u0: String = SaveManager.current_universe_id(base)
	var u1: String = "u_extra"
	base = SaveManager.set_universe(base, u1, SaveManager.create_universe_record("Universe 2"))

	var a0: Dictionary = SaveManager.allocate_seed_for_current_universe(base, "world_a")
	var save_after_a0: Dictionary = a0.get("save_data", {})
	var seed_a0: int = int(a0.get("seed", -1))
	var universe0_after_a0: Dictionary = save_after_a0.get("universes", {}).get(u0, {})
	var universe1_after_a0: Dictionary = save_after_a0.get("universes", {}).get(u1, {})
	if int(universe0_after_a0.get("seed_counter", -1)) != 1:
		failures.append("Seed allocation did not increment active universe counter.")
	if int(universe1_after_a0.get("seed_counter", -1)) != 0:
		failures.append("Seed allocation leaked counter update to non-active universe.")

	var switched: Dictionary = SaveManager.set_current_universe_id(save_after_a0, u1)
	var b0: Dictionary = SaveManager.allocate_seed_for_current_universe(switched, "world_b")
	var save_after_b0: Dictionary = b0.get("save_data", {})
	var seed_b0: int = int(b0.get("seed", -1))
	var universe0_after_b0: Dictionary = save_after_b0.get("universes", {}).get(u0, {})
	var universe1_after_b0: Dictionary = save_after_b0.get("universes", {}).get(u1, {})
	if int(universe0_after_b0.get("seed_counter", -1)) != 1:
		failures.append("Switching universes unexpectedly modified prior universe seed counter.")
	if int(universe1_after_b0.get("seed_counter", -1)) != 1:
		failures.append("Seed allocation did not increment switched-to universe counter.")
	if seed_a0 == seed_b0:
		failures.append("Distinct universes produced identical first allocated seed.")


func _build_map_signature(seed_value: int, map_type: String) -> Dictionary:
	var generated_root := Node3D.new()
	generated_root.name = "ValidationGeneratedRoot"

	var generator := MapGenerator.new({
		"world_seed": seed_value,
		"graphics_level": GRAPHICS_LEVEL,
		"density_level": DENSITY_LEVEL,
		"map_type": map_type,
	})
	generator.generate(generated_root)

	var lines: PackedStringArray = PackedStringArray()
	var structure_lines: PackedStringArray = PackedStringArray()
	var core_lines: PackedStringArray = PackedStringArray()
	_collect_signature(generated_root, 0, lines)
	_collect_structure_signature(generated_root, structure_lines)
	_collect_core_signature(generated_root, core_lines)
	lines.sort()
	structure_lines.sort()
	core_lines.sort()
	var signature: String = "\n".join(lines)
	var structure_signature: String = "\n".join(structure_lines)
	var core_signature: String = "\n".join(core_lines)
	var node_count: int = lines.size()

	generated_root.free()
	return {
		"signature": signature,
		"structure_signature": structure_signature,
		"core_signature": core_signature,
		"node_count": node_count,
	}


func _run_gate_travel_checks(failures: Array[String]) -> void:
	var base_world := {
		"name": "Travel Test World",
		"maps": {
			"m0": {
				"seed": 101,
				"type": WorldGraph.MAP_NORMAL,
				"gates": {},
				"discoveries": {},
				"available_discoveries": 0,
				"wonder_count": 0,
			},
		},
		"root_map": "m0",
		"current_map": "m0",
	}
	_validation_id_counter = 0
	var first: Dictionary = GateTravelService.resolve_gate_transition(
		SEED_A,
		"m0",
		0,
		base_world.duplicate(true),
		Callable(self, "_validation_new_map_id"),
		0.0,
		0.0,
		0.0
	)
	_validation_id_counter = 0
	var second: Dictionary = GateTravelService.resolve_gate_transition(
		SEED_A,
		"m0",
		0,
		base_world.duplicate(true),
		Callable(self, "_validation_new_map_id"),
		0.0,
		0.0,
		0.0
	)
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		failures.append("Gate travel deterministic check failed to resolve gate transition.")
		return
	if bool(first.get("inert", false)) or bool(second.get("inert", false)):
		failures.append("Gate travel deterministic check unexpectedly produced inert gate.")
		return
	if str(first.get("target_map_id", "")) != str(second.get("target_map_id", "")):
		failures.append("Gate travel target map id is non-deterministic for fixed seed/input.")
	var first_world: Dictionary = first.get("world", {})
	var second_world: Dictionary = second.get("world", {})
	var first_maps: Dictionary = first_world.get("maps", {})
	var second_maps: Dictionary = second_world.get("maps", {})
	var first_target: Dictionary = first_maps.get(str(first.get("target_map_id", "")), {})
	var second_target: Dictionary = second_maps.get(str(second.get("target_map_id", "")), {})
	if int(first_target.get("seed", -1)) != int(second_target.get("seed", -1)):
		failures.append("Gate travel produced non-deterministic target seed.")
	if str(first_target.get("type", "")) != str(second_target.get("type", "")):
		failures.append("Gate travel produced non-deterministic target map type.")


func _validation_new_map_id(prefix: String) -> String:
	var id: String = "%s_det_%d" % [prefix, _validation_id_counter]
	_validation_id_counter += 1
	return id


func _run_gate_room_and_nexus_checks(failures: Array[String]) -> void:
	var worlds := {
		"w0": {
			"name": "Source World",
			"root_map": "src_map",
			"maps": {
				"src_map": {
					"seed": 500,
					"type": WorldGraph.MAP_GATE_ROOM,
					"gate_room_slots": {},
					"gates": {},
					"discoveries": {},
				},
			},
		},
	}
	var source_map: Dictionary = worlds["w0"]["maps"]["src_map"]
	var gate_room_result: Dictionary = GateTravelService.resolve_gate_room_slot(
		SEED_A,
		"w0",
		"src_map",
		1,
		worlds.duplicate(true),
		source_map.duplicate(true),
		Callable(self, "_validation_new_map_id"),
		Callable(self, "_validation_create_world_record_dict")
	)
	if not bool(gate_room_result.get("ok", false)):
		failures.append("Gate room slot resolution failed.")
		return
	if not bool(gate_room_result.get("changed", false)):
		failures.append("Gate room slot did not create/link a new world on empty slot.")
		return
	var room_target_world: String = str(gate_room_result.get("target_world_id", ""))
	var room_target_map: String = str(gate_room_result.get("target_map_id", ""))
	var updated_worlds: Dictionary = gate_room_result.get("worlds", {})
	if room_target_world == "" or room_target_map == "" or not updated_worlds.has(room_target_world):
		failures.append("Gate room slot resolution produced invalid world/map target.")
		return
	var created_world: Dictionary = updated_worlds.get(room_target_world, {})
	if str(created_world.get("gate_room_source_world", "")) != "w0":
		failures.append("Gate room slot resolution lost source world linkage.")
	if str(created_world.get("gate_room_source_map", "")) != "src_map":
		failures.append("Gate room slot resolution lost source map linkage.")

	var nexus_map := {
		"seed": 777,
		"type": WorldGraph.MAP_NEXUS,
		"nexus_slots": {},
		"gates": {},
		"discoveries": {},
	}
	var universe_worlds := {
		"w0": {"name": "Current", "root_map": "m0", "maps": {"m0": {"seed": 1, "type": WorldGraph.MAP_NORMAL}}},
		"w1": {"name": "Elsewhere", "root_map": "m1", "maps": {"m1": {"seed": 2, "type": WorldGraph.MAP_NORMAL}}},
	}
	var nexus_result: Dictionary = GateTravelService.resolve_nexus_slot(
		SEED_A,
		"w0",
		"nexus_map",
		0,
		nexus_map.duplicate(true),
		universe_worlds
	)
	if not bool(nexus_result.get("ok", false)):
		failures.append("Nexus slot resolution failed.")
		return
	if bool(nexus_result.get("skip", false)):
		failures.append("Nexus slot 0 unexpectedly skipped despite alternate world availability.")
		return
	var nexus_target_world: String = str(nexus_result.get("target_world_id", ""))
	if nexus_target_world == "" or nexus_target_world == "w0":
		failures.append("Nexus slot resolution did not select a non-current world.")

	var return_record := {
		"gate_room_return_world": "w_back",
		"gate_room_return_map": "m_back",
	}
	var return_result: Dictionary = GateTravelService.resolve_gate_room_return(return_record)
	if not bool(return_result.get("ok", false)) or not bool(return_result.get("has_return", false)):
		failures.append("Gate room return resolution did not produce expected return target.")
	if str(return_result.get("target_world_id", "")) != "w_back" or str(return_result.get("target_map_id", "")) != "m_back":
		failures.append("Gate room return resolution produced incorrect target linkage.")


func _validation_create_world_record_dict(world_name: String, root_map_id: String, map_seed: int) -> Dictionary:
	return WorldGraph.create_world_record(world_name, root_map_id, map_seed).to_dict()


func _run_persisted_universe_isolation_checks(failures: Array[String]) -> void:
	var save_data := {
		"version": SaveManager.SAVE_VERSION,
		"current_universe_id": "u_a",
		"universes": {
			"u_a": {
				"name": "Universe A",
				"worlds": {
					"w_a0": {
						"name": "World A0",
						"root_map": "m_gate",
						"current_map": "m_gate",
						"maps": {
							"m_gate": {
								"seed": 3001,
								"type": WorldGraph.MAP_GATE_ROOM,
								"gate_room_slots": {},
								"gates": {},
								"discoveries": {},
							},
						},
					},
				},
				"last_world_id": "w_a0",
				"achievements": {},
				"maps_visited": [],
				"lichen_count": 0,
				"settings": {"cycle_speed_multiplier": 1.0, "start_fullscreen": true, "graphics_level": 0, "density_level": 2},
			},
			"u_b": {
				"name": "Universe B",
				"worlds": {
					"w_b0": {
						"name": "World B0",
						"root_map": "m_b0",
						"current_map": "m_b0",
						"maps": {
							"m_b0": {"seed": 7001, "type": WorldGraph.MAP_NORMAL, "gates": {}, "discoveries": {}},
						},
					},
				},
				"last_world_id": "w_b0",
				"achievements": {"b_only": 1},
				"maps_visited": ["m_b0"],
				"lichen_count": 4,
				"settings": {"cycle_speed_multiplier": 1.2, "start_fullscreen": false, "graphics_level": 1, "density_level": 1},
			},
		},
	}
	save_data = SaveManager.normalize_save_data(save_data)
	var current_universe: Dictionary = SaveManager.current_universe(save_data)
	var worlds_a: Dictionary = current_universe.get("worlds", {})
	var world_a0: Dictionary = worlds_a.get("w_a0", {})
	var map_a_gate: Dictionary = world_a0.get("maps", {}).get("m_gate", {})
	_validation_id_counter = 0
	var travel_result: Dictionary = GateTravelService.resolve_gate_room_slot(
		SEED_A,
		"w_a0",
		"m_gate",
		2,
		worlds_a.duplicate(true),
		map_a_gate.duplicate(true),
		Callable(self, "_validation_new_map_id"),
		Callable(self, "_validation_create_world_record_dict")
	)
	if not bool(travel_result.get("ok", false)) or not bool(travel_result.get("changed", false)):
		failures.append("Persisted isolation check: gate-room slot did not resolve expected new world.")
		return
	var updated_worlds_a: Dictionary = travel_result.get("worlds", worlds_a)
	var updated_map_a: Dictionary = travel_result.get("current_map_record", map_a_gate)
	world_a0["maps"]["m_gate"] = updated_map_a
	updated_worlds_a["w_a0"] = world_a0
	current_universe["worlds"] = updated_worlds_a
	var after_update: Dictionary = SaveManager.set_current_universe(save_data.duplicate(true), current_universe)
	var universes_after: Dictionary = after_update.get("universes", {})
	var ua_after: Dictionary = universes_after.get("u_a", {})
	var ub_after: Dictionary = universes_after.get("u_b", {})
	if int(ua_after.get("worlds", {}).size()) <= 1:
		failures.append("Persisted isolation check: current universe did not receive new gate-room world.")
	if int(ub_after.get("worlds", {}).size()) != 1:
		failures.append("Persisted isolation check: non-current universe world count changed.")
	if not ub_after.get("achievements", {}).has("b_only"):
		failures.append("Persisted isolation check: non-current universe achievements changed.")
	if int(ub_after.get("lichen_count", -1)) != 4:
		failures.append("Persisted isolation check: non-current universe lichen count changed.")

	var nexus_worlds_a := {
		"w_a0": {
			"name": "World A0",
			"root_map": "m_nexus",
			"current_map": "m_nexus",
			"maps": {
				"m_nexus": {
					"seed": 3111,
					"type": WorldGraph.MAP_NEXUS,
					"nexus_slots": {},
					"gates": {},
					"discoveries": {},
				},
			},
		},
		"w_a1": {
			"name": "World A1",
			"root_map": "m_a1",
			"current_map": "m_a1",
			"maps": {
				"m_a1": {"seed": 3222, "type": WorldGraph.MAP_NORMAL, "gates": {}, "discoveries": {}},
			},
		},
	}
	var save_data_nexus := {
		"version": SaveManager.SAVE_VERSION,
		"current_universe_id": "u_a",
		"universes": {
			"u_a": {
				"name": "Universe A",
				"worlds": nexus_worlds_a,
				"last_world_id": "w_a0",
				"achievements": {},
				"maps_visited": [],
				"lichen_count": 0,
				"settings": {"cycle_speed_multiplier": 1.0, "start_fullscreen": true, "graphics_level": 0, "density_level": 2},
			},
			"u_b": {
				"name": "Universe B",
				"worlds": {
					"w_b0": {
						"name": "World B0",
						"root_map": "m_b0",
						"current_map": "m_b0",
						"maps": {"m_b0": {"seed": 7001, "type": WorldGraph.MAP_NORMAL, "gates": {}, "discoveries": {}}},
					},
				},
				"last_world_id": "w_b0",
				"achievements": {"b_only": 1},
				"maps_visited": ["m_b0"],
				"lichen_count": 4,
				"settings": {"cycle_speed_multiplier": 1.2, "start_fullscreen": false, "graphics_level": 1, "density_level": 1},
			},
		},
	}
	save_data_nexus = SaveManager.normalize_save_data(save_data_nexus)
	var current_universe_nexus: Dictionary = SaveManager.current_universe(save_data_nexus)
	var worlds_nexus: Dictionary = current_universe_nexus.get("worlds", {})
	var world_nexus: Dictionary = worlds_nexus.get("w_a0", {})
	var map_nexus: Dictionary = world_nexus.get("maps", {}).get("m_nexus", {})
	var nexus_result_persisted: Dictionary = GateTravelService.resolve_nexus_slot(
		SEED_A,
		"w_a0",
		"m_nexus",
		0,
		map_nexus.duplicate(true),
		worlds_nexus
	)
	if not bool(nexus_result_persisted.get("ok", false)) or bool(nexus_result_persisted.get("skip", false)):
		failures.append("Persisted isolation check: nexus slot did not resolve as expected.")
		return
	var updated_nexus_map: Dictionary = nexus_result_persisted.get("current_map_record", map_nexus)
	world_nexus["maps"]["m_nexus"] = updated_nexus_map
	worlds_nexus["w_a0"] = world_nexus
	current_universe_nexus["worlds"] = worlds_nexus
	var after_nexus_update: Dictionary = SaveManager.set_current_universe(save_data_nexus.duplicate(true), current_universe_nexus)
	var universes_after_nexus: Dictionary = after_nexus_update.get("universes", {})
	var ub_after_nexus: Dictionary = universes_after_nexus.get("u_b", {})
	if int(ub_after_nexus.get("worlds", {}).size()) != 1:
		failures.append("Persisted isolation check: nexus update changed non-current universe world count.")
	if not ub_after_nexus.get("achievements", {}).has("b_only"):
		failures.append("Persisted isolation check: nexus update changed non-current universe achievements.")
	if int(ub_after_nexus.get("lichen_count", -1)) != 4:
		failures.append("Persisted isolation check: nexus update changed non-current universe lichen count.")


func _run_tree_factory_checks(failures: Array[String]) -> void:
	var norm_err: String = TreeFactory.verify_normalization()
	if norm_err != "":
		failures.append("TreeFactory normalization: " + norm_err)
	var stats_a: Dictionary = _build_tree_stats(SEED_A)
	var stats_b: Dictionary = _build_tree_stats(SEED_A)
	if int(stats_a.get("instances", 0)) <= 0:
		failures.append("TreeFactory produced no MultiMesh instances.")
		return
	if int(stats_a.get("multimesh_nodes", 0)) <= 0:
		failures.append("TreeFactory produced no MultiMeshInstance3D nodes.")
	if int(stats_a.get("instances", 0)) != int(stats_b.get("instances", 0)):
		failures.append("TreeFactory instance count is non-deterministic (%d vs %d)." % [int(stats_a.get("instances", 0)), int(stats_b.get("instances", 0))])
	if str(stats_a.get("sig", "")) != str(stats_b.get("sig", "")):
		failures.append("TreeFactory instance transforms are non-deterministic.")
	if int(stats_a.get("colliders", 0)) <= 0:
		failures.append("TreeFactory produced no trunk colliders.")


func _build_tree_stats(seed_value: int) -> Dictionary:
	var context := MapContext.new({
		"world_seed": seed_value,
		"map_type": WorldGraph.MAP_NORMAL,
	})
	var root := Node3D.new()
	root.name = "TreeValidationRoot"
	TreeFactory.scatter_trees(root, seed_value, DENSITY_LEVEL, GRAPHICS_LEVEL, context)
	var stats := {
		"multimesh_nodes": 0,
		"instances": 0,
		"colliders": 0,
	}
	var sig := PackedStringArray()
	_collect_tree_stats(root, stats, sig)
	stats["sig"] = "|".join(sig).md5_text()
	root.free()
	return stats


func _collect_tree_stats(node: Node, stats: Dictionary, sig: PackedStringArray) -> void:
	if node is MultiMeshInstance3D:
		var mmi: MultiMeshInstance3D = node as MultiMeshInstance3D
		if mmi.multimesh != null:
			stats["multimesh_nodes"] = int(stats.get("multimesh_nodes", 0)) + 1
			var instance_count: int = mmi.multimesh.instance_count
			stats["instances"] = int(stats.get("instances", 0)) + instance_count
			for i in range(instance_count):
				sig.append(_vector_key(mmi.multimesh.get_instance_transform(i).origin))
	if node is CollisionShape3D:
		stats["colliders"] = int(stats.get("colliders", 0)) + 1
	for child in node.get_children():
		_collect_tree_stats(child, stats, sig)


func _assert_stat_delta_within(failures: Array[String], label: String, a: Dictionary, b: Dictionary, key: String, tolerance: int) -> void:
	var av: int = int(a.get(key, 0))
	var bv: int = int(b.get(key, 0))
	if abs(av - bv) > tolerance:
		failures.append("%s drift exceeded tolerance (%d vs %d, tol=%d)." % [label, av, bv, tolerance])


func _collect_signature(node: Node, depth: int, out: PackedStringArray) -> void:
	var line: String = node.get_class()
	if node is Node3D:
		var node3d := node as Node3D
		line += "|p=" + _vector_key(node3d.position)
		line += "|r=" + _vector_key(node3d.rotation_degrees)
		line += "|s=" + _vector_key(node3d.scale)
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			line += "|mesh=" + mesh_instance.mesh.get_class()
	out.append(line)

	for child in node.get_children():
		_collect_signature(child, depth + 1, out)


func _collect_structure_signature(node: Node, out: PackedStringArray) -> void:
	var token: String = node.get_class()
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			token += "|mesh=" + mesh_instance.mesh.get_class()
	out.append(token)
	for child in node.get_children():
		_collect_structure_signature(child, out)


func _collect_core_signature(node: Node, out: PackedStringArray) -> void:
	var include_names := {
		"GeneratedTerrain": true,
		"TerrainCollision": true,
		"WorldEdgeBarriers": true,
		"DungeonWalls": true,
		"DungeonWallCollision": true,
		"DungeonFloor": true,
		"DungeonCeiling": true,
		"MoonSkyDetails": true,
		"DistantBlueWorld": true,
		"PlanetSurface": true,
		"MoonHorizonGlow": true,
		"GateRoomDisk": true,
		"GateRoomCenter": true,
		"NexusFloor": true,
		"NexusPillar": true,
	}
	if include_names.has(node.name):
		var token := "%s|%s" % [node.get_class(), node.name]
		if node is Node3D:
			var node3d := node as Node3D
			token += "|p=" + _vector_key(node3d.position)
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				token += "|mesh=" + mesh_instance.mesh.get_class()
		out.append(token)
	for child in node.get_children():
		_collect_core_signature(child, out)


func _vector_key(v: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [v.x, v.y, v.z]


func _signature_diff_summary(a: String, b: String) -> String:
	var a_counts: Dictionary = {}
	var b_counts: Dictionary = {}
	for line in a.split("\n", false):
		a_counts[line] = int(a_counts.get(line, 0)) + 1
	for line in b.split("\n", false):
		b_counts[line] = int(b_counts.get(line, 0)) + 1

	var only_a: Array[String] = []
	var only_b: Array[String] = []
	for key in a_counts.keys():
		if int(a_counts[key]) != int(b_counts.get(key, 0)):
			only_a.append(str(key))
	for key in b_counts.keys():
		if int(b_counts[key]) != int(a_counts.get(key, 0)):
			only_b.append(str(key))

	var sample_a: String = only_a[0] if not only_a.is_empty() else "<none>"
	var sample_b: String = only_b[0] if not only_b.is_empty() else "<none>"
	return "delta_a=%d delta_b=%d sample_a=%s sample_b=%s" % [only_a.size(), only_b.size(), sample_a, sample_b]


func _run_rock_multimesh_checks(failures: Array[String]) -> void:
	# Rocks render via a single MultiMesh (one draw call) with a matching StaticBody of
	# sphere colliders. Verify structure + that the seed still produces an identical,
	# deterministic layout after the MultiMesh conversion.
	var ctx: MapContext = MapContext.new({"world_seed": 5151, "map_type": WorldGraph.MAP_NORMAL})
	RockFactory.clear_cache()
	var root_a: Node3D = Node3D.new()
	RockFactory.scatter_rocks(root_a, 5151, DENSITY_LEVEL, ctx)
	var mmi_a: MultiMeshInstance3D = root_a.get_node_or_null("Rocks/RockMesh") as MultiMeshInstance3D
	if mmi_a == null or mmi_a.multimesh == null:
		failures.append("RockFactory did not produce a Rocks/RockMesh MultiMeshInstance3D.")
		root_a.free()
		return
	var count_a: int = mmi_a.multimesh.instance_count
	if count_a <= 0:
		failures.append("RockFactory MultiMesh produced no instances.")
	var body_a: Node = root_a.get_node_or_null("Rocks/RockColliders")
	if body_a == null or body_a.get_child_count() != count_a:
		failures.append("RockFactory collider count does not match rock instance count.")

	var root_b: Node3D = Node3D.new()
	RockFactory.scatter_rocks(root_b, 5151, DENSITY_LEVEL, ctx)
	var mmi_b: MultiMeshInstance3D = root_b.get_node_or_null("Rocks/RockMesh") as MultiMeshInstance3D
	if mmi_b != null and mmi_b.multimesh != null:
		if mmi_b.multimesh.instance_count != count_a:
			failures.append("RockFactory instance count is non-deterministic.")
		else:
			for i in range(count_a):
				if not mmi_a.multimesh.get_instance_transform(i).is_equal_approx(mmi_b.multimesh.get_instance_transform(i)):
					failures.append("RockFactory instance transform %d is non-deterministic." % i)
					break
	root_a.free()
	root_b.free()


func _run_crystal_multimesh_checks(failures: Array[String]) -> void:
	var ctx: MapContext = MapContext.new({"world_seed": 7777, "map_type": WorldGraph.MAP_NORMAL})
	CrystalFactory.clear_cache()
	var root_a: Node3D = Node3D.new()
	CrystalFactory.scatter_crystals(root_a, 7777, DENSITY_LEVEL, ctx)
	var mmi_a: MultiMeshInstance3D = root_a.get_node_or_null("Crystals/CrystalMesh") as MultiMeshInstance3D
	if mmi_a == null or mmi_a.multimesh == null:
		failures.append("CrystalFactory did not produce a Crystals/CrystalMesh MultiMeshInstance3D.")
		root_a.free()
		return
	var count_a: int = mmi_a.multimesh.instance_count
	if count_a <= 0:
		failures.append("CrystalFactory MultiMesh produced no instances.")
	var body_a: Node = root_a.get_node_or_null("Crystals/CrystalColliders")
	if body_a == null or body_a.get_child_count() != count_a:
		failures.append("CrystalFactory collider count does not match crystal instance count.")

	var root_b: Node3D = Node3D.new()
	CrystalFactory.scatter_crystals(root_b, 7777, DENSITY_LEVEL, ctx)
	var mmi_b: MultiMeshInstance3D = root_b.get_node_or_null("Crystals/CrystalMesh") as MultiMeshInstance3D
	if mmi_b != null and mmi_b.multimesh != null and mmi_b.multimesh.instance_count == count_a:
		for i in range(count_a):
			if not mmi_a.multimesh.get_instance_transform(i).is_equal_approx(mmi_b.multimesh.get_instance_transform(i)):
				failures.append("CrystalFactory instance transform %d is non-deterministic." % i)
				break
	else:
		failures.append("CrystalFactory instance count is non-deterministic.")
	root_a.free()
	root_b.free()


func _run_flower_multimesh_checks(failures: Array[String]) -> void:
	# Flowers render as two MultiMeshes (stems + blossoms, one blossom per stem).
	var ctx: MapContext = MapContext.new({"world_seed": 6262, "map_type": WorldGraph.MAP_NORMAL})
	FlowerFactory.clear_cache()
	var root_a: Node3D = Node3D.new()
	FlowerFactory.scatter_flowers(root_a, 6262, DENSITY_LEVEL, ctx)
	var stems_a: MultiMeshInstance3D = root_a.get_node_or_null("Flowers/FlowerStems") as MultiMeshInstance3D
	var blossoms_a: MultiMeshInstance3D = root_a.get_node_or_null("Flowers/FlowerBlossoms") as MultiMeshInstance3D
	if stems_a == null or stems_a.multimesh == null or blossoms_a == null or blossoms_a.multimesh == null:
		failures.append("FlowerFactory did not produce FlowerStems/FlowerBlossoms MultiMeshInstance3D.")
		root_a.free()
		return
	var stem_count: int = stems_a.multimesh.instance_count
	if stem_count <= 0:
		failures.append("FlowerFactory produced no stem instances.")
	if stem_count != blossoms_a.multimesh.instance_count:
		failures.append("FlowerFactory stem/blossom counts differ (%d vs %d)." % [stem_count, blossoms_a.multimesh.instance_count])

	var root_b: Node3D = Node3D.new()
	FlowerFactory.scatter_flowers(root_b, 6262, DENSITY_LEVEL, ctx)
	var stems_b: MultiMeshInstance3D = root_b.get_node_or_null("Flowers/FlowerStems") as MultiMeshInstance3D
	if stems_b != null and stems_b.multimesh != null and stems_b.multimesh.instance_count == stem_count:
		for i in range(stem_count):
			if not stems_a.multimesh.get_instance_transform(i).is_equal_approx(stems_b.multimesh.get_instance_transform(i)):
				failures.append("FlowerFactory stem transform %d is non-deterministic." % i)
				break
	else:
		failures.append("FlowerFactory stem count is non-deterministic.")
	root_a.free()
	root_b.free()


func _run_gate_sight_preview_checks(failures: Array[String]) -> void:
	# Gate Sight's predict_gate_target_type() must equal the type that
	# resolve_gate_transition() actually creates, using the same route chances Main
	# passes (water=0.12, arctic=0.10, floating=0.18, cave=0.06). Depends on the
	# StableRng determinism fix; would have failed ~60% before it.
	var mismatches: int = 0
	for seed_value in range(0, 48):
		for gate_index in range(4):
			var base_world := {
				"maps": {"m0": {"seed": seed_value, "type": WorldGraph.MAP_NORMAL, "gates": {}, "discoveries": {}}},
				"root_map": "m0",
			}
			var predicted: String = GateTravelService.predict_gate_target_type(
				seed_value, "m0", gate_index, base_world.duplicate(true), 0.12, 0.10, 0.18, 0.06)
			_validation_id_counter = 0
			var result: Dictionary = GateTravelService.resolve_gate_transition(
				seed_value, "m0", gate_index, base_world.duplicate(true),
				Callable(self, "_validation_new_map_id"), 0.12, 0.10, 0.18, 0.06)
			var maps: Dictionary = result.get("world", {}).get("maps", {})
			var tid: String = str(result.get("target_map_id", ""))
			var actual: String = str(maps[tid].get("type", "?")) if maps.has(tid) else "inert"
			if predicted != actual:
				mismatches += 1
	if mismatches > 0:
		failures.append("Gate Sight preview disagreed with resolve on %d/192 gate routes." % mismatches)


func _run_stable_rng_checks(failures: Array[String]) -> void:
	# Guards the bug class where an unqualified randf() inside StableRng binds to the
	# global (per-process, non-deterministic) RNG instead of self.randf(), silently
	# breaking seed reproducibility for randf_range() and chance(). Two instances with
	# the same seed must produce identical sequences.
	var a := StableRng.new(424242)
	var b := StableRng.new(424242)
	for i in range(32):
		if not is_equal_approx(a.randf_range(-5.0, 5.0), b.randf_range(-5.0, 5.0)):
			failures.append("StableRng.randf_range is non-deterministic for a fixed seed.")
			break
	var c := StableRng.new(424242)
	var d := StableRng.new(424242)
	for i in range(64):
		if c.chance(0.5) != d.chance(0.5):
			failures.append("StableRng.chance is non-deterministic for a fixed seed.")
			break
	# And the draws must actually advance (not return a constant).
	var e := StableRng.new(7)
	if is_equal_approx(e.randf_range(0.0, 1.0), e.randf_range(0.0, 1.0)):
		failures.append("StableRng.randf_range returned identical consecutive draws.")


func _run_water_cache_terrain_checks(failures: Array[String]) -> void:
	# Sunken caches (Main._scatter_sunken_caches) only place where the seabed is at
	# least 4m below the surface. Guard the assumption that water maps actually have
	# enough deep seabed, so caches don't silently vanish if terrain is retuned.
	var ctx: MapContext = MapContext.new({"world_seed": 4242, "map_type": WorldGraph.MAP_WATER})
	var half: float = ctx.world_half_size() * 0.86
	var water_level: float = ctx.water_level
	var deep: int = 0
	var samples: int = 0
	var step: float = (half * 2.0) / 24.0
	var gx: float = -half
	while gx <= half:
		var gz: float = -half
		while gz <= half:
			samples += 1
			if water_level - ctx.height_at_world(gx, gz) >= 4.0:
				deep += 1
			gz += step
		gx += step
	if deep < 30:
		failures.append("Water map has too few deep-seabed points for sunken caches (%d/%d sampled)." % [deep, samples])


func _run_progression_checks(failures: Array[String]) -> void:
	# Base kit at zero discoveries mirrors Player constants.
	var base: Dictionary = ProgressionService.capabilities(0)
	if not is_equal_approx(float(base.get("max_breath", 0.0)), 60.0):
		failures.append("Progression base max_breath expected 60, got %s." % str(base.get("max_breath")))
	if int(base.get("pin_cap", 0)) != 6:
		failures.append("Progression base pin_cap expected 6, got %d." % int(base.get("pin_cap", 0)))
	if bool(base.get("gate_sight", true)):
		failures.append("Progression base gate_sight should be false.")
	if not is_equal_approx(float(base.get("max_warmth", 0.0)), 50.0):
		failures.append("Progression base max_warmth expected 50, got %s." % str(base.get("max_warmth")))
	if ProgressionService.kit_summary(0) != "":
		failures.append("Progression kit summary should be empty before the first unlock.")

	# Each defined upgrade's effect must be present in capabilities exactly at its threshold.
	for def in ProgressionService.UPGRADE_DEFS:
		var threshold: int = int(def.get("threshold", 0))
		var caps_at: Dictionary = ProgressionService.capabilities(threshold)
		var effect: Dictionary = def.get("effect", {})
		for key in effect.keys():
			if str(caps_at.get(key)) != str(effect[key]):
				failures.append("Upgrade '%s' effect %s not applied at threshold %d (got %s)." % [
					str(def.get("id")), key, threshold, str(caps_at.get(key))])
		# Just below the threshold the upgrade must not yet be unlocked.
		if threshold > 0 and ProgressionService.unlocked_ids(threshold - 1).has(str(def.get("id"))):
			failures.append("Upgrade '%s' unlocked one discovery early." % str(def.get("id")))

	# Capability ceilings are monotonic in the discovery count (never regress).
	var prev: Dictionary = ProgressionService.capabilities(0)
	for total in range(1, 170):
		var caps: Dictionary = ProgressionService.capabilities(total)
		for key in ["max_breath", "max_sprint_stamina", "max_flashlight_charge", "pin_cap", "survey_radius", "max_warmth"]:
			if float(caps.get(key, 0.0)) < float(prev.get(key, 0.0)):
				failures.append("Progression capability '%s' regressed at total %d." % [key, total])
				break
		# Warmth drain should only ever improve (decrease) with more upgrades.
		if float(caps.get("warmth_drain_per_sec", 9.0)) > float(prev.get("warmth_drain_per_sec", 9.0)):
			failures.append("Progression warmth_drain_per_sec got worse at total %d." % total)
		prev = caps

	# next_upgrade points at the first unearned tier, then empties out.
	if str(ProgressionService.next_upgrade(0).get("id", "")) != "strider_1":
		failures.append("Progression next_upgrade(0) expected 'strider_1'.")
	if not ProgressionService.next_upgrade(100000).is_empty():
		failures.append("Progression next_upgrade should be empty once everything is unlocked.")

	# newly_unlocked reports tiers crossed by a delta, including multiple at once.
	var n1: Array = ProgressionService.newly_unlocked(2, 3)
	if n1.size() != 1 or str(n1[0].get("id", "")) != "strider_1":
		failures.append("Progression newly_unlocked(2,3) expected exactly strider_1.")
	var n2_ids: Array = []
	for d in ProgressionService.newly_unlocked(5, 10):
		n2_ids.append(str(d.get("id", "")))
	if not (n2_ids.has("lungs_1") and n2_ids.has("lantern_1")):
		failures.append("Progression newly_unlocked(5,10) should include lungs_1 and lantern_1.")

	# The ProgressionService capability keys must match what Player.apply_capabilities consumes.
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	if player_scene == null:
		failures.append("Progression check could not load player scene.")
		return
	var player: Node = player_scene.instantiate()
	var full_caps: Dictionary = ProgressionService.capabilities(200)
	player.apply_capabilities(full_caps)
	if not is_equal_approx(float(player.get("max_breath")), float(full_caps["max_breath"])):
		failures.append("Player.apply_capabilities did not adopt max_breath ceiling.")
	if not is_equal_approx(float(player.get("max_flashlight_charge")), float(full_caps["max_flashlight_charge"])):
		failures.append("Player.apply_capabilities did not adopt max_flashlight_charge ceiling.")
	if not is_equal_approx(float(player.get("max_sprint_stamina")), float(full_caps["max_sprint_stamina"])):
		failures.append("Player.apply_capabilities did not adopt max_sprint_stamina ceiling.")
	if not is_equal_approx(float(player.get("max_warmth")), float(full_caps["max_warmth"])):
		failures.append("Player.apply_capabilities did not adopt max_warmth ceiling.")
	if not is_equal_approx(float(player.get("warmth_drain_per_sec")), float(full_caps["warmth_drain_per_sec"])):
		failures.append("Player.apply_capabilities did not adopt warmth_drain_per_sec.")
	# Pools should be topped up to the new ceiling so an earned upgrade is felt immediately.
	if not is_equal_approx(float(player.get("breath")), float(full_caps["max_breath"])):
		failures.append("Player.apply_capabilities did not top up breath to the new ceiling.")
	if not is_equal_approx(float(player.get("warmth")), float(full_caps["max_warmth"])):
		failures.append("Player.apply_capabilities did not top up warmth to the new ceiling.")
	player.free()
