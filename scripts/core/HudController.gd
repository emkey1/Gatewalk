extends Node
class_name HudController

const GRID_SIZE: int = 224
const CELL_SIZE: float = 2.0
const WATER_LEVEL: float = -1.7

var hud_layer: CanvasLayer
var hud_label: Label
var stamina_bar: ProgressBar
var breath_bar: ProgressBar
var minimap_panel: PanelContainer
var minimap_marker_layer: Control
var fps_label: Label
var underwater_layer: CanvasLayer
var underwater_overlay: ColorRect
var is_underwater: bool = false

var world_environment: Environment :
	set(value):
		world_environment = value

var moon_grid_scale: int = 1
var show_fps: bool = false

var _get_world_fn: Callable
var _get_player_fn: Callable
var _is_moon_fn: Callable
var _is_water_fn: Callable
var _is_cave_fn: Callable
var _is_arctic_fn: Callable
var _is_gate_room_fn: Callable

var _trail: Array = []
var _trail_timer: float = 0.0
var _wonder_positions: Array = []
var _discovered_ids: Dictionary = {}
var _last_map_id: String = ""
var _minimap_zoom: float = 1.0


func setup(parent: Node) -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 10
	parent.add_child(hud_layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 180.0
	panel.offset_bottom = 212.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var hud_stack := VBoxContainer.new()
	hud_stack.add_theme_constant_override("separation", 8)
	hud_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hud_stack)

	hud_label = Label.new()
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_label.add_theme_font_size_override("font_size", 7)
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stack.add_child(hud_label)

	var stamina_label := Label.new()
	stamina_label.text = "Sprint"
	stamina_label.add_theme_font_size_override("font_size", 6)
	stamina_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stack.add_child(stamina_label)

	stamina_bar = ProgressBar.new()
	stamina_bar.min_value = 0.0
	stamina_bar.max_value = 15.0
	stamina_bar.value = 15.0
	stamina_bar.show_percentage = false
	stamina_bar.custom_minimum_size = Vector2(0.0, 9.0)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stack.add_child(stamina_bar)

	var breath_label := Label.new()
	breath_label.text = "Breath"
	breath_label.add_theme_font_size_override("font_size", 6)
	breath_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stack.add_child(breath_label)

	breath_bar = ProgressBar.new()
	breath_bar.min_value = 0.0
	breath_bar.max_value = 60.0
	breath_bar.value = 60.0
	breath_bar.show_percentage = false
	breath_bar.custom_minimum_size = Vector2(0.0, 9.0)
	breath_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stack.add_child(breath_bar)

	minimap_panel = PanelContainer.new()
	minimap_panel.custom_minimum_size = Vector2(80.0, 80.0)
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.set_h_size_flags(Control.SIZE_SHRINK_CENTER)
	hud_stack.add_child(minimap_panel)

	minimap_marker_layer = Control.new()
	minimap_marker_layer.custom_minimum_size = Vector2(80.0, 80.0)
	minimap_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(minimap_marker_layer)

	fps_label = Label.new()
	fps_label.anchor_left = 0.0
	fps_label.anchor_top = 0.0
	fps_label.anchor_right = 1.0
	fps_label.anchor_bottom = 0.0
	fps_label.offset_left = 0.0
	fps_label.offset_top = 4.0
	fps_label.offset_right = -8.0
	fps_label.offset_bottom = 30.0
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	fps_label.add_theme_font_size_override("font_size", 11)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.visible = false
	hud_layer.add_child(fps_label)

	_setup_underwater_overlay(parent)


func _setup_underwater_overlay(parent: Node) -> void:
	underwater_layer = CanvasLayer.new()
	underwater_layer.name = "UnderwaterLayer"
	underwater_layer.layer = 20
	parent.add_child(underwater_layer)

	underwater_overlay = ColorRect.new()
	underwater_overlay.name = "UnderwaterOverlay"
	underwater_overlay.anchor_right = 1.0
	underwater_overlay.anchor_bottom = 1.0
	underwater_overlay.color = Color(0.02, 0.22, 0.36, 0.34)
	underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underwater_overlay.visible = false
	underwater_layer.add_child(underwater_overlay)


func update(data: Dictionary) -> void:
	if hud_label == null:
		return

	var map_short: String = str(data.get("map_short", "none"))
	var world_name: String = str(data.get("world_name", "?"))
	var map_type: String = str(data.get("map_type", ""))
	var position_text: String = str(data.get("position_text", "No active player"))
	var warning_text: String = str(data.get("warning_text", ""))
	var flashlight_text: String = str(data.get("flashlight_text", ""))
	var discovery_line: String = str(data.get("discovery_line", "Seek gates, ruins, and wonders."))
	var objective_line: String = str(data.get("objective_line", ""))
	var progression_line: String = str(data.get("progression_line", ""))
	var recent_discoveries: Array = data.get("recent_discoveries", [])
	var maps_line: String = str(data.get("maps_line", ""))
	var atlas_summary: String = str(data.get("atlas_summary", ""))
	var map_completion: String = str(data.get("map_completion", ""))
	var lichen_count: int = int(data.get("lichen_count", 0))
	var pin_count: int = int(data.get("pin_count", 0))
	var is_gate_room: bool = bool(data.get("is_gate_room", false))
	var gate_room_return_world: String = str(data.get("gate_room_return_world", ""))
	var gate_room_source_world: String = str(data.get("gate_room_source_world", ""))
	var gate_room_source_map: String = str(data.get("gate_room_source_map", ""))
	var is_map_nexus: bool = bool(data.get("is_map_nexus", false))

	if is_gate_room:
		hud_label.text = "World: " + world_name + " — Inter-world Gate Room\n" + atlas_summary + "\n" + maps_line + "\n" + position_text + "\n" + discovery_line
		if gate_room_return_world != "":
			hud_label.text += "\nWalk to Return portal to exit."
	elif is_map_nexus or map_type == "map_nexus":
		hud_label.text = "World: " + world_name + " — World Nexus\n" + atlas_summary + "\n" + maps_line + "\n" + position_text + "\n" + discovery_line
		hud_label.text += "\n[G] Return to Gate Room"
	else:
		hud_label.text = "World: " + world_name + "\n" + atlas_summary + "\n" + maps_line + "\nMap " + map_short + ": " + map_completion + "\n" + position_text + "\n" + discovery_line
		if map_type != "":
			hud_label.text += "\nBiome: " + map_type
		if gate_room_source_world != "" and gate_room_source_map != "":
			hud_label.text += "\n[G] Return to Gate Room"

	if pin_count > 0:
		hud_label.text += "\nPins: " + str(pin_count) + " [P] place pin"
	else:
		hud_label.text += "\n[P] place pin"

	if lichen_count > 0:
		hud_label.text += "\nLichen: " + str(lichen_count) + " [C] grab [T] throw"

	if flashlight_text != "":
		hud_label.text += "\n" + flashlight_text

	if warning_text != "":
		hud_label.text += "\n" + warning_text

	if recent_discoveries.size() > 0:
		hud_label.text += "\nRecent: " + ", ".join(recent_discoveries)
	if objective_line != "":
		hud_label.text += "\n" + objective_line
	if progression_line != "":
		hud_label.text += "\n" + progression_line

	var stamina: float = float(data.get("stamina", -1.0))
	if stamina_bar != null and stamina >= 0.0:
		stamina_bar.value = stamina
	var breath: float = float(data.get("breath", -1.0))
	if breath_bar != null and breath >= 0.0:
		breath_bar.value = breath
		breath_bar.visible = breath < 60.0

	var player: Node3D = data.get("player_node", null) as Node3D
	var world_half_size: float = float(data.get("world_half_size", 0.0))
	var discoveries_dict: Dictionary = data.get("discoveries", {})
	var pins_dict: Dictionary = data.get("pins", {})
	_wonder_positions = data.get("wonder_positions", [])
	_discovered_ids = {}
	for dk in discoveries_dict.keys():
		_discovered_ids[dk] = true

	var current_map_id: String = str(data.get("current_map_id", ""))
	_minimap_zoom = clamp(float(data.get("minimap_zoom", 1.0)), 0.6, 2.5)
	if minimap_panel != null and minimap_marker_layer != null:
		var panel_size: float = 96.0 if (_is_moon_fn.is_valid() and _is_moon_fn.call()) else 80.0
		minimap_panel.custom_minimum_size = Vector2(panel_size, panel_size)
		minimap_marker_layer.custom_minimum_size = Vector2(panel_size, panel_size)
	if current_map_id != _last_map_id:
		_last_map_id = current_map_id
		_trail.clear()

	if player != null:
		_trail_timer += data.get("delta", 0.0)
		if _trail_timer > 0.25:
			_trail_timer = 0.0
			var px: float = player.global_position.x
			var pz: float = player.global_position.z
			if _trail.is_empty() or _trail[-1]["x"] != px or _trail[-1]["z"] != pz:
				_trail.append({"x": px, "z": pz})
				if _trail.size() > 400:
					_trail.pop_front()

	_update_minimap(player, world_half_size, discoveries_dict, pins_dict, data.get("delta", 0.0), _minimap_zoom)

	if fps_label != null and show_fps:
		fps_label.text = str(Engine.get_frames_per_second()) + " FPS"


func _update_minimap(player: Node3D, half: float, discoveries: Dictionary, pins: Dictionary, delta: float = 0.0, zoom: float = 1.0) -> void:
	if minimap_marker_layer == null:
		return

	for child in minimap_marker_layer.get_children():
		child.queue_free()

	var layer_size: Vector2 = minimap_marker_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		layer_size = minimap_marker_layer.custom_minimum_size
	var size: float = min(layer_size.x, layer_size.y)
	if size <= 0.0:
		size = 80.0
	var effective_half: float = max(half * zoom, 1.0)

	for ti in range(max(0, _trail.size() - 1)):
		var tp: Dictionary = _trail[ti]
		var tpos: Vector2 = _world_to_minimap(float(tp["x"]), float(tp["z"]), size, effective_half)
		var alpha: float = 0.08 + 0.12 * float(ti) / float(max(_trail.size(), 1))
		var tdot := ColorRect.new()
		tdot.color = Color(0.35, 0.55, 0.75, alpha)
		tdot.position = tpos - Vector2(0.6, 0.6)
		tdot.size = Vector2(1.2, 1.2)
		tdot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minimap_marker_layer.add_child(tdot)

	for w in _wonder_positions:
		var wx: float = float(w["x"])
		var wz: float = float(w["z"])
		var wpos: Vector2 = _world_to_minimap(wx, wz, size, effective_half)
		var wid: String = str(w.get("id", ""))
		var is_discovered: bool = _discovered_ids.has(wid)
		var kind: String = str(w.get("kind", "wonder"))
		var wonder_color: Color
		if is_discovered:
			match kind:
				"gate": wonder_color = Color(1.0, 0.7, 0.2)
				"ruin": wonder_color = Color(0.75, 0.6, 1.0)
				"orb": wonder_color = Color(0.3, 1.0, 0.6)
				"crystal": wonder_color = Color(0.25, 0.90, 0.85)
				_: wonder_color = Color(0.35, 0.85, 1.0)
			_add_minimap_dot(wpos, wonder_color, 2.0)
		else:
			wonder_color = Color(0.2, 0.25, 0.3, 0.5)
			_add_minimap_dot(wpos, wonder_color, 1.2)

	for discovery_key in discoveries.keys():
		var discovery: Dictionary = discoveries[discovery_key]
		if not discovery.has("x") or not discovery.has("z"):
			continue
		var x: float = float(discovery["x"])
		var z: float = float(discovery["z"])
		var pos: Vector2 = _world_to_minimap(x, z, size, effective_half)
		var kind: String = str(discovery.get("kind", "wonder"))
		var color: Color = Color(0.35, 0.85, 1.0)
		if kind == "gate":
			color = Color(1.0, 0.7, 0.2)
		elif kind == "ruin":
			color = Color(0.75, 0.6, 1.0)
		elif kind == "orb":
			color = Color(0.3, 1.0, 0.6)
		elif kind == "crystal":
			color = Color(0.25, 0.90, 0.85)
		_add_minimap_dot(pos, color, 1.5)

	for pin_key in pins.keys():
		var pin: Dictionary = pins[pin_key]
		if not pin.has("x") or not pin.has("z"):
			continue
		var px: float = float(pin["x"])
		var pz: float = float(pin["z"])
		var ppos: Vector2 = _world_to_minimap(px, pz, size, effective_half)
		_add_minimap_dot(ppos, Color(1.0, 0.45, 0.9), 1.2)

	if player != null:
		var player_pos: Vector2 = _world_to_minimap(player.global_position.x, player.global_position.z, size, effective_half)
		var fwd: Vector3 = -player.global_transform.basis.z
		var angle: float = atan2(fwd.x, -fwd.z)

		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(0.0, -5.0), Vector2(-4.0, 4.0), Vector2(4.0, 4.0)])
		arrow.color = Color(1.0, 0.55, 0.0)
		arrow.position = player_pos
		arrow.rotation = angle
		minimap_marker_layer.add_child(arrow)


func _world_to_minimap(x: float, z: float, size: float, half: float) -> Vector2:
	return Vector2((x / half) * size * 0.5 + size * 0.5, (z / half) * size * 0.5 + size * 0.5)


func _add_minimap_dot(pos: Vector2, color: Color, radius: float) -> void:
	var dot := ColorRect.new()
	dot.color = color
	dot.position = pos - Vector2(radius, radius)
	dot.size = Vector2(radius * 2.0, radius * 2.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_marker_layer.add_child(dot)


func update_underwater_state(is_moon: bool, is_gate_room: bool, camera: Camera3D) -> void:
	if is_moon or is_gate_room:
		if is_underwater:
			is_underwater = false
			if underwater_overlay != null:
				underwater_overlay.visible = false
		return

	if camera == null:
		return

	var now_underwater: bool = camera.global_position.y < WATER_LEVEL
	if now_underwater == is_underwater:
		return

	is_underwater = now_underwater
	if underwater_overlay != null:
		underwater_overlay.visible = is_underwater

	if world_environment != null:
		if is_underwater:
			world_environment.fog_density = 0.075
			world_environment.fog_light_color = Color(0.05, 0.32, 0.48)
			world_environment.ambient_light_color = Color(0.18, 0.45, 0.58)
		else:
			world_environment.fog_density = 0.010
			world_environment.fog_light_color = Color(0.65, 0.75, 0.85)
			world_environment.ambient_light_color = Color(0.7, 0.78, 0.86)
