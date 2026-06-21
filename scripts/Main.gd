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
const LandmarkFactory = preload("res://scripts/factories/LandmarkFactory.gd")
const RoadFactory = preload("res://scripts/factories/RoadFactory.gd")
const BridgeFactory = preload("res://scripts/factories/BridgeFactory.gd")
const CityFactory = preload("res://scripts/factories/CityFactory.gd")
const FlowerFactory = preload("res://scripts/factories/FlowerFactory.gd")
const CreatureFactory = preload("res://scripts/factories/CreatureFactory.gd")
const WeatherFactory = preload("res://scripts/factories/WeatherFactory.gd")
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
const ProgressionService = preload("res://scripts/core/ProgressionService.gd")


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
const FLOATING_ROUTE_CHANCE: float = 0.10
const NEXUS_ROUTE_CHANCE: float = 0.06
const CITY_ROUTE_CHANCE: float = 0.12
const MAZE_OBJECTIVE_VARIANTS: Array[String] = [
	"gate_sprint",
	"discover_then_exit",
	"orb_and_exit",
	"clean_exit",
]


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
var hud_position: String = "left"
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
var e_key_gate_enabled: bool = false
var audio_muted: bool = false
var audio_master_db: float = -3.0
var audio_music_db: float = -6.0
var audio_sfx_db: float = -4.0
var audio_output_device: String = "Default"
var current_slot: int = 0
var slot_count: int = 0
var show_fps: bool = false
var _save_audit_summary: String = ""
var _transition_status_line: String = ""
var show_gate_debug_hud: bool = false
var _status_banner_text: String = ""
var _status_banner_until_msec: int = 0

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
var _nexus_slot_active: Dictionary = {}
var _moon_gate_last_trigger_msec: int = 0
var _floating_local_gate_positions: Array[Vector3] = []
var _floating_recovery_gate_positions: Array[Vector3] = []
var _floating_local_gate_last_trigger_msec: int = 0
var _moon_cutscene_active: bool = false
var _cutscene_active: bool = false
var _moon_cut_cam: Camera3D = null
var _moon_cut_focus: Vector3 = Vector3.ZERO
var _cycle_time: float = 0.0
var _map_loaded_at_msec: int = 0
var _arctic_shelter_check_msec: int = 0
var _arctic_recover_cooldown_until_msec: int = 0
var _water_recover_cooldown_until_msec: int = 0
var _cave_dark_since_msec: int = 0
var _cave_recover_cooldown_until_msec: int = 0
var _bioscan_next_msec: int = 0
var _weather_type: String = "clear"
var _weather_root: Node3D
var _weather_sun_mult: float = 1.0
var _map_loading: bool = false
var _loading_layer: CanvasLayer
var _loading_label: Label
var cycle_speed_multiplier: float = 1.0
var start_fullscreen: bool = true
var discovery_tracker: DiscoveryTracker
var generation_rng = StableRng.new(1)
const CYCLE_HOURS_PER_SECOND: float = 0.01
const CYCLE_LENGTH: float = 24.0 / CYCLE_HOURS_PER_SECOND
const DEFAULT_START_HOUR: float = 7.5
const MAP_SURVEY_LICHEN_REWARD: int = 1
const ARCTIC_SHELTER_RADIUS: float = 15.0
const CAVE_DARK_LIMIT_MSEC: int = 8000
const BIOSCAN_BASE_RANGE: float = 22.0

# First-run field tips — each shown once per universe (tips_seen), the rest of the
# teaching is carried by the per-map objective and warning lines.
const FIELD_TIPS := {
	"welcome": "Welcome, cartographer. [WASD] move · mouse look · [Shift] sprint · [Space] jump. Walk into a world gate to cross to a new map. Chart wonders, ruins, and gates — every discovery upgrades your Cartographer's Kit.",
	"gate": "A world gate. Step into the shimmer to travel through it. [Tab] opens your Atlas; [P] drops a survey pin.",
	"kit": "First discovery logged. Every wonder, ruin, and gate you chart upgrades your kit — breath, lantern, sprint, warmth, pins, and more.",
	"moon_lichen": "Moon shrines: grab a glowing lichen with [C], hurl it at a shrine with [T] to charge it, then collect the orb it reveals. Nine shrines in all.",
}


func _ready() -> void:
	print("GATEWALK PATCHED MAIN: trees restored safely")
	print("Main._ready: script is loading")
	print("Random World Explorer v6: starting")
	print("Audio Driver: ", AudioServer.get_driver_name())
	print("Output Devices: ", AudioServer.get_output_device_list())
	print("Current Device: ", AudioServer.output_device)

	hud_controller = HudController.new()
	hud_controller.name = "HudController"
	hud_controller._get_world_fn = _get_world
	hud_controller._get_player_fn = _get_player
	hud_controller._is_moon_fn = _is_current_map_moon
	hud_controller._is_water_fn = _is_current_map_water
	hud_controller._is_cave_fn = _is_current_map_cave
	hud_controller._is_arctic_fn = _is_current_map_arctic
	hud_controller._is_gate_room_fn = _is_current_map_gate_room
	hud_controller._on_prev_music_fn = _on_prev_music_pressed
	hud_controller._on_next_music_fn = _on_next_music_pressed
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
	discovery_tracker.on_discovery_recorded = _on_discovery_recorded

	atlas_view = AtlasView.new()
	atlas_view.name = "AtlasView"
	atlas_view.get_worlds_fn = _get_worlds
	atlas_view.get_world_fn = _get_world
	atlas_view.get_current_universe_fn = _current_universe
	atlas_view.seed_color_fn = _seed_color
	atlas_view.short_id_fn = _short_id
	atlas_view.completion_text_fn = _completion_text
	atlas_view.opposite_gate_index_fn = _opposite_gate_index
	atlas_view.set_map_name_fn = _set_map_name
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
	dev_menu.get_e_key_gate_enabled_fn = _get_e_key_gate_enabled
	dev_menu.set_e_key_gate_enabled_fn = _set_e_key_gate_enabled
	dev_menu.get_gate_debug_hud_enabled_fn = _get_gate_debug_hud_enabled
	dev_menu.set_gate_debug_hud_enabled_fn = _set_gate_debug_hud_enabled
	dev_menu.toggle_day_night_fn = _toggle_day_night
	add_child(dev_menu)

	_load_slot_index()
	_load_save_data()
	_consolidate_slots()
	_apply_audio_settings()

	if start_fullscreen:
		call_deferred("_configure_fullscreen")
	else:
		call_deferred("_configure_windowed")

	var preview := get_node_or_null("EditorPreviewGround")
	if preview != null:
		preview.queue_free()

	_setup_environment()
	hud_controller.setup(self)
	hud_controller.set_hud_position(hud_position)
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
	if _map_loading:
		return
	_poll_gate_use_input()
	_poll_hub_use_input()
	_update_gate_room_ambience(_delta)
	if not _is_current_map_gate_room() and not _is_current_map_cave() and not _is_current_map_map_nexus():
		_cycle_time += _delta * cycle_speed_multiplier
		if _cycle_time >= CYCLE_LENGTH:
			_cycle_time = fmod(_cycle_time, CYCLE_LENGTH)
		_update_day_night_cycle()
	_update_underwater_state()
	_update_arctic_exposure()
	_update_drowning()
	_update_cave_darkness()
	_update_bioscan()
	_update_weather_follow()
	_recover_fallen_player()
	_enforce_world_bounds()
	_update_hud(_delta)


func _update_gate_room_ambience(_delta: float) -> void:
	if generated_root == null:
		return
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	if _is_current_map_map_nexus():
		var core_nexus: Node3D = generated_root.get_node_or_null("MapNexusCore") as Node3D
		if core_nexus != null:
			core_nexus.rotation_degrees.y = fmod(now_sec * 22.0, 360.0)
			core_nexus.position.y = 2.0 + sin(now_sec * 1.1) * 0.18
		var plinth_body: StaticBody3D = generated_root.get_node_or_null("MapNexusCenterPlinthBody") as StaticBody3D
		if plinth_body != null:
			plinth_body.constant_angular_velocity = Vector3(0.0, 0.42, 0.0)
		var plinth_visual: Node3D = generated_root.get_node_or_null("MapNexusCenterPlinth") as Node3D
		if plinth_visual != null:
			plinth_visual.rotation_degrees.y = fmod(now_sec * 24.0, 360.0)
		var inner_ring: Node3D = generated_root.get_node_or_null("MapNexusInnerRing") as Node3D
		if inner_ring != null:
			inner_ring.rotation_degrees.z = fmod(now_sec * 10.0, 360.0)
		var outer_ring: Node3D = generated_root.get_node_or_null("MapNexusOuterRing") as Node3D
		if outer_ring != null:
			outer_ring.rotation_degrees.z = fmod(-now_sec * 7.0, 360.0)
		for child in generated_root.get_children():
			var node: Node3D = child as Node3D
			if node == null:
				continue
			var n: String = str(node.name)
			if n.begins_with("MapNexusGate_"):
				var idx: int = int(n.trim_prefix("MapNexusGate_"))
				var light: OmniLight3D = node.get_node_or_null("MapNexusSlotLight_" + str(idx)) as OmniLight3D
				if light != null:
					light.light_energy = 1.45 + 0.75 * (0.5 + 0.5 * sin(now_sec * 1.9 + float(idx) * 1.27))
		return
	if not _is_current_map_gate_room():
		return
	var core: Node3D = generated_root.get_node_or_null("GateRoomCore") as Node3D
	if core != null:
		core.rotation_degrees.z = fmod(now_sec * 18.0, 360.0)
		core.position.y = 2.6 + sin(now_sec * 0.9) * 0.15
	var return_portal: Node3D = generated_root.get_node_or_null("GateRoomReturnPortal") as Node3D
	if return_portal != null:
		return_portal.position.y = 1.8 + sin(now_sec * 1.7) * 0.12
	for child in generated_root.get_children():
		var n3d: Node3D = child as Node3D
		if n3d == null:
			continue
		var nm: String = str(n3d.name)
		if nm.begins_with("GateRoomGate_"):
			var idx_text: String = nm.trim_prefix("GateRoomGate_")
			var idx: int = int(idx_text)
			var phase: float = now_sec * 1.8 + float(idx) * 1.25
			var sigil: Node3D = n3d.get_node_or_null("GateRoomSlotSigil_" + str(idx)) as Node3D
			if sigil != null:
				sigil.rotation_degrees.z = fmod(now_sec * (42.0 + float(idx) * 4.0), 360.0)
				sigil.position.y = 0.14 + sin(phase) * 0.08
			var light: OmniLight3D = n3d.get_node_or_null("GateRoomSlotLight_" + str(idx)) as OmniLight3D
			if light != null:
				light.light_energy = 1.25 + 0.55 * (0.5 + 0.5 * sin(phase))


func _physics_process(_delta: float) -> void:
	if _map_loading:
		return
	_poll_primary_gate_activation()
	_poll_wonder_proximity_fallback()
	_poll_moon_gate_proximity_fallback()
	_poll_moon_shrine_fallback()
	_poll_city_cores()
	_poll_gate_room_slot_fallback()
	_poll_gate_room_return_fallback()
	_poll_map_nexus_slot_fallback()


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
	var activation_radius: float = 1.4
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
	if not e_key_gate_enabled:
		return
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
	_force_gate_transition(gate_index, player)


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
	if not e_key_gate_enabled:
		last_discovery_text = "E-key gate use is disabled (enable in Secret Admin)."
		return
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
	if _is_current_map_cave():
		var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
		if not map_record.is_empty():
			var updated_record: Dictionary = _try_complete_maze_objective_on_exit(map_record)
			if updated_record != map_record:
				_update_world_map_record(current_world_id, current_map_id, updated_record, true)
				world = _get_world(current_world_id)
	var gate_result: Dictionary = GateTravelService.resolve_gate_transition(
		world_seed,
		current_map_id,
		gate_index,
		world,
		Callable(self, "_new_id"),
		WATER_ROUTE_CHANCE,
		0.10,
		0.18,
		NEXUS_ROUTE_CHANCE,
		0.0,
		CITY_ROUTE_CHANCE
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
	if not e_key_gate_enabled:
		return
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

	if _is_current_map_map_nexus():
		if generated_root != null and player != null:
			var nearest_slot: int = -1
			var best_dist: float = INF
			for child in generated_root.get_children():
				var gate_node: Node3D = child as Node3D
				if gate_node == null:
					continue
				var gate_name: String = str(gate_node.name)
				if not gate_name.begins_with("MapNexusGate_"):
					continue
				var slot_index: int = int(gate_name.trim_prefix("MapNexusGate_"))
				var dist: float = Vector2(
					gate_node.global_position.x - player.global_position.x,
					gate_node.global_position.z - player.global_position.z
				).length()
				if dist < best_dist:
					best_dist = dist
					nearest_slot = slot_index
			if nearest_slot >= 0 and best_dist <= 8.5:
				_last_gate_index_in_range = nearest_slot
			else:
				_last_gate_index_in_range = -1
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
	var proximity_radius: float = 6.0
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
	if best_dist > 8.5:
		_gate_room_slot_in_range = -1


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


func _poll_map_nexus_slot_fallback() -> void:
	if not _is_current_map_map_nexus():
		return
	if generated_root == null:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var proximity_radius: float = 6.5
	for child in generated_root.get_children():
		var gate_node: Node3D = child as Node3D
		if gate_node == null:
			continue
		var gate_name: String = str(gate_node.name)
		if not gate_name.begins_with("MapNexusGate_"):
			continue
		var slot_index: int = int(gate_name.trim_prefix("MapNexusGate_"))
		var dist: float = Vector2(
			gate_node.global_position.x - player.global_position.x,
			gate_node.global_position.z - player.global_position.z
		).length()
		var near: bool = dist <= proximity_radius
		var was_near: bool = bool(_nexus_slot_active.get(slot_index, false))
		if near and not was_near:
			_nexus_slot_active[slot_index] = true
			_on_map_nexus_gate_body_entered(player, slot_index)
		elif not near and was_near:
			_nexus_slot_active.erase(slot_index)


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
				_update_mouse_mode_for_overlays()

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

		if event.keycode == KEY_COMMA:
			_on_prev_music_pressed()

		if event.keycode == KEY_PERIOD:
			_on_next_music_pressed()

		if event.keycode == KEY_S and event.shift_pressed:
			if dev_menu != null:
				dev_menu.show_login()

		if event.keycode == KEY_F5:
			_explicit_save_world_data()

		if event.keycode == KEY_E:
			if e_key_gate_enabled:
				_try_activate_nearest_gate_from_input()
			else:
				last_discovery_text = "E-key gate use is disabled (Secret Admin)."


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


# One-time migration: older builds let you create multiple save "slots" (separate
# files) on top of multiple universes — two redundant ways to have several games.
# Fold every slot's universes into a single file so "Saved Games" is the only
# concept. Retired slot files are renamed to .merged backups, never deleted.
func _consolidate_slots() -> void:
	var indices: Array = []
	for i in range(64):
		if FileAccess.file_exists(_slot_path(i)):
			indices.append(i)
	if indices.size() <= 1:
		return

	var universes: Dictionary = save_data.get("universes", {})
	for i in indices:
		if i == current_slot:
			continue
		var raw: Variant = JSON.parse_string(FileAccess.open(_slot_path(i), FileAccess.READ).get_as_text())
		if raw is Dictionary:
			var other_universes: Dictionary = (raw as Dictionary).get("universes", {})
			for uid in other_universes.keys():
				if not universes.has(uid):
					universes[uid] = other_universes[uid]
			# Only retire a slot we actually merged, so a corrupt file is never lost.
			DirAccess.rename_absolute(_slot_path(i), _slot_path(i) + ".merged")
	save_data["universes"] = universes

	# Everything now lives in slot 0 as the sole save file.
	if current_slot != 0:
		DirAccess.rename_absolute(_slot_path(current_slot), _slot_path(current_slot) + ".merged")
		current_slot = 0
	var file := FileAccess.open(_slot_path(0), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
	slot_count = 1
	_save_slot_index()
	print("Consolidated ", indices.size(), " save slots into one; ", universes.size(), " saved games total.")


func _load_save_data() -> void:
	var path: String = _slot_path(current_slot)
	save_data = {}
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				save_data = parsed

	var audited: Dictionary = SaveManager.audit_and_repair_save_data(save_data)
	save_data = audited.get("save_data", SaveManager.normalize_save_data(save_data))
	var audit_report: Dictionary = audited.get("report", {})
	var repaired_fields: int = int(audit_report.get("repaired_fields", 0))
	if repaired_fields > 0:
		_save_audit_summary = "Integrity repair: " + str(repaired_fields) + " fields across " + str(int(audit_report.get("repaired_worlds", 0))) + " worlds / " + str(int(audit_report.get("repaired_maps", 0))) + " maps."
	else:
		_save_audit_summary = "Integrity check: no repairs needed."
	current_universe_id = SaveManager.current_universe_id(save_data)
	var universe: Dictionary = _current_universe()
	var settings: Dictionary = universe.get("settings", {})
	cycle_speed_multiplier = float(settings.get("cycle_speed_multiplier", 1.0))
	start_fullscreen = bool(settings.get("start_fullscreen", true))
	graphics_level = int(settings.get("graphics_level", 0))
	density_level = int(settings.get("density_level", 2))
	hud_position = str(settings.get("hud_position", "left"))
	if hud_position != "bottom":
		hud_position = "left"
	audio_muted = bool(settings.get("audio_muted", false))
	audio_master_db = float(settings.get("audio_master_db", -3.0))
	audio_music_db = float(settings.get("audio_music_db", -6.0))
	audio_sfx_db = float(settings.get("audio_sfx_db", -4.0))
	audio_output_device = str(settings.get("audio_output_device", "Default"))
	if audio_output_device == "Default":
		audio_output_device = _preferred_output_device()
	lichen_count = int(universe.get("lichen_count", 0))
	e_key_gate_enabled = bool(universe.get("e_key_gate_enabled", false))
	_cycle_time = _cycle_time_from_universe(universe)


func _save_world_data() -> void:
	var universe: Dictionary = _current_universe()
	var player_state: Dictionary = _capture_player_save_state()
	if bool(player_state.get("has_position", false)):
		universe["last_player_state"] = player_state
	var settings: Dictionary = universe.get("settings", {})
	settings["density_level"] = density_level
	settings["hud_position"] = hud_position
	settings["cycle_speed_multiplier"] = cycle_speed_multiplier
	settings["start_fullscreen"] = start_fullscreen
	settings["graphics_level"] = graphics_level
	settings["audio_muted"] = audio_muted
	settings["audio_master_db"] = audio_master_db
	settings["audio_music_db"] = audio_music_db
	settings["audio_sfx_db"] = audio_sfx_db
	settings["audio_output_device"] = audio_output_device
	universe["settings"] = settings
	universe["lichen_count"] = lichen_count
	universe["e_key_gate_enabled"] = e_key_gate_enabled
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


func _last_explicit_save_line() -> String:
	var universe: Dictionary = _current_universe()
	if not universe.has("last_explicit_save_unix"):
		return "Last explicit save: none in this universe."
	var unix_time: int = int(universe.get("last_explicit_save_unix", 0))
	if unix_time <= 0:
		return "Last explicit save: none in this universe."
	return "Last explicit save: " + _format_unix_local(unix_time)


func _format_unix_local(unix_time: int) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	var year: int = int(dt.get("year", 0))
	var month: int = int(dt.get("month", 0))
	var day: int = int(dt.get("day", 0))
	var hour: int = int(dt.get("hour", 0))
	var minute: int = int(dt.get("minute", 0))
	return str(year) + "-" + _two(month) + "-" + _two(day) + " " + _two(hour) + ":" + _two(minute)


func _two(value: int) -> String:
	return str(value).pad_zeros(2)


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
		"flashlight_requested_on": bool(player.get("flashlight_requested_on")),
	}


func _persist_active_player_state() -> void:
	var state: Dictionary = _capture_player_save_state()
	if not bool(state.get("has_position", false)):
		return
	var universe: Dictionary = _current_universe()
	universe["last_player_state"] = state
	_set_current_universe(universe)


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
	var restored_position := Vector3(
		float(state.get("x", player.global_position.x)),
		float(state.get("y", player.global_position.y)),
		float(state.get("z", player.global_position.z)),
	)
	var safe_position: Vector3 = _sanitize_player_position(restored_position)
	player.global_position = safe_position
	player.rotation.y = float(state.get("yaw", player.rotation.y))
	if state.has("sprint_stamina"):
		player.set("sprint_stamina", float(state.get("sprint_stamina", player.get("sprint_stamina"))))
	if state.has("breath"):
		player.set("breath", float(state.get("breath", player.get("breath"))))
	if state.has("flashlight_on"):
		player.set("flashlight_on", bool(state.get("flashlight_on", player.get("flashlight_on"))))
	if state.has("flashlight_charge"):
		player.set("flashlight_charge", float(state.get("flashlight_charge", player.get("flashlight_charge"))))
	if state.has("flashlight_requested_on"):
		player.set("flashlight_requested_on", bool(state.get("flashlight_requested_on", player.get("flashlight_requested_on"))))
	var camera: Camera3D = player.get_node_or_null("PlayerCamera") as Camera3D
	var pitch: float = float(state.get("pitch", player.get("pitch")))
	player.set("pitch", pitch)
	if camera != null:
		camera.rotation.x = pitch
	var flashlight: SpotLight3D = player.get_node_or_null("PlayerCamera/Flashlight") as SpotLight3D
	if flashlight != null:
		flashlight.light_energy = 10.5 if bool(player.get("flashlight_on")) else 0.0
	if safe_position.distance_to(restored_position) > 1.0:
		last_discovery_text = "Spawn adjusted to map bounds."
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
	hud_position = str(settings.get("hud_position", "left"))
	if hud_position != "bottom":
		hud_position = "left"
	lichen_count = int(universe.get("lichen_count", 0))
	_cycle_time = _cycle_time_from_universe(universe)
	if hud_controller != null:
		hud_controller.set_hud_position(hud_position)


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
	var world_seed_value: int = _seed_for_new_record(label)
	var world_record: Dictionary = _create_precomputed_world_record(world_name, world_id, root_map_id, world_seed_value)
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
	var world_record: Dictionary = _create_precomputed_world_record(default_world_name, default_world_id, root_map_id, world_seed)
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
	# Caves are enclosed and flashlight-lit; the dim top-down sun's shadows only
	# produce hard wedges in the wall corners, so never cast shadows there.
	var enable: bool = graphics_level >= 2 and not _is_current_map_cave()
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


func _on_toggle_hud_position(btn: Button) -> void:
	hud_position = "bottom" if hud_position == "left" else "left"
	btn.text = "Bottom" if hud_position == "bottom" else "Left"
	if hud_controller != null:
		hud_controller.set_hud_position(hud_position)
	_save_world_data()


func _on_toggle_audio_mute(pressed: bool, btn: Button) -> void:
	audio_muted = pressed
	btn.text = "Muted" if audio_muted else "Unmuted"
	_apply_audio_settings()
	_save_world_data()


func _on_audio_volume_changed(value: float) -> void:
	audio_master_db = value
	_apply_audio_settings()
	_save_world_data()


func _on_music_volume_changed(value: float) -> void:
	audio_music_db = value
	_apply_audio_settings()
	_save_world_data()


func _on_sfx_volume_changed(value: float) -> void:
	audio_sfx_db = value
	_apply_audio_settings()
	_save_world_data()


func _on_audio_output_device_selected(device_name: String) -> void:
	audio_output_device = device_name
	_apply_audio_settings()
	_save_world_data()


func _apply_audio_settings() -> void:
	var bus_idx: int = _ensure_audio_bus("Master", "")
	var music_idx: int = _ensure_audio_bus("Music", "Master")
	var sfx_idx: int = _ensure_audio_bus("SFX", "Master")
	audio_master_db = clamp(audio_master_db, -30.0, 6.0)
	audio_music_db = clamp(audio_music_db, -30.0, 6.0)
	audio_sfx_db = clamp(audio_sfx_db, -30.0, 6.0)
	AudioServer.set_bus_mute(bus_idx, audio_muted)
	AudioServer.set_bus_volume_db(bus_idx, audio_master_db)
	AudioServer.set_bus_mute(music_idx, audio_muted)
	AudioServer.set_bus_mute(sfx_idx, audio_muted)
	AudioServer.set_bus_volume_db(music_idx, audio_music_db)
	AudioServer.set_bus_volume_db(sfx_idx, audio_sfx_db)
	var device_list: PackedStringArray = AudioServer.get_output_device_list()
	if audio_output_device == "" or audio_output_device == "Default":
		audio_output_device = _preferred_output_device()
	if device_list.has(audio_output_device):
		AudioServer.output_device = audio_output_device
	else:
		AudioServer.output_device = "Default"
	print("Audio output applied: ", AudioServer.output_device)


func _ensure_audio_bus(bus_name: String, send_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus(AudioServer.bus_count)
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	if send_name != "":
		AudioServer.set_bus_send(idx, send_name)
	return idx


func _preferred_output_device() -> String:
	var device_list: PackedStringArray = AudioServer.get_output_device_list()
	for i in range(device_list.size()):
		var d: String = str(device_list[i])
		if d.contains("Speakers"):
			return d
	for i in range(device_list.size()):
		var d2: String = str(device_list[i])
		if not d2.contains("BlackHole"):
			return d2
	return "Default"


func _play_audio_test_tone() -> void:
	if generated_root == null:
		return
	var test := AudioStreamPlayer.new()
	test.name = "AudioTestTone"
	test.bus = "Master"
	test.volume_db = 0.0
	test.stream = AudioManager.generate_wav_stream([440.0, 660.0, 880.0], 0.8, 0.65, false)
	generated_root.add_child(test)
	test.play()
	call_deferred("_run_audio_bus_probe")
	test.finished.connect(func() -> void:
		if is_instance_valid(test):
			test.queue_free()
	)


func _run_audio_bus_probe() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		last_discovery_text = "Audio probe: no Master bus."
		return
	var peak_l: float = -80.0
	var peak_r: float = -80.0
	for _i in range(20):
		await get_tree().create_timer(0.05).timeout
		peak_l = max(peak_l, AudioServer.get_bus_peak_volume_left_db(master_idx, 0))
		peak_r = max(peak_r, AudioServer.get_bus_peak_volume_right_db(master_idx, 0))
	var signal_present: bool = peak_l > -50.0 or peak_r > -50.0
	last_discovery_text = "Audio probe: " + ("signal detected" if signal_present else "no signal") + " (L " + str(int(round(peak_l))) + " dB, R " + str(int(round(peak_r))) + " dB)"
	print("Audio probe: master peaks L=", peak_l, " R=", peak_r, " device=", AudioServer.output_device, " muted=", audio_muted)


func _update_time_speed_label() -> void:
	if menu_layer == null:
		return
	var label := menu_layer.find_child("TimeSpeedLabel", true, false)
	if label != null:
		label.text = "%.2fx" % cycle_speed_multiplier


func _show_main_menu() -> void:
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

	# Save "slots" were folded into the Saved Games (universe) list — see _consolidate_slots.

	var story := Label.new()
	story.text = _backstory_text()
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 12)
	story.add_theme_constant_override("line_separation", -3)
	var progression_section: VBoxContainer = _add_menu_section(list, "Mission")
	progression_section.add_child(story)

	var worlds_section: VBoxContainer = _add_menu_section(list, "Universes & Worlds")
	var map_section: VBoxContainer = _add_menu_section(list, "Map Session")
	var system_section: VBoxContainer = _add_menu_section(list, "System")
	var audio_section: VBoxContainer = _add_menu_section(list, "Audio")
	var atlas_section: VBoxContainer = _add_menu_section(list, "Atlas & Progress")

	var universe_header := Label.new()
	universe_header.text = "Saved Games:"
	universe_header.add_theme_font_size_override("font_size", 13)
	worlds_section.add_child(universe_header)

	var universe_list := VBoxContainer.new()
	universe_list.add_theme_constant_override("separation", 4)
	worlds_section.add_child(universe_list)
	var universes: Dictionary = save_data.get("universes", {})
	for universe_key in universes.keys():
		var uid: String = str(universe_key)
		var universe: Dictionary = universes[uid]
		var is_cur: bool = uid == current_universe_id

		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 0)
		universe_list.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		card.add_child(row)

		var load_btn := Button.new()
		var uname: String = str(universe.get("name", "")).strip_edges()
		if uname == "":
			uname = "Untitled Game"
		load_btn.text = ("> " if is_cur else "   ") + uname
		load_btn.disabled = is_cur
		load_btn.tooltip_text = "Load this saved game"
		load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_btn.pressed.connect(_switch_universe.bind(uid))
		row.add_child(load_btn)

		var ren_btn := Button.new()
		ren_btn.text = "Rename"
		ren_btn.pressed.connect(_rename_universe.bind(uid))
		row.add_child(ren_btn)

		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.disabled = is_cur or universes.size() <= 1
		del_btn.tooltip_text = "Switch to another game first" if is_cur else "Delete this saved game"
		del_btn.pressed.connect(_delete_universe.bind(uid))
		row.add_child(del_btn)

		var summary := Label.new()
		summary.text = "      " + _universe_summary(universe) + ("  ·  (current)" if is_cur else "")
		summary.add_theme_font_size_override("font_size", 10)
		summary.modulate = Color(0.66, 0.72, 0.8)
		card.add_child(summary)

	var world_header := Label.new()
	world_header.text = "Worlds:"
	world_header.add_theme_font_size_override("font_size", 13)
	worlds_section.add_child(world_header)

	var world_list := VBoxContainer.new()
	world_list.add_theme_constant_override("separation", 4)
	worlds_section.add_child(world_list)

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
		map_section.add_child(resume_button)

		var save_btn := Button.new()
		save_btn.text = "Save Game"
		save_btn.pressed.connect(_explicit_save_world_data)
		map_section.add_child(save_btn)

	var smoke_btn := Button.new()
	smoke_btn.text = "Run Smoke Check"
	smoke_btn.pressed.connect(_run_stability_smoke_check)
	map_section.add_child(smoke_btn)

	var save_meta := Label.new()
	save_meta.text = _last_explicit_save_line()
	save_meta.add_theme_font_size_override("font_size", 11)
	save_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_section.add_child(save_meta)

	var integrity_meta := Label.new()
	integrity_meta.text = _save_audit_summary
	integrity_meta.add_theme_font_size_override("font_size", 11)
	integrity_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_section.add_child(integrity_meta)

	var new_world_btn := Button.new()
	new_world_btn.text = "New World"
	new_world_btn.pressed.connect(_create_new_world_direct)
	world_list.add_child(new_world_btn)

	var new_universe_btn := Button.new()
	new_universe_btn.text = "+ New Game (Universe)"
	new_universe_btn.tooltip_text = "Start a fresh saved game with its own worlds, kept separate from the others"
	new_universe_btn.pressed.connect(_start_new_game)
	world_list.add_child(new_universe_btn)

	var gfx_row := HBoxContainer.new()
	gfx_row.add_theme_constant_override("separation", 6)
	system_section.add_child(gfx_row)
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
	system_section.add_child(dens_row)
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
	system_section.add_child(time_row)
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
	system_section.add_child(fs_row)
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

	var hud_row := HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", 6)
	system_section.add_child(hud_row)
	var hud_label := Label.new()
	hud_label.text = "HUD Position:"
	hud_label.add_theme_font_size_override("font_size", 12)
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_row.add_child(hud_label)
	var hud_btn := Button.new()
	hud_btn.text = "Bottom" if hud_position == "bottom" else "Left"
	hud_btn.pressed.connect(_on_toggle_hud_position.bind(hud_btn))
	hud_row.add_child(hud_btn)

	var audio_header := HBoxContainer.new()
	audio_header.add_theme_constant_override("separation", 6)
	audio_section.add_child(audio_header)
	var audio_label := Label.new()
	audio_label.text = "Audio:"
	audio_label.add_theme_font_size_override("font_size", 12)
	audio_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	audio_header.add_child(audio_label)
	var audio_mute_btn := Button.new()
	audio_mute_btn.text = "Muted" if audio_muted else "Unmuted"
	audio_mute_btn.toggle_mode = true
	audio_mute_btn.button_pressed = audio_muted
	audio_mute_btn.toggled.connect(_on_toggle_audio_mute.bind(audio_mute_btn))
	audio_header.add_child(audio_mute_btn)
	var audio_test_btn := Button.new()
	audio_test_btn.text = "Test Tone"
	audio_test_btn.pressed.connect(_play_audio_test_tone)
	audio_header.add_child(audio_test_btn)

	var output_row := HBoxContainer.new()
	output_row.add_theme_constant_override("separation", 6)
	audio_section.add_child(output_row)
	var output_label := Label.new()
	output_label.text = "Output Device:"
	output_label.add_theme_font_size_override("font_size", 12)
	output_label.custom_minimum_size.x = 108
	output_row.add_child(output_label)
	var output_option := OptionButton.new()
	output_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_row.add_child(output_option)
	output_option.add_item("Default")
	var output_devices: PackedStringArray = AudioServer.get_output_device_list()
	for i in range(output_devices.size()):
		output_option.add_item(output_devices[i])
	var selected_idx: int = 0
	for i in range(output_option.item_count):
		if output_option.get_item_text(i) == audio_output_device:
			selected_idx = i
			break
	output_option.select(selected_idx)
	output_option.item_selected.connect(func(idx: int) -> void:
		_on_audio_output_device_selected(output_option.get_item_text(idx))
	)
	var output_active := Label.new()
	output_active.text = "Active: " + AudioServer.output_device
	output_active.add_theme_font_size_override("font_size", 11)
	audio_section.add_child(output_active)

	var master_row := HBoxContainer.new()
	master_row.add_theme_constant_override("separation", 6)
	audio_section.add_child(master_row)
	var master_label := Label.new()
	master_label.text = "Master:"
	master_label.add_theme_font_size_override("font_size", 12)
	master_label.custom_minimum_size.x = 64
	master_row.add_child(master_label)
	var master_slider := HSlider.new()
	master_slider.min_value = -30.0
	master_slider.max_value = 6.0
	master_slider.step = 0.5
	master_slider.value = audio_master_db
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_slider.value_changed.connect(_on_audio_volume_changed)
	master_row.add_child(master_slider)
	var master_val := Label.new()
	master_val.text = str(int(round(audio_master_db))) + " dB"
	master_val.add_theme_font_size_override("font_size", 12)
	master_row.add_child(master_val)
	master_slider.value_changed.connect(func(v: float) -> void:
		master_val.text = str(int(round(v))) + " dB"
	)

	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 6)
	audio_section.add_child(music_row)
	var music_label := Label.new()
	music_label.text = "Music:"
	music_label.add_theme_font_size_override("font_size", 12)
	music_label.custom_minimum_size.x = 64
	music_row.add_child(music_label)
	var music_slider := HSlider.new()
	music_slider.min_value = -30.0
	music_slider.max_value = 6.0
	music_slider.step = 0.5
	music_slider.value = audio_music_db
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(_on_music_volume_changed)
	music_row.add_child(music_slider)
	var music_val := Label.new()
	music_val.text = str(int(round(audio_music_db))) + " dB"
	music_val.add_theme_font_size_override("font_size", 12)
	music_row.add_child(music_val)
	music_slider.value_changed.connect(func(v: float) -> void:
		music_val.text = str(int(round(v))) + " dB"
	)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 6)
	audio_section.add_child(sfx_row)
	var sfx_label := Label.new()
	sfx_label.text = "Effects:"
	sfx_label.add_theme_font_size_override("font_size", 12)
	sfx_label.custom_minimum_size.x = 64
	sfx_row.add_child(sfx_label)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = -30.0
	sfx_slider.max_value = 6.0
	sfx_slider.step = 0.5
	sfx_slider.value = audio_sfx_db
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_row.add_child(sfx_slider)
	var sfx_val := Label.new()
	sfx_val.text = str(int(round(audio_sfx_db))) + " dB"
	sfx_val.add_theme_font_size_override("font_size", 12)
	sfx_row.add_child(sfx_val)
	sfx_slider.value_changed.connect(func(v: float) -> void:
		sfx_val.text = str(int(round(v))) + " dB"
	)

	var atlas := Label.new()
	atlas.text = _atlas_summary_text()
	atlas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	atlas.add_theme_font_size_override("font_size", 15)
	atlas_section.add_child(atlas)

	var atlas_title := Label.new()
	atlas_title.text = "Atlas Graph"
	atlas_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atlas_title.add_theme_font_size_override("font_size", 18)
	atlas_section.add_child(atlas_title)

	var ach_row := HBoxContainer.new()
	ach_row.add_theme_constant_override("separation", 6)
	atlas_section.add_child(ach_row)
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

	var fg_btn := Button.new()
	fg_btn.text = "Field Guide (" + str(_catalog_species_total(_build_catalog())) + " species)"
	fg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fg_btn.pressed.connect(_show_field_guide)
	ach_row.add_child(fg_btn)

	var hint := Label.new()
	hint.text = "Objective: restore the Atlas by finding wonders and gates.\nM: menu | Tab: atlas graph | G: return to Gate Room | P: pin location | H: HUD | F10: windowed | F11: fullscreen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	progression_section.add_child(hint)
	_update_mouse_mode_for_overlays()


func _add_menu_section(parent: VBoxContainer, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.14, 0.18, 0.45)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.34, 0.42, 0.52, 0.45)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	margin.add_child(section)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	section.add_child(title)
	return section


func _run_stability_smoke_check() -> void:
	var findings: Array[String] = []
	var warnings: Array[String] = []
	var checked_maps: int = 0

	var universe: Dictionary = _current_universe()
	var worlds: Dictionary = universe.get("worlds", {})
	if worlds.is_empty():
		findings.append("FAIL: universe has no worlds.")
	else:
		findings.append("PASS: worlds present (" + str(worlds.size()) + ").")

	for world_id in worlds.keys():
		var world: Dictionary = worlds[world_id] as Dictionary
		var maps: Dictionary = world.get("maps", {})
		if maps.is_empty():
			findings.append("FAIL: world " + str(world_id) + " has no maps.")
			continue
		var root_map_id: String = str(world.get("root_map", ""))
		if root_map_id == "" or not maps.has(root_map_id):
			findings.append("FAIL: world " + str(world_id) + " missing valid root_map.")
		var current_map_ref: String = str(world.get("current_map", ""))
		if current_map_ref == "" or not maps.has(current_map_ref):
			warnings.append("WARN: world " + str(world_id) + " has invalid current_map.")
		for map_id in maps.keys():
			checked_maps += 1
			var map_record: Dictionary = maps[map_id] as Dictionary
			if typeof(map_record) != TYPE_DICTIONARY or map_record.is_empty():
				findings.append("FAIL: map " + str(map_id) + " record invalid.")
				continue
			var map_type: String = str(map_record.get("type", ""))
			if map_type == "":
				findings.append("FAIL: map " + str(map_id) + " missing type.")
			var gates: Dictionary = map_record.get("gates", {})
			for gate_key in gates.keys():
				var target_id: String = str(gates[gate_key])
				if target_id != "" and not maps.has(target_id):
					findings.append("FAIL: map " + str(map_id) + " gate " + str(gate_key) + " targets missing map " + target_id + ".")
			var discoveries = map_record.get("discoveries", {})
			if typeof(discoveries) != TYPE_DICTIONARY:
				findings.append("FAIL: map " + str(map_id) + " discoveries malformed.")
			var pins = map_record.get("pins", {})
			if typeof(pins) != TYPE_DICTIONARY:
				findings.append("FAIL: map " + str(map_id) + " pins malformed.")

	if current_world_id == "" or current_map_id == "":
		warnings.append("WARN: no active world/map loaded.")
	else:
		if generated_root == null:
			findings.append("FAIL: generated_root missing during active map.")
		var player: CharacterBody3D = _get_player()
		if player == null:
			findings.append("FAIL: player missing during active map.")
		if generated_root != null and not _is_current_map_gate_room() and not _is_current_map_map_nexus():
			var gates_root: Node = generated_root.get_node_or_null("Gates")
			if gates_root == null:
				findings.append("FAIL: active map missing Gates root.")
			elif gates_root.get_child_count() < GATE_COUNT:
				findings.append("FAIL: active map has only " + str(gates_root.get_child_count()) + "/" + str(GATE_COUNT) + " gates.")

	var fail_count: int = 0
	for line in findings:
		if line.begins_with("FAIL:"):
			fail_count += 1
	var pass_summary: String = "Smoke Check: " + ("PASS" if fail_count == 0 else "FAIL") + " | checked maps " + str(checked_maps) + " | failures " + str(fail_count) + " | warnings " + str(warnings.size())
	last_discovery_text = pass_summary
	_show_smoke_report_dialog(pass_summary, findings, warnings)


func _show_smoke_report_dialog(summary: String, findings: Array[String], warnings: Array[String]) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Stability Smoke Report"
	dialog.dialog_text = ""
	dialog.min_size = Vector2(640, 420)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 340)
	dialog.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	scroll.add_child(vb)

	var summary_label := Label.new()
	summary_label.text = summary
	summary_label.add_theme_font_size_override("font_size", 14)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(summary_label)

	for line in findings:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		if line.begins_with("FAIL:"):
			l.modulate = Color(1.0, 0.5, 0.5)
		vb.add_child(l)

	for line in warnings:
		var w := Label.new()
		w.text = line
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.add_theme_font_size_override("font_size", 12)
		w.modulate = Color(1.0, 0.85, 0.45)
		vb.add_child(w)

	add_child(dialog)
	dialog.popup_centered()


func _close_menu() -> void:
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null
	_update_mouse_mode_for_overlays()


func _update_mouse_mode_for_overlays() -> void:
	var menu_open: bool = menu_layer != null
	var atlas_open: bool = atlas_view != null and atlas_view.is_open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (menu_open or atlas_open) else Input.MOUSE_MODE_CAPTURED


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


# Aggregate every discovery across the current saved game into catalog buckets.
# Returns { category: { title: sighting_count } } for birds/fish/land/wonder/orb/other.
func _build_catalog() -> Dictionary:
	var cats: Dictionary = {"birds": {}, "fish": {}, "land": {}, "landmark": {}, "wonder": {}, "orb": {}, "other": {}}
	var universe: Dictionary = _current_universe()
	var worlds: Dictionary = universe.get("worlds", {})
	for w in worlds.values():
		var maps: Dictionary = (w as Dictionary).get("maps", {})
		for m in maps.values():
			var discs: Dictionary = (m as Dictionary).get("discoveries", {})
			for did in discs.keys():
				var d: Dictionary = discs[did]
				var title: String = str(d.get("title", ""))
				if title == "":
					continue
				var id_str: String = str(did)
				var kind: String = str(d.get("kind", ""))
				var cat: String = "other"
				if id_str.begins_with("bio_bird_"):
					cat = "birds"
				elif id_str.begins_with("bio_fish_"):
					cat = "fish"
				elif id_str.begins_with("bio_land_"):
					cat = "land"
				elif kind == "landmark":
					cat = "landmark"
				elif kind == "wonder":
					cat = "wonder"
				elif kind == "orb":
					cat = "orb"
				var bucket: Dictionary = cats[cat]
				bucket[title] = int(bucket.get(title, 0)) + 1
	return cats


func _catalog_species_total(cats: Dictionary) -> int:
	return (cats.get("birds", {}) as Dictionary).size() + (cats.get("fish", {}) as Dictionary).size() + (cats.get("land", {}) as Dictionary).size()


func _show_field_guide() -> void:
	var cats: Dictionary = _build_catalog()
	var dialog := AcceptDialog.new()
	dialog.title = "Field Guide"
	dialog.min_size = Vector2(440, 460)
	dialog.exclusive = true

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 420)
	dialog.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var sections: Array = [
		["Birds", "birds"], ["Fish", "fish"], ["Land Creatures", "land"],
		["Landmarks", "landmark"], ["Wonders", "wonder"], ["Moon Relics", "orb"], ["Other Finds", "other"],
	]
	var any_found: bool = false
	for s in sections:
		var bucket: Dictionary = cats.get(str(s[1]), {})
		if bucket.is_empty():
			continue
		any_found = true
		var header := Label.new()
		header.text = str(s[0]) + "   (" + str(bucket.size()) + ")"
		header.add_theme_font_size_override("font_size", 16)
		header.modulate = Color(0.82, 0.9, 1.0)
		vbox.add_child(header)
		var titles: Array = bucket.keys()
		titles.sort()
		for title in titles:
			var cnt: int = int(bucket[title])
			var row := Label.new()
			row.text = "    •  " + str(title) + ("    ×" + str(cnt) if cnt > 1 else "")
			row.add_theme_font_size_override("font_size", 13)
			vbox.add_child(row)
		vbox.add_child(HSeparator.new())

	if not any_found:
		var empty := Label.new()
		empty.text = "Nothing cataloged yet. Explore — your bioscanner logs nearby wildlife automatically (upgrade Survey range to scan farther), then come back here."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(400, 0)
		vbox.add_child(empty)

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
	_save_world_data()  # preserve the current saved game before starting a fresh one
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


# One-line summary of a saved game (universe) for the menu: worlds, total
# discoveries across all its maps, and how long ago it was last saved.
func _universe_summary(universe: Dictionary) -> String:
	var worlds: Dictionary = universe.get("worlds", {})
	var world_count: int = worlds.size()
	var disc: int = 0
	for w in worlds.values():
		var maps: Dictionary = (w as Dictionary).get("maps", {})
		for m in maps.values():
			disc += (m as Dictionary).get("discoveries", {}).size()
	var parts: Array = []
	parts.append(str(world_count) + (" world" if world_count == 1 else " worlds"))
	parts.append(str(disc) + " discovered")
	var unix: int = int(universe.get("last_explicit_save_unix", 0))
	if unix > 0:
		parts.append("played " + _relative_time(unix))
	return "  ·  ".join(parts)


func _relative_time(unix_time: int) -> String:
	var delta: int = maxi(0, int(Time.get_unix_time_from_system()) - unix_time)
	if delta < 60:
		return "just now"
	if delta < 3600:
		return str(delta / 60) + "m ago"
	if delta < 86400:
		return str(delta / 3600) + "h ago"
	return str(delta / 86400) + "d ago"


func _rename_universe(universe_id: String) -> void:
	var universes: Dictionary = save_data.get("universes", {})
	if not universes.has(universe_id):
		return
	var current_name: String = str((universes[universe_id] as Dictionary).get("name", universe_id))
	var dialog := AcceptDialog.new()
	dialog.title = "Rename Saved Game"
	var vb := VBoxContainer.new()
	dialog.add_child(vb)
	var label := Label.new()
	label.text = "Enter a new name:"
	vb.add_child(label)
	var line_edit := LineEdit.new()
	line_edit.text = current_name
	line_edit.select_all()
	line_edit.custom_minimum_size = Vector2(240, 0)
	vb.add_child(line_edit)
	dialog.register_text_enter(line_edit)
	if menu_layer != null:
		menu_layer.add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered(Vector2i(300, 100))
	dialog.confirmed.connect(func():
		var new_name: String = line_edit.text.strip_edges()
		if new_name != "":
			_apply_universe_rename(universe_id, new_name)
			_show_main_menu()
	)


func _apply_universe_rename(universe_id: String, new_name: String) -> void:
	var universes: Dictionary = save_data.get("universes", {})
	if not universes.has(universe_id):
		return
	var universe: Dictionary = universes[universe_id]
	universe["name"] = new_name
	_set_universe(universe_id, universe)
	_save_world_data()


func _delete_universe(universe_id: String) -> void:
	var universes: Dictionary = save_data.get("universes", {})
	if not universes.has(universe_id) or universe_id == current_universe_id or universes.size() <= 1:
		return
	var nm: String = str((universes[universe_id] as Dictionary).get("name", universe_id))
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Saved Game"
	dialog.dialog_text = "Permanently delete \"" + nm + "\"? This cannot be undone."
	if menu_layer != null:
		menu_layer.add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered(Vector2i(360, 120))
	dialog.confirmed.connect(func():
		_apply_universe_delete(universe_id)
		_show_main_menu()
	)


func _apply_universe_delete(universe_id: String) -> void:
	var universes: Dictionary = save_data.get("universes", {})
	if not universes.has(universe_id) or universe_id == current_universe_id or universes.size() <= 1:
		return
	universes.erase(universe_id)
	save_data["universes"] = universes
	_save_world_data()


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

func _create_floating_island_map_record(map_seed: int) -> MapRecord:
	return WorldGraph.create_map_record(map_seed, WorldGraph.MAP_FLOATING_ISLAND)


func _create_world_record(world_name: String, root_map_id: String, map_seed: int) -> WorldRecord:
	return WorldGraph.create_world_record(world_name, root_map_id, map_seed)


func _create_world_record_dict(world_name: String, root_map_id: String, map_seed: int) -> Dictionary:
	return _create_precomputed_world_record(world_name, root_map_id, root_map_id, map_seed)


func _create_precomputed_world_record(world_name: String, world_id: String, root_map_id: String, map_seed: int) -> Dictionary:
	var world_record: Dictionary = _create_world_record(world_name, root_map_id, map_seed).to_dict()
	var map_ids: Array[String] = [root_map_id]
	var route_map_count: int = GateTravelService.MAX_ROUTE_MAPS
	for i in range(1, route_map_count):
		map_ids.append(_new_id("map"))

	var route_rng := StableRng.new(StableRng.mix_string(StableRng.mix_string(map_seed, "route_types"), world_id))
	var maps: Dictionary = {}
	for i in range(map_ids.size()):
		var map_id: String = map_ids[i]
		if i == 0:
			maps[map_id] = _create_map_record(map_seed).to_dict()
			continue
		var branch_roll: float = route_rng.randf()
		var map_type: String = WorldGraph.MAP_NORMAL
		if branch_roll < WATER_ROUTE_CHANCE:
			map_type = WorldGraph.MAP_WATER
		elif branch_roll < WATER_ROUTE_CHANCE + 0.10:
			map_type = WorldGraph.MAP_ARCTIC
		elif branch_roll < WATER_ROUTE_CHANCE + 0.10 + FLOATING_ROUTE_CHANCE:
			map_type = WorldGraph.MAP_FLOATING_ISLAND
		elif branch_roll < WATER_ROUTE_CHANCE + 0.10 + FLOATING_ROUTE_CHANCE + 0.18:
			map_type = WorldGraph.MAP_CAVE
		elif branch_roll < WATER_ROUTE_CHANCE + 0.10 + FLOATING_ROUTE_CHANCE + 0.18 + CITY_ROUTE_CHANCE:
			map_type = WorldGraph.MAP_RUINED_CITY
		var local_seed: int = int((StableRng.mix_string(map_seed, "route_map_seed", i) & 0x7fffffff))
		if local_seed == 0:
			local_seed = map_seed + i + 1
		maps[map_id] = WorldGraph.create_map_record(local_seed, map_type).to_dict()

	var layout: Array[String] = map_ids.duplicate()
	var layout_rng := StableRng.new(StableRng.mix_string(StableRng.mix_string(map_seed, "route_layout"), world_id))
	for i in range(layout.size() - 1, 0, -1):
		var j: int = layout_rng.randi_range(0, i)
		var tmp: String = layout[i]
		layout[i] = layout[j]
		layout[j] = tmp

	var n: int = layout.size()
	var step: int = 7
	if n > 4:
		step = int(max(2, int(n / 4) - 1))
	for i in range(n):
		var current_id: String = layout[i]
		var current_record: Dictionary = maps.get(current_id, {})
		var gates: Dictionary = current_record.get("gates", {})
		gates["0"] = layout[(i + 1) % n]
		gates["1"] = layout[(i - 1 + n) % n]
		gates["2"] = layout[(i + step) % n]
		gates["3"] = layout[(i - step + n) % n]
		current_record["gates"] = gates
		maps[current_id] = current_record

	world_record["maps"] = maps
	world_record["root_map"] = root_map_id
	world_record["current_map"] = root_map_id
	return world_record


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
	_push_status_banner(msg, 2600)
	_try_award_map_survey_completion(current_world_id, current_map_id)


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


func _get_e_key_gate_enabled() -> bool:
	return e_key_gate_enabled


func _set_e_key_gate_enabled(enabled: bool) -> void:
	e_key_gate_enabled = enabled
	_save_world_data()
	last_discovery_text = "E-key gate use: " + ("enabled" if enabled else "disabled")
	_push_status_banner(last_discovery_text, 2200)


func _get_gate_debug_hud_enabled() -> bool:
	return show_gate_debug_hud


func _set_gate_debug_hud_enabled(enabled: bool) -> void:
	show_gate_debug_hud = enabled
	last_discovery_text = "Gate debug HUD: " + ("enabled" if enabled else "disabled")
	_push_status_banner(last_discovery_text, 2200)


func _push_status_banner(message: String, duration_msec: int = 2200) -> void:
	if message.strip_edges() == "":
		return
	_status_banner_text = message
	_status_banner_until_msec = Time.get_ticks_msec() + max(duration_msec, 400)


func _set_map_name(world_id: String, map_id: String, map_name: String) -> void:
	if world_id == "" or map_id == "":
		return
	var map_record: Dictionary = _get_map_record(world_id, map_id)
	if map_record.is_empty():
		return
	var trimmed: String = map_name.strip_edges()
	if trimmed == "":
		map_record.erase("name")
	else:
		map_record["name"] = trimmed.left(48)
	_update_world_map_record(world_id, map_id, map_record, true)


func _backstory_text() -> String:
	return "The Atlas of Gates once held every world together, but it shattered during the Convergence Collapse. Fragments of reality drifted apart, each sealed behind a dormant gate.\n\nYou are the last field cartographer of the Celestial Survey, dispatched from the floating observatory to cross the gates, map the splintered territories, and reassemble the Atlas one discovery at a time.\n\nOn the far side of certain gates lies the Moon — a silent world of glass craters and drifting lichen, where ancient shrines float in the void. Pilgrims who reach them all earn the title Moon Pilgrim.\n\nThe Survey's old handbooks speak of a limit: no more than thirty-two maps can be opened from a single world before the local gate-network saturates. Choose your path wisely."


func _atlas_summary_text() -> String:
	var worlds: Dictionary = _get_worlds()
	var universe: Dictionary = _current_universe()
	var world_count: int = worlds.size()
	var map_count: int = 0
	var discovery_count: int = 0
	var pin_count: int = 0
	var surveyed_count: int = 0
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
			if bool(map_record.get("map_survey_rewarded", false)):
				surveyed_count += 1

	var current_completion: String = ""
	if current_map_id != "":
		current_completion = " Current map: " + _map_completion_text(current_map_id) + "."

	return "Universe: " + str(universe.get("name", current_universe_id)) + " | Atlas: " + str(world_count) + " worlds, " + str(map_count) + " maps, " + str(discovery_count) + " discoveries, " + str(pin_count) + " pins, " + str(surveyed_count) + " surveyed." + current_completion


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
	body.continuous_cd = true
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
	var pin_cap: int = int(_progression_capabilities().get("pin_cap", 6))
	if pins.size() >= pin_cap:
		last_discovery_text = "Pin satchel full (" + str(pins.size()) + "/" + str(pin_cap) + ") — earn Pathfinder's Pins to carry more."
		_push_status_banner(last_discovery_text, 3000)
		return
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
	area.monitoring = true
	area.monitorable = true
	area.position = local_position

	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	shape_node.shape = shape
	area.add_child(shape_node)
	area.body_entered.connect(_on_discovery_body_entered.bind(discovery_id, title, kind, discovery_position))
	parent.add_child(area)


func _poll_wonder_proximity_fallback() -> void:
	if current_world_id == "" or current_map_id == "" or generated_root == null or discovery_tracker == null:
		return
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var wonders: Array = generated_root.find_children("Wonder_*", "Node3D", true, false)
	for raw in wonders:
		var wonder: Node3D = raw as Node3D
		if wonder == null:
			continue
		var fallback_id: String = "wonder_" + str(int(round(wonder.global_position.x))) + "_" + str(int(round(wonder.global_position.z)))
		var discovery_id: String = str(wonder.get_meta("discovery_id", fallback_id))
		var title: String = str(wonder.get_meta("discovery_title", _wonder_title(wonder.name)))
		var kind: String = str(wonder.get_meta("discovery_kind", "wonder"))
		if not wonder.has_meta("discovery_id"):
			wonder.set_meta("discovery_id", discovery_id)
		if not wonder.has_meta("discovery_title"):
			wonder.set_meta("discovery_title", title)
		if not wonder.has_meta("discovery_kind"):
			wonder.set_meta("discovery_kind", kind)
		var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
		var discoveries: Dictionary = map_record.get("discoveries", {})
		if discoveries.has(discovery_id):
			continue
		var dist: float = wonder.global_position.distance_to(player.global_position)
		if dist <= 13.0:
			discovery_tracker.record_discovery(discovery_id, title, kind, wonder.global_position)
			last_discovery_text = "New discovery: " + title


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
	player.global_position = _sanitize_player_position(_find_spawn_position())
	player.velocity = Vector3.ZERO


func _enforce_world_bounds() -> void:
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var pos: Vector3 = player.global_position
	var half: float = _world_half_size() * 0.98
	if _is_current_map_gate_room():
		half = 32.0
	elif _is_current_map_map_nexus():
		half = 42.0
	var changed: bool = false
	if abs(pos.x) > half:
		pos.x = clamp(pos.x, -half, half)
		changed = true
	if abs(pos.z) > half:
		pos.z = clamp(pos.z, -half, half)
		changed = true
	if changed:
		if not _is_current_map_cave():
			var ground_y: float = _height_at_world(pos.x, pos.z)
			pos.y = max(pos.y, ground_y + 1.2)
		player.global_position = pos
		player.velocity = Vector3.ZERO
		_transition_status_line = "Boundary correction applied."


func _update_underwater_state() -> void:
	var player: CharacterBody3D = _get_player()
	if player == null or hud_controller == null:
		return
	hud_controller.update_underwater_state(
		_is_current_map_moon(),
		_is_current_map_gate_room(),
		player.camera,
	)


# Arctic exposure pressure. Warmth ticks down in Player every frame; here Main
# (which knows the map type and landmark layout) drives the sheltered flag and the
# gentle, fully recoverable cold blackout. No effect off arctic maps.
func _update_arctic_exposure() -> void:
	if not _is_current_map_arctic():
		return
	var player: CharacterBody3D = _get_player()
	if player == null or player.get("warmth_enabled") == null:
		return
	var now: int = Time.get_ticks_msec()
	# Throttle the landmark scan (warmth itself ticks every frame in Player).
	if now >= _arctic_shelter_check_msec:
		_arctic_shelter_check_msec = now + 250
		player.set("sheltered", _near_warm_landmark(player.global_position))
	if float(player.get("warmth")) <= 0.0 and now >= _arctic_recover_cooldown_until_msec:
		_arctic_recover_cooldown_until_msec = now + 2500
		_recover_frozen_player(player)


# Gates and wonders radiate warmth — routing between them is how you survive the
# cold. Reads the already-maintained _wonder_positions list (a handful of entries).
func _near_warm_landmark(from: Vector3) -> bool:
	var radius_sq: float = ARCTIC_SHELTER_RADIUS * ARCTIC_SHELTER_RADIUS
	for entry in _wonder_positions:
		var kind: String = str(entry.get("kind", ""))
		if kind != "gate" and kind != "wonder":
			continue
		var dx: float = float(entry.get("x", 0.0)) - from.x
		var dz: float = float(entry.get("z", 0.0)) - from.z
		if dx * dx + dz * dz <= radius_sq:
			return true
	return false


func _recover_frozen_player(player: CharacterBody3D) -> void:
	if player == null:
		return
	player.global_position = _sanitize_player_position(_find_spawn_position())
	player.velocity = Vector3.ZERO
	player.set("warmth", float(player.get("max_warmth")))
	player.set("sheltered", true)
	last_discovery_text = "You nearly froze — recovered at a safe ridge. Warm up near gates and wonders."
	_push_status_banner(last_discovery_text, 4200)


# Running out of air below the surface ends in a gentle, fully recoverable
# blackout: surface back at a safe spawn with full breath. Uses the player's own
# water_level so moon/arctic (water disabled, level -100000) never trigger it.
func _update_drowning() -> void:
	var player: CharacterBody3D = _get_player()
	if player == null or player.get("breath") == null or player.get("water_level") == null:
		return
	var player_water_level: float = float(player.get("water_level"))
	var underwater: bool = player.global_position.y + 1.65 < player_water_level
	if not underwater or float(player.get("breath")) > 0.0:
		return
	var now: int = Time.get_ticks_msec()
	if now < _water_recover_cooldown_until_msec:
		return
	_water_recover_cooldown_until_msec = now + 2500
	_recover_drowned_player(player)


func _recover_drowned_player(player: CharacterBody3D) -> void:
	if player == null:
		return
	player.global_position = _sanitize_player_position(_find_spawn_position())
	player.velocity = Vector3.ZERO
	player.set("breath", float(player.get("max_breath")))
	last_discovery_text = "Out of air — you surface gasping. Upgrade Lungs to dive deeper."
	_push_status_banner(last_discovery_text, 4200)


# Cave darkness pressure. The flashlight recharges by moving, so a fully-dead lamp
# only persists if you stall in the dark; after a sustained spell, a gentle
# recoverable retreat to the entrance. The Lantern kit track (more charge, longer
# range) is what keeps this from happening — the cave's coupling to the kit.
func _update_cave_darkness() -> void:
	if not _is_current_map_cave():
		_cave_dark_since_msec = 0
		return
	var player: CharacterBody3D = _get_player()
	if player == null or player.get("flashlight_charge") == null:
		_cave_dark_since_msec = 0
		return
	if float(player.get("flashlight_charge")) > 0.01:
		_cave_dark_since_msec = 0
		return
	var now: int = Time.get_ticks_msec()
	if _cave_dark_since_msec == 0:
		_cave_dark_since_msec = now
	elif now - _cave_dark_since_msec >= CAVE_DARK_LIMIT_MSEC and now >= _cave_recover_cooldown_until_msec:
		_cave_recover_cooldown_until_msec = now + 2500
		_cave_dark_since_msec = 0
		_recover_lost_player(player)


func _recover_lost_player(player: CharacterBody3D) -> void:
	if player == null:
		return
	player.global_position = _sanitize_player_position(_find_spawn_position())
	player.velocity = Vector3.ZERO
	player.set("flashlight_charge", float(player.get("max_flashlight_charge")))
	last_discovery_text = "Lost in the dark — you retrace your steps to the entrance. Upgrade Lantern to range farther."
	_push_status_banner(last_discovery_text, 4200)


# Bioscan: auto-catalog creature flocks within survey range as atlas discoveries
# (No Man's Sky-style fauna logging). Scan range = base + the Survey kit's reach, so
# the previously-inert survey_radius capability now has a tangible payoff. Cataloged
# species feed the discovery total like any other find.
func _update_bioscan() -> void:
	if generated_root == null or discovery_tracker == null:
		return
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var now: int = Time.get_ticks_msec()
	if now < _bioscan_next_msec:
		return
	_bioscan_next_msec = now + 500
	var scan_range: float = BIOSCAN_BASE_RANGE + float(_progression_capabilities().get("survey_radius", 0.0))
	var range_sq: float = scan_range * scan_range
	for child in generated_root.get_children():
		var name_str: String = str(child.name)
		if not (name_str.begins_with("BirdFlock") or name_str.begins_with("FishSchool") or name_str.begins_with("CritterHerd")):
			continue
		var flock: Node3D = child as Node3D
		if flock == null or flock.get("catalog_id") == null:
			continue
		var catalog_id: String = str(flock.get("catalog_id"))
		if catalog_id == "":
			continue
		if flock.global_position.distance_squared_to(player.global_position) > range_sq:
			continue
		# record_discovery dedupes by id, so re-scans of a logged species are no-ops.
		discovery_tracker.record_discovery(catalog_id, str(flock.get("species_name")), "creature", flock.global_position)

	# Survey nearby landmarks (static monuments) into the Field Guide as well.
	var landmarks_node: Node = generated_root.get_node_or_null("Landmarks")
	if landmarks_node != null:
		for lm in landmarks_node.get_children():
			if not (lm is Node3D) or not (lm as Node3D).has_meta("catalog_id"):
				continue
			var lm3d: Node3D = lm as Node3D
			if lm3d.global_position.distance_squared_to(player.global_position) > range_sq:
				continue
			discovery_tracker.record_discovery(str(lm3d.get_meta("catalog_id")), str(lm3d.get_meta("survey_name", "Landmark")), "landmark", lm3d.global_position)


# Deterministic, biome-appropriate weather for the map (consistent on reload). Caves,
# the moon and hub spaces have no sky, so they stay clear.
func _determine_weather() -> String:
	if _is_current_map_cave() or _is_current_map_moon() or _is_current_map_gate_room() or _is_current_map_map_nexus():
		return WeatherFactory.CLEAR
	var rng := StableRng.new(StableRng.mix_string(world_seed, "weather"))
	var r: float = rng.randf()
	if _is_current_map_arctic():
		if r < 0.35:
			return WeatherFactory.CLEAR
		if r < 0.72:
			return WeatherFactory.SNOW
		return WeatherFactory.BLIZZARD
	if _is_current_map_water():
		return WeatherFactory.CLEAR if r < 0.5 else WeatherFactory.RAIN
	if _is_current_map_floating_island():
		return WeatherFactory.CLEAR if r < 0.7 else WeatherFactory.RAIN
	return WeatherFactory.CLEAR if r < 0.55 else WeatherFactory.RAIN


func _setup_weather() -> void:
	_weather_root = null
	_weather_type = _determine_weather()
	# Storms dim the directional sun for a gloomier, overcast feel (applied each frame
	# on top of the day/night energy in _update_day_night_cycle).
	match _weather_type:
		WeatherFactory.RAIN:
			_weather_sun_mult = 0.60
		WeatherFactory.SNOW:
			_weather_sun_mult = 0.78
		WeatherFactory.BLIZZARD:
			_weather_sun_mult = 0.48
		_:
			_weather_sun_mult = 1.0
	var node: Node3D = WeatherFactory.build(_weather_type)
	if node != null and generated_root != null:
		generated_root.add_child(node)
		_weather_root = node
		_update_weather_follow()
	# A blizzard makes the arctic cold bite harder (ties into the warmth pressure).
	if _weather_type == WeatherFactory.BLIZZARD:
		var player: CharacterBody3D = _get_player()
		if player != null and player.get("warmth_drain_per_sec") != null:
			player.set("warmth_drain_per_sec", float(player.get("warmth_drain_per_sec")) * 1.7)


# Keep the storm centred on the player so it feels continuous as they move.
func _update_weather_follow() -> void:
	if not is_instance_valid(_weather_root):
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	_weather_root.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
	# Hide falling rain/snow when the player is under a roof (indoors) — the particles
	# would otherwise pass straight through a solid ceiling. Guarded against the brief
	# mid-transition states where the player isn't in a live physics world.
	if _map_loading or not player.is_inside_tree():
		return
	var world: World3D = player.get_world_3d()
	if world == null or world.direct_space_state == null:
		return
	var from: Vector3 = player.global_position + Vector3(0.0, 1.7, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, 28.0, 0.0))
	query.exclude = [player.get_rid()]
	_weather_root.visible = world.direct_space_state.intersect_ray(query).is_empty()


func _weather_hud_text() -> String:
	if _weather_type == WeatherFactory.CLEAR:
		return ""
	return "Weather: " + WeatherFactory.label_for(_weather_type)


# Dev toggle (Shift+S menu): flip between bright midday and deep night.
func _toggle_day_night() -> void:
	var hour: float = (_cycle_time / CYCLE_LENGTH) * 24.0
	var is_day: bool = hour >= 7.0 and hour < 17.5
	_cycle_time = CYCLE_LENGTH * (0.0 if is_day else 0.5)   # -> midnight or noon
	_update_day_night_cycle()


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

	sun_light.light_energy *= _weather_sun_mult

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
	var warmth: float = -1.0
	var max_warmth: float = -1.0
	var warmth_enabled: bool = false
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
		if player.get("warmth_enabled") != null and bool(player.get("warmth_enabled")):
			warmth_enabled = true
			warmth = float(player.get("warmth"))
			max_warmth = float(player.get("max_warmth"))
			if warmth <= max_warmth * 0.25:
				warning_text = "Freezing — warm up near a gate or wonder"
			elif warmth <= max_warmth * 0.5 and warning_text == "":
				warning_text = "Getting cold — head for a gate or wonder"
		if _is_current_map_cave() and player.get("flashlight_charge") != null:
			var f_charge: float = float(player.get("flashlight_charge"))
			var f_max: float = float(player.get("max_flashlight_charge")) if player.get("max_flashlight_charge") != null else 30.0
			if f_charge <= 0.01:
				warning_text = "In the dark — keep moving to recharge your lantern"
			elif f_charge <= f_max * 0.25 and warning_text == "":
				warning_text = "Lantern low — keep moving to recharge"
		var gate_hint: String = _gate_sight_hint()
		if gate_hint != "":
			warning_text = (warning_text + " | " + gate_hint) if warning_text != "" else gate_hint
			_show_field_tip("gate")
	if show_gate_debug_hud and not _is_current_map_gate_room() and not _is_current_map_map_nexus() and _gate_debug_line != "":
		if warning_text != "":
			warning_text += " | "
		warning_text += _gate_debug_line
	if _transition_status_line != "":
		if warning_text != "":
			warning_text += " | "
		warning_text += _transition_status_line

	var flashlight_text: String = ""
	if player != null and player.get("flashlight_on") != null:
		var f_on: bool = bool(player.get("flashlight_on"))
		var f_requested: bool = bool(player.get("flashlight_requested_on"))
		var f_charge: float = float(player.get("flashlight_charge"))
		if f_on:
			flashlight_text = "Flashlight: " + str(int(f_charge)) + "s"
		elif f_requested and f_charge <= 0.01:
			flashlight_text = "Flashlight: DEAD (ON)"
		elif f_requested:
			flashlight_text = "Flashlight: charging " + str(int(f_charge)) + "s/8s"
		else:
			flashlight_text = "[F] Flashlight"
	var music_text: String = _current_music_line()

	var world_name: String = "?"
	var map_name: String = ""
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
	map_name = _display_name_for_map(current_world_id, current_map_id)

	var now_msec: int = Time.get_ticks_msec()
	var discovery_line: String = _status_banner_text if now_msec <= _status_banner_until_msec else last_discovery_text
	if discovery_line == "":
		discovery_line = "Seek gates, ruins, and wonders."
	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	var objective_line: String = _next_objective_hint(map_record)
	var progression_line: String = _progression_hint(map_record)
	var next_reward_line: String = _next_survey_reward_hint(current_world_id)
	var world_map_count: int = discovery_tracker.current_world_map_count() if discovery_tracker != null else 0
	var maps_line: String = "Maps in world: " + str(world_map_count)
	var map_type: String = str(map_record.get("type", ""))
	var recent_discoveries: Array[String] = _recent_discovery_titles(map_record.get("discoveries", {}), 3)
	hud_controller.update({
		"delta": delta,
		"map_short": map_short,
		"world_name": world_name,
		"map_name": map_name,
		"map_type": map_type,
		"map_type_label": _map_type_label(map_type),
		"position_text": position_text,
		"warning_text": warning_text,
			"flashlight_text": flashlight_text,
			"weather_text": _weather_hud_text(),
			"music_text": music_text,
		"discovery_line": discovery_line,
		"objective_line": objective_line,
		"kit_line": _kit_hud_line(),
		"progression_line": progression_line,
		"next_reward_line": next_reward_line,
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
		"warmth": warmth,
		"max_warmth": max_warmth,
		"warmth_enabled": warmth_enabled,
		"player_node": player,
		"world_half_size": _world_half_size(),
		"minimap_zoom": 1.15 if _is_current_map_moon() else 1.0,
	})


func _next_objective_hint(map_record: Dictionary) -> String:
	if _is_current_map_gate_room():
		return "Objective: Enter a world gate to chart another map."
	if _is_current_map_map_nexus():
		return "Objective: Select a nexus gate to branch your atlas route. " + _nexus_slot_hint_text(map_record)
	if _is_current_map_moon():
		var discoveries: Dictionary = map_record.get("discoveries", {})
		var shrine_count: int = 0
		for key in discoveries.keys():
			if str(key).begins_with("moon_orb_"):
				shrine_count += 1
		var shrine_charge: Dictionary = map_record.get("moon_shrine_charge", {})
		var charged_count: int = shrine_charge.size()
		if shrine_count < 9:
			return "Objective: Attune moon shrines with thrown lichen, then recover orbs (" + str(shrine_count) + "/9, charged " + str(charged_count) + ")."
		return "Objective: Return through a gate and continue atlas expansion."
	if _is_current_map_cave():
		return _maze_objective_text(map_record)
	if _is_current_map_water():
		var water_available: int = int(map_record.get("available_discoveries", 0))
		var water_found: int = map_record.get("discoveries", {}).size()
		if water_available > water_found:
			return "Objective: Dive for sunken caches on the seabed (" + str(water_found) + "/" + str(water_available) + ") — surface before your breath runs out."
		return "Objective: Caches recovered. Cross a gate to chart onward."
	if _is_current_map_ruined_city():
		var city_total: int = int(map_record.get("city_cores_total", 0))
		var city_found: int = _city_cores_found(map_record)
		if city_total <= 0 or city_found < city_total:
			return "Objective: Explore the ruined buildings for data cores (" + str(city_found) + "/" + str(maxi(city_total, 1)) + ")."
		return "Objective: All data cores recovered. Cross a gate to chart onward."

	var available: int = int(map_record.get("available_discoveries", 0))
	var found: int = map_record.get("discoveries", {}).size()
	if found <= 0 and map_record.get("pins", {}).is_empty():
		return "Objective: Find a discovery, then drop a pin [P] to mark your route."
	if available > 0 and found < available:
		return "Objective: Find remaining discoveries on this map (" + str(found) + "/" + str(available) + ")."
	if found <= 0:
		return "Objective: Find your first discovery on this map."
	var route_hint: String = _linked_route_hint(map_record)
	if route_hint != "":
		return route_hint

	var world_map_count: int = discovery_tracker.current_world_map_count() if discovery_tracker != null else 0
	return "Objective: Traverse gates and expand this world atlas (" + str(world_map_count) + " maps)."


func _nexus_slot_hint_text(map_record: Dictionary) -> String:
	var slots: Dictionary = map_record.get("nexus_slots", {})
	var universe: Dictionary = _current_universe()
	var worlds: Dictionary = universe.get("worlds", {})
	var parts: Array[String] = []
	for si in range(4):
		var wid: String = str(slots.get(str(si), ""))
		if wid != "" and worlds.has(wid):
			var w: Dictionary = worlds.get(wid, {})
			parts.append("G" + str(si + 1) + ": " + str(w.get("name", _short_id(wid))))
		else:
			parts.append("G" + str(si + 1) + ": Uncharted")
	return "Slots -> " + ", ".join(parts) + "."


func _maze_objective_text(map_record: Dictionary) -> String:
	var objective: Dictionary = _maze_objective_data(map_record)
	var key: String = str(objective.get("key", "gate_sprint"))
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var found: int = discoveries.size()
	match key:
		"gate_sprint":
			var seconds: int = int(objective.get("seconds", 0))
			var elapsed: int = max(int(round(float(Time.get_ticks_msec() - _map_loaded_at_msec) / 1000.0)), 0)
			var remaining: int = max(seconds - elapsed, 0)
			if bool(map_record.get("maze_objective_completed", false)):
				return "Objective complete: Gate sprint done (reward secured)."
			return "Objective: Find any gate and route out in " + str(seconds) + "s for a bonus (" + str(remaining) + "s left)."
		"discover_then_exit":
			var target: int = int(objective.get("target_discoveries", 2))
			if bool(map_record.get("maze_objective_completed", false)):
				return "Objective complete: Cartography sweep done."
			if found < target:
				return "Objective: Secure " + str(target) + " discoveries, then route through any gate (" + str(found) + "/" + str(target) + ")."
			return "Objective: Discoveries secured. Exit through any gate for reward."
		"orb_and_exit":
			if bool(map_record.get("maze_objective_completed", false)):
				return "Objective complete: Orb relay done."
			var has_orb: bool = lichen_count > 0
			if not has_orb:
				return "Objective: Recover a cave orb/lichen and carry it to a gate."
			return "Objective: Orb cargo ready. Route through any gate for reward."
		"clean_exit":
			if bool(map_record.get("maze_objective_completed", false)):
				return "Objective complete: Clean run done."
			var sprint_value: float = 0.0
			var player: CharacterBody3D = _get_player()
			if player != null and player.get("sprint_stamina") != null:
				sprint_value = float(player.get("sprint_stamina"))
			var stamina_target: float = float(objective.get("stamina_min", 8.0))
			if sprint_value < stamina_target:
				return "Objective: Recover stamina to " + str(int(stamina_target)) + "+, then exit through a gate."
			return "Objective: Stamina threshold met. Exit through any gate for reward."
	return "Objective: Route deeper into the maze network."


func _maze_objective_data(map_record: Dictionary) -> Dictionary:
	var objective: Dictionary = map_record.get("maze_objective", {})
	if typeof(objective) != TYPE_DICTIONARY or objective.is_empty():
		return {"key": "gate_sprint", "seconds": 90, "target_discoveries": 2, "stamina_min": 8.0}
	return objective


func _ensure_maze_objective(map_record: Dictionary) -> Dictionary:
	var existing: Dictionary = map_record.get("maze_objective", {})
	if typeof(existing) == TYPE_DICTIONARY and not existing.is_empty():
		return map_record
	var seed: int = int(map_record.get("seed", 0))
	var idx: int = int(abs(seed) % MAZE_OBJECTIVE_VARIANTS.size())
	var key: String = MAZE_OBJECTIVE_VARIANTS[idx]
	var objective: Dictionary = {"key": key}
	match key:
		"gate_sprint":
			objective["seconds"] = 75 + int(abs(seed) % 56)
		"discover_then_exit":
			objective["target_discoveries"] = 2 + int(abs(seed / 5) % 2)
		"orb_and_exit":
			objective["carry_key"] = "lichen"
		"clean_exit":
			objective["stamina_min"] = 8.0 + float(int(abs(seed / 7) % 5))
	map_record["maze_objective"] = objective
	map_record["maze_objective_completed"] = false
	map_record["maze_objective_rewarded"] = false
	return map_record


func _try_complete_maze_objective_on_exit(map_record: Dictionary) -> Dictionary:
	if not _is_current_map_cave():
		return map_record
	map_record = _ensure_maze_objective(map_record)
	if bool(map_record.get("maze_objective_completed", false)):
		return map_record
	var objective: Dictionary = _maze_objective_data(map_record)
	var key: String = str(objective.get("key", "gate_sprint"))
	var completed: bool = false
	match key:
		"gate_sprint":
			var seconds: int = int(objective.get("seconds", 90))
			var elapsed: float = float(Time.get_ticks_msec() - _map_loaded_at_msec) / 1000.0
			completed = elapsed <= float(seconds)
			if not completed:
				last_discovery_text = "Maze objective missed: gate sprint over " + str(seconds) + "s."
				_push_status_banner(last_discovery_text, 3600)
		"discover_then_exit":
			var target: int = int(objective.get("target_discoveries", 2))
			var found: int = map_record.get("discoveries", {}).size()
			completed = found >= target
			if not completed:
				last_discovery_text = "Maze objective incomplete: discoveries " + str(found) + "/" + str(target) + "."
				_push_status_banner(last_discovery_text, 3600)
		"orb_and_exit":
			completed = lichen_count > 0
			if not completed:
				last_discovery_text = "Maze objective incomplete: carry a lichen/orb through gate."
				_push_status_banner(last_discovery_text, 3600)
		"clean_exit":
			var player: CharacterBody3D = _get_player()
			var stamina: float = 0.0
			if player != null and player.get("sprint_stamina") != null:
				stamina = float(player.get("sprint_stamina"))
			completed = stamina >= float(objective.get("stamina_min", 8.0))
			if not completed:
				last_discovery_text = "Maze objective incomplete: stamina threshold not met."
				_push_status_banner(last_discovery_text, 3600)
	if not completed:
		if last_discovery_text == "":
			last_discovery_text = "Maze objective incomplete; route logged."
			_push_status_banner(last_discovery_text, 3000)
		return map_record
	map_record["maze_objective_completed"] = true
	if not bool(map_record.get("maze_objective_rewarded", false)):
		map_record["maze_objective_rewarded"] = true
		lichen_count += 2
		var player_node: CharacterBody3D = _get_player()
		if player_node != null and player_node.has_method(&"set"):
			player_node.set("lichen_count", lichen_count)
		last_discovery_text = "Maze objective complete: +2 lichen reward."
		_push_status_banner(last_discovery_text, 4200)
	return map_record


func _current_music_line() -> String:
	var music_parent: Node3D = self
	var music_player: AudioStreamPlayer = music_parent.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player == null and generated_root != null:
		music_player = generated_root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		var title: String = str(music_player.get_meta("track_title", "")).strip_edges()
		if title != "":
			return "Now Playing: " + title
		if music_player.stream != null and str(music_player.stream.resource_path) != "":
			var path: String = str(music_player.stream.resource_path)
			var file_name: String = path.get_file()
			var dot: int = file_name.rfind(".")
			if dot > 0:
				file_name = file_name.substr(0, dot)
			return "Now Playing: " + file_name
	var proc_pad: AudioStreamPlayer = music_parent.get_node_or_null("ProceduralSynthPad") as AudioStreamPlayer
	if proc_pad == null and generated_root != null:
		proc_pad = generated_root.get_node_or_null("ProceduralSynthPad") as AudioStreamPlayer
	if proc_pad != null:
		return "Now Playing: Procedural Synth"
	return ""


func _on_prev_music_pressed() -> void:
	if not AudioManager.playlist_prev(self):
		last_discovery_text = "Now Playing: at first track."


func _on_next_music_pressed() -> void:
	if not AudioManager.playlist_next(self):
		last_discovery_text = "Now Playing: no playlist loaded."


func _progression_hint(_map_record: Dictionary) -> String:
	var total_discoveries: int = _progression_total()
	var nxt: Dictionary = ProgressionService.next_upgrade(total_discoveries)
	if nxt.is_empty():
		return "Kit complete: full Cartographer's Kit earned (" + str(total_discoveries) + " discoveries)."
	var threshold: int = int(nxt.get("threshold", 0))
	return "Next upgrade: " + str(nxt.get("name", "?")) + " at " + str(threshold) + " (" + str(total_discoveries) + "/" + str(threshold) + ") — " + str(nxt.get("desc", ""))


func _surveyed_map_count_in_world(world_id: String) -> int:
	if world_id == "":
		return 0
	var world: Dictionary = _get_world(world_id)
	var maps: Dictionary = world.get("maps", {})
	var count: int = 0
	for map_id in maps.keys():
		var raw = maps[map_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var map_record: Dictionary = raw
		if bool(map_record.get("map_survey_rewarded", false)):
			count += 1
	return count


func _next_survey_reward_hint(world_id: String) -> String:
	var milestones: Array[int] = [3, 6, 10, 15]
	var surveyed: int = _surveyed_map_count_in_world(world_id)
	for milestone in milestones:
		if surveyed < milestone:
			return "Next survey reward: " + str(milestone) + " surveyed maps (" + str(surveyed) + "/" + str(milestone) + ")."
	return "Survey rewards complete: all milestones reached (" + str(surveyed) + " surveyed maps)."


func _map_type_label(map_type: String) -> String:
	match map_type:
		WorldGraph.MAP_NORMAL:
			return "Frontier"
		WorldGraph.MAP_WATER:
			return "Archipelago"
		WorldGraph.MAP_ARCTIC:
			return "Arctic Expanse"
		WorldGraph.MAP_FLOATING_ISLAND:
			return "Sky Archipelago"
		WorldGraph.MAP_CAVE:
			return "Labyrinth Cave"
		WorldGraph.MAP_MOON:
			return "Moon Surface"
		WorldGraph.MAP_GATE_ROOM:
			return "Inter-world Gate Room"
		WorldGraph.MAP_NEXUS:
			return "World Nexus"
		WorldGraph.MAP_RUINED_CITY:
			return "Ruined City"
		_:
			return map_type


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
		var target_name: String = _display_name_for_map(current_world_id, best_target_id)
		return "Objective: Route through " + target_name + " (" + str(best_remaining) + " discoveries remaining)."
	return ""


func _display_name_for_map(world_id: String, map_id: String) -> String:
	if world_id == "" or map_id == "":
		return _short_id(map_id)
	var map_record: Dictionary = _get_map_record(world_id, map_id)
	var custom_name: String = str(map_record.get("name", "")).strip_edges()
	if custom_name != "" and custom_name != map_id:
		return custom_name
	return _short_id(map_id)


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

func _is_current_map_floating_island() -> bool:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return str(raw.get("type", "")) == WorldGraph.MAP_FLOATING_ISLAND


func _is_current_map_ruined_city() -> bool:
	var raw: Dictionary = _get_map_record(current_world_id, current_map_id)
	return str(raw.get("type", "")) == WorldGraph.MAP_RUINED_CITY


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


func _progression_total() -> int:
	return discovery_tracker.total_discoveries_in_universe() if discovery_tracker != null else 0


func _kit_hud_line() -> String:
	var summary: String = ProgressionService.kit_summary(_progression_total())
	if summary == "":
		return "Kit: base gear — earn discoveries to upgrade."
	return "Kit: " + summary


# Show a first-run tip once per universe. Seen ids persist in universe.tips_seen
# (the save schema is permissive, so no migration is needed).
func _show_field_tip(tip_id: String) -> void:
	if not FIELD_TIPS.has(tip_id):
		return
	var universe: Dictionary = _current_universe()
	var seen: Array = universe.get("tips_seen", [])
	if seen.has(tip_id):
		return
	seen.append(tip_id)
	universe["tips_seen"] = seen
	_set_current_universe(universe)
	_save_world_data()
	_push_status_banner(str(FIELD_TIPS[tip_id]), 7000)


func _gate_is_charted(gate_index: int) -> bool:
	if current_world_id == "":
		return false
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var mr: Dictionary = maps.get(current_map_id, {})
	var gates: Dictionary = mr.get("gates", {})
	var tid: String = str(gates.get(str(gate_index), ""))
	return tid != "" and maps.has(tid)


# Destination world type for a gate. Passes predict the SAME route chances Main
# feeds resolve_gate_transition() (see _force_gate_transition), so the preview
# matches what activation will actually produce.
func _gate_destination_type(gate_index: int) -> String:
	var world: Dictionary = _get_world(current_world_id)
	return GateTravelService.predict_gate_target_type(
		world_seed, current_map_id, gate_index, world,
		WATER_ROUTE_CHANCE, 0.10, 0.18, NEXUS_ROUTE_CHANCE, 0.0, CITY_ROUTE_CHANCE,
	)


# Gate Sight: when standing near a gate, name where it leads. Already-charted gates
# always show their type; unknown routes reveal it only once Gate Sight is unlocked.
func _gate_sight_hint() -> String:
	if _last_gate_index_in_range < 0:
		return ""
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		return ""
	var gate_num: int = _last_gate_index_in_range + 1
	if _gate_is_charted(_last_gate_index_in_range) or bool(_progression_capabilities().get("gate_sight", false)):
		return "Gate " + str(gate_num) + " → " + _map_type_label(_gate_destination_type(_last_gate_index_in_range))
	return "Gate " + str(gate_num) + " → uncharted (unlock Gate Sight to read it)"


func _progression_capabilities() -> Dictionary:
	return ProgressionService.capabilities(_progression_total())


func _apply_progression_to_player(player: CharacterBody3D) -> void:
	if player != null and player.has_method(&"apply_capabilities"):
		player.apply_capabilities(_progression_capabilities())


# Called after every newly-recorded discovery. Detects Cartographer's Kit upgrades
# crossed since the last announcement, applies the higher ceilings to the live
# player, toasts once, and persists the announced set. Capabilities themselves are
# derived from the discovery count, so the announced list is the only state stored.
func _on_discovery_recorded() -> void:
	_show_field_tip("kit")
	var total: int = _progression_total()
	var universe: Dictionary = _current_universe()
	var announced: Array = universe.get("announced_upgrades", [])
	var newly: Array[String] = []
	for id in ProgressionService.unlocked_ids(total):
		if not announced.has(id):
			newly.append(str(id))
	if newly.is_empty():
		return
	for id in newly:
		announced.append(id)
	universe["announced_upgrades"] = announced
	_set_current_universe(universe)
	_save_world_data()
	_apply_progression_to_player(_get_player())
	var names: Array[String] = []
	for id in newly:
		names.append(str(ProgressionService.upgrade_by_id(id).get("name", id)))
	var label: String = "Kit upgrade: " + ", ".join(names) + "!"
	last_discovery_text = label
	_push_status_banner(label, 4600)
	print("Kit upgrade unlocked: ", ", ".join(names))


func _ensure_loading_overlay() -> void:
	if is_instance_valid(_loading_layer):
		return
	_loading_layer = CanvasLayer.new()
	_loading_layer.name = "LoadingLayer"
	_loading_layer.layer = 100
	add_child(_loading_layer)
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.02, 0.03, 0.06, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_layer.add_child(bg)
	_loading_label = Label.new()
	_loading_label.anchor_right = 1.0
	_loading_label.anchor_bottom = 1.0
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 28)
	_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_loading_label)
	_loading_layer.visible = false


func _show_loading_overlay(text: String) -> void:
	_ensure_loading_overlay()
	if _loading_label != null:
		_loading_label.text = text
	_loading_layer.visible = true


func _hide_loading_overlay() -> void:
	if is_instance_valid(_loading_layer):
		_loading_layer.visible = false


func _load_map(world_id: String, map_id: String) -> void:
	if _map_loading:
		return
	_map_loading = true
	_persist_active_player_state()
	_gate_transition_in_progress = false
	_gate_overlap_active.clear()
	_gate_proximity_active.clear()
	_gate_room_slot_active.clear()
	_nexus_slot_active.clear()
	_gate_room_return_active = false
	_last_gate_index_in_range = -1
	_gate_room_slot_in_range = -1
	_gate_room_return_in_range = false
	_gate_use_was_pressed = Input.is_key_pressed(KEY_E)
	_gate_trigger_enable_time_msec = Time.get_ticks_msec() + 1500
	_gate_auto_retry_time_msec = _gate_trigger_enable_time_msec
	_gate_auto_cooldown_until_msec = _gate_trigger_enable_time_msec
	_close_menu()
	current_world_id = world_id
	current_map_id = map_id
	_transition_status_line = ""
	_map_loaded_at_msec = Time.get_ticks_msec()
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
	if WorldGraph.map_type_from_dict(map_record) == WorldGraph.MAP_CAVE:
		map_record = _ensure_maze_objective(map_record)
		maps[map_id] = map_record
		world["maps"] = maps
		last_discovery_text = _maze_objective_text(map_record)
		_push_status_banner(last_discovery_text, 4200)

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
	# Spread the heavy build across frames behind a loading overlay so gate travel
	# no longer freezes the main thread. The await lets the overlay paint first.
	_show_loading_overlay("Charting " + _map_type_label(map_type) + " …")
	await get_tree().process_frame
	_clear_generated_map()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedMap"
	add_child(generated_root)
	_apply_map_atmosphere()
	_apply_graphics_level()
	AudioManager.setup_music(self, generation_rng)
	_create_visible_sun()

	var gen := MapGenerator.new({
		"world_seed": world_seed,
		"graphics_level": graphics_level,
		"density_level": density_level,
		"map_type": map_type,
		"map_context": map_context,
	})
	gen.generate(generated_root)
	await get_tree().process_frame

	_spawn_player()
	# Freeze the player during the rest of the build so it can't drift through the
	# half-decorated, overlay-hidden world while scatter spreads over frames.
	if is_instance_valid(_player_ref):
		_player_ref.set_physics_process(false)
	await get_tree().process_frame

	if _is_current_map_gate_room():
		GateFactory.scatter_gate_room_gates(generated_root, 4)
		GateFactory.scatter_gate_room_return_portal(generated_root)
	elif _is_current_map_cave():
		GateFactory.scatter_cave_items(generated_root, world_seed)
		_spawn_wonders()
		await get_tree().process_frame
		_begin_generation_channel("gates")
		var target_seeds: Array[int] = []
		for gi in range(GATE_COUNT):
			target_seeds.append(_gate_target_seed(gi))
		GateFactory.create_gates(generated_root, world_seed, target_seeds, map_context)
		_gate_positions_to_wonders()
	elif _is_current_map_map_nexus():
		GateFactory.scatter_map_nexus_gates(generated_root, 4)
	else:
		if _is_current_map_arctic():
			AudioManager.setup_arctic_audio(generated_root)
		if _is_current_map_water():
			AudioManager.setup_water_audio(generated_root)
		if _is_current_map_moon():
			AudioManager.setup_moon_audio(generated_root)
			_scatter_moon_lichen()
			await get_tree().process_frame
			_scatter_moon_glass_craters()
			_scatter_moon_platforms()
			await get_tree().process_frame
		elif _is_current_map_arctic():
			_spawn_wonders()
			_scatter_landmarks()
			await get_tree().process_frame
			_scatter_arctic_trees()
			await get_tree().process_frame
			_scatter_rocks()
			_scatter_crystals()
			await get_tree().process_frame
			_scatter_ruins()
			_scatter_roads()
			_scatter_critter_herds()
			await get_tree().process_frame
		elif _is_current_map_water():
			_scatter_bird_flocks()
			_scatter_rocks()
			_scatter_crystals()
			await get_tree().process_frame
			_scatter_ruins()
			_scatter_underwater_plants()
			_scatter_fish_schools()
			await get_tree().process_frame
			_scatter_sunken_caches()
			_spawn_wonders()
			await get_tree().process_frame
		elif _is_current_map_floating_island():
			_spawn_wonders()
			_scatter_landmarks()
			await get_tree().process_frame
			_scatter_trees()
			await get_tree().process_frame
			_scatter_rocks()
			_scatter_crystals()
			await get_tree().process_frame
			_scatter_ruins()
			_scatter_bird_flocks()
			_scatter_critter_herds()
			await get_tree().process_frame
		elif _is_current_map_ruined_city():
			_scatter_city()
			await get_tree().process_frame
			_scatter_bird_flocks()
			await get_tree().process_frame
		else:
			_spawn_wonders()
			_scatter_landmarks()
			_scatter_bridges()
			await get_tree().process_frame
			_scatter_trees()
			await get_tree().process_frame
			_scatter_rocks()
			_scatter_crystals()
			await get_tree().process_frame
			_scatter_ruins()
			_scatter_roads()
			_scatter_flowers()
			_scatter_bird_flocks()
			_scatter_critter_herds()
			await get_tree().process_frame
		_begin_generation_channel("gates")
		var target_seeds: Array[int] = []
		for gi in range(GATE_COUNT):
			target_seeds.append(_gate_target_seed(gi))
		GateFactory.create_gates(generated_root, world_seed, target_seeds, map_context)
		_gate_positions_to_wonders()
		if _is_current_map_floating_island():
			_spawn_floating_local_gates()
		_ensure_player_not_on_gate_spawn()
	_post_load_map_sanity(map_type)
	_store_current_map_available_discoveries()
	await get_tree().process_frame

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

	if _is_current_map_moon():
		_show_field_tip("moon_lichen")
	elif not _is_current_map_gate_room() and not _is_current_map_map_nexus():
		_show_field_tip("welcome")

	_setup_weather()

	if is_instance_valid(_player_ref):
		_player_ref.set_physics_process(true)
	_map_loading = false
	_hide_loading_overlay()


func _clear_generated_map() -> void:
	if generated_root != null:
		generated_root.queue_free()
		generated_root = null
	_gate_overlap_active.clear()
	_gate_proximity_active.clear()
	_gate_room_slot_active.clear()
	_nexus_slot_active.clear()
	_gate_room_return_active = false
	_gate_room_slot_in_range = -1
	_gate_room_return_in_range = false
	_gate_transition_in_progress = false
	_floating_local_gate_positions.clear()
	_floating_recovery_gate_positions.clear()
	_floating_local_gate_last_trigger_msec = 0
	_clear_factory_caches()


func _clear_factory_caches() -> void:
	TreeFactory.clear_cache()
	RockFactory.clear_cache()
	CrystalFactory.clear_cache()
	FlowerFactory.clear_cache()
	UnderwaterPlantFactory.clear_cache()
	GateFactory.clear_cache()


func _post_load_map_sanity(map_type: String) -> void:
	if generated_root == null:
		_transition_status_line = "Sanity: generated root missing."
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		_transition_status_line = "Sanity: player missing after load."
		return
	if map_type != WorldGraph.MAP_GATE_ROOM and map_type != WorldGraph.MAP_NEXUS:
		var gates_root: Node = generated_root.get_node_or_null("Gates")
		if gates_root == null:
			_transition_status_line = "Sanity: gate root missing on map load."
			return
		var gate_nodes: Array = gates_root.get_children()
		if gate_nodes.size() < GATE_COUNT:
			_transition_status_line = "Sanity: expected " + str(GATE_COUNT) + " gates, found " + str(gate_nodes.size()) + "."
			return
	_transition_status_line = ""


func _ensure_player_not_on_gate_spawn() -> void:
	if generated_root == null:
		return
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var gate_root: Node = generated_root.get_node_or_null("Gates")
	if gate_root == null:
		return
	var nearest_gate: Node3D = null
	var nearest_dist: float = INF
	for child in gate_root.get_children():
		var gate_node: Node3D = child as Node3D
		if gate_node == null:
			continue
		var d: float = Vector2(
			gate_node.global_position.x - player.global_position.x,
			gate_node.global_position.z - player.global_position.z
		).length()
		if d < nearest_dist:
			nearest_dist = d
			nearest_gate = gate_node
	if nearest_gate == null:
		return
	var safe_radius: float = 3.2
	if nearest_dist >= safe_radius:
		return
	var away: Vector2 = Vector2(
		player.global_position.x - nearest_gate.global_position.x,
		player.global_position.z - nearest_gate.global_position.z
	)
	if away.length() < 0.001:
		away = Vector2.RIGHT
	away = away.normalized()
	var push: float = safe_radius - nearest_dist + 0.2
	player.global_position.x += away.x * push
	player.global_position.z += away.y * push


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
	elif _is_current_map_floating_island():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.58, 0.74, 0.96)
		world_environment.ambient_light_color = Color(0.66, 0.78, 0.92)
		world_environment.ambient_light_energy = 0.62
		world_environment.fog_density = 0.0007
		world_environment.fog_light_color = Color(0.72, 0.82, 0.95)
		if sun_light != null:
			sun_light.light_color = Color(1.0, 0.97, 0.92)
			sun_light.light_energy = 1.7
			sun_light.rotation_degrees = Vector3(-46.0, -24.0, 0.0)
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
	TreeFactory.scatter_trees(generated_root, world_seed, density_level, graphics_level, map_context, 1.0, _wonder_exclusions())


func _scatter_arctic_trees() -> void:
	_begin_generation_channel("trees")
	TreeFactory.scatter_trees(generated_root, world_seed, density_level, graphics_level, map_context, 0.12, _wonder_exclusions())


# World-space centers of already-spawned wonders, so trees can be kept clear of them.
# (Requires _spawn_wonders to run before tree scatter — see _load_map ordering.)
func _wonder_exclusions() -> Array:
	var out: Array = []
	for w in _wonder_positions:
		out.append(Vector3(float(w.get("x", 0.0)), 0.0, float(w.get("z", 0.0))))
	# Gates are built after the scatter, so predict their (deterministic) positions
	# to keep trees clear of them too.
	if map_context != null and not _is_current_map_gate_room() and not _is_current_map_map_nexus():
		for gate_pos in GateFactory.predict_gate_positions(map_context):
			out.append(Vector3(gate_pos.x, 0.0, gate_pos.z))
	# Landmarks and bridges are scattered before trees, so their recorded centers keep trees clear.
	for lp in _landmark_positions:
		out.append(Vector3(lp.x, 0.0, lp.z))
	for bp in _bridge_positions:
		out.append(Vector3(bp.x, 0.0, bp.z))
	return out


func _scatter_rocks() -> void:
	_begin_generation_channel("rocks")
	RockFactory.scatter_rocks(generated_root, world_seed, density_level, map_context)


func _scatter_crystals() -> void:
	_begin_generation_channel("crystals")
	CrystalFactory.scatter_crystals(generated_root, world_seed, density_level, map_context)


func _scatter_ruins() -> void:
	_begin_generation_channel("ruins")
	RuinFactory.scatter_ruins(generated_root, world_seed, density_level, map_context)


func _scatter_landmarks() -> void:
	_begin_generation_channel("landmarks")
	_landmark_positions = LandmarkFactory.scatter_landmarks(generated_root, world_seed, density_level, map_context)


func _scatter_roads() -> void:
	_begin_generation_channel("roads")
	RoadFactory.scatter_roads(generated_root, world_seed, density_level, map_context)


func _scatter_bridges() -> void:
	_begin_generation_channel("bridges")
	_bridge_positions = BridgeFactory.scatter_bridges(generated_root, world_seed, density_level, map_context)


func _scatter_flowers() -> void:
	_begin_generation_channel("flowers")
	FlowerFactory.scatter_flowers(generated_root, world_seed, density_level, map_context)


func _scatter_bird_flocks() -> void:
	_begin_generation_channel("birds")
	CreatureFactory.scatter_birds(generated_root, world_seed, map_context)


func _scatter_fish_schools() -> void:
	_begin_generation_channel("fish")
	CreatureFactory.scatter_fish(generated_root, world_seed, map_context)


func _scatter_critter_herds() -> void:
	_begin_generation_channel("critters")
	CreatureFactory.scatter_critters(generated_root, world_seed, map_context)


func _scatter_city() -> void:
	_begin_generation_channel("city")
	_city_core_positions = CityFactory.scatter_city(generated_root, world_seed, density_level, map_context)
	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	map_record["city_cores_total"] = _city_core_positions.size()
	_update_world_map_record(current_world_id, current_map_id, map_record, false)
	_spawn_city_cores(map_record)


# Glowing collectible "data cores" hidden inside buildings — the city objective.
func _spawn_city_cores(map_record: Dictionary) -> void:
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var root := Node3D.new()
	root.name = "CityCores"
	generated_root.add_child(root)
	for i in range(_city_core_positions.size()):
		if discoveries.has("city_core_" + str(i)):
			continue
		var core := Node3D.new()
		core.name = "CityCore_" + str(i)
		core.position = _city_core_positions[i]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.55, 0.55, 0.55)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.9, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.8, 1.0)
		mat.emission_energy_multiplier = 3.5
		mi.material_override = mat
		core.add_child(mi)
		var light := OmniLight3D.new()
		light.light_color = Color(0.45, 0.85, 1.0)
		light.light_energy = 2.0
		light.omni_range = 7.0
		light.shadow_enabled = false
		core.add_child(light)
		root.add_child(core)


func _poll_city_cores() -> void:
	if not _is_current_map_ruined_city() or generated_root == null or discovery_tracker == null:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var cores_root: Node = generated_root.get_node_or_null("CityCores")
	if cores_root == null:
		return
	var collected_any: bool = false
	for child in cores_root.get_children():
		if not (child is Node3D):
			continue
		var core := child as Node3D
		if core.global_position.distance_to(player.global_position) <= 2.4:
			discovery_tracker.record_discovery("city_core_" + str(core.name).trim_prefix("CityCore_"), "Data Core", "core", core.global_position)
			core.queue_free()
			collected_any = true
	if not collected_any:
		return
	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	if int(map_record.get("city_cores_total", 0)) > 0 and _city_cores_found(map_record) >= int(map_record.get("city_cores_total", 0)) and not bool(map_record.get("city_cleared", false)):
		map_record["city_cleared"] = true
		_update_world_map_record(current_world_id, current_map_id, map_record, true)
		lichen_count += 4
		if player.has_method(&"set"):
			player.set("lichen_count", lichen_count)
		last_discovery_text = "City secured — every data core recovered. +4 lichen."
		_push_status_banner(last_discovery_text, 5200)


func _city_cores_found(map_record: Dictionary) -> int:
	var found: int = 0
	for k in map_record.get("discoveries", {}).keys():
		if str(k).begins_with("city_core_"):
			found += 1
	return found


func _scatter_underwater_plants() -> void:
	_begin_generation_channel("underwater_plants")
	UnderwaterPlantFactory.scatter_plants(generated_root, world_seed, density_level, map_context)


# Sunken caches give water maps a reason to dive: glowing relics on the deep
# seabed that register as atlas discoveries. Depth is the gate — reaching the
# deepest ones (and surfacing) takes the breath that the Lungs kit track buys.
func _scatter_sunken_caches() -> void:
	if not _is_current_map_water() or generated_root == null:
		return
	_begin_generation_channel("sunken_caches")
	var rng := StableRng.new(StableRng.mix_string(world_seed, "sunken_caches"))
	var half: float = _world_half_size() * 0.86
	var water_level: float = _water_level()
	var container := Node3D.new()
	container.name = "SunkenCaches"
	generated_root.add_child(container)
	var placed: int = 0
	var attempts: int = 0
	while placed < 8 and attempts < 240:
		attempts += 1
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var seabed: float = _height_at_world(x, z)
		if water_level - seabed < 4.0:
			continue
		var cache := Node3D.new()
		cache.name = "SunkenCache_" + str(placed)
		cache.position = Vector3(x, seabed + 1.2, z)
		container.add_child(cache)
		_build_sunken_cache_visual(cache, rng)
		var cache_id: String = "sunken_cache_" + str(int(round(x))) + "_" + str(int(round(z)))
		_add_discovery_area(cache, Vector3.ZERO, 3.2, cache_id, "Sunken Cache", "relic")
		_wonder_positions.append({"x": x, "z": z, "kind": "relic", "id": cache_id, "title": "Sunken Cache"})
		placed += 1


func _build_sunken_cache_visual(parent: Node3D, rng: StableRng) -> void:
	var color: Color = Color.from_hsv(rng.randf_range(0.09, 0.14), 0.6, 1.0)
	var mesh := MeshInstance3D.new()
	mesh.name = "CacheGlow"
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	mesh.mesh = sphere
	mesh.position = Vector3(0.0, 0.55, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.2
	mesh.material_override = mat
	parent.add_child(mesh)
	var glow := OmniLight3D.new()
	glow.name = "CacheLight"
	glow.light_color = color
	glow.light_energy = 2.4
	glow.omni_range = 9.0
	glow.position = Vector3(0.0, 0.8, 0.0)
	parent.add_child(glow)


func _scatter_moon_lichen() -> void:
	_begin_generation_channel("moon_lichen")
	MoonFeatureFactory.scatter_lichen(generated_root, world_seed, map_context)


func _scatter_moon_glass_craters() -> void:
	_begin_generation_channel("moon_craters")
	MoonFeatureFactory.scatter_glass_craters(generated_root, world_seed, map_context)


var _wonder_positions: Array = []
var _landmark_positions: Array = []
var _bridge_positions: Array = []
var _city_core_positions: Array = []


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
	var spawned_count: int = 0

	for cell_z in range(min_cell, max_cell + 1):
		for cell_x in range(min_cell, max_cell + 1):
			if not WonderGenerator.cell_has_wonder(world_seed, cell_x, cell_z, WONDER_CHANCE):
				continue
			var wonder_pos: Vector3 = WonderGenerator.get_cell_wonder_position(world_seed, cell_x, cell_z, Callable(map_context, "height_at_world"), WONDER_CELL_SIZE)
			if not _can_place_wonder_at(wonder_pos, half):
				continue
			if _spawn_wonder_instance(wonder_pos, cell_x, cell_z):
				spawned_count += 1

	var min_wonders: int = 3
	if _is_current_map_cave() or _is_current_map_water():
		min_wonders = 2
	elif _is_current_map_arctic():
		min_wonders = 1
	if spawned_count >= min_wonders:
		return

	var rng := StableRng.new(StableRng.mix_string(world_seed, "wonder_fallback"))
	var attempts: int = 0
	while spawned_count < min_wonders and attempts < 220:
		attempts += 1
		var x: float = rng.randf_range(-(half - 30.0), half - 30.0)
		var z: float = rng.randf_range(-(half - 30.0), half - 30.0)
		var y: float = _height_at_world(x, z)
		var pos := Vector3(x, y, z)
		if not _can_place_wonder_at(pos, half):
			continue
		var cx: int = int(round(x / WONDER_CELL_SIZE))
		var cz: int = int(round(z / WONDER_CELL_SIZE))
		if _spawn_wonder_instance(pos, cx, cz):
			spawned_count += 1


func _can_place_wonder_at(wonder_pos: Vector3, half: float) -> bool:
	if abs(wonder_pos.x) > half - 28.0 or abs(wonder_pos.z) > half - 28.0:
		return false
	if wonder_pos.distance_to(Vector3.ZERO) < 25.0:
		return false
	var river_min: float = 9.0
	var water_clearance_min: float = 0.4
	if _is_current_map_arctic():
		river_min = 7.0
		water_clearance_min = 0.2
	elif _is_current_map_water():
		river_min = 6.0
		water_clearance_min = 0.15
	if wonder_pos.y < _water_level() + water_clearance_min:
		return false
	if _river_distance(wonder_pos.x, wonder_pos.z) < river_min:
		return false
	# Slope is fine: the base is grounded to its lowest footprint point at spawn
	# (_wonder_grounded_y), so it sits planted instead of hovering.
	return true


# Lowest terrain under a wonder's ~7m base footprint, minus a small embed, so the
# wide flat base sits planted into the ground instead of hovering over the downhill
# side of a slope.
func _wonder_grounded_y(pos: Vector3) -> float:
	var lo: float = pos.y
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		lo = minf(lo, _height_at_world(pos.x + cos(a) * 7.0, pos.z + sin(a) * 7.0))
	return lo - 0.4


func _spawn_wonder_instance(wonder_pos: Vector3, cell_x: int, cell_z: int) -> bool:
	var discovery_id: String = "wonder_" + str(cell_x) + "_" + str(cell_z)
	for existing in _wonder_positions:
		if str(existing.get("id", "")) == discovery_id:
			return false
	var wonder_info: Dictionary = WonderGenerator.describe_wonder(world_seed, cell_x, cell_z, 0)
	var wonder_seed: int = int(wonder_info.get("seed", 0))
	var archetype: String = str(wonder_info.get("archetype", "wonder"))
	var variant: int = int(wonder_info.get("variant", 0))
	var grounded_pos: Vector3 = Vector3(wonder_pos.x, _wonder_grounded_y(wonder_pos), wonder_pos.z)
	var wonder: Node3D = WonderGenerator.create_wonder_from_seed(grounded_pos, wonder_seed, true)
	var title: String = str(wonder.get_meta("wonder_title", WonderGenerator.title_for_archetype(archetype, variant)))
	var wonder_kind: String = "wonder"
	_wonder_positions.append({
		"x": wonder_pos.x,
		"z": wonder_pos.z,
		"kind": wonder_kind,
		"id": discovery_id,
		"title": title,
		"seed": wonder_seed,
		"archetype": archetype,
		"variant": variant,
	})
	wonder.set_meta("discovery_id", discovery_id)
	wonder.set_meta("discovery_title", title)
	wonder.set_meta("discovery_kind", wonder_kind)
	wonder.set_meta("wonder_seed", wonder_seed)
	wonder.set_meta("wonder_archetype", archetype)
	wonder.set_meta("wonder_variant", variant)
	_add_discovery_area(wonder, Vector3(0.0, 2.0, 0.0), 12.0, discovery_id, title, wonder_kind)
	if archetype == "moon_gate":
		MoonGateFactory.add_moon_gate_trigger(wonder)
	_add_generated_child(wonder)
	return true


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
	_moon_gate_last_trigger_msec = Time.get_ticks_msec()

	moon_map_return_map_id = current_map_id
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	if not maps.has("moon") or typeof(maps.get("moon", null)) != TYPE_DICTIONARY:
		_update_world_map_record(current_world_id, "moon", _create_moon_map_record(_moon_seed(world)).to_dict(), true)

	_load_map(current_world_id, "moon")


func _poll_moon_gate_proximity_fallback() -> void:
	if current_world_id == "" or current_map_id == "" or generated_root == null or _is_current_map_moon():
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _moon_gate_last_trigger_msec < 1200:
		return
	var trigger_nodes: Array = generated_root.find_children("MoonGateTrigger", "Area3D", true, false)
	for raw_trigger in trigger_nodes:
		var trigger: Area3D = raw_trigger as Area3D
		if trigger == null:
			continue
		if trigger.global_position.distance_to(player.global_position) <= 6.5:
			_moon_gate_last_trigger_msec = now_msec
			last_discovery_text = "Moon Gate activated."
			_on_moon_gate_body_entered(player)
			return
	var wonders: Array = generated_root.find_children("Wonder_*", "Node3D", true, false)
	for raw in wonders:
		var wonder: Node3D = raw as Node3D
		if wonder == null:
			continue
		var archetype: String = str(wonder.get_meta("wonder_archetype", ""))
		var title: String = str(wonder.get_meta("discovery_title", _wonder_title(wonder.name)))
		if archetype != "moon_gate" and not wonder.name.contains("moon_gate") and not title.begins_with("Moon Gate"):
			continue
		var dist: float = wonder.global_position.distance_to(player.global_position)
		if dist <= 8.5:
			_moon_gate_last_trigger_msec = now_msec
			last_discovery_text = "Moon Gate activated."
			_on_moon_gate_body_entered(player)
			return


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
		orb_body.collision_mask = 1 | 2
		var orb_shape := CollisionShape3D.new()
		var orb_sphere := SphereShape3D.new()
		orb_sphere.radius = 1.2
		orb_shape.shape = orb_sphere
		orb_body.add_child(orb_shape)
		orb_body.position = platform.position + Vector3(0.0, 1.5, 0.0)
		orb_body.body_entered.connect(_on_orb_collected.bind(i, orb_body))
		platform_root.add_child(orb_body)

		var orb_visual := MeshInstance3D.new()
		orb_visual.name = "ShrineOrbVisual"
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
		orb_body.set_meta("platform_index", i)
	_refresh_moon_shrine_visuals()


func _random_position(rng: StableRng, half: float) -> Vector3:
	for attempt in range(18):
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = _height_at_world(x, z)
		if y >= -10.0:
			return Vector3(x, y, z)
	return Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))


func _on_orb_collected(body: Node3D, platform_index: int, orb_body: Area3D) -> void:
	if body == null:
		return
	if not _is_current_map_moon():
		return
	var is_player: bool = body.name == "Player"
	var is_thrown_lichen: bool = _is_thrown_lichen_node(body)
	if not is_player and not is_thrown_lichen:
		return
	if discovery_tracker == null:
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
	var shrine_charge: Dictionary = map_record.get("moon_shrine_charge", {})
	var charge_key: String = str(platform_index)
	if is_thrown_lichen:
		if shrine_charge.has(charge_key):
			if is_instance_valid(body):
				body.queue_free()
			last_discovery_text = "Shrine already attuned."
			return
		if is_instance_valid(body):
			body.queue_free()
		shrine_charge[charge_key] = true
		map_record["moon_shrine_charge"] = shrine_charge
		_update_world_map_record(current_world_id, current_map_id, map_record, true)
		last_discovery_text = "Shrine attuned by lichen. Touch orb to claim."
		_refresh_moon_shrine_visuals(map_record)
		return
	if not shrine_charge.has(charge_key):
		var lichen_node: Node3D = _find_nearby_thrown_lichen(orb_body.global_position if orb_body != null else body.global_position, 3.2)
		if lichen_node == null:
			last_discovery_text = "Shrine inert. Throw lichen at it first."
			return
		lichen_node.queue_free()
		shrine_charge[charge_key] = true
		map_record["moon_shrine_charge"] = shrine_charge
		_update_world_map_record(current_world_id, current_map_id, map_record, true)
		last_discovery_text = "Shrine attuned by lichen. Touch orb again to claim."
		_refresh_moon_shrine_visuals(map_record)
		return
	_claim_moon_orb(platform_index, orb_body, body.global_position, map_record)


func _poll_moon_shrine_fallback() -> void:
	if not _is_current_map_moon() or generated_root == null or discovery_tracker == null:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var shrine_charge: Dictionary = map_record.get("moon_shrine_charge", {})
	var changed: bool = false
	var orbs: Array = generated_root.find_children("ShrineOrb_*", "Area3D", true, false)
	for raw in orbs:
		var orb_area: Area3D = raw as Area3D
		if orb_area == null:
			continue
		var idx_text: String = str(orb_area.name).trim_prefix("ShrineOrb_")
		var idx: int = int(idx_text)
		var key: String = "moon_orb_" + str(idx)
		var charge_key: String = str(idx)
		if discoveries.has(key):
			if is_instance_valid(orb_area):
				orb_area.queue_free()
			continue
		if not shrine_charge.has(charge_key):
			var nearby_lichen: Node3D = _find_nearby_thrown_lichen(orb_area.global_position, 3.0)
			if nearby_lichen != null:
				nearby_lichen.queue_free()
				shrine_charge[charge_key] = true
				changed = true
				last_discovery_text = "Shrine attuned by lichen. Touch orb to claim."
		if shrine_charge.has(charge_key) and is_instance_valid(orb_area):
			var claim_dist: float = orb_area.global_position.distance_to(player.global_position)
			if claim_dist <= 1.8:
				_claim_moon_orb(idx, orb_area, player.global_position, map_record)
				discoveries = map_record.get("discoveries", {})
				shrine_charge = map_record.get("moon_shrine_charge", {})
				changed = false
	if changed:
		map_record["moon_shrine_charge"] = shrine_charge
		_update_world_map_record(current_world_id, current_map_id, map_record, true)
	_refresh_moon_shrine_visuals(map_record)


func _find_nearby_thrown_lichen(from: Vector3, max_dist: float) -> Node3D:
	if generated_root == null:
		return null
	var best: Node3D = null
	var best_dist: float = max_dist
	var stack: Array[Node] = [generated_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D:
			var n3d: Node3D = node as Node3D
			if n3d != null and n3d.is_in_group("floating_lichen") and n3d.name == "ThrownLichen" and is_instance_valid(n3d):
				var dist: float = n3d.global_position.distance_to(from)
				if dist <= best_dist:
					best_dist = dist
					best = n3d
		for child in node.get_children():
			stack.append(child)
	return best


func _is_thrown_lichen_node(node: Node) -> bool:
	if node == null:
		return false
	if not (node is Node3D):
		return false
	var n3d: Node3D = node as Node3D
	if n3d == null:
		return false
	return n3d.name == "ThrownLichen" or n3d.is_in_group("floating_lichen")


func _claim_moon_orb(platform_index: int, orb_body: Area3D, discovery_position: Vector3, map_record: Dictionary) -> void:
	if discovery_tracker == null:
		return
	var key: String = "moon_orb_" + str(platform_index)
	var discoveries: Dictionary = map_record.get("discoveries", {})
	if discoveries.has(key):
		if orb_body != null:
			orb_body.queue_free()
		return
	discovery_tracker.record_discovery(key, "Shrine " + str(platform_index + 1) + " Orb", "orb", discovery_position)
	var shrine_charge: Dictionary = map_record.get("moon_shrine_charge", {})
	shrine_charge.erase(str(platform_index))
	map_record["moon_shrine_charge"] = shrine_charge
	_update_world_map_record(current_world_id, current_map_id, map_record, true)
	if orb_body != null:
		orb_body.queue_free()
	_refresh_moon_shrine_visuals(map_record)
	print("Moon orb ", platform_index, " collected")


func _refresh_moon_shrine_visuals(map_record_override: Dictionary = {}) -> void:
	if not _is_current_map_moon() or generated_root == null:
		return
	var map_record: Dictionary = map_record_override
	if map_record.is_empty():
		map_record = _get_map_record(current_world_id, current_map_id)
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var shrine_charge: Dictionary = map_record.get("moon_shrine_charge", {})
	var orbs: Array = generated_root.find_children("ShrineOrb_*", "Area3D", true, false)
	for raw in orbs:
		var orb_area: Area3D = raw as Area3D
		if orb_area == null:
			continue
		var idx: int = int(str(orb_area.name).trim_prefix("ShrineOrb_"))
		var key: String = "moon_orb_" + str(idx)
		var charge_key: String = str(idx)
		var visual: MeshInstance3D = orb_area.get_node_or_null("ShrineOrbVisual") as MeshInstance3D
		if visual == null:
			continue
		var mat: StandardMaterial3D = visual.material_override as StandardMaterial3D
		if mat == null:
			continue
		if discoveries.has(key):
			orb_area.visible = false
			orb_area.monitoring = false
			continue
		orb_area.visible = true
		orb_area.monitoring = true
		var charged: bool = shrine_charge.has(charge_key)
		if charged:
			mat.albedo_color = Color(0.35, 1.0, 0.88)
			mat.emission = Color(0.28, 1.0, 0.85)
			mat.emission_energy_multiplier = 3.2
			visual.scale = Vector3.ONE * 1.45
		else:
			mat.albedo_color = Color(1.0, 0.88, 0.28)
			mat.emission = Color(0.70, 0.45, 0.08)
			mat.emission_energy_multiplier = 1.5
			visual.scale = Vector3.ONE


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
	slot_index = clamp(slot_index, 0, 3)
	last_discovery_text = "Nexus gate " + str(slot_index + 1) + " engaged."

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
	if not bool(nexus_result.get("ok", false)):
		last_discovery_text = "Nexus routing failed."
		return
	if bool(nexus_result.get("skip", false)):
		var created: Dictionary = _create_world_in_current_universe("Nexus World " + str(slot_index + 1), "nexus_slot_" + str(slot_index))
		var new_world_id: String = str(created.get("world_id", ""))
		var new_map_id: String = str(created.get("root_map_id", ""))
		if new_world_id == "" or new_map_id == "":
			last_discovery_text = "Nexus gate unresolved."
			return
		var slots: Dictionary = map_record.get("nexus_slots", {})
		slots[str(slot_index)] = new_world_id
		map_record["nexus_slots"] = slots
		_update_world_map_record(current_world_id, current_map_id, map_record, true)
		last_discovery_text = "Nexus unfolded " + _display_name_for_map(new_world_id, new_map_id) + "."
		call_deferred("_load_map", new_world_id, new_map_id)
		return
	var updated_map_record: Dictionary = nexus_result.get("current_map_record", map_record)
	_update_world_map_record(current_world_id, current_map_id, updated_map_record, bool(nexus_result.get("changed", false)))
	if bool(nexus_result.get("changed", false)):
		pass
	var target_world_id: String = str(nexus_result.get("target_world_id", ""))
	var target_map_id: String = str(nexus_result.get("target_map_id", ""))
	if target_world_id == "" or target_map_id == "":
		var created_fallback: Dictionary = _create_world_in_current_universe("Nexus World " + str(slot_index + 1), "nexus_fallback_" + str(slot_index))
		target_world_id = str(created_fallback.get("world_id", ""))
		target_map_id = str(created_fallback.get("root_map_id", ""))
		if target_world_id == "" or target_map_id == "":
			last_discovery_text = "Nexus target unresolved."
			return
		var slots_fallback: Dictionary = updated_map_record.get("nexus_slots", {})
		slots_fallback[str(slot_index)] = target_world_id
		updated_map_record["nexus_slots"] = slots_fallback
		_update_world_map_record(current_world_id, current_map_id, updated_map_record, true)
		last_discovery_text = "Nexus forged fallback route."
		call_deferred("_load_map", target_world_id, target_map_id)
		return
	last_discovery_text = str(nexus_result.get("message", ""))
	call_deferred("_load_map", target_world_id, target_map_id)


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
	# Free the previous player via the authoritative _player_ref. (Using only the
	# "Player" node path leaked nodes: a prior respawn's queue_free + same-frame
	# add_child name-collides and renames the live player, so the path lookup misses
	# it on the next respawn.) Rename the retiring node so the new one cleanly takes
	# "Player" instead of getting an auto-suffixed name.
	var existing_player: CharacterBody3D = _player_ref if is_instance_valid(_player_ref) else get_node_or_null("Player")
	if existing_player != null:
		existing_player.name = "PlayerRetiring"
		existing_player.queue_free()
	_player_ref = null

	var player_scene: PackedScene = preload("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.name = "Player"
	player.position = _sanitize_player_position(_find_spawn_position())
	if _is_current_map_moon():
		player.set("gravity_multiplier", 0.25)
		player.set("jump_multiplier", 4.0)
		player.set("water_level", -100000.0)
	elif _is_current_map_arctic():
		player.set("gravity_multiplier", 1.0)
		player.set("jump_multiplier", 1.0)
		player.set("water_level", -100000.0)
		player.set("warmth_enabled", true)
	else:
		player.set("gravity_multiplier", 1.0)
		player.set("jump_multiplier", 1.0)
		player.set("water_level", WATER_LEVEL)
	add_child(player)
	_player_ref = player
	if _is_current_map_cave():
		AudioManager.setup_cave_player_audio(player)
	player.lichen_count = lichen_count
	_apply_progression_to_player(player)
	_restore_player_save_state(player)
	_ensure_player_above_surface(player)


func _sanitize_player_position(position: Vector3) -> Vector3:
	var pos: Vector3 = position
	if _is_current_map_gate_room():
		var radial: Vector2 = Vector2(pos.x, pos.z)
		if radial.length() > 27.0:
			radial = radial.normalized() * 27.0
		return Vector3(radial.x, max(pos.y, 1.2), radial.y)
	if _is_current_map_map_nexus():
		var radial_n: Vector2 = Vector2(pos.x, pos.z)
		if radial_n.length() > 39.0:
			radial_n = radial_n.normalized() * 39.0
		return Vector3(radial_n.x, max(pos.y, 1.2), radial_n.y)
	if _is_current_map_cave():
		var cave_half: float = _world_half_size() * 0.90
		pos.x = clamp(pos.x, -cave_half, cave_half)
		pos.z = clamp(pos.z, -cave_half, cave_half)
		pos.y = clamp(pos.y, 1.2, 4.2)
		return pos
	var half: float = _world_half_size() * 0.90
	pos.x = clamp(pos.x, -half, half)
	pos.z = clamp(pos.z, -half, half)
	var terrain_y: float = _height_at_world(pos.x, pos.z)
	var min_y: float = terrain_y + 1.2
	if not _is_current_map_moon() and not _is_current_map_arctic():
		min_y = max(min_y, _water_level() + 1.2)
	pos.y = max(pos.y, min_y)
	return pos


func _find_spawn_position() -> Vector3:
	if _is_current_map_gate_room():
		return Vector3(0.0, _height_at_world(0.0, 0.0) + 1.2, 28.0)

	if _is_current_map_map_nexus():
		return Vector3(0.0, _height_at_world(0.0, 0.0) + 1.2, 40.0)

	if _is_current_map_cave():
		return Vector3(5.0, 2.5, 5.0)

	if _is_current_map_arctic():
		return Vector3(0.0, 2.5, 0.0)

	if _is_current_map_ruined_city():
		return Vector3(0.0, _height_at_world(0.0, 0.0) + 1.2, 0.0)

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
	# Inside a ruined-city basement the ground is holed and being below grade is
	# legitimate — rescuing here would pogo-stick the player back to the surface.
	if _is_current_map_ruined_city() and _active_map_context().city_point_in_basement(player.global_position.x, player.global_position.z):
		return false
	var terrain_y: float = _height_at_world(player.global_position.x, player.global_position.z)
	# Only rescue when clearly below terrain to avoid canceling legitimate jumps,
	# especially on moon maps with low gravity.
	var rescue_y: float = terrain_y - 2.0
	if player.global_position.y < rescue_y:
		player.global_position = Vector3(player.global_position.x, terrain_y + 1.2, player.global_position.z)
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
	var orb_count: int = _moon_orb_discovery_count(discoveries)
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
		_play_moon_pilgrim_cutscene()
		_try_award_map_survey_completion(current_world_id, current_map_id)


func _play_moon_pilgrim_cutscene() -> void:
	if _cutscene_active or _moon_cutscene_active or generated_root == null:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var player_camera: Camera3D = player.get_node_or_null("PlayerCamera") as Camera3D
	if player_camera == null:
		return
	var map_record: Dictionary = _get_map_record(current_world_id, current_map_id)
	if bool(map_record.get("moon_pilgrim_cutscene_seen", false)):
		return
	map_record["moon_pilgrim_cutscene_seen"] = true
	_update_world_map_record(current_world_id, current_map_id, map_record, true)
	_cutscene_active = true
	_moon_cutscene_active = true
	AudioManager.play_moon_pilgrim_fanfare(generated_root)
	last_discovery_text = "Moon Pilgrim complete. The Atlas resonates."
	_push_status_banner(last_discovery_text, 5200)

	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Gather the nine shrine platforms; the finale fires a beam of light from each.
	var shrine_points: Array[Vector3] = []
	var platforms_node: Node = generated_root.get_node_or_null("MoonPlatforms")
	if platforms_node != null:
		for c in platforms_node.get_children():
			if c is Node3D and str(c.name).begins_with("MoonPlatform_"):
				shrine_points.append((c as Node3D).global_position)
	if shrine_points.is_empty():
		shrine_points.append(player.global_position)

	var centroid := Vector3.ZERO
	for sp in shrine_points:
		centroid += sp
	centroid /= float(shrine_points.size())
	var spread := 18.0
	for sp in shrine_points:
		spread = maxf(spread, Vector2(sp.x - centroid.x, sp.z - centroid.z).length())
	spread = clampf(spread + 8.0, 20.0, 60.0)
	var focus := centroid + Vector3(0.0, 10.0, 0.0)
	var conv_center := centroid + Vector3(0.0, 15.0, 0.0)

	var base_ambient: float = world_environment.ambient_light_energy if world_environment != null else 0.65
	if world_environment != null:
		world_environment.fog_light_color = Color(0.6, 0.82, 1.0)

	# World-space FX container (kept separate from the moving camera rig).
	var fx := Node3D.new()
	fx.name = "MoonFinaleFX"
	generated_root.add_child(fx)
	var beams: Array[Node3D] = []
	for sp in shrine_points:
		beams.append(_moon_fx_beam(fx, sp))

	var cutscene_rig := Node3D.new()
	cutscene_rig.name = "MoonPilgrimCutsceneRig"
	generated_root.add_child(cutscene_rig)
	var cut_cam := Camera3D.new()
	cut_cam.current = true
	cutscene_rig.add_child(cut_cam)
	cutscene_rig.global_position = centroid + Vector3(-spread * 0.8, 4.0, -spread * 0.8)
	cut_cam.look_at(focus, Vector3.UP)
	_moon_cut_cam = cut_cam
	_moon_cut_focus = focus

	var pos_b := centroid + Vector3(spread * 0.9, 6.5, spread * 0.5)
	var pos_c := centroid + Vector3(0.0, spread * 0.9 + 14.0, spread * 1.45)

	# Keep the shrine field framed for the entire sweep (per-frame, via _moon_cut_look).
	var look := create_tween()
	look.tween_method(_moon_cut_look, 0.0, 1.0, 10.7)

	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Beams ignite in a rolling cascade as the camera sweeps low across the field.
	t.tween_callback(func() -> void:
		for i in range(beams.size()):
			_moon_fx_ignite(beams[i], float(i) * 0.16)
		_push_status_banner("The nine shrines answer...", 2400)
	)
	t.tween_property(cutscene_rig, "global_position", pos_b, 2.6)
	# Energy lifts from every shrine and converges; the camera rises to a hero shot.
	t.tween_callback(func() -> void:
		_moon_fx_converge(fx, shrine_points, conv_center, 1.7)
		_push_status_banner("Atlas signal converging.", 2200)
	)
	t.tween_property(cutscene_rig, "global_position", pos_c, 2.0)
	# The burst.
	t.tween_callback(func() -> void:
		_moon_fx_burst(fx, conv_center, base_ambient)
	)
	# Let the burst bloom and the moment breathe before handing control back.
	t.tween_property(cutscene_rig, "global_position", pos_c + Vector3(0.0, 3.5, -spread * 0.28), 2.6)
	t.tween_callback(func() -> void:
		_push_status_banner("Moon Pilgrim — the Atlas resonates.", 4800)
	)
	t.tween_property(cutscene_rig, "global_position", pos_c + Vector3(spread * 0.10, 5.0, -spread * 0.30), 1.8)
	# Beams power down gently so the return isn't a hard snap.
	t.tween_callback(func() -> void:
		_moon_fx_fade(fx, 1.7)
	)
	t.tween_interval(1.7)
	t.finished.connect(func() -> void:
		_moon_cut_cam = null
		if is_instance_valid(player_camera):
			player_camera.current = true
		if is_instance_valid(cutscene_rig):
			cutscene_rig.queue_free()
		if is_instance_valid(fx):
			fx.queue_free()
		if is_instance_valid(player):
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)
		if world_environment != null:
			world_environment.ambient_light_energy = base_ambient
			world_environment.fog_light_color = Color(0.65, 0.75, 0.85)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_moon_cutscene_active = false
		_cutscene_active = false
		lichen_count += 3
		if player != null and player.has_method(&"set"):
			player.set("lichen_count", lichen_count)
		last_discovery_text = "Moon Pilgrim route unlocked. +3 lichen. Return through a gate when ready."
		_push_status_banner(last_discovery_text, 5200)
	)


func _moon_cut_look(_p: float) -> void:
	if is_instance_valid(_moon_cut_cam):
		_moon_cut_cam.look_at(_moon_cut_focus, Vector3.UP)


func _moon_glow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.9, 0.55, 0.9)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.82, 0.4)
	m.emission_energy_multiplier = 2.0
	return m


# A pillar of light rising from a shrine; grows from its base when ignited.
func _moon_fx_beam(parent: Node3D, base_pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = base_pos
	root.scale = Vector3(1.0, 0.001, 1.0)
	parent.add_child(root)
	var h := 34.0
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.55
	cyl.height = h
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.92, 0.55, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	mesh.position.y = h * 0.5
	root.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.45)
	light.light_energy = 0.0
	light.omni_range = 16.0
	light.position.y = 2.5
	light.shadow_enabled = false
	root.add_child(light)
	root.set_meta("beam_light", light)
	return root


func _moon_fx_ignite(beam: Node3D, delay: float) -> void:
	if not is_instance_valid(beam):
		return
	var bt := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_interval(delay)
	bt.tween_property(beam, "scale:y", 1.0, 0.55)
	var light: Variant = beam.get_meta("beam_light", null)
	if light is OmniLight3D:
		var lt := create_tween()
		lt.tween_interval(delay)
		lt.tween_property(light, "light_energy", 2.6, 0.25)
		lt.tween_property(light, "light_energy", 1.3, 0.5)


# Glowing motes lift from each shrine top and stream into the convergence point.
func _moon_fx_converge(parent: Node3D, shrines: Array, center: Vector3, arrive: float) -> void:
	if not is_instance_valid(parent):
		return
	for s in shrines:
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		orb.mesh = sm
		orb.material_override = _moon_glow_material()
		orb.position = (s as Vector3) + Vector3(0.0, 30.0, 0.0)
		parent.add_child(orb)
		var ot := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		ot.tween_property(orb, "position", center, arrive)
		ot.parallel().tween_property(orb, "scale", Vector3(0.35, 0.35, 0.35), arrive)


# The climax: a particle burst, an expanding shockwave ring, a light flash, a swell.
func _moon_fx_burst(parent: Node3D, center: Vector3, base_ambient: float) -> void:
	if not is_instance_valid(parent):
		return
	var p := GPUParticles3D.new()
	p.position = center
	p.amount = 240
	p.lifetime = 1.7
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.2
	pm.spread = 180.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0.0, -3.0, 0.0)
	pm.scale_min = 0.3
	pm.scale_max = 0.9
	pm.color = Color(1.0, 0.9, 0.55)
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.35, 0.35)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pmat.albedo_color = Color(1.0, 0.92, 0.6)
	pmat.emission_enabled = true
	pmat.emission = Color(1.0, 0.85, 0.4)
	qm.material = pmat
	p.draw_pass_1 = qm
	parent.add_child(p)
	p.emitting = true

	var ring := MeshInstance3D.new()
	ring.position = center
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 1.0
	ring.mesh = torus
	var rmat := _moon_glow_material()
	ring.material_override = rmat
	parent.add_child(ring)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(20.0, 6.0, 20.0), 1.3).set_ease(Tween.EASE_OUT)
	rt.tween_property(rmat, "albedo_color:a", 0.0, 1.3)

	var flash := OmniLight3D.new()
	flash.position = center
	flash.light_color = Color(1.0, 0.9, 0.6)
	flash.light_energy = 8.0
	flash.omni_range = 70.0
	flash.shadow_enabled = false
	parent.add_child(flash)
	create_tween().tween_property(flash, "light_energy", 0.0, 1.4)

	if world_environment != null:
		var et := create_tween()
		et.tween_property(world_environment, "ambient_light_energy", 1.7, 0.18)
		et.tween_property(world_environment, "ambient_light_energy", base_ambient + 0.25, 1.0)


# Gently retract the beams and dim their lights so the finale powers down instead
# of snapping off when the FX are freed at the end.
func _moon_fx_fade(fx: Node3D, dur: float) -> void:
	if not is_instance_valid(fx):
		return
	for child in fx.get_children():
		if child is Node3D and (child as Node3D).has_meta("beam_light"):
			var beam := child as Node3D
			var ft := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			ft.tween_property(beam, "scale:y", 0.02, dur)
			var lt: Variant = beam.get_meta("beam_light", null)
			if lt is OmniLight3D:
				ft.tween_property(lt, "light_energy", 0.0, dur)


func _try_award_map_survey_completion(world_id: String, map_id: String) -> void:
	if world_id == "" or map_id == "" or current_world_id == "":
		return
	var map_record: Dictionary = _get_map_record(world_id, map_id)
	if map_record.is_empty():
		return
	var map_type: String = str(map_record.get("type", WorldGraph.MAP_NORMAL))
	if map_type == WorldGraph.MAP_GATE_ROOM or map_type == WorldGraph.MAP_NEXUS:
		return
	if bool(map_record.get("map_survey_rewarded", false)):
		return
	var available: int = int(map_record.get("available_discoveries", 0))
	if available <= 0:
		return
	var found: int = map_record.get("discoveries", {}).size()
	if found < available:
		return
	map_record["map_survey_rewarded"] = true
	map_record["map_survey_rewarded_at"] = Time.get_unix_time_from_system()
	_update_world_map_record(world_id, map_id, map_record, true)
	lichen_count += MAP_SURVEY_LICHEN_REWARD
	var player: CharacterBody3D = _get_player()
	if player != null and player.has_method(&"set"):
		player.set("lichen_count", lichen_count)
	var map_label: String = _display_name_for_map(world_id, map_id)
	last_discovery_text = "Survey complete: " + map_label + " (+%d lichen)." % MAP_SURVEY_LICHEN_REWARD
	_push_status_banner(last_discovery_text, 3200)
	if world_id == current_world_id and map_id == current_map_id and map_type == WorldGraph.MAP_MOON:
		_try_play_map_survey_cutscene(map_record, map_label)


func _try_play_map_survey_cutscene(map_record: Dictionary, map_label: String) -> void:
	if _cutscene_active or _moon_cutscene_active or generated_root == null:
		return
	if bool(map_record.get("map_survey_cutscene_seen", false)):
		return
	if bool(map_record.get("moon_pilgrim_cutscene_seen", false)):
		return
	if map_record.get("discoveries", {}).has("moon_pilgrim"):
		return
	var orb_count: int = _moon_orb_discovery_count(map_record.get("discoveries", {}))
	if orb_count >= MOON_SHRINE_COUNT:
		return
	var player: CharacterBody3D = _get_player()
	if player == null:
		return
	var player_camera: Camera3D = player.get_node_or_null("PlayerCamera") as Camera3D
	if player_camera == null:
		return
	map_record["map_survey_cutscene_seen"] = true
	_update_world_map_record(current_world_id, current_map_id, map_record, true)
	_cutscene_active = true
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rig := Node3D.new()
	rig.name = "MapSurveyCutsceneRig"
	generated_root.add_child(rig)
	var cam := Camera3D.new()
	cam.current = true
	rig.add_child(cam)
	var center: Vector3 = player.global_position + Vector3(0.0, 2.2, 0.0)
	rig.global_position = center + Vector3(-7.0, 3.6, -8.0)
	cam.look_at(center, Vector3.UP)
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(rig, "global_position", center + Vector3(8.5, 4.2, -5.0), 1.5)
	t.tween_callback(func() -> void:
		if is_instance_valid(cam):
			cam.look_at(center, Vector3.UP)
	)
	t.tween_property(rig, "global_position", center + Vector3(0.0, 6.8, 10.0), 1.3)
	t.finished.connect(func() -> void:
		if is_instance_valid(player_camera):
			player_camera.current = true
		if is_instance_valid(rig):
			rig.queue_free()
		if is_instance_valid(player):
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_cutscene_active = false
		last_discovery_text = "Atlas entry sealed for " + map_label + "."
		_push_status_banner(last_discovery_text, 2600)
	)


func _moon_orb_discovery_count(discoveries: Dictionary) -> int:
	var count: int = 0
	for key in discoveries.keys():
		if str(key).begins_with("moon_orb_"):
			count += 1
	return count


func _deferred_load_gate_target(target_world_id: String, target_map_id: String) -> void:
	_gate_transition_in_progress = false
	if not _validate_transition_target(target_world_id, target_map_id):
		return
	_load_map(target_world_id, target_map_id)
	if discovery_tracker != null:
		discovery_tracker.award_achievement("gate_crasher")


func _spawn_floating_local_gates() -> void:
	if generated_root == null or not _is_current_map_floating_island():
		return
	var rng := StableRng.new(StableRng.mix_string(world_seed, "floating_local_gates"))
	var half: float = _world_half_size() * 0.72
	var positions: Array[Vector3] = []
	for _attempt in range(320):
		if positions.size() >= 4:
			break
		var x: float = rng.randf_range(-half, half)
		var z: float = rng.randf_range(-half, half)
		var y: float = _height_at_world(x, z)
		if y <= WATER_LEVEL + 2.2:
			continue
		var too_close: bool = false
		for p in positions:
			if p.distance_to(Vector3(x, y, z)) < 42.0:
				too_close = true
				break
		if too_close:
			continue
		positions.append(Vector3(x, y + 1.0, z))

	if positions.size() < 2:
		return

	_floating_local_gate_positions = positions
	_floating_recovery_gate_positions.clear()
	for i in range(_floating_local_gate_positions.size()):
		var pos: Vector3 = _floating_local_gate_positions[i]
		_spawn_single_floating_local_gate(pos, i, "top")
		_wonder_positions.append({"x": pos.x, "z": pos.z, "kind": "gate", "id": "local_gate_" + str(i), "title": "Local Gate " + str(i + 1)})

	var low_y: float = _water_level() + 1.6
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0
		var r: float = 18.0 + float(i) * 7.0
		var pos := Vector3(cos(ang) * r, low_y, sin(ang) * r)
		_floating_recovery_gate_positions.append(pos)
		_spawn_single_floating_local_gate(pos, i, "recovery")
		_wonder_positions.append({"x": pos.x, "z": pos.z, "kind": "gate", "id": "recovery_gate_" + str(i), "title": "Recovery Gate " + str(i + 1)})


func _spawn_single_floating_local_gate(pos: Vector3, gate_index: int, gate_mode: String) -> void:
	var root := Node3D.new()
	root.name = "FloatingLocalGate_" + gate_mode + "_" + str(gate_index)
	root.position = pos

	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.outer_radius = 2.6
	torus.inner_radius = 2.15
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	var ring_mat := StandardMaterial3D.new()
	if gate_mode == "recovery":
		ring_mat.albedo_color = Color(1.0, 0.68, 0.26)
		ring_mat.emission = Color(1.0, 0.64, 0.20)
	else:
		ring_mat.albedo_color = Color(0.30, 0.88, 1.0)
		ring_mat.emission = Color(0.25, 0.82, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission_energy_multiplier = 1.25
	ring.material_override = ring_mat
	root.add_child(ring)

	var area := Area3D.new()
	area.name = "LocalGateArea"
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2
	cyl.height = 4.0
	shape.shape = cyl
	shape.position = Vector3(0.0, 1.8, 0.0)
	area.add_child(shape)
	area.body_entered.connect(_on_floating_local_gate_body_entered.bind(gate_index, gate_mode))
	root.add_child(area)

	generated_root.add_child(root)


func _on_floating_local_gate_body_entered(body: Node3D, gate_index: int, gate_mode: String) -> void:
	if body.name != "Player" or not _is_current_map_floating_island():
		return
	if _floating_local_gate_positions.size() < 2:
		return
	var now: int = Time.get_ticks_msec()
	if now - _floating_local_gate_last_trigger_msec < 700:
		return
	_floating_local_gate_last_trigger_msec = now
	var target_index: int = (gate_index + 1) % _floating_local_gate_positions.size()
	if gate_mode == "recovery":
		target_index = gate_index % _floating_local_gate_positions.size()
	var player: CharacterBody3D = body as CharacterBody3D
	if player == null:
		return
	player.global_position = _floating_local_gate_positions[target_index] + Vector3(0.0, 1.2, 0.0)
	player.velocity = Vector3.ZERO
	if gate_mode == "recovery":
		last_discovery_text = "Recovery gate lift " + str(gate_index + 1) + " -> island gate " + str(target_index + 1)
	else:
		last_discovery_text = "Local gate jump " + str(gate_index + 1) + " -> " + str(target_index + 1)


func _validate_transition_target(world_id: String, map_id: String) -> bool:
	if world_id == "" or map_id == "":
		_transition_status_line = "Transition: missing world/map id."
		last_discovery_text = _transition_status_line
		return false
	var world: Dictionary = _get_world(world_id)
	if world.is_empty():
		_transition_status_line = "Transition: target world missing."
		last_discovery_text = _transition_status_line
		return false
	var maps: Dictionary = world.get("maps", {})
	if not maps.has(map_id):
		_transition_status_line = "Transition: target map missing."
		last_discovery_text = _transition_status_line
		return false
	return true
