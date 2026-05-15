extends Node3D

const WonderGenerator = preload("res://scripts/WonderGenerator.gd")
const StableRng = preload("res://scripts/core/StableRng.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")
const WorldGraph = preload("res://scripts/core/WorldGraph.gd")
const CollisionFactory = preload("res://scripts/factories/CollisionFactory.gd")
const MapGenerator = preload("res://scripts/core/MapGenerator.gd")
const TreeFactory = preload("res://scripts/factories/TreeFactory.gd")
const RockFactory = preload("res://scripts/factories/RockFactory.gd")
const CrystalFactory = preload("res://scripts/factories/CrystalFactory.gd")
const RuinFactory = preload("res://scripts/factories/RuinFactory.gd")
const FlowerFactory = preload("res://scripts/factories/FlowerFactory.gd")
const CreatureFactory = preload("res://scripts/factories/CreatureFactory.gd")
const UnderwaterPlantFactory = preload("res://scripts/factories/UnderwaterPlantFactory.gd")
const MoonFeatureFactory = preload("res://scripts/factories/MoonFeatureFactory.gd")
const GateFactory = preload("res://scripts/factories/GateFactory.gd")
const MoonGateFactory = preload("res://scripts/factories/MoonGateFactory.gd")
const AudioManager = preload("res://scripts/core/AudioManager.gd")
const DiscoveryTracker = preload("res://scripts/core/DiscoveryTracker.gd")
const HudController = preload("res://scripts/core/HudController.gd")
const AtlasView = preload("res://scripts/core/AtlasView.gd")
const DevMenu = preload("res://scripts/core/DevMenu.gd")
const GateTravelService = preload("res://scripts/core/GateTravelService.gd")
const MapContext = preload("res://scripts/core/MapContext.gd")
const MapRecordClass = preload("res://scripts/core/MapRecord.gd")
const WorldRecordClass = preload("res://scripts/core/WorldRecord.gd")
const DiscoveryRecordClass = preload("res://scripts/core/DiscoveryRecord.gd")


const GRID_SIZE: int = 224
const CELL_SIZE: float = 2.0

# Larger worlds need broader terrain forms so the space does not feel flat.
const HEIGHT_SCALE: float = 15.0
const WATER_LEVEL: float = -1.7

const GATE_COUNT: int = 4
const WONDER_CELL_SIZE: float = 96.0
const WONDER_CHANCE: float = 0.20
const MOON_SHRINE_COUNT: int = 9
const WATER_ROUTE_CHANCE: float = 0.12


const SLOT_INDEX_PATH: String = "user://save_index.json"

var noise: FastNoiseLite = FastNoiseLite.new()
var world_seed: int = 12345
var map_context: MapContext
var generated_root: Node3D
var menu_layer: CanvasLayer
var hud_controller: HudController
var atlas_view: AtlasView
var dev_menu: DevMenu
var show_hud: bool = true
var world_environment: Environment
var sun_light: DirectionalLight3D
var world_environment_node: WorldEnvironment
var _player_ref: CharacterBody3D
var save_data: Dictionary = {}
var current_world_id: String = ""
var current_map_id: String = ""
var current_universe_id: String = ""
var last_discovery_text: String = ""
var current_map_available_discoveries: int = 0
var moon_map_return_map_id: String = ""
var graphics_level: int = 0
var density_level: int = 2
var lichen_count: int = 0
var current_slot: int = 0
var slot_count: int = 0
var show_fps: bool = false

var _moon_grid_scale: int = 1
var _gate_transition_in_progress: bool = false
var _gate_overlap_active: Dictionary = {}
var _gate_proximity_active: Dictionary = {}
var _last_gate_index_in_range: int = -1
var _gate_use_was_pressed: bool = false
var _gate_trigger_enable_time_msec: int = 0
var _gate_auto_retry_time_msec: int = 0
var _gate_auto_cooldown_until_msec: int = 0
var _gate_debug_line: String = ""
var _gate_room_slot_active: Dictionary = {}
var _gate_room_return_active: bool = false
var _gate_room_slot_in_range: int = -1
var _gate_room_return_in_range: bool = false
var _cycle_time: float = 0.0
var cycle_speed_multiplier: float = 1.0
var start_fullscreen: bool = true
var discovery_tracker: DiscoveryTracker
var generation_rng = StableRng.new(1)
const CYCLE_HOURS_PER_SECOND: float = 0.01
const CYCLE_LENGTH: float = 24.0 / CYCLE_HOURS_PER_SECOND
const DEFAULT_START_HOUR: float = 7.5


func _ready() -> void:
	print("GATEWALK PATCHED MAIN: trees restored safely")
	print("Main._ready: script is loading")
	print("Random World Explorer v6: starting")

	hud_controller = HudController.new()
	hud_controller.name = "HudController"
	hud_controller._get_world_fn = _get_world
	hud_controller._get_player_fn = _get_player
	hud_controller._is_moon_fn = _is_current_map_moon
	hud_controller._is_water_fn = _is_current_map_water
	hud_controller._is_cave_fn = _is_current_map_cave
	hud_controller._is_arctic_fn = _is_current_map_arctic
	hud_controller._is_gate_room_fn = _is_current_map_gate_room
	add_child(hud_controller)

	discovery_tracker = DiscoveryTracker.new()
	discovery_tracker.get_world = _get_world
	discovery_tracker.set_world = _set_world
	discovery_tracker.update_world_map_record = _update_world_map_record
	discovery_tracker.get_current_universe = _current_universe
	discovery_tracker.set_current_universe = _set_current_universe
	discovery_tracker.save_world_data = _save_world_data
	discovery_tracker.get_map_record = _get_map_record
	discovery_tracker.on_orb_discovered = _check_moon_shrine_completion
	discovery_tracker.on_message = _on_discovery_message

	atlas_view = AtlasView.new()
	atlas_view.name = "AtlasView"
	atlas_view.get_worlds_fn = _get_worlds
	atlas_view.get_world_fn = _get_world
	atlas_view.seed_color_fn = _seed_color
	atlas_view.short_id_fn = _short_id
	atlas_view.completion_text_fn = _completion_text
	atlas_view.opposite_gate_index_fn = _opposite_gate_index
	add_child(atlas_view)

	dev_menu = DevMenu.new()
	dev_menu.name = "DevMenu"
	dev_menu.get_worlds_fn = _get_worlds
	dev_menu.get_world_fn = _get_world
	dev_menu.set_world_fn = _set_world
	dev_menu.set_worlds_fn = _set_worlds
	dev_menu.set_last_world_id_fn = _set_last_world_id
	dev_menu.load_map_fn = _load_map
	dev_menu.save_world_data_fn = _save_world_data
	dev_menu.seed_for_new_record_fn = _seed_for_new_record
	dev_menu.create_map_record_fn = _create_map_record
	dev_menu.create_water_map_record_fn = _create_water_map_record
	dev_menu.create_cave_map_record_fn = _create_cave_map_record
	dev_menu.create_arctic_map_record_fn = _create_arctic_map_record
	dev_menu.new_id_fn = _new_id
	dev_menu.moon_seed_fn = _moon_seed
	dev_menu.create_gate_room_map_record_fn = _create_gate_room_map_record
	dev_menu.create_map_nexus_map_record_fn = _create_map_nexus_map_record
	dev_menu.close_main_menu_fn = _close_menu
	add_child(dev_menu)

	_load_slot_index()
	_load_save_data()

	if start_fullscreen:
		call_deferred("_configure_fullscreen")
	else:
		call_deferred("_configure_windowed")

	var preview := get_node_or_null("EditorPreviewGround")
	if preview != null:
		preview.queue_free()

	_setup_environment()
	hud_controller.setup(self)
	hud_controller.world_environment = world_environment
	_apply_graphics_level()
	_ensure_default_world()
	var resume_target: Dictionary = _explicit_resume_target()
	if not resume_target.is_empty():
		_activate_world(str(resume_target.get("world_id", "")), str(resume_target.get("map_id", "")))
	else:
		var last_world_id: String = _last_world_id()
		if last_world_id != "":
			_load_world_from_menu(last_world_id)

	print("Random World Explorer v6: slot ", current_slot, " saved to ", _slot_path(current_slot))
	print("Random World Explorer v6: press F11 to toggle fullscreen")
	print("Random World Explorer v6: press F10 to force 1280x720 windowed mode")


func _process(_delta: float) -> void:
	_poll_gate_use_input()
	_poll_hub_use_input()
	if not _is_current_map_gate_room() and not _is_current_map_cave() and not _is_current_map_map_nexus():
		_cycle_time += _delta * cycle_speed_multiplier
		if _cycle_time >= CYCLE_LENGTH:
			_cycle_time = fmod(_cycle_time, CYCLE_LENGTH)
			_update_day_night_cycle()
	_update_underwater_state()
	_recover_fallen_player()
	_update_hud(_delta)


func _physics_process(_delta: float) -> void:
	_poll_primary_gate_activation()
	_poll_gate_room_slot_fallback()
	_poll_gate_room_return_fallback()


func _poll_primary_gate_activation() -> void:
	if _gate_transition_in_progress:
		_gate_debug_line = "GateDbg: locked transition"
		return
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		_last_gate_index_in_range = -1
		_gate_debug_line = "GateDbg: hub map"
		return
	if generated_root == null:
		_last_gate_index_in_range = -1
		_gate_debug_line = "GateDbg: no generated root"
		return
	var gate_root: Node = generated_root.get_node_or_null("Gates")
	var player: CharacterBody3D = _get_player()
	if player == null:
		_last_gate_index_in_range = -1
		_gate_debug_line = "GateDbg: no player"
		return
	var proximity_radius: float = 6.0
	var activation_radius: float = 2.8
	_last_gate_index_in_range = -1
	var best_dist: float = INF
	var now_msec: int = Time.get_ticks_msec()
	var can_auto_trigger: bool = now_msec >= _gate_trigger_enable_time_msec and now_msec >= _gate_auto_cooldown_until_msec
	if gate_root != null:
		for child in gate_root.get_children():
			var gate_node: Node3D = child as Node3D
			if gate_node == null:
				continue
			var gate_name: String = str(gate_node.name)
			if not gate_name.begins_with("Gate_"):
				continue
			var gate_index: int = int(gate_name.trim_prefix("Gate_"))
			var delta: Vector3 = gate_node.global_position - player.global_position
			var dist: float = Vector2(delta.x, delta.z).length()
			if dist <= proximity_radius and dist < best_dist:
				best_dist = dist
				_last_gate_index_in_range = gate_index
	else:
		_last_gate_index_in_range = _edge_gate_index_if_near(player.global_position)
		if _last_gate_index_in_range >= 0:
			best_dist = 2.0
	if can_auto_trigger and _last_gate_index_in_range >= 0 and best_dist <= activation_radius:
		_gate_auto_cooldown_until_msec = now_msec + 850
		_gate_debug_line = "GateDbg: fire g" + str(_last_gate_index_in_range + 1) + " d=" + str(snapped(best_dist, 0.01))
		_force_gate_transition(_last_gate_index_in_range, player)
		return
	var cd_left: int = max(_gate_auto_cooldown_until_msec - now_msec, 0)
	var warmup_left: int = max(_gate_trigger_enable_time_msec - now_msec, 0)
	if _last_gate_index_in_range < 0:
		_gate_debug_line = "GateDbg: no gate in range"
	else:
		_gate_debug_line = "GateDbg: g" + str(_last_gate_index_in_range + 1) + " d=" + str(snapped(best_dist, 0.01)) + " warm=" + str(warmup_left) + " cd=" + str(cd_left)


func _edge_gate_index_if_near(pos: Vector3) -> int:
	var half: float = _world_half_size()
	var trigger_band: float = half * 0.62
	if max(abs(pos.x), abs(pos.z)) < trigger_band:
		return -1
	return _inferred_gate_index_from_position(pos)


func _poll_gate_use_input() -> void:
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		return
	var use_pressed: bool = Input.is_key_pressed(KEY_E)
	var just_pressed: bool = use_pressed and not _gate_use_was_pressed
	_gate_use_was_pressed = use_pressed
	if not just_pressed:
		return
	if _gate_transition_in_progress:
		return
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var gate_index: int = _nearest_gate_index(player, 7.5)
	if gate_index < 0:
		last_discovery_text = "No gate in range."
		_gate_debug_line = "GateDbg: E no gate"
		return
	last_discovery_text = "Attempting gate " + str(gate_index + 1) + "..."
	_gate_debug_line = "GateDbg: E fire g" + str(gate_index + 1)
	_on_gate_body_entered(player, gate_index)


func _nearest_gate_index(player: CharacterBody3D, max_radius: float) -> int:
	if player == null or generated_root == null:
		return -1
	var gate_root: Node = generated_root.get_node_or_null("Gates")
	if gate_root == null:
		var all_gate_nodes: Array = generated_root.find_children("Gate_*", "Node3D", true, false)
		var best_gate_global: int = -1
		var best_dist_global: float = max_radius
		for raw_node in all_gate_nodes:
			var gate_node_global: Node3D = raw_node as Node3D
			if gate_node_global == null:
				continue
			var gate_name_global: String = str(gate_node_global.name)
			if not gate_name_global.begins_with("Gate_"):
				continue
			var gate_index_global: int = int(gate_name_global.trim_prefix("Gate_"))
			var dg: float = Vector2(
				gate_node_global.global_position.x - player.global_position.x,
				gate_node_global.global_position.z - player.global_position.z
			).length()
			if dg <= best_dist_global:
				best_dist_global = dg
				best_gate_global = gate_index_global
		return best_gate_global
	var best_gate: int = -1
	var best_dist: float = max_radius
	for child in gate_root.get_children():
		var gate_node: Node3D = child as Node3D
		if gate_node == null:
			continue
		var gate_name: String = str(gate_node.name)
		if not gate_name.begins_with("Gate_"):
			continue
		var gate_index: int = int(gate_name.trim_prefix("Gate_"))
		var d: float = Vector2(
			gate_node.global_position.x - player.global_position.x,
			gate_node.global_position.z - player.global_position.z
		).length()
		if d <= best_dist:
			best_dist = d
			best_gate = gate_index
	return best_gate


func _try_activate_nearest_gate_from_input() -> void:
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		return
	if _gate_transition_in_progress:
		last_discovery_text = "Gate busy."
		_gate_debug_line = "GateDbg: input lock"
		return
	var player: CharacterBody3D = _get_player()
	var gate_index: int = _nearest_gate_index(player, 9.0) if player != null else -1
	if gate_index < 0:
		var fallback_pos: Vector3 = player.global_position if player != null else Vector3.ZERO
		gate_index = _inferred_gate_index_from_position(fallback_pos)
		_gate_debug_line = "GateDbg: input inferred g" + str(gate_index + 1)
		last_discovery_text = "Gate node not detected; inferring gate " + str(gate_index + 1) + "."
	_force_gate_transition(gate_index, player)


func _inferred_gate_index_from_position(pos: Vector3) -> int:
	# Fallback when gate scene nodes are missing or not discoverable:
	# infer gate by dominant axis from player location.
	if abs(pos.x) >= abs(pos.z):
		return 0 if pos.x >= 0.0 else 1
	return 2 if pos.z >= 0.0 else 3


func _force_gate_transition(gate_index: int, player: CharacterBody3D = null) -> void:
	if current_world_id == "" or current_map_id == "":
		last_discovery_text = "Gate failed: missing world/map state."
		_gate_debug_line = "GateDbg: force missing ids"
		return
	_gate_transition_in_progress = true
	var worlds: Dictionary = _get_worlds()
	var world: Dictionary = worlds.get(current_world_id, {})
	var gate_result: Dictionary = GateTravelService.resolve_gate_transition(
		world_seed,
		current_map_id,
		gate_index,
		world,
		Callable(self, "_new_id"),
		WATER_ROUTE_CHANCE
	)
	if not bool(gate_result.get("ok", false)):
		var gate_error: String = str(gate_result.get("error", "unknown"))
		last_discovery_text = "Gate force failed: " + gate_error
		_gate_debug_line = "GateDbg: force err " + gate_error
		_gate_transition_in_progress = false
		return
	if bool(gate_result.get("inert", false)):
		last_discovery_text = "Gate inert."
		_gate_debug_line = "GateDbg: force inert"
		_gate_transition_in_progress = false
		return
	if bool(gate_result.get("changed", false)):
		var merged_worlds: Dictionary = GateTravelService.with_updated_world(worlds, current_world_id, gate_result.get("world", world))
		_set_worlds(merged_worlds)
		_save_world_data()
	var target_map_id: String = str(gate_result.get("target_map_id", ""))
	if target_map_id == "":
		last_discovery_text = "Gate force failed: empty target."
		_gate_debug_line = "GateDbg: force empty"
		_gate_transition_in_progress = false
		return
	if player != null and discovery_tracker != null:
		discovery_tracker.record_discovery("gate_" + str(gate_index), str(gate_index + 1), "gate", Vector3(player.global_position.x, 0.0, player.global_position.z))
	last_discovery_text = "Activate gate " + str(gate_index + 1) + "."
	_gate_debug_line = "GateDbg: force pass g" + str(gate_index + 1) + " -> " + _short_id(target_map_id)
	call_deferred("_deferred_load_gate_target", current_world_id, target_map_id)


func _poll_hub_use_input() -> void:
	if not (_is_current_map_gate_room() or _is_current_map_map_nexus()):
		return
	var use_pressed: bool = Input.is_key_pressed(KEY_E)
	var just_pressed: bool = use_pressed and not _gate_use_was_pressed
	_gate_use_was_pressed = use_pressed
	if not just_pressed:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	if _is_current_map_gate_room():
		if _gate_room_return_in_range:
			_on_gate_room_return_body_entered(player)
			return
		if _gate_room_slot_in_range >= 0:
			_on_gate_room_gate_body_entered(player, _gate_room_slot_in_range)
			return
		last_discovery_text = "No Gate Room portal in range."
		return

	if _last_gate_index_in_range >= 0:
		_on_map_nexus_gate_body_entered(player, _last_gate_index_in_range)
	else:
		last_discovery_text = "No nexus gate in range."


func _poll_gate_room_slot_fallback() -> void:
	if not _is_current_map_gate_room():
		_gate_room_slot_in_range = -1
		return
	if generated_root == null:
		_gate_room_slot_in_range = -1
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		_gate_room_slot_in_range = -1
		return
	var proximity_radius: float = 4.0
	var best_dist: float = INF
	_gate_room_slot_in_range = -1
	for child in generated_root.get_children():
		var gate_node: Node3D = child as Node3D
		if gate_node == null:
			continue
		var gate_name: String = str(gate_node.name)
		if not gate_name.begins_with("GateRoomGate_"):
			continue
		var slot_index: int = int(gate_name.trim_prefix("GateRoomGate_"))
		var dist: float = Vector2(
			gate_node.global_position.x - player.global_position.x,
			gate_node.global_position.z - player.global_position.z
		).length()
		if dist < best_dist:
			best_dist = dist
			_gate_room_slot_in_range = slot_index
		var near: bool = dist <= proximity_radius
		var was_near: bool = bool(_gate_room_slot_active.get(slot_index, false))
		if near and not was_near:
			_gate_room_slot_active[slot_index] = true
			_on_gate_room_gate_body_entered(player, slot_index)
		elif not near and was_near:
			_gate_room_slot_active.erase(slot_index)


func _poll_gate_room_return_fallback() -> void:
	_gate_room_return_in_range = false
	if not _is_current_map_gate_room():
		return
	if generated_root == null:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var return_portal: Node3D = generated_root.get_node_or_null("GateRoomReturnPortal") as Node3D
	if return_portal == null:
		return
	var dist: float = Vector2(
		return_portal.global_position.x - player.global_position.x,
		return_portal.global_position.z - player.global_position.z
	).length()
	_gate_room_return_in_range = dist <= 4.0
	if _gate_room_return_in_range and not _gate_room_return_active:
		_gate_room_return_active = true
		_on_gate_room_return_body_entered(player)
	elif not _gate_room_return_in_range and _gate_room_return_active:
		_gate_room_return_active = false


func _configure_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("Window mode requested: fullscreen")
	print("Actual DisplayServer window size: ", DisplayServer.window_get_size())
	print("Actual Godot Window size: ", get_window().size)


func _configure_windowed() -> void:
	var requested_size: Vector2i = Vector2i(1280, 720)
	var minimum_size: Vector2i = Vector2i(960, 540)

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_min_size(minimum_size)
	DisplayServer.window_set_size(requested_size)

	# Also set the root Window. On macOS this can matter when DisplayServer
	# changes are applied before the game window fully settles.
	get_window().min_size = minimum_size
	get_window().size = requested_size

	_center_window()

	print("Window size requested: ", requested_size)
	print("Actual DisplayServer window size: ", DisplayServer.window_get_size())
	print("Actual Godot Window size: ", get_window().size)


func _center_window() -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	var window_size: Vector2i = DisplayServer.window_get_size()

	var centered_x: int = int(float(screen_size.x - window_size.x) * 0.5)
	var centered_y: int = int(float(screen_size.y - window_size.y) * 0.5)

	DisplayServer.window_set_position(Vector2i(max(centered_x, 0), max(centered_y, 0)))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				_configure_windowed()
			else:
				_configure_fullscreen()

		if event.keycode == KEY_F10:
			_configure_windowed()

		if event.keycode == KEY_F3:
			show_fps = not show_fps
			if hud_controller != null:
				hud_controller.show_fps = show_fps

		if event.keycode == KEY_M:
			if menu_layer != null:
				_close_menu()
			else:
				_show_main_menu()

		if event.keycode == KEY_G:
			_return_to_gate_room()

		if event.keycode == KEY_TAB:
			if atlas_view != null:
				atlas_view.toggle()

		if event.keycode == KEY_H:
			show_hud = not show_hud
			if hud_controller != null and hud_controller.hud_layer != null:
				hud_controller.hud_layer.visible = show_hud

		if event.keycode == KEY_C:
			_try_grab_lichen()

		if event.keycode == KEY_P:
			_place_cartography_pin()

		if event.keycode == KEY_T:
			_throw_lichen()

		if event.keycode == KEY_S and event.shift_pressed:
			if dev_menu != null:
				dev_menu.show_login()

		if event.keycode == KEY_F5:
			_explicit_save_world_data()

		if event.keycode == KEY_E:
			_try_activate_nearest_gate_from_input()


func _slot_path(slot: int) -> String:
	return "user://save_" + str(slot) + ".json"


func _load_slot_index() -> void:
	if FileAccess.file_exists(SLOT_INDEX_PATH):
		var file := FileAccess.open(SLOT_INDEX_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				current_slot = int(parsed.get("current", 0))
				slot_count = int(parsed.get("count", 1))
				return

	if FileAccess.file_exists("user://world_graphs.json"):
		var old_read := FileAccess.open("user://world_graphs.json", FileAccess.READ)
		if old_read != null:
			var old_text: String = old_read.get_as_text()
			old_read.close()
			var old_write := FileAccess.open(_slot_path(0), FileAccess.WRITE)
			if old_write != null:
				old_write.store_string(old_text)
				old_write.close()
			DirAccess.remove_absolute("user://world_graphs.json")

	current_slot = 0
	slot_count = 1


func _save_slot_index() -> void:
	var file := FileAccess.open(SLOT_INDEX_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open slot index: " + SLOT_INDEX_PATH)
		return
	file.store_string(JSON.stringify({"current": current_slot, "count": slot_count}, "\t"))


func _load_save_data() -> void:
	var path: String = _slot_path(current_slot)
	save_data = {}
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				save_data = parsed

	save_data = SaveManager.normalize_save_data(save_data)
	current_universe_id = SaveManager.current_universe_id(save_data)
	var universe: Dictionary = _current_universe()
	var settings: Dictionary = universe.get("settings", {})
	cycle_speed_multiplier = float(settings.get("cycle_speed_multiplier", 1.0))
	start_fullscreen = bool(settings.get("start_fullscreen", true))
	graphics_level = int(settings.get("graphics_level", 0))
	density_level = int(settings.get("density_level", 2))
	lichen_count = int(universe.get("lichen_count", 0))
	_cycle_time = _cycle_time_from_universe(universe)


func _save_world_data() -> void:
	var universe: Dictionary = _current_universe()
	var settings: Dictionary = universe.get("settings", {})
	settings["density_level"] = density_level
	settings["cycle_speed_multiplier"] = cycle_speed_multiplier
	settings["start_fullscreen"] = start_fullscreen
	settings["graphics_level"] = graphics_level
	universe["settings"] = settings
	universe["lichen_count"] = lichen_count
	save_data = SaveManager.set_current_universe(save_data, universe)
	var path: String = _slot_path(current_slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing: " + path)
		return

	file.store_string(JSON.stringify(save_data, "\t"))


func _explicit_save_world_data() -> void:
	var universe: Dictionary = _current_universe()
	universe["last_saved_cycle_time"] = _normalized_cycle_time(_cycle_time)
	universe["last_explicit_save_unix"] = Time.get_unix_time_from_system()
	var saved_player_state: Dictionary = _capture_player_save_state()
	universe["last_player_state"] = saved_player_state
	_set_current_universe(universe)
	_save_world_data()
	last_discovery_text = "Game saved."


func _capture_player_save_state() -> Dictionary:
	var base := {
		"world_id": current_world_id,
		"map_id": current_map_id,
		"has_position": false,
	}
	if current_world_id == "" or current_map_id == "":
		return base

	var player: CharacterBody3D = _get_player()
	if player == null:
		return base

	var camera: Camera3D = player.get_node_or_null("PlayerCamera") as Camera3D
	return {
		"world_id": current_world_id,
		"map_id": current_map_id,
		"has_position": true,
		"x": player.global_position.x,
		"y": player.global_position.y,
		"z": player.global_position.z,
		"yaw": player.rotation.y,
		"pitch": camera.rotation.x if camera != null else float(player.get("pitch")),
		"sprint_stamina": float(player.get("sprint_stamina")),
		"breath": float(player.get("breath")),
		"flashlight_on": bool(player.get("flashlight_on")),
		"flashlight_charge": float(player.get("flashlight_charge")),
	}


func _restore_player_save_state(player: CharacterBody3D) -> bool:
	if player == null:
		return false
	var universe: Dictionary = _current_universe()
	var state: Dictionary = universe.get("last_player_state", {})
	if state.is_empty():
		return false
	if str(state.get("world_id", "")) != current_world_id:
		return false
	if str(state.get("map_id", "")) != current_map_id:
		return false
	if not bool(state.get("has_position", false)):
		return false
	player.global_position = Vector3(
		float(state.get("x", player.global_position.x)),
		float(state.get("y", player.global_position.y)),
		float(state.get("z", player.global_position.z)),
	)
	player.rotation.y = float(state.get("yaw", player.rotation.y))
	if state.has("sprint_stamina"):
		player.set("sprint_stamina", float(state.get("sprint_stamina", player.get("sprint_stamina"))))
	if state.has("breath"):
		player.set("breath", float(state.get("breath", player.get("breath"))))
	if state.has("flashlight_on"):
		player.set("flashlight_on", bool(state.get("flashlight_on", player.get("flashlight_on"))))
	if state.has("flashlight_charge"):
		player.set("flashlight_charge", float(state.get("flashlight_charge", player.get("flashlight_charge"))))
	var camera: Camera3D = player.get_node_or_null("PlayerCamera") as Camera3D
	var pitch: float = float(state.get("pitch", player.get("pitch")))
	player.set("pitch", pitch)
	if camera != null:
		camera.rotation.x = pitch
	var flashlight: SpotLight3D = player.get_node_or_null("PlayerCamera/Flashlight") as SpotLight3D
	if flashlight != null:
		flashlight.light_energy = 10.5 if bool(player.get("flashlight_on")) else 0.0
	return true


func _current_universe() -> Dictionary:
	return SaveManager.current_universe(save_data)


func _set_current_universe(universe: Dictionary) -> void:
	save_data = SaveManager.set_current_universe(save_data, universe)
	current_universe_id = SaveManager.current_universe_id(save_data)


func _set_current_universe_id(universe_id: String) -> void:
	save_data = SaveManager.set_current_universe_id(save_data, universe_id)
	current_universe_id = SaveManager.current_universe_id(save_data)


func _set_universe(universe_id: String, universe: Dictionary) -> void:
	save_data = SaveManager.set_universe(save_data, universe_id, universe)


func _get_worlds() -> Dictionary:
	return _current_universe().get("worlds", {})


func _get_universe_count() -> int:
	var universes: Dictionary = save_data.get("universes", {})
	return universes.size()


func _set_worlds(worlds: Dictionary) -> void:
	var universe: Dictionary = _current_universe()
	universe["worlds"] = worlds
	_set_current_universe(universe)


func _last_world_id() -> String:
	return str(_current_universe().get("last_world_id", ""))


func _set_last_world_id(world_id: String) -> void:
	var universe: Dictionary = _current_universe()
	universe["last_world_id"] = world_id
	_set_current_universe(universe)


func _apply_current_universe_runtime_state() -> void:
	var universe: Dictionary = _current_universe()
	var settings: Dictionary = universe.get("settings", {})
	cycle_speed_multiplier = float(settings.get("cycle_speed_multiplier", 1.0))
	start_fullscreen = bool(settings.get("start_fullscreen", true))
	graphics_level = int(settings.get("graphics_level", 0))
	density_level = int(settings.get("density_level", 2))
	lichen_count = int(universe.get("lichen_count", 0))
	_cycle_time = _cycle_time_from_universe(universe)


func _default_daylight_cycle_time() -> float:
	return (DEFAULT_START_HOUR / 24.0) * CYCLE_LENGTH


func _explicit_resume_target() -> Dictionary:
	var universe: Dictionary = _current_universe()
	var state: Dictionary = universe.get("last_player_state", {})
	if state.is_empty():
		return {}
	if not bool(state.get("has_position", false)):
		return {}
	var world_id: String = str(state.get("world_id", ""))
	var map_id: String = str(state.get("map_id", ""))
	if world_id == "" or map_id == "":
		return {}
	var worlds: Dictionary = universe.get("worlds", {})
	if not worlds.has(world_id):
		return {}
	var world: Dictionary = worlds.get(world_id, {})
	var maps: Dictionary = world.get("maps", {})
	if not maps.has(map_id):
		return {}
	return {"world_id": world_id, "map_id": map_id}


func _normalized_cycle_time(value: float) -> float:
	var normalized: float = fmod(value, CYCLE_LENGTH)
	if normalized < 0.0:
		normalized += CYCLE_LENGTH
	return normalized


func _cycle_time_from_universe(universe: Dictionary) -> float:
	if universe.has("last_saved_cycle_time"):
		return _normalized_cycle_time(float(universe.get("last_saved_cycle_time", _default_daylight_cycle_time())))
	return _default_daylight_cycle_time()


func _seed_for_new_record(label: String, salt: int = 0) -> int:
	var allocated: Dictionary = SaveManager.allocate_seed_for_current_universe(save_data, label, salt)
	save_data = allocated.get("save_data", save_data)
	current_universe_id = SaveManager.current_universe_id(save_data)
	return int(allocated.get("seed", 0))


func _begin_generation_channel(label: String, salt: int = 0) -> void:
	generation_rng = StableRng.new(StableRng.mix_string(world_seed, label, salt))


func _randf() -> float:
	return generation_rng.randf()


func _randf_range(min_value: float, max_value: float) -> float:
	return generation_rng.randf_range(min_value, max_value)


func _randi_range(min_value: int, max_value: int) -> int:
	return generation_rng.randi_range(min_value, max_value)


func _randi() -> int:
	return generation_rng.next_u32()


func _ensure_default_world() -> void:
	var worlds: Dictionary = _get_worlds()
	if not worlds.is_empty():
		return

	var created: Dictionary = _create_world_in_current_universe("Default World", "default_world")
	var world_id: String = str(created.get("world_id", ""))
	if world_id != "":
		_set_last_world_id(world_id)
	_save_world_data()


func _create_world_in_current_universe(world_name: String, seed_label: String = "") -> Dictionary:
	var world_id: String = _new_id("world")
	var root_map_id: String = _new_id("map")
	var label: String = seed_label if seed_label != "" else world_id
	var world_record: Dictionary = _create_world_record(world_name, root_map_id, _seed_for_new_record(label)).to_dict()
	var worlds: Dictionary = _get_worlds()
	worlds[world_id] = world_record
	_set_worlds(worlds)
	return {"world_id": world_id, "root_map_id": root_map_id}


func _activate_world(world_id: String, map_id: String = "") -> void:
	if world_id == "":
		return
	var world: Dictionary = _get_world(world_id)
	if world.is_empty():
		return
	var target_map_id: String = map_id
	if target_map_id == "":
		target_map_id = str(world.get("current_map", world.get("root_map", "")))
	if target_map_id == "":
		return
	_set_last_world_id(world_id)
	_load_map(world_id, target_map_id)


func _create_universe_with_default_world(universe_name: String, default_world_name: String) -> Dictionary:
	var universe_id: String = _new_id("universe")
	var universe: Dictionary = SaveManager.create_universe_record(universe_name)
	var default_world_id: String = _new_id("world")
	var root_map_id: String = _new_id("map")
	var world_seed: int = _seed_for_new_record(default_world_id)
	var world_record: Dictionary = _create_world_record(default_world_name, root_map_id, world_seed).to_dict()
	var worlds: Dictionary = {}
	worlds[default_world_id] = world_record
	universe["worlds"] = worlds
	universe["last_world_id"] = default_world_id
	return {
		"universe_id": universe_id,
		"universe": universe,
		"world_id": default_world_id,
		"root_map_id": root_map_id,
	}


func _apply_graphics_level() -> void:
	if sun_light != null:
		_configure_sun_shadows()

	match graphics_level:
		0:
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			get_viewport().use_taa = false
			if world_environment != null:
				world_environment.glow_enabled = false
				world_environment.ssao_enabled = false
				world_environment.ssil_enabled = false
				world_environment.ssr_enabled = false
				_set_environment_property("glow_bloom", 0.0)
		1:
			get_viewport().msaa_3d = Viewport.MSAA_2X
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			get_viewport().use_taa = false
			if world_environment != null:
				world_environment.glow_enabled = true
				world_environment.glow_intensity = 0.10
				world_environment.glow_strength = 0.15
				_set_environment_property("glow_bloom", 0.0)
				world_environment.ssao_enabled = false
				world_environment.ssil_enabled = false
				world_environment.ssr_enabled = false
		2:
			get_viewport().msaa_3d = Viewport.MSAA_4X
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
			get_viewport().use_taa = false
			if world_environment != null:
				world_environment.glow_enabled = true
				world_environment.glow_intensity = 0.16
				world_environment.glow_strength = 0.22
				_set_environment_property("glow_bloom", 0.004)
				_set_environment_property("glow_hdr_bleed_threshold", 1.20)
				_set_environment_property("glow_hdr_bleed_scale", 0.75)
				world_environment.ssao_enabled = true
				world_environment.ssao_radius = 0.75
				world_environment.ssao_intensity = 1.4
				_set_environment_property("ssao_power", 1.35)
				_set_environment_property("ssao_detail", 0.45)
				world_environment.ssil_enabled = true
				world_environment.ssil_radius = 1.5
				world_environment.ssil_intensity = 0.20
				_set_environment_property("ssil_sharpness", 0.85)
				world_environment.ssr_enabled = false
		3:
			get_viewport().msaa_3d = Viewport.MSAA_8X
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			get_viewport().use_taa = true
			if world_environment != null:
				world_environment.glow_enabled = true
				world_environment.glow_intensity = 0.22
				world_environment.glow_strength = 0.30
				_set_environment_property("glow_bloom", 0.005)
				_set_environment_property("glow_hdr_bleed_threshold", 1.15)
				_set_environment_property("glow_hdr_bleed_scale", 0.80)
				world_environment.ssao_enabled = true
				world_environment.ssao_radius = 1.0
				world_environment.ssao_intensity = 1.6
				_set_environment_property("ssao_power", 1.5)
				_set_environment_property("ssao_detail", 0.65)
				world_environment.ssil_enabled = true
				world_environment.ssil_radius = 2.0
				world_environment.ssil_intensity = 0.25
				_set_environment_property("ssil_sharpness", 1.0)
				world_environment.ssr_enabled = false


func _set_environment_property(property_name: String, value: Variant) -> void:
	if world_environment == null:
		return
	for property in world_environment.get_property_list():
		if str(property.get("name", "")) == property_name:
			world_environment.set(property_name, value)
			return


func _configure_sun_shadows() -> void:
	if sun_light == null:
		return
	var enable: bool = graphics_level >= 2
	sun_light.shadow_enabled = enable
	if enable:
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun_light.directional_shadow_max_distance = 140.0
		sun_light.directional_shadow_split_1 = 0.08
		sun_light.directional_shadow_split_2 = 0.2
		sun_light.directional_shadow_split_3 = 0.45
		sun_light.directional_shadow_blend_splits = true
		if graphics_level >= 3:
			sun_light.shadow_bias = 0.02
			sun_light.directional_shadow_max_distance = 200.0
		else:
			sun_light.shadow_bias = 0.04


func _set_graphics_level(level: int) -> void:
	graphics_level = level
	_save_world_data()
	_apply_graphics_level()
	if menu_layer != null or current_world_id == "" or current_map_id == "":
		_show_main_menu()


func _set_density_level(level: int) -> void:
	density_level = level
	_save_world_data()
	var was_menu_open: bool = menu_layer != null
	if current_world_id != "" and current_map_id != "":
		_load_map(current_world_id, current_map_id)
	if was_menu_open:
		_show_main_menu()
	elif current_world_id == "" or current_map_id == "":
		_show_main_menu()


func _on_time_speed_changed(value: float) -> void:
	cycle_speed_multiplier = value
	_update_time_speed_label()


func _on_toggle_start_fullscreen(pressed: bool, btn: Button) -> void:
	start_fullscreen = pressed
	btn.text = "Fullscreen" if start_fullscreen else "Windowed"
	_save_world_data()


func _update_time_speed_label() -> void:
	if menu_layer == null:
		return
	var label := menu_layer.find_child("TimeSpeedLabel", true, false)
	if label != null:
		label.text = "%.2fx" % cycle_speed_multiplier


func _show_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu_layer != null:
		menu_layer.queue_free()

	menu_layer = CanvasLayer.new()
	menu_layer.name = "WorldMenuLayer"
	menu_layer.layer = 30
	add_child(menu_layer)

	var overlay := ColorRect.new()
	overlay.name = "MenuOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	menu_layer.add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390.0
	panel.offset_top = -300.0
	panel.offset_right = 390.0
	panel.offset_bottom = 300.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.075, 0.085, 0.96)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	menu_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroller)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	scroller.add_child(list)

	var title := Label.new()
	title.text = "Random World Explorer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	list.add_child(title)

	var slot_bar := HBoxContainer.new()
	slot_bar.add_theme_constant_override("separation", 6)
	list.add_child(slot_bar)

	var slot_label := Label.new()
	slot_label.text = "Slot " + str(current_slot + 1)
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_bar.add_child(slot_label)

	var switch_btn := Button.new()
	switch_btn.text = "Switch"
	switch_btn.pressed.connect(_show_slot_picker)
	slot_bar.add_child(switch_btn)

	var new_slot_btn := Button.new()
	new_slot_btn.text = "New Slot"
	new_slot_btn.pressed.connect(_create_new_slot)
	slot_bar.add_child(new_slot_btn)

	var story := Label.new()
	story.text = _backstory_text()
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 12)
	story.add_theme_constant_override("line_separation", -3)
	list.add_child(story)

	var universe_header := Label.new()
	universe_header.text = "Universes:"
	universe_header.add_theme_font_size_override("font_size", 13)
	list.add_child(universe_header)

	var universe_list := VBoxContainer.new()
	universe_list.add_theme_constant_override("separation", 4)
	list.add_child(universe_list)
	var universes: Dictionary = save_data.get("universes", {})
	for universe_key in universes.keys():
		var uid: String = str(universe_key)
		var universe: Dictionary = universes[uid]
		var universe_btn := Button.new()
		universe_btn.text = ("> " if uid == current_universe_id else "  ") + str(universe.get("name", uid))
		universe_btn.disabled = uid == current_universe_id
		universe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		universe_btn.pressed.connect(_switch_universe.bind(uid))
		universe_list.add_child(universe_btn)

	var world_header := Label.new()
	world_header.text = "Worlds:"
	world_header.add_theme_font_size_override("font_size", 13)
	list.add_child(world_header)

	var world_list := VBoxContainer.new()
	world_list.add_theme_constant_override("separation", 4)
	list.add_child(world_list)

	var worlds: Dictionary = _get_worlds()
	if worlds.is_empty():
		var empty_w := Label.new()
		empty_w.text = "No worlds yet."
		empty_w.add_theme_font_size_override("font_size", 11)
		world_list.add_child(empty_w)
	else:
		for world_key in worlds.keys():
			var world_id: String = str(world_key)
			var world: Dictionary = worlds[world_id]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			world_list.add_child(row)

			var is_current: bool = world_id == current_world_id
			var load_btn := Button.new()
			load_btn.text = ("> " if is_current else "  ") + str(world.get("name", world_id))
			load_btn.pressed.connect(_load_world_from_menu.bind(world_id))
			load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(load_btn)

			var rename_btn := Button.new()
			rename_btn.text = "R"
			rename_btn.custom_minimum_size = Vector2(24, 0)
			rename_btn.pressed.connect(_rename_world.bind(world_id, load_btn))
			row.add_child(rename_btn)

	if current_world_id != "":
		var resume_button := Button.new()
		resume_button.text = "Resume Current Map"
		resume_button.pressed.connect(_close_menu)
		world_list.add_child(resume_button)

		var save_btn := Button.new()
		save_btn.text = "Save Game"
		save_btn.pressed.connect(_explicit_save_world_data)
		world_list.add_child(save_btn)

	var new_world_btn := Button.new()
	new_world_btn.text = "New World"
	new_world_btn.pressed.connect(_create_new_world_direct)
	world_list.add_child(new_world_btn)

	var new_universe_btn := Button.new()
	new_universe_btn.text = "New Universe"
	new_universe_btn.pressed.connect(_start_new_game)
	world_list.add_child(new_universe_btn)

	var gfx_row := HBoxContainer.new()
	gfx_row.add_theme_constant_override("separation", 6)
	list.add_child(gfx_row)
	var gfx_label := Label.new()
	gfx_label.text = "Graphics:"
	gfx_label.add_theme_font_size_override("font_size", 12)
	gfx_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gfx_row.add_child(gfx_label)
	var gfx_names: Array[String] = ["Low", "Medium", "High", "Ultra"]
	for gi in range(gfx_names.size()):
		var btn := Button.new()
		btn.text = gfx_names[gi]
		btn.disabled = gi == graphics_level
		btn.pressed.connect(_set_graphics_level.bind(gi))
		gfx_row.add_child(btn)

	var dens_row := HBoxContainer.new()
	dens_row.add_theme_constant_override("separation", 6)
	list.add_child(dens_row)
	var dens_label := Label.new()
	dens_label.text = "Density:"
	dens_label.add_theme_font_size_override("font_size", 12)
	dens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dens_row.add_child(dens_label)
	var dens_names: Array[String] = ["Low", "Medium", "High"]
	for di in range(dens_names.size()):
		var btn2 := Button.new()
		btn2.text = dens_names[di]
		btn2.disabled = di == density_level
		btn2.pressed.connect(_set_density_level.bind(di))
		dens_row.add_child(btn2)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 6)
	list.add_child(time_row)
	var time_label := Label.new()
	time_label.text = "Time Speed:"
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_row.add_child(time_label)
	var time_slider := HSlider.new()
	time_slider.min_value = 0.1
	time_slider.max_value = 10.0
	time_slider.step = 0.01
	time_slider.value = cycle_speed_multiplier
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.value_changed.connect(_on_time_speed_changed)
	time_row.add_child(time_slider)
	var time_val := Label.new()
	time_val.set("name", "TimeSpeedLabel")
	time_val.text = "%.2fx" % cycle_speed_multiplier
	time_val.add_theme_font_size_override("font_size", 12)
	time_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_val.custom_minimum_size.x = 32
	time_row.add_child(time_val)

	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 6)
	list.add_child(fs_row)
	var fs_label := Label.new()
	fs_label.text = "Start Mode:"
	fs_label.add_theme_font_size_override("font_size", 12)
	fs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fs_row.add_child(fs_label)
	var fs_btn := Button.new()
	fs_btn.text = "Fullscreen" if start_fullscreen else "Windowed"
	fs_btn.toggle_mode = true
	fs_btn.button_pressed = start_fullscreen
	fs_btn.toggled.connect(_on_toggle_start_fullscreen.bind(fs_btn))
	fs_row.add_child(fs_btn)

	var atlas := Label.new()
	atlas.text = _atlas_summary_text()
	atlas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	atlas.add_theme_font_size_override("font_size", 15)
	list.add_child(atlas)

	var atlas_title := Label.new()
	atlas_title.text = "Atlas Graph"
	atlas_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atlas_title.add_theme_font_size_override("font_size", 18)
	list.add_child(atlas_title)

	var ach_row := HBoxContainer.new()
	ach_row.add_theme_constant_override("separation", 6)
	list.add_child(ach_row)
	var ach_earned := 0
	var saved_achs: Dictionary = _current_universe().get("achievements", {})
	for ak in DiscoveryTracker.ACHIEVEMENT_DEFS.keys():
		if saved_achs.has(ak):
			ach_earned += 1
	var ach_btn := Button.new()
	ach_btn.text = "Achievements (" + str(ach_earned) + "/" + str(DiscoveryTracker.ACHIEVEMENT_DEFS.size()) + ")"
	ach_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_btn.pressed.connect(_show_achievements_dialog)
	ach_row.add_child(ach_btn)

	var hint := Label.new()
	hint.text = "Objective: restore the Atlas by finding wonders and gates.\nM: menu | Tab: atlas graph | G: return to Gate Room | P: pin location | H: HUD | F10: windowed | F11: fullscreen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	list.add_child(hint)


func _close_menu() -> void:
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_achievements_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Achievements"
	dialog.dialog_text = ""
	dialog.min_size = Vector2(360, 300)
	dialog.exclusive = true

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	dialog.add_child(vbox)

	var earned_achs: Dictionary = _current_universe().get("achievements", {})
	for akey in DiscoveryTracker.ACHIEVEMENT_DEFS.keys():
		var def: Dictionary = DiscoveryTracker.ACHIEVEMENT_DEFS[akey]
		var earned: bool = earned_achs.has(akey)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var check := Label.new()
		check.text = "[X]" if earned else "[ ]"
		check.add_theme_font_size_override("font_size", 13)
		row.add_child(check)

		var name_label := Label.new()
		name_label.text = def.get("name", akey)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = def.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(desc_label)

	add_child(dialog)
	dialog.popup_centered()


func _create_new_world(name_input: LineEdit) -> void:
	var raw: String = name_input.text.strip_edges()
	_create_new_world_named(raw)


func _create_new_world_direct() -> void:
	_create_new_world_named("")


func _create_new_world_named(raw_name: String) -> void:
	var world_name: String = raw_name if raw_name != "" else "World " + str(_get_worlds().size() + 1)
	var created: Dictionary = _create_world_in_current_universe(world_name)
	var world_id: String = str(created.get("world_id", ""))
	var root_map_id: String = str(created.get("root_map_id", ""))
	_set_last_world_id(world_id)
	_save_world_data()
	_load_map(world_id, root_map_id)


func _load_world_from_menu(world_id: String) -> void:
	_activate_world(world_id)


func _switch_universe(universe_id: String) -> void:
	var universes: Dictionary = save_data.get("universes", {})
	if not universes.has(universe_id):
		return
	_close_menu()
	_save_world_data()
	_set_current_universe_id(universe_id)
	current_world_id = ""
	current_map_id = ""
	last_discovery_text = ""
	_apply_current_universe_runtime_state()
	_ensure_default_world()
	var last_world_id: String = _last_world_id()
	if last_world_id != "":
		_activate_world(last_world_id)
	_show_main_menu()


func _start_new_game() -> void:
	_close_menu()
	var created: Dictionary = _create_universe_with_default_world("Universe " + str(_get_universe_count() + 1), "Default World")
	var universe_id: String = str(created.get("universe_id", ""))
	var universe: Dictionary = created.get("universe", {})
	var world_id: String = str(created.get("world_id", ""))
	var root_map_id: String = str(created.get("root_map_id", ""))
	_set_universe(universe_id, universe)
	_set_current_universe_id(universe_id)
	_apply_current_universe_runtime_state()
	_save_world_data()
	_load_map(world_id, root_map_id)


func _create_new_slot() -> void:
	_close_menu()
	_save_world_data()
	slot_count += 1
	current_slot = slot_count - 1
	_save_slot_index()
	save_data = SaveManager.default_save_data()
	current_universe_id = SaveManager.current_universe_id(save_data)
	_apply_current_universe_runtime_state()
	var created: Dictionary = _create_world_in_current_universe("Slot " + str(current_slot + 1))
	var world_id: String = str(created.get("world_id", ""))
	var root_map_id: String = str(created.get("root_map_id", ""))
	_set_last_world_id(world_id)
	_save_world_data()
	_load_map(world_id, root_map_id)


func _show_slot_picker() -> void:
	if menu_layer == null:
		return

	var dialog := AcceptDialog.new()
	dialog.title = "Switch Save Slot"
	dialog.dialog_text = ""
	dialog.close_on_escape = true
	dialog.ok_button_text = "Cancel"
	var vb := VBoxContainer.new()
	dialog.add_child(vb)

	var slots_scroll := ScrollContainer.new()
	slots_scroll.custom_minimum_size = Vector2(240.0, 150.0)
	vb.add_child(slots_scroll)

	var slots_list := VBoxContainer.new()
	slots_list.add_theme_constant_override("separation", 4)
	slots_scroll.add_child(slots_list)

	for i in range(slot_count):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		slots_list.add_child(row)

		var name_label := Label.new()
		name_label.text = "Slot " + str(i + 1)
		if i == current_slot:
			name_label.text += " (current)"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		if i != current_slot:
			var load_btn := Button.new()
			load_btn.text = "Load"
			load_btn.pressed.connect(_switch_to_slot.bind(i, dialog))
			row.add_child(load_btn)

	dialog.popup_centered(Vector2i(300, 220))
	menu_layer.add_child(dialog)


func _switch_to_slot(slot: int, dialog: AcceptDialog) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
	_close_menu()
	_save_world_data()
	current_slot = slot
	_save_slot_index()
	save_data = {}
	_load_save_data()
	var last_world_id: String = str(_last_world_id())
	if last_world_id != "":
		_activate_world(last_world_id)
	else:
		_ensure_default_world()
		_activate_world(str(_last_world_id()))


func _rename_world(world_id: String, button: Button) -> void:
	var world: Dictionary = _get_world(world_id)
	if world.is_empty() or not is_instance_valid(button):
		return
	var current_name: String = str(world.get("name", world_id))

	var dialog := AcceptDialog.new()
	dialog.title = "Rename World"
	dialog.dialog_text = ""
	var vb := VBoxContainer.new()
	dialog.add_child(vb)
	var label := Label.new()
	label.text = "Enter a new name:"
	vb.add_child(label)
	var line_edit := LineEdit.new()
	line_edit.text = current_name
	line_edit.select_all()
	vb.add_child(line_edit)
	dialog.register_text_enter(line_edit)
	dialog.popup_centered(Vector2i(280, 80))
	if menu_layer != null:
		menu_layer.add_child(dialog)
	else:
		add_child(dialog)

	dialog.confirmed.connect(func():
		if not is_instance_valid(button):
			return
		var new_name: String = line_edit.text.strip_edges()
		if new_name != "" and new_name != current_name:
			world["name"] = new_name
			_set_world(world_id, world)
			_save_world_data()
			button.text = new_name
	)


func _create_map_record(map_seed: int) -> MapRecord:
	return WorldGraph.create_map_record(map_seed, WorldGraph.MAP_NORMAL)


func _create_moon_map_record(map_seed: int) -> MapRecord:
	return WorldGraph.create_map_record(map_seed, WorldGraph.MAP_MOON)


func _create_water_map_record(map_seed: int) -> MapRecord:
	return WorldGraph.create_map_record(map_seed, WorldGraph.MAP_WATER)


func _create_arctic_map_record(map_seed: int) -> MapRecord:
	return WorldGraph.create_map_record(map_seed, WorldGraph.MAP_ARCTIC)


func _create_gate_room_map_record(map_seed: int) -> MapRecord:
	return WorldGraph.create_map_record(map_seed, WorldGraph.MAP_GATE_ROOM)


func _create_cave_map_record(map_seed: int) -> MapRecord:
	return WorldGraph.create_map_record(map_seed, WorldGraph.MAP_CAVE)


func _create_map_nexus_map_record(map_seed: int) -> MapRecord:
	return WorldGraph.create_map_record(map_seed, WorldGraph.MAP_NEXUS)


func _create_world_record(world_name: String, root_map_id: String, map_seed: int) -> WorldRecord:
	return WorldGraph.create_world_record(world_name, root_map_id, map_seed)


func _create_world_record_dict(world_name: String, root_map_id: String, map_seed: int) -> Dictionary:
	return _create_world_record(world_name, root_map_id, map_seed).to_dict()


func _new_id(prefix: String) -> String:
	return SaveManager.new_id(prefix)


func _get_world(world_id: String) -> Dictionary:
	var worlds: Dictionary = _get_worlds()
	var value = worlds.get(world_id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _get_map_record(world_id: String, map_id: String) -> Dictionary:
	if world_id == "" or map_id == "":
		return {}
	var world: Dictionary = _get_world(world_id)
	var maps: Dictionary = world.get("maps", {})
	var value = maps.get(map_id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _get_map_record_typed(world_id: String, map_id: String) -> MapRecord:
	var raw: Dictionary = _get_map_record(world_id, map_id)
	if raw.is_empty():
		return null
	return MapRecordClass.from_dict(raw)


func _get_current_map_record_typed() -> MapRecord:
	if current_world_id == "" or current_map_id == "":
		return null
	return _get_map_record_typed(current_world_id, current_map_id)


func _get_world_typed(world_id: String) -> WorldRecord:
	var raw: Dictionary = _get_world(world_id)
	if raw.is_empty():
		return null
	return WorldRecordClass.from_dict(raw)


func _set_world_typed(world_id: String, record: WorldRecord) -> void:
	_set_world(world_id, record.to_dict())


func _get_worlds_typed() -> Dictionary:
	var raw: Dictionary = _get_worlds()
	var result: Dictionary = {}
	for key in raw.keys():
		result[str(key)] = WorldRecordClass.from_dict(raw[key] as Dictionary)
	return result


func _set_worlds_typed(worlds: Dictionary) -> void:
	var raw: Dictionary = {}
	for key in worlds.keys():
		var wr: WorldRecord = worlds[key] as WorldRecord
		raw[str(key)] = wr.to_dict() if wr != null else {}
	_set_worlds(raw)


func _on_discovery_message(msg: String) -> void:
	last_discovery_text = msg


func _set_world(world_id: String, world: Dictionary) -> void:
	var worlds: Dictionary = _get_worlds()
	worlds[world_id] = world
	_set_worlds(worlds)


func _update_world_map_record(world_id: String, map_id: String, map_record: Dictionary, save_now: bool = false) -> void:
	var base_world: Dictionary = _get_world(world_id)
	var updated_world: Dictionary = GateTravelService.with_updated_map_record(base_world, map_id, map_record)
	var merged_worlds: Dictionary = GateTravelService.with_updated_world(_get_worlds(), world_id, updated_world)
	_set_worlds(merged_worlds)
	if save_now:
		_save_world_data()


func _backstory_text() -> String:
	return "The Atlas of Gates once held every world together, but it shattered during the Convergence Collapse. Fragments of reality drifted apart, each sealed behind a dormant gate.\n\nYou are the last field cartographer of the Celestial Survey, dispatched from the floating observatory to cross the gates, map the splintered territories, and reassemble the Atlas one discovery at a time.\n\nOn the far side of certain gates lies the Moon — a silent world of glass craters and drifting lichen, where ancient shrines float in the void. Pilgrims who reach them all earn the title Moon Pilgrim.\n\nThe Survey's old handbooks speak of a limit: no more than thirty-two maps can be opened from a single world before the local gate-network saturates. Choose your path wisely."


func _atlas_summary_text() -> String:
	var worlds: Dictionary = _get_worlds()
	var universe: Dictionary = _current_universe()
	var world_count: int = worlds.size()
	var map_count: int = 0
	var discovery_count: int = 0
	var pin_count: int = 0
	for world_key in worlds.keys():
		var world: Dictionary = worlds[world_key]
		var maps: Dictionary = world.get("maps", {})
		map_count += maps.size()
		for map_key in maps.keys():
			var map_record = maps[map_key]
			if typeof(map_record) != TYPE_DICTIONARY:
				continue
			var discoveries: Dictionary = map_record.get("discoveries", {})
			var pins: Dictionary = map_record.get("pins", {})
			discovery_count += discoveries.size()
			pin_count += pins.size()

	var current_completion: String = ""
	if current_map_id != "":
		current_completion = " Current map: " + _map_completion_text(current_map_id) + "."

	return "Universe: " + str(universe.get("name", current_universe_id)) + " | Atlas: " + str(world_count) + " worlds, " + str(map_count) + " maps, " + str(discovery_count) + " discoveries, " + str(pin_count) + " pins." + current_completion


func _store_current_map_available_discoveries() -> void:
	if current_world_id == "" or current_map_id == "":
		return

	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	map_record["available_discoveries"] = current_map_available_discoveries
	_update_world_map_record(current_world_id, current_map_id, map_record, true)


func _map_completion_text(map_id: String) -> String:
	if current_world_id == "":
		return "0%"

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var available: int = int(map_record.get("available_discoveries", 0))
	if available <= 0:
		return str(discoveries.size()) + " found"

	var percent: int = int(round(float(discoveries.size()) / float(available) * 100.0))
	return str(percent) + "% (" + str(discoveries.size()) + "/" + str(available) + ")"


func _short_id(id: String) -> String:
	if id.length() <= 8:
		return id
	return ".." + id.substr(id.length() - 6)


func _completion_text(found: int, available: int) -> String:
	if available <= 0:
		return str(found) + " found"
	var percent: int = int(round(float(found) / float(available) * 100.0))
	return str(percent) + "%"


func _atlas_graph_text() -> String:
	var worlds: Dictionary = _get_worlds()
	if worlds.is_empty():
		return "No worlds discovered yet."

	var lines: Array[String] = []
	for world_key in worlds.keys():
		var world_id: String = str(world_key)
		var world: Dictionary = worlds[world_id]
		var maps: Dictionary = world.get("maps", {})
		lines.append(str(world.get("name", world_id)) + " (" + str(maps.size()) + " maps)")

		for map_key in maps.keys():
			var map_id: String = str(map_key)
			var map_record: Dictionary = maps[map_id]
			var discoveries: Dictionary = map_record.get("discoveries", {})
			var pins: Dictionary = map_record.get("pins", {})
			var gates: Dictionary = map_record.get("gates", {})
			var marker: String = ""
			if world_id == current_world_id and map_id == current_map_id:
				marker = " <- current"

			lines.append("  " + _short_id(map_id) + marker + " | discoveries " + str(discoveries.size()) + " | pins " + str(pins.size()) + " | gates " + str(gates.size()) + "/" + str(GATE_COUNT))
			for gate_key in gates.keys():
				var target_map_id: String = str(gates[gate_key])
				lines.append("    gate " + str(int(str(gate_key)) + 1) + " -> " + _short_id(target_map_id))

		lines.append("")

	return "\n".join(lines)


func _opposite_gate_index(gate_index: int) -> int:
	return WorldGraph.opposite_gate_index(gate_index)


func _try_grab_lichen() -> void:
	if generated_root == null:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var player_pos: Vector3 = player.global_position
	var closest: Node3D = _find_closest_lichen(player_pos, 10.0)
	if closest != null:
		if closest.name == "ThrownLichen":
			if discovery_tracker != null: discovery_tracker.award_achievement("lichen_catcher")
		closest.queue_free()
		lichen_count += 1
		if is_instance_valid(player) and player.has_method(&"set"):
			player.set("lichen_count", lichen_count)
		last_discovery_text = "Grabbed lichen. Carry: " + str(lichen_count)
		if lichen_count >= 50:
			if discovery_tracker != null: discovery_tracker.award_achievement("collector_50")


func _throw_lichen() -> void:
	_begin_generation_channel("throw_lichen", lichen_count)
	if lichen_count <= 0:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return

	lichen_count -= 1
	if is_instance_valid(player) and player.has_method(&"set"):
		player.set("lichen_count", lichen_count)

	var body := RigidBody3D.new()
	body.name = "ThrownLichen"
	body.collision_layer = 1
	body.collision_mask = 1 | 2 | 4
	body.gravity_scale = 0.0
	body.linear_damp = 0.25
	body.angular_damp = 0.4
	body.mass = 0.2
	body.add_to_group("floating_lichen")

	var lichen_script: Script = preload("res://scripts/FloatingLichen.gd")
	body.set_script(lichen_script)
	body.set("rng_seed", _randi())

	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.75
	phys_mat.friction = 0.1
	body.physics_material_override = phys_mat

	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = _randf_range(0.4, 0.8)
	mesh.height = mesh.radius * _randf_range(0.55, 0.9)
	visual.mesh = mesh
	visual.scale = Vector3(_randf_range(1.0, 1.5), _randf_range(0.45, 0.8), _randf_range(1.0, 1.5))

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.82, 0.64)
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.42, 0.24)
	mat.emission_energy_multiplier = 0.85
	visual.material_override = mat
	body.add_child(visual)

	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = mesh.radius
	shape_node.shape = shape
	body.add_child(shape_node)

	var cam: Camera3D = player.camera
	var fwd: Vector3 = -cam.global_transform.basis.z
	var up: Vector3 = cam.global_transform.basis.y
	body.position = player.global_position + Vector3(0.0, 1.2, 0.0) + fwd * 2.5
	body.apply_impulse(fwd * 12.0 + up * 5.0)

	_add_generated_child(body)
	last_discovery_text = "Threw lichen. " + str(lichen_count) + " left."


func _place_cartography_pin() -> void:
	if current_world_id == "" or current_map_id == "":
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var pins: Dictionary = map_record.get("pins", {})
	var pin_index: int = pins.size() + 1
	while pins.has("pin_" + str(pin_index)):
		pin_index += 1
	var pin_id: String = "pin_" + str(pin_index)
	var pin_title: String = "Survey Pin " + str(pin_index)
	pins[pin_id] = DiscoveryRecordClass.new(
		pin_title,
		"pin",
		Time.get_unix_time_from_system(),
		player.global_position.x,
		player.global_position.z,
	).to_dict()
	map_record["pins"] = pins
	_update_world_map_record(current_world_id, current_map_id, map_record, true)
	last_discovery_text = "Placed " + pin_title + "."


func _find_closest_lichen(from: Vector3, max_dist: float) -> Node3D:
	if generated_root == null:
		return null
	var closest: Node3D = null
	var closest_dist: float = max_dist
	var stack: Array[Node] = [generated_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			if child is Node3D and child.is_in_group("floating_lichen") and is_instance_valid(child):
				var lichen := child as Node3D
				var dist: float = lichen.global_position.distance_to(from)
				if dist < closest_dist:
					closest_dist = dist
					closest = lichen
	return closest


func _return_to_gate_room() -> void:
	if current_world_id == "" or current_map_id == "":
		return
	var world: Dictionary = _get_world(current_world_id)
	if world.is_empty():
		return
	var src_world: String = str(world.get("gate_room_source_world", ""))
	var src_map: String = str(world.get("gate_room_source_map", ""))
	if src_world != "" and src_map != "":
		var gate_room_record: Dictionary = _get_map_record(src_world, src_map)
		if not gate_room_record.is_empty():
			gate_room_record["gate_room_return_world"] = current_world_id
			gate_room_record["gate_room_return_map"] = current_map_id
			_update_world_map_record(src_world, src_map, gate_room_record, true)
		last_discovery_text = "Returning to Gate Room."
		_load_map(src_world, src_map)


func _gate_target_seed(gate_index: int) -> int:
	if current_world_id == "":
		return _preview_gate_seed(gate_index)
	var world: Dictionary = _get_world(current_world_id)
	return GateTravelService.gate_target_seed(world_seed, current_map_id, world, gate_index)


func _preview_gate_seed(gate_index: int) -> int:
	var value: int = int((world_seed ^ ((gate_index + 1) * 747796405) ^ 2891336453) & 0x7fffffff)
	if value == 0:
		value = 12345 + gate_index
	return value


func _seed_color(seed_value: int, alpha: float = 1.0) -> Color:
	var hue: float = float(abs(seed_value) % 360) / 360.0
	return Color.from_hsv(hue, 0.72, 1.0, alpha)




func _add_box_collision(parent: Node3D, local_position: Vector3, size: Vector3) -> void:
	CollisionFactory.add_box(parent, local_position, size)


func _add_cylinder_collision(parent: Node3D, local_position: Vector3, radius: float, height: float) -> void:
	CollisionFactory.add_cylinder(parent, local_position, radius, height)


func _add_sphere_collision(parent: Node3D, local_position: Vector3, radius: float) -> void:
	CollisionFactory.add_sphere(parent, local_position, radius)


func _add_discovery_area(parent: Node3D, local_position: Vector3, radius: float, discovery_id: String, title: String, kind: String) -> void:
	current_map_available_discoveries += 1
	var discovery_position: Vector3 = parent.position + local_position

	var area := Area3D.new()
	area.name = "DiscoveryArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = local_position

	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	shape_node.shape = shape
	area.add_child(shape_node)
	area.body_entered.connect(_on_discovery_body_entered.bind(discovery_id, title, kind, discovery_position))
	parent.add_child(area)


func _height_at_world(wx: float, wz: float) -> float:
	return _active_map_context().height_at_world(wx, wz)


func _biome_value(wx: float, wz: float) -> float:
	return _active_map_context().biome_value(wx, wz)


func _river_distance(wx: float, wz: float) -> float:
	return _active_map_context().river_distance(wx, wz)


func _water_level() -> float:
	return _active_map_context().water_level


func _get_player() -> CharacterBody3D:
	if is_instance_valid(_player_ref):
		return _player_ref
	var player := find_child("Player", true, false)
	if player is CharacterBody3D:
		_player_ref = player as CharacterBody3D
		return _player_ref
	return null


func _recover_fallen_player() -> void:
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	if _ensure_player_above_surface(player):
		last_discovery_text = "Repositioned above terrain."
		return
	if player.global_position.y > -50.0:
		return
	player.global_position = _find_spawn_position()
	player.velocity = Vector3.ZERO


func _update_underwater_state() -> void:
	var player: CharacterBody3D = _get_player()
	if player == null or hud_controller == null:
		return
	hud_controller.update_underwater_state(
		_is_current_map_moon(),
		_is_current_map_gate_room(),
		player.camera,
	)


func _update_day_night_cycle() -> void:
	if sun_light == null or world_environment == null:
		return
	if _is_current_map_moon() or _is_current_map_water() or _is_current_map_cave():
		return

	var t: float = _cycle_time / CYCLE_LENGTH
	var hour: float = t * 24.0

	var sun_elevation: float
	var is_night: bool = false
	var is_dawn: bool = false
	var is_dusk: bool = false

	if hour < 5.5:
		sun_elevation = -1.0 + (hour / 5.5)
		is_night = true
	elif hour < 7.0:
		sun_elevation = lerp(-1.0, 0.0, (hour - 5.5) / 1.5)
		is_dawn = true
	elif hour < 17.0:
		sun_elevation = sin(((hour - 7.0) / 10.0) * PI * 0.5)
	elif hour < 18.5:
		sun_elevation = cos(((hour - 17.0) / 1.5) * PI * 0.5)
		is_dusk = true
	else:
		sun_elevation = -(hour - 18.5) / 5.5
		is_night = true

	sun_elevation = clamp(sun_elevation, -1.0, 1.0)
	sun_light.rotation_degrees.x = lerp(-90.0, 90.0, (sun_elevation + 1.0) * 0.5)

	var sun_base: Color = _sun_color_for_world()

	if is_night and not is_dawn:
		sun_light.light_energy = 0.02
		world_environment.ambient_light_energy = 0.025
		world_environment.ambient_light_color = Color(0.02, 0.02, 0.04)
		world_environment.fog_density = 0.002
		world_environment.fog_light_color = Color(0.005, 0.005, 0.01)
		_set_sky_cycle_colors(Color(0.005, 0.005, 0.02), Color(0.02, 0.02, 0.06), Color(0.01, 0.01, 0.02))
		sun_light.light_color = Color(0.08, 0.09, 0.18)
	elif is_dawn:
		var p: float = 0.0
		if hour >= 5.5 and hour < 6.0:
			p = (hour - 5.5) / 0.5
		elif hour >= 6.0 and hour < 7.0:
			p = 0.5 + (hour - 6.0) * 0.5
		else:
			p = 1.0 if hour >= 7.0 else 0.0
		p = clamp(p, 0.0, 1.0)
		sun_light.light_energy = lerp(0.02, 2.8, p)
		world_environment.ambient_light_energy = lerp(0.025, 0.65, p)
		world_environment.ambient_light_color = Color(0.04, 0.04, 0.08).lerp(Color(0.65, 0.58, 0.52), p)
		world_environment.fog_density = lerp(0.002, 0.002, p)
		world_environment.fog_light_color = Color(0.01, 0.01, 0.02).lerp(Color(0.70, 0.55, 0.42), p)
		_set_sky_cycle_colors(
			Color(0.005, 0.005, 0.02).lerp(Color(0.72, 0.62, 0.55), p),
			Color(0.005, 0.005, 0.02).lerp(Color(0.82, 0.72, 0.65), p),
			Color(0.005, 0.005, 0.02).lerp(Color(0.70, 0.55, 0.42), p))
		sun_light.light_color = Color(0.15, 0.18, 0.35).lerp(sun_base, p)
	elif is_dusk:
		var p: float = 1.0 - clamp((hour - 17.0) / 1.5, 0.0, 1.0)
		p = 1.0 - p * p
		sun_light.light_energy = lerp(1.4, 0.03, p)
		world_environment.ambient_light_energy = lerp(0.30, 0.03, p)
		world_environment.ambient_light_color = Color(0.65, 0.55, 0.48).lerp(Color(0.04, 0.04, 0.08), p)
		world_environment.fog_density = lerp(0.002, 0.002, p)
		world_environment.fog_light_color = Color(0.72, 0.50, 0.38).lerp(Color(0.01, 0.01, 0.02), p)
		_set_sky_cycle_colors(
			Color(0.65, 0.48, 0.38).lerp(Color(0.005, 0.005, 0.02), p),
			Color(0.78, 0.58, 0.45).lerp(Color(0.005, 0.005, 0.02), p),
			Color(0.72, 0.50, 0.38).lerp(Color(0.01, 0.01, 0.02), p))
		sun_light.light_color = sun_base.lerp(Color(0.65, 0.30, 0.15), p)
	else:
		var midday: float = cos((hour - 12.0) * PI / 10.0) * 0.08
		var energy: float = 2.5 + midday
		sun_light.light_energy = energy
		world_environment.ambient_light_energy = 0.65 + midday * 0.5
		world_environment.ambient_light_color = Color(0.65, 0.68, 0.72)
		world_environment.fog_density = 0.002
		world_environment.fog_light_color = Color(0.65, 0.75, 0.85)
		_set_sky_cycle_colors(
			Color(0.55, 0.72, 0.95),
			Color(0.72, 0.82, 0.90),
			Color(0.65, 0.75, 0.85))
		sun_light.light_color = sun_base

	if generated_root != null:
		var sun_disc: Node3D = generated_root.get_node_or_null("SunDisc") as Node3D
		if sun_disc != null:
			sun_disc.visible = not is_night
		var sun_glow: Node3D = generated_root.get_node_or_null("SunGlow") as Node3D
		if sun_glow != null:
			sun_glow.visible = not is_night
		var cloud_root: Node3D = generated_root.get_node_or_null("SkyClouds") as Node3D
		if cloud_root != null:
			cloud_root.visible = not is_night

	if sun_light != null:
		sun_light.visible = not is_night


func _update_hud(delta: float = 0.0) -> void:
	if hud_controller == null:
		return
	var player: CharacterBody3D = _get_player()
	var map_short: String = "none"
	if current_map_id.length() > 8:
		map_short = current_map_id.substr(0, 8)
	elif current_map_id != "":
		map_short = current_map_id

	var position_text: String = "No active player"
	var warning_text: String = ""
	var stamina: float = -1.0
	var breath: float = -1.0
	if player != null:
		var half: float = _world_half_size()
		var distance_to_edge: float = half - max(abs(player.global_position.x), abs(player.global_position.z))
		position_text = "Position: " + str(int(player.global_position.x)) + ", " + str(int(player.global_position.z)) + " | edge " + str(max(int(distance_to_edge), 0)) + "m"
		if hud_controller.is_underwater:
			warning_text = "Underwater: Space swims upward"
		elif distance_to_edge < 18.0:
			warning_text = "Edge barrier nearby"
		stamina = float(player.get("sprint_stamina")) if player.get("sprint_stamina") != null else -1.0
		breath = float(player.get("breath")) if player.get("breath") != null else -1.0
	if not _is_current_map_gate_room() and not _is_current_map_map_nexus() and _gate_debug_line != "":
		if warning_text != "":
			warning_text += " | "
		warning_text += _gate_debug_line

	var flashlight_text: String = ""
	if player != null and player.get("flashlight_on") != null:
		var f_on: bool = bool(player.get("flashlight_on"))
		if f_on:
			var f_charge: float = float(player.get("flashlight_charge"))
			flashlight_text = "Flashlight: " + str(int(f_charge)) + "s"
		else:
			flashlight_text = "[F] Flashlight"

	var world_name: String = "?"
	var gate_room_return_world: String = ""
	var gate_room_source_world: String = ""
	var gate_room_source_map: String = ""
	if current_world_id != "":
		var w: Dictionary = _get_world(current_world_id)
		world_name = str(w.get("name", current_world_id))
		gate_room_source_world = str(w.get("gate_room_source_world", ""))
		gate_room_source_map = str(w.get("gate_room_source_map", ""))
	if _is_current_map_gate_room():
		gate_room_return_world = str(_get_map_record(current_world_id, current_map_id).get("gate_room_return_world", ""))

	var discovery_line: String = last_discovery_text
	if discovery_line == "":
		discovery_line = "Seek gates, ruins, and wonders."
	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	var objective_line: String = _next_objective_hint(map_record)
	var progression_line: String = _progression_hint(map_record)
	var world_map_count: int = discovery_tracker.current_world_map_count() if discovery_tracker != null else 0
	var maps_line: String = "Maps in world: " + str(world_map_count)
	var map_type: String = str(map_record.get("type", ""))
	var recent_discoveries: Array[String] = _recent_discovery_titles(map_record.get("discoveries", {}), 3)
	hud_controller.update({
		"delta": delta,
		"map_short": map_short,
		"world_name": world_name,
		"map_type": map_type,
		"position_text": position_text,
		"warning_text": warning_text,
		"flashlight_text": flashlight_text,
		"discovery_line": discovery_line,
		"objective_line": objective_line,
		"progression_line": progression_line,
		"recent_discoveries": recent_discoveries,
		"maps_line": maps_line,
		"atlas_summary": _atlas_summary_text(),
		"map_completion": _map_completion_text(current_map_id),
		"lichen_count": lichen_count,
		"current_map_id": current_map_id,
		"discoveries": map_record.get("discoveries", {}),
		"wonder_positions": _wonder_positions,
		"pins": map_record.get("pins", {}),
		"pin_count": map_record.get("pins", {}).size(),
		"is_gate_room": _is_current_map_gate_room(),
		"is_map_nexus": _is_current_map_map_nexus(),
		"gate_room_return_world": map_record.get("gate_room_return_world", ""),
		"gate_room_source_world": gate_room_source_world,
		"gate_room_source_map": gate_room_source_map,
		"stamina": stamina,
		"breath": breath,
		"player_node": player,
		"world_half_size": _world_half_size(),
		"minimap_zoom": 1.15 if _is_current_map_moon() else 1.0,
	})


func _next_objective_hint(map_record: Dictionary) -> String:
	if _is_current_map_gate_room():
		return "Objective: Enter a world gate to chart another map."
	if _is_current_map_map_nexus():
		return "Objective: Select a nexus gate to branch your atlas route."
	if _is_current_map_moon():
		var discoveries: Dictionary = map_record.get("discoveries", {})
		var shrine_count: int = 0
		for key in discoveries.keys():
			if str(key).begins_with("moon_orb_"):
				shrine_count += 1
		if shrine_count < 9:
			return "Objective: Recover moon shrine orbs (" + str(shrine_count) + "/9)."
		return "Objective: Return through a gate and continue atlas expansion."

	var available: int = int(map_record.get("available_discoveries", 0))
	var found: int = map_record.get("discoveries", {}).size()
	if available > 0 and found < available:
		return "Objective: Find remaining discoveries on this map (" + str(found) + "/" + str(available) + ")."
	if found <= 0:
		return "Objective: Find your first discovery on this map."
	var route_hint: String = _linked_route_hint(map_record)
	if route_hint != "":
		return route_hint

	var world_map_count: int = discovery_tracker.current_world_map_count() if discovery_tracker != null else 0
	if world_map_count < 5:
		return "Objective: Traverse gates and expand this world atlas (" + str(world_map_count) + " maps)."
	return "Objective: Use gates to reach rare biomes and hidden routes."


func _progression_hint(map_record: Dictionary) -> String:
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var found: int = discoveries.size()
	var world_map_count: int = discovery_tracker.current_world_map_count() if discovery_tracker != null else 0
	var universe: Dictionary = _current_universe()
	var achievements: Dictionary = universe.get("achievements", {})
	var achieved: int = achievements.size()
	if found < 3:
		return "Progress: Early survey - secure 3 discoveries on this map."
	if world_map_count < 3:
		return "Progress: Cartographer I - chart 3 maps in this world."
	if achieved < 5:
		return "Progress: Expeditioner - unlock 5 achievements."
	return "Progress: Deep expedition - pursue moon shrines and world saturation routes."


func _linked_route_hint(map_record: Dictionary) -> String:
	if current_world_id == "":
		return ""
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var gates: Dictionary = map_record.get("gates", {})
	var best_target_id: String = ""
	var best_remaining: int = -1
	for gate_key in gates.keys():
		var target_id: String = str(gates[gate_key])
		if target_id == "" or not maps.has(target_id):
			continue
		var target_record: Dictionary = maps.get(target_id, {})
		if target_record.is_empty():
			continue
		var available: int = int(target_record.get("available_discoveries", 0))
		if available <= 0:
			continue
		var found: int = target_record.get("discoveries", {}).size()
		var remaining: int = max(available - found, 0)
		if remaining <= 0:
			continue
		if best_target_id == "" or remaining > best_remaining:
			best_target_id = target_id
			best_remaining = remaining
	if best_target_id != "":
		return "Objective: Route through linked map " + _short_id(best_target_id) + " (" + str(best_remaining) + " discoveries remaining)."
	return ""


func _recent_discovery_titles(discoveries: Dictionary, max_count: int) -> Array[String]:
	var rows: Array = []
	for dk in discoveries.keys():
		var raw = discoveries[dk]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw
		rows.append({
			"title": str(d.get("title", "")),
			"found_at": int(d.get("found_at", 0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("found_at", 0)) > int(b.get("found_at", 0))
	)
	var out: Array[String] = []
	for i in range(min(max_count, rows.size())):
		var title: String = str(rows[i].get("title", ""))
		if title != "":
			out.append(title)
	return out


func _is_current_map_gate_room() -> bool:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return str(raw.get("type", "")) == WorldGraph.MAP_GATE_ROOM


func _is_current_map_moon() -> bool:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return str(raw.get("type", "")) == WorldGraph.MAP_MOON


func _is_current_map_water() -> bool:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return str(raw.get("type", "")) == WorldGraph.MAP_WATER


func _is_current_map_cave() -> bool:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return str(raw.get("type", "")) == WorldGraph.MAP_CAVE


func _is_current_map_arctic() -> bool:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return str(raw.get("type", "")) == WorldGraph.MAP_ARCTIC


func _is_current_map_map_nexus() -> bool:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return str(raw.get("type", "")) == WorldGraph.MAP_NEXUS


func _current_map_type() -> String:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return WorldGraph.map_type_from_dict(raw)


func _active_map_context() -> MapContext:
	if map_context == null:
		_setup_noise(_current_map_type())
	return map_context


func _moon_seed(world: Dictionary) -> int:
	return int((world_seed ^ 0x4D4F4F4E) & 0x7fffffff)


func _on_discovery_body_entered(body: Node3D, discovery_id: String, title: String, kind: String, discovery_position: Vector3) -> void:
	if body.name == "Player" and discovery_tracker != null:
		discovery_tracker.record_discovery(discovery_id, title, kind, discovery_position)


func _load_map(world_id: String, map_id: String) -> void:
	_gate_transition_in_progress = false
	_gate_overlap_active.clear()
	_gate_proximity_active.clear()
	_gate_room_slot_active.clear()
	_gate_room_return_active = false
	_last_gate_index_in_range = -1
	_gate_room_slot_in_range = -1
	_gate_room_return_in_range = false
	_gate_use_was_pressed = Input.is_key_pressed(KEY_E)
	_gate_trigger_enable_time_msec = Time.get_ticks_msec() + 300
	_gate_auto_retry_time_msec = _gate_trigger_enable_time_msec
	_gate_auto_cooldown_until_msec = _gate_trigger_enable_time_msec
	_close_menu()
	current_world_id = world_id
	current_map_id = map_id
	_wonder_positions.clear()
	if atlas_view != null:
		atlas_view.current_world_id = world_id
		atlas_view.current_map_id = map_id
	if discovery_tracker != null:
		discovery_tracker.current_world_id = world_id
		discovery_tracker.current_map_id = map_id

	var world: Dictionary = _get_world(world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_value = maps.get(map_id, {})
	var map_record: Dictionary = map_value if typeof(map_value) == TYPE_DICTIONARY else {}
	if map_record.is_empty():
		push_error("Missing map record: " + map_id)
		return

	world["current_map"] = map_id
	_set_world(world_id, world)
	_set_last_world_id(world_id)
	_save_world_data()

	var map_type: String = WorldGraph.map_type_from_dict(map_record)
	_moon_grid_scale = 2 if map_type == WorldGraph.MAP_MOON else 1
	world_seed = int(map_record.get("seed", 12345))
	_setup_noise(map_type)
	_begin_generation_channel("map")
	current_map_available_discoveries = 0
	_clear_generated_map()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedMap"
	add_child(generated_root)
	_apply_map_atmosphere()
	_apply_graphics_level()
	AudioManager.setup_music(generated_root, generation_rng)
	_create_visible_sun()

	var gen := MapGenerator.new({
		"world_seed": world_seed,
		"graphics_level": graphics_level,
		"density_level": density_level,
		"map_type": map_type,
		"map_context": map_context,
	})
	gen.generate(generated_root)

	_spawn_player()

	if _is_current_map_gate_room():
		GateFactory.scatter_gate_room_gates(generated_root, 4, _on_gate_room_gate_body_entered)
		GateFactory.scatter_gate_room_return_portal(generated_root, _on_gate_room_return_body_entered)
	elif _is_current_map_cave():
		GateFactory.scatter_cave_items(generated_root, world_seed)
		_begin_generation_channel("gates")
		var target_seeds: Array[int] = []
		for gi in range(GATE_COUNT):
			target_seeds.append(_gate_target_seed(gi))
		GateFactory.create_gates(generated_root, world_seed, target_seeds, map_context, _on_gate_body_entered)
		_gate_positions_to_wonders()
	elif _is_current_map_map_nexus():
		GateFactory.scatter_map_nexus_gates(generated_root, 4, _on_map_nexus_gate_body_entered)
	else:
		if _is_current_map_arctic():
			AudioManager.setup_arctic_audio(generated_root)
		if _is_current_map_water():
			AudioManager.setup_water_audio(generated_root)
		if _is_current_map_moon():
			AudioManager.setup_moon_audio(generated_root)
			_scatter_moon_lichen()
			_scatter_moon_glass_craters()
			_scatter_moon_platforms()
		elif _is_current_map_arctic():
			_scatter_arctic_trees()
			_scatter_rocks()
			_scatter_crystals()
			_scatter_ruins()
			_spawn_wonders()
		elif _is_current_map_water():
			_scatter_bird_flocks()
			_scatter_rocks()
			_scatter_crystals()
			_scatter_ruins()
			_scatter_underwater_plants()
			_scatter_fish_schools()
		else:
			_scatter_trees()
			_scatter_rocks()
			_scatter_crystals()
			_scatter_ruins()
			_scatter_flowers()
			_spawn_wonders()
		_begin_generation_channel("gates")
		var target_seeds: Array[int] = []
		for gi in range(GATE_COUNT):
			target_seeds.append(_gate_target_seed(gi))
		GateFactory.create_gates(generated_root, world_seed, target_seeds, map_context, _on_gate_body_entered)
		_gate_positions_to_wonders()
	_store_current_map_available_discoveries()

	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		pass
	else:
		_add_environment_collision()

	if discovery_tracker != null:
		discovery_tracker.check_map_visit_achievements()
	if _is_current_map_moon() and discovery_tracker != null:
		discovery_tracker.award_achievement("moon_visitor")
	if _is_current_map_gate_room() and discovery_tracker != null:
		discovery_tracker.award_achievement("gate_room_finder")
	if _is_current_map_water() and discovery_tracker != null:
		discovery_tracker.award_achievement("island_hopper")
	if _is_current_map_arctic() and discovery_tracker != null:
		discovery_tracker.award_achievement("arctic_explorer")
	if _is_current_map_cave() and discovery_tracker != null:
		discovery_tracker.award_achievement("cavern_explorer")


func _clear_generated_map() -> void:
	if generated_root != null:
		generated_root.queue_free()
		generated_root = null
	_gate_overlap_active.clear()
	_gate_proximity_active.clear()
	_gate_room_slot_active.clear()
	_gate_room_return_active = false
	_gate_room_slot_in_range = -1
	_gate_room_return_in_range = false
	_gate_transition_in_progress = false
	_clear_factory_caches()


func _clear_factory_caches() -> void:
	TreeFactory.clear_cache()
	RockFactory.clear_cache()
	CrystalFactory.clear_cache()
	FlowerFactory.clear_cache()
	UnderwaterPlantFactory.clear_cache()
	GateFactory.clear_cache()


func _add_generated_child(node: Node) -> void:
	if generated_root != null:
		generated_root.add_child(node)
	else:
		add_child(node)


func _setup_noise(map_type: String = "") -> void:
	var resolved_map_type: String = map_type
	if resolved_map_type == "":
		resolved_map_type = _current_map_type()
	map_context = MapContext.new({
		"world_seed": world_seed,
		"map_type": resolved_map_type,
		"grid_size": GRID_SIZE,
		"cell_size": CELL_SIZE,
		"water_level": WATER_LEVEL,
		"height_scale": HEIGHT_SCALE,
		"moon_grid_scale": _moon_grid_scale,
	})
	noise = map_context.noise


func _setup_environment() -> void:
	if world_environment_node != null:
		world_environment_node.queue_free()
		world_environment_node = null
	if sun_light != null:
		sun_light.queue_free()
		sun_light = null

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 3.0
	sun_light = sun
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.78, 0.86)
	env.ambient_light_energy = 0.8
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.72
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.88
	world_environment = env

	world_environment_node = WorldEnvironment.new()
	world_environment_node.name = "WorldEnvironment"
	world_environment_node.environment = env
	add_child(world_environment_node)

	if _is_current_map_cave():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.005, 0.004, 0.010)
		world_environment.ambient_light_color = Color(0.08, 0.06, 0.14)
		world_environment.ambient_light_energy = 0.25
		world_environment.fog_density = 0.06
		world_environment.fog_light_color = Color(0.02, 0.01, 0.04)
		if sun_light != null:
			sun_light.light_color = Color(0.10, 0.06, 0.20)
			sun_light.light_energy = 0.3
			sun_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	elif _is_current_map_gate_room() or _is_current_map_map_nexus():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.008, 0.010, 0.020)
		world_environment.ambient_light_color = Color(0.38, 0.30, 0.52)
		world_environment.ambient_light_energy = 0.78
		world_environment.fog_density = 0.002
		world_environment.fog_light_color = Color(0.34, 0.24, 0.46)
		if sun_light != null:
			if _is_current_map_map_nexus():
				sun_light.light_color = Color(0.70, 0.60, 1.0)
				sun_light.light_energy = 2.2
			else:
				sun_light.light_color = Color(0.60, 0.50, 0.90)
				sun_light.light_energy = 1.5
	elif _is_current_map_moon():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.006, 0.008, 0.020)
		world_environment.ambient_light_color = Color(0.12, 0.14, 0.20)
		world_environment.ambient_light_energy = 0.24
		world_environment.fog_density = 0.0
		world_environment.fog_light_color = Color(0.12, 0.14, 0.20)
		if sun_light != null:
			sun_light.light_color = Color(0.78, 0.86, 1.0)
			sun_light.light_energy = 0.95
			sun_light.rotation_degrees = Vector3(-28.0, -62.0, 0.0)
	elif _is_current_map_arctic():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.68, 0.78, 0.92)
		world_environment.ambient_light_color = Color(0.55, 0.62, 0.82)
		world_environment.ambient_light_energy = 0.65
		world_environment.fog_density = 0.004
		world_environment.fog_light_color = Color(0.60, 0.72, 0.90)
		if sun_light != null:
			sun_light.light_color = Color(0.78, 0.82, 1.0)
			sun_light.light_energy = 1.8
			sun_light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	elif _is_current_map_water():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.45, 0.65, 0.88)
		world_environment.ambient_light_color = Color(0.55, 0.70, 0.82)
		world_environment.ambient_light_energy = 0.75
		world_environment.fog_density = 0.001
		world_environment.fog_light_color = Color(0.50, 0.68, 0.82)
		if sun_light != null:
			sun_light.light_color = _sun_color_for_world()
			sun_light.light_energy = 2.6
			sun_light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	else:
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.55, 0.72, 0.95)
		world_environment.ambient_light_color = Color(0.7, 0.78, 0.86)
		world_environment.ambient_light_energy = 0.58
		world_environment.fog_density = 0.001
		world_environment.fog_light_color = Color(0.65, 0.75, 0.85)
		if sun_light != null:
			sun_light.light_color = Color(1.0, 0.95, 0.85)
			sun_light.light_energy = 1.6
			sun_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)


func _apply_map_atmosphere() -> void:
	_setup_environment()
	_update_day_night_cycle()


func _set_sky_cycle_colors(sky_top: Color, sky_horizon: Color, ground_horizon: Color) -> void:
	if world_environment == null:
		return
	world_environment.background_color = sky_horizon


func _sun_color_for_world() -> Color:
	var world: Dictionary = _get_world(current_world_id)
	if world.is_empty():
		return Color.WHITE

	var root_map_id: String = str(world.get("root_map", ""))
	var maps: Dictionary = world.get("maps", {})
	var root_record: Dictionary = maps.get(root_map_id, {})
	var root_seed: int = int(root_record.get("seed", 12345))
	var hue: float = float(abs(root_seed) % 360) / 360.0
	if hue > 0.16 and hue < 0.50:
		hue = 0.08 + float(abs(root_seed * 7) % 80) / 1000.0
	return Color.from_hsv(hue, 0.25, 1.0)


func _world_half_size() -> float:
	return _active_map_context().world_half_size()


func _scatter_trees() -> void:
	_begin_generation_channel("trees")
	TreeFactory.scatter_trees(generated_root, world_seed, density_level, graphics_level, map_context)


func _scatter_arctic_trees() -> void:
	_begin_generation_channel("trees")
	TreeFactory.scatter_trees(generated_root, world_seed, density_level, graphics_level, map_context, 0.12)


func _scatter_rocks() -> void:
	_begin_generation_channel("rocks")
	RockFactory.scatter_rocks(generated_root, world_seed, density_level, map_context)


func _scatter_crystals() -> void:
	_begin_generation_channel("crystals")
	CrystalFactory.scatter_crystals(generated_root, world_seed, density_level, map_context)


func _scatter_ruins() -> void:
	_begin_generation_channel("ruins")
	RuinFactory.scatter_ruins(generated_root, world_seed, density_level, map_context)


func _scatter_flowers() -> void:
	_begin_generation_channel("flowers")
	FlowerFactory.scatter_flowers(generated_root, world_seed, density_level, map_context)


func _scatter_bird_flocks() -> void:
	_begin_generation_channel("birds")
	CreatureFactory.scatter_birds(generated_root, world_seed, map_context)


func _scatter_fish_schools() -> void:
	_begin_generation_channel("fish")
	CreatureFactory.scatter_fish(generated_root, world_seed, map_context)


func _scatter_underwater_plants() -> void:
	_begin_generation_channel("underwater_plants")
	UnderwaterPlantFactory.scatter_plants(generated_root, world_seed, density_level, map_context)


func _scatter_moon_lichen() -> void:
	_begin_generation_channel("moon_lichen")
	MoonFeatureFactory.scatter_lichen(generated_root, world_seed, map_context)


func _scatter_moon_glass_craters() -> void:
	_begin_generation_channel("moon_craters")
	MoonFeatureFactory.scatter_glass_craters(generated_root, world_seed, map_context)


var _wonder_positions: Array = []


func _gate_positions_to_wonders() -> void:
	var max_dist: float = _world_half_size() * 0.72
	var dirs: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	for i in range(dirs.size()):
		var d: Vector3 = dirs[i]
		var gx: float = d.x * max_dist
		var gz: float = d.z * max_dist
		_wonder_positions.append({"x": gx, "z": gz, "kind": "gate", "id": "gate_" + str(i), "title": "Gate " + str(i + 1)})


func _add_environment_collision() -> void:
	if generated_root == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_find_loose_meshes(generated_root, meshes)
	for mi in meshes:
		if mi.mesh == null:
			continue
		var aabb: AABB = mi.mesh.get_aabb()
		if mi.name == "GeneratedTerrain" or mi.name == "RiverAndLakeWater" or mi.name == "SkyClouds" or mi.name == "CloudLayerNear" or mi.name == "CloudLayerFar":
			continue
		if aabb.size.x > 80.0 and aabb.size.z > 80.0:
			continue
		if aabb.size.length() < 1.0:
			continue
		var body := StaticBody3D.new()
		body.name = mi.name + "_AutoCol"
		body.collision_layer = 1
		body.collision_mask = 1
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size
		col.shape = box
		col.position = aabb.position + aabb.size * 0.5
		body.add_child(col)
		body.transform = mi.transform
		mi.get_parent().add_child(body)


func _find_loose_meshes(parent: Node, out: Array) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D:
			var p = child.get_parent()
			if p != null and (p is StaticBody3D or p is Area3D):
				continue
			out.append(child)
		elif child is Node3D:
			_find_loose_meshes(child, out)


func _spawn_wonders() -> void:
	_wonder_positions.clear()
	var half: float = _world_half_size()
	var min_cell: int = int(floor(-half / WONDER_CELL_SIZE))
	var max_cell: int = int(ceil(half / WONDER_CELL_SIZE))

	for cell_z in range(min_cell, max_cell + 1):
		for cell_x in range(min_cell, max_cell + 1):
			if not WonderGenerator.cell_has_wonder(world_seed, cell_x, cell_z, WONDER_CHANCE):
				continue
			var wonder_pos: Vector3 = WonderGenerator.get_cell_wonder_position(world_seed, cell_x, cell_z, Callable(map_context, "height_at_world"), WONDER_CELL_SIZE)
			if abs(wonder_pos.x) > half - 28.0 or abs(wonder_pos.z) > half - 28.0:
				continue
			if wonder_pos.y < _water_level() + 0.4 or _river_distance(wonder_pos.x, wonder_pos.z) < 9.0:
				continue
			if wonder_pos.distance_to(Vector3.ZERO) < 25.0:
				continue

			var wonder: Node3D = WonderGenerator.create_wonder(world_seed, wonder_pos, 0, true)
			var discovery_id: String = "wonder_" + str(cell_x) + "_" + str(cell_z)
			var title: String = _wonder_title(wonder.name)
			var wonder_kind: String = "crystal" if title == "Crystal Spire" else "wonder"
			_wonder_positions.append({"x": wonder_pos.x, "z": wonder_pos.z, "kind": wonder_kind, "id": discovery_id, "title": title})
			_add_discovery_area(wonder, Vector3(0.0, 2.0, 0.0), 12.0, discovery_id, title, wonder_kind)
			if title == "Moon Gate":
				MoonGateFactory.add_moon_gate_trigger(wonder, _on_moon_gate_body_entered)
			_add_generated_child(wonder)


func _wonder_title(wonder_name: String) -> String:
	if wonder_name.contains("moon_gate"):
		return "Moon Gate"
	if wonder_name.contains("crystal_spire"):
		return "Crystal Spire"
	if wonder_name.contains("runestone_circle"):
		return "Runestone Circle"
	if wonder_name.contains("floating_shrine"):
		return "Floating Shrine"
	return "Uncatalogued Wonder"


func _on_moon_gate_body_entered(body: Node3D) -> void:
	if body.name != "Player" or current_world_id == "" or _is_current_map_moon():
		return

	moon_map_return_map_id = current_map_id
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	if not maps.has("moon"):
		_update_world_map_record(current_world_id, "moon", _create_moon_map_record(_moon_seed(world)).to_dict(), true)

	_load_map(current_world_id, "moon")


func _scatter_moon_platforms() -> void:
	_begin_generation_channel("moon_platforms")
	var rng := StableRng.new(StableRng.mix_string(world_seed, "moon_platforms"))
	var platform_root := Node3D.new()
	platform_root.name = "MoonPlatforms"
	generated_root.add_child(platform_root)

	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.18, 0.19, 0.24)
	platform_mat.roughness = 0.70

	var half: float = _world_half_size() * 0.88
	for i in range(MOON_SHRINE_COUNT):
		var pos: Vector3 = _random_position(rng, half)
		var platform := MeshInstance3D.new()
		platform.name = "MoonPlatform_" + str(i)
		var platform_mesh := BoxMesh.new()
		platform_mesh.size = Vector3(rng.randf_range(3.0, 8.0), rng.randf_range(0.15, 0.25), rng.randf_range(3.0, 8.0))
		platform.mesh = platform_mesh
		platform.material_override = platform_mat
		platform.position = pos + Vector3(0.0, rng.randf_range(0.8, 2.5), 0.0)
		platform_root.add_child(platform)

		var orb_body := Area3D.new()
		orb_body.name = "ShrineOrb_" + str(i)
		orb_body.collision_layer = 0
		orb_body.collision_mask = 2
		var orb_shape := CollisionShape3D.new()
		var orb_sphere := SphereShape3D.new()
		orb_sphere.radius = 1.2
		orb_shape.shape = orb_sphere
		orb_body.add_child(orb_shape)
		orb_body.position = platform.position + Vector3(0.0, 1.5, 0.0)
		orb_body.body_entered.connect(_on_orb_collected.bind(i, orb_body))
		platform_root.add_child(orb_body)

		var orb_visual := MeshInstance3D.new()
		var orb_mesh := SphereMesh.new()
		orb_mesh.radius = 0.20
		orb_mesh.height = 0.40
		orb_visual.mesh = orb_mesh
		var orb_mat := StandardMaterial3D.new()
		orb_mat.albedo_color = Color(1.0, 0.88, 0.28)
		orb_mat.emission_enabled = true
		orb_mat.emission = Color(0.70, 0.45, 0.08)
		orb_mat.emission_energy_multiplier = 1.5
		orb_visual.material_override = orb_mat
		orb_body.add_child(orb_visual)


func _random_position(rng: StableRng, half: float) -> Vector3:
	for attempt in range(18):
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = _height_at_world(x, z)
		if y >= -10.0:
			return Vector3(x, y, z)
	return Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))


func _on_orb_collected(body: Node3D, platform_index: int, orb_body: Area3D) -> void:
	if body.name != "Player" or discovery_tracker == null:
		return
	if not _is_current_map_moon():
		return
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var key: String = "moon_orb_" + str(platform_index)
	if discoveries.has(key):
		if orb_body != null:
			orb_body.queue_free()
		return
	discovery_tracker.record_discovery(key, "Shrine " + str(platform_index + 1) + " Orb", "orb", body.global_position)
	if orb_body != null:
		orb_body.queue_free()
	print("Moon orb ", platform_index, " collected")


func _on_gate_room_gate_body_entered(body: Node3D, slot_index: int) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		return
	if not _is_current_map_gate_room():
		return

	var worlds: Dictionary = _get_worlds()
	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	var gate_room_result: Dictionary = GateTravelService.resolve_gate_room_slot(
		world_seed,
		current_world_id,
		current_map_id,
		slot_index,
		worlds,
		map_record,
		Callable(self, "_new_id"),
		Callable(self, "_create_world_record_dict")
	)
	if not bool(gate_room_result.get("ok", false)):
		return
	var updated_worlds: Dictionary = gate_room_result.get("worlds", worlds)
	var updated_map_record: Dictionary = gate_room_result.get("current_map_record", map_record)
	var updated_world: Dictionary = GateTravelService.with_updated_map_record(_get_world(current_world_id), current_map_id, updated_map_record)
	var merged_worlds: Dictionary = GateTravelService.with_updated_world(updated_worlds, current_world_id, updated_world)
	_set_worlds(merged_worlds)
	if bool(gate_room_result.get("changed", false)):
		_save_world_data()
	var target_world_id: String = str(gate_room_result.get("target_world_id", ""))
	var target_map_id: String = str(gate_room_result.get("target_map_id", ""))
	if target_world_id == "" or target_map_id == "":
		return
	last_discovery_text = str(gate_room_result.get("message", ""))
	_load_map(target_world_id, target_map_id)


func _on_gate_room_return_body_entered(body: Node3D) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		return
	if not _is_current_map_gate_room():
		return

	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	var return_result: Dictionary = GateTravelService.resolve_gate_room_return(map_record)
	if not bool(return_result.get("ok", false)) or not bool(return_result.get("has_return", false)):
		last_discovery_text = "No active return portal."
		return
	var target_world_id: String = str(return_result.get("target_world_id", ""))
	var target_map_id: String = str(return_result.get("target_map_id", ""))
	if target_world_id == "" or target_map_id == "":
		last_discovery_text = "Return portal is unlinked."
		return
	map_record["gate_room_return_world"] = ""
	map_record["gate_room_return_map"] = ""
	_update_world_map_record(current_world_id, current_map_id, map_record, true)
	last_discovery_text = str(return_result.get("message", "Returning from Gate Room."))
	_load_map(target_world_id, target_map_id)


func _on_map_nexus_gate_body_entered(body: Node3D, slot_index: int) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		return
	if not _is_current_map_map_nexus():
		return

	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	var universe: Dictionary = _current_universe()
	var all_worlds: Dictionary = universe.get("worlds", {})
	var nexus_result: Dictionary = GateTravelService.resolve_nexus_slot(
		world_seed,
		current_world_id,
		current_map_id,
		slot_index,
		map_record,
		all_worlds
	)
	if not bool(nexus_result.get("ok", false)) or bool(nexus_result.get("skip", false)):
		return
	var updated_map_record: Dictionary = nexus_result.get("current_map_record", map_record)
	_update_world_map_record(current_world_id, current_map_id, updated_map_record, bool(nexus_result.get("changed", false)))
	if bool(nexus_result.get("changed", false)):
		pass
	var target_world_id: String = str(nexus_result.get("target_world_id", ""))
	var target_map_id: String = str(nexus_result.get("target_map_id", ""))
	if target_world_id == "" or target_map_id == "":
		return
	last_discovery_text = str(nexus_result.get("message", ""))
	_load_map(target_world_id, target_map_id)


func _create_visible_sun() -> void:
	if _is_current_map_cave() or _is_current_map_moon():
		return
	if _is_current_map_gate_room():
		return

	var sun_mesh := MeshInstance3D.new()
	sun_mesh.name = "SunDisc"
	var sphere := SphereMesh.new()
	sphere.radius = 18.0
	sphere.height = 36.0
	sun_mesh.mesh = sphere
	var sun_mat := StandardMaterial3D.new()
	sun_mat.albedo_color = Color(0.95, 0.80, 0.45)
	sun_mat.emission_enabled = true
	sun_mat.emission = Color(0.85, 0.55, 0.20)
	sun_mat.emission_energy_multiplier = 1.8
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mesh.material_override = sun_mat
	sun_mesh.position = Vector3(280.0, 380.0, -420.0)
	generated_root.add_child(sun_mesh)

	var glow := MeshInstance3D.new()
	glow.name = "SunGlow"
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 28.0
	glow_mesh.height = 56.0
	glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.70, 0.30, 0.03)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.80, 0.45, 0.18)
	glow_mat.emission_energy_multiplier = 0.35
	glow.material_override = glow_mat
	glow.position = sun_mesh.position
	generated_root.add_child(glow)


func _spawn_player() -> void:
	var existing_player: CharacterBody3D = get_node_or_null("Player")
	if existing_player != null:
		existing_player.queue_free()
	_player_ref = null

	var player_scene: PackedScene = preload("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.name = "Player"
	player.position = _find_spawn_position()
	if _is_current_map_moon():
		player.set("gravity_multiplier", 0.25)
		player.set("jump_multiplier", 4.0)
		player.set("water_level", -100000.0)
	elif _is_current_map_arctic():
		player.set("gravity_multiplier", 1.0)
		player.set("jump_multiplier", 1.0)
		player.set("water_level", -100000.0)
	else:
		player.set("gravity_multiplier", 1.0)
		player.set("jump_multiplier", 1.0)
		player.set("water_level", WATER_LEVEL)
	add_child(player)
	_player_ref = player
	if _is_current_map_cave():
		AudioManager.setup_cave_player_audio(player)
	player.lichen_count = lichen_count
	_restore_player_save_state(player)
	_ensure_player_above_surface(player)


func _find_spawn_position() -> Vector3:
	if _is_current_map_gate_room():
		return Vector3(0.0, _height_at_world(0.0, 0.0) + 1.2, 28.0)

	if _is_current_map_map_nexus():
		return Vector3(0.0, _height_at_world(0.0, 0.0) + 1.2, 40.0)

	if _is_current_map_cave():
		return Vector3(5.0, 2.5, 5.0)

	if _is_current_map_arctic():
		return Vector3(0.0, 2.5, 0.0)

	var rng := StableRng.new(StableRng.mix_string(world_seed, "spawn"))
	var half: float = _world_half_size() * 0.84
	var best_pos: Vector3 = Vector3(0.0, _height_at_world(0.0, 0.0) + 1.2, 0.0)
	var best_score: float = -999999.0
	for i in range(64):
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = _height_at_world(x, z)
		var water_clearance: float = y - _water_level()
		var river_clearance: float = _river_distance(x, z)
		var score: float = y
		if water_clearance <= 0.8:
			score -= 1000.0
		if river_clearance < 8.0:
			score -= (8.0 - river_clearance) * 40.0
		if score > best_score:
			best_score = score
			best_pos = Vector3(x, y + 1.2, z)

	if best_pos.y <= _water_level() + 0.8 or _river_distance(best_pos.x, best_pos.z) < 8.0:
		var center_y: float = _height_at_world(0.0, 0.0)
		if center_y > _water_level() + 0.8 and _river_distance(0.0, 0.0) >= 8.0:
			return Vector3(0.0, center_y + 1.2, 0.0)
		return Vector3(0.0, _water_level() + 2.0, 0.0)

	return best_pos


func _ensure_player_above_surface(player: CharacterBody3D) -> bool:
	if player == null:
		return false
	if _is_current_map_cave() or _is_current_map_gate_room() or _is_current_map_map_nexus():
		return false
	var terrain_y: float = _height_at_world(player.global_position.x, player.global_position.z)
	var min_safe_y: float = terrain_y + 1.2
	if player.global_position.y < min_safe_y:
		player.global_position = Vector3(player.global_position.x, min_safe_y, player.global_position.z)
		player.velocity = Vector3.ZERO
		return true
	return false


func _check_moon_shrine_completion() -> void:
	if not _is_current_map_moon():
		return
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var orb_count := 0
	for key in discoveries.keys():
		if key.begins_with("moon_orb_"):
			orb_count += 1
	if orb_count >= MOON_SHRINE_COUNT and not discoveries.has("moon_pilgrim"):
		discoveries["moon_pilgrim"] = {
			"title": "Moon Pilgrim",
			"kind": "shrine_complete",
			"found_at": Time.get_unix_time_from_system(),
			"x": 0.0,
			"z": 0.0,
		}
		map_record["discoveries"] = discoveries
		_update_world_map_record(current_world_id, current_map_id, map_record, true)
		if discovery_tracker != null:
			discovery_tracker.award_achievement("moon_pilgrim")


func _on_gate_body_entered(body: Node3D, gate_index: int) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		_gate_debug_line = "GateDbg: ignored body/world/map"
		return
	if _gate_transition_in_progress:
		_gate_debug_line = "GateDbg: ignored lock"
		return
	if discovery_tracker == null:
		_gate_debug_line = "GateDbg: no tracker"
		return
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		_gate_debug_line = "GateDbg: ignored hub"
		return
	_force_gate_transition(gate_index, body as CharacterBody3D)


func _deferred_load_gate_target(target_world_id: String, target_map_id: String) -> void:
	_gate_transition_in_progress = false
	_load_map(target_world_id, target_map_id)
	if discovery_tracker != null:
		discovery_tracker.award_achievement("gate_crasher")
