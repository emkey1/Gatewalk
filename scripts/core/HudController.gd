extends Node
class_name HudController

const GRID_SIZE: int = 224
const CELL_SIZE: float = 2.0
const WATER_LEVEL: float = -1.7

var hud_layer: CanvasLayer
var hud_root_panel: PanelContainer
var meta_label: Label
var status_label: Label
var controls_label: Label
var goals_label: Label
var stamina_bar: ProgressBar
var breath_bar: ProgressBar
var minimap_panel: PanelContainer
var minimap_marker_layer: Control
var music_label: Label
var music_prev_button: Button
var music_next_button: Button
var fps_label: Label
var underwater_layer: CanvasLayer
var underwater_overlay: ColorRect
var is_underwater: bool = false
var hud_position: String = "left"
var _ui_parent: Node

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
var _on_prev_music_fn: Callable
var _on_next_music_fn: Callable

var _trail: Array = []
var _trail_timer: float = 0.0
var _wonder_positions: Array = []
var _discovered_ids: Dictionary = {}
var _last_map_id: String = ""
var _minimap_zoom: float = 1.0


func setup(parent: Node) -> void:
	_ui_parent = parent
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 10
	parent.add_child(hud_layer)
	_rebuild_hud_layout()

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


func set_hud_position(position: String) -> void:
	var normalized: String = "bottom" if position == "bottom" else "left"
	if hud_position == normalized and hud_root_panel != null:
		return
	hud_position = normalized
	_rebuild_hud_layout()


func _rebuild_hud_layout() -> void:
	if hud_layer == null:
		return
	if hud_root_panel != null:
		hud_root_panel.queue_free()
		hud_root_panel = null
	var panel := PanelContainer.new()
	hud_root_panel = panel
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hud_position == "bottom":
		panel.anchor_left = 0.0
		panel.anchor_top = 1.0
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 14.0
		panel.offset_top = -208.0
		panel.offset_right = -14.0
		panel.offset_bottom = -10.0
	else:
		panel.anchor_left = 0.0
		panel.anchor_top = 0.0
		panel.anchor_right = 0.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 12.0
		panel.offset_top = 12.0
		panel.offset_right = 256.0
		panel.offset_bottom = -12.0
	hud_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	if hud_position == "bottom":
		_build_bottom_hud(margin)
	else:
		_build_left_hud(margin)


func _build_left_hud(parent: Control) -> void:
	var hud_stack := VBoxContainer.new()
	hud_stack.add_theme_constant_override("separation", 6)
	hud_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hud_stack)

	var info_stack := VBoxContainer.new()
	info_stack.add_theme_constant_override("separation", 5)
	info_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stack.add_child(info_stack)
	meta_label = _add_info_block(info_stack, 11)
	status_label = _add_info_block(info_stack, 11)
	controls_label = _add_info_block(info_stack, 11)
	goals_label = _add_info_block(info_stack, 11)

	hud_stack.add_child(_create_vitals_panel(11))

	minimap_panel = PanelContainer.new()
	minimap_panel.custom_minimum_size = Vector2(130.0, 130.0)
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.set_h_size_flags(Control.SIZE_SHRINK_CENTER)
	hud_stack.add_child(minimap_panel)
	minimap_marker_layer = Control.new()
	minimap_marker_layer.custom_minimum_size = Vector2(130.0, 130.0)
	minimap_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(minimap_marker_layer)

	hud_stack.add_child(_create_music_panel(11))


func _build_bottom_hud(parent: Control) -> void:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 4)
	root.add_child(info_col)
	meta_label = _add_info_block(info_col, 10)
	status_label = _add_info_block(info_col, 10)
	goals_label = _add_info_block(info_col, 10)
	controls_label = _add_info_block(info_col, 10)

	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(360.0, 0.0)
	right_col.add_theme_constant_override("separation", 5)
	root.add_child(right_col)
	right_col.add_child(_create_vitals_panel(10))
	right_col.add_child(_create_music_panel(10))

	minimap_panel = PanelContainer.new()
	minimap_panel.custom_minimum_size = Vector2(122.0, 122.0)
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap_panel)
	minimap_marker_layer = Control.new()
	minimap_marker_layer.custom_minimum_size = Vector2(122.0, 122.0)
	minimap_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(minimap_marker_layer)


func _create_vitals_panel(font_size: int) -> PanelContainer:
	var vitals_panel := PanelContainer.new()
	vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vitals_margin := MarginContainer.new()
	vitals_margin.add_theme_constant_override("margin_left", 6)
	vitals_margin.add_theme_constant_override("margin_top", 5)
	vitals_margin.add_theme_constant_override("margin_right", 6)
	vitals_margin.add_theme_constant_override("margin_bottom", 5)
	vitals_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_panel.add_child(vitals_margin)
	var vitals_stack := VBoxContainer.new()
	vitals_stack.add_theme_constant_override("separation", 4)
	vitals_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_margin.add_child(vitals_stack)

	var stamina_label := Label.new()
	stamina_label.text = "Sprint"
	stamina_label.add_theme_font_size_override("font_size", font_size)
	stamina_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_stack.add_child(stamina_label)
	stamina_bar = ProgressBar.new()
	stamina_bar.min_value = 0.0
	stamina_bar.max_value = 15.0
	stamina_bar.value = 15.0
	stamina_bar.show_percentage = false
	stamina_bar.custom_minimum_size = Vector2(0.0, 12.0)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_stack.add_child(stamina_bar)

	var breath_label := Label.new()
	breath_label.text = "Breath"
	breath_label.add_theme_font_size_override("font_size", font_size)
	breath_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_stack.add_child(breath_label)
	breath_bar = ProgressBar.new()
	breath_bar.min_value = 0.0
	breath_bar.max_value = 60.0
	breath_bar.value = 60.0
	breath_bar.show_percentage = false
	breath_bar.custom_minimum_size = Vector2(0.0, 12.0)
	breath_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_stack.add_child(breath_bar)
	return vitals_panel


func _create_music_panel(font_size: int) -> PanelContainer:
	var music_panel := PanelContainer.new()
	music_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var music_margin := MarginContainer.new()
	music_margin.add_theme_constant_override("margin_left", 6)
	music_margin.add_theme_constant_override("margin_top", 5)
	music_margin.add_theme_constant_override("margin_right", 6)
	music_margin.add_theme_constant_override("margin_bottom", 5)
	music_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	music_panel.add_child(music_margin)
	var music_stack := VBoxContainer.new()
	music_stack.add_theme_constant_override("separation", 4)
	music_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	music_margin.add_child(music_stack)
	music_label = Label.new()
	music_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	music_label.add_theme_font_size_override("font_size", font_size)
	music_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music_stack.add_child(music_label)
	var music_controls := HBoxContainer.new()
	music_controls.add_theme_constant_override("separation", 6)
	music_controls.mouse_filter = Control.MOUSE_FILTER_PASS
	music_stack.add_child(music_controls)
	music_prev_button = Button.new()
	music_prev_button.text = "Prev"
	music_prev_button.focus_mode = Control.FOCUS_NONE
	music_prev_button.mouse_filter = Control.MOUSE_FILTER_STOP
	music_prev_button.pressed.connect(func() -> void:
		if _on_prev_music_fn.is_valid():
			_on_prev_music_fn.call()
	)
	music_controls.add_child(music_prev_button)
	music_next_button = Button.new()
	music_next_button.text = "Next"
	music_next_button.focus_mode = Control.FOCUS_NONE
	music_next_button.mouse_filter = Control.MOUSE_FILTER_STOP
	music_next_button.pressed.connect(func() -> void:
		if _on_next_music_fn.is_valid():
			_on_next_music_fn.call()
	)
	music_controls.add_child(music_next_button)
	return music_panel


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
	if meta_label == null or status_label == null or controls_label == null or goals_label == null:
		return

	var map_short: String = str(data.get("map_short", "none"))
	var map_name: String = str(data.get("map_name", map_short))
	var world_name: String = str(data.get("world_name", "?"))
	var map_type: String = str(data.get("map_type", ""))
	var map_type_label: String = str(data.get("map_type_label", map_type))
	var position_text: String = str(data.get("position_text", "No active player"))
	var warning_text: String = str(data.get("warning_text", ""))
	var flashlight_text: String = str(data.get("flashlight_text", ""))
	var music_text: String = str(data.get("music_text", ""))
	var discovery_line: String = str(data.get("discovery_line", "Seek gates, ruins, and wonders."))
	var objective_line: String = str(data.get("objective_line", ""))
	var progression_line: String = str(data.get("progression_line", ""))
	var next_reward_line: String = str(data.get("next_reward_line", ""))
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

	var header_lines: Array[String] = []
	var status_lines: Array[String] = []
	var controls_lines: Array[String] = []
	var goals_lines: Array[String] = []

	if is_gate_room:
		header_lines = [
			"World: " + world_name + " — Inter-world Gate Room",
			atlas_summary,
			maps_line,
		]
		status_lines = [position_text, discovery_line]
		if gate_room_return_world != "":
			status_lines.append("Walk to Return portal to exit.")
	elif is_map_nexus or map_type == "map_nexus":
		header_lines = [
			"World: " + world_name + " — World Nexus",
			atlas_summary,
			maps_line,
		]
		status_lines = [position_text, discovery_line]
		controls_lines.append("[G] Return to Gate Room")
	else:
		header_lines = [
			"World: " + world_name,
			atlas_summary,
			maps_line,
			"Map " + map_name + " (" + map_short + "): " + map_completion,
		]
		status_lines = [position_text, discovery_line]
		if map_type != "":
			status_lines.append("Biome: " + map_type_label)
		if gate_room_source_world != "" and gate_room_source_map != "":
			controls_lines.append("[G] Return to Gate Room")

	if pin_count > 0:
		controls_lines.append("Pins: " + str(pin_count) + " [P] place pin")
	else:
		controls_lines.append("[P] place pin")
	if lichen_count > 0:
		controls_lines.append("Lichen: " + str(lichen_count) + " [C] grab [T] throw")
	if flashlight_text != "":
		controls_lines.append(flashlight_text)
	if warning_text != "":
		status_lines.append(warning_text)

	if recent_discoveries.size() > 0:
		goals_lines.append("Recent: " + ", ".join(recent_discoveries))
	if objective_line != "":
		goals_lines.append(objective_line)
	if progression_line != "":
		goals_lines.append(progression_line)
	if next_reward_line != "":
		goals_lines.append(next_reward_line)

	meta_label.text = "\n".join(header_lines)
	status_label.text = "\n".join(status_lines)
	controls_label.text = "\n".join(controls_lines)
	goals_label.text = "\n".join(goals_lines)
	if music_label != null:
		music_label.text = music_text if music_text != "" else "Now Playing: None"
	if music_prev_button != null:
		music_prev_button.disabled = music_text == ""
	if music_next_button != null:
		music_next_button.disabled = music_text == ""

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
		var panel_size: float = 176.0 if (_is_moon_fn.is_valid() and _is_moon_fn.call()) else 150.0
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


func _add_info_block(parent: VBoxContainer, font_size: int = 12) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)
	return label


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
