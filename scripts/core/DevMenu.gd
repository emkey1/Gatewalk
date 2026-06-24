extends Node
class_name DevMenu

var dev_menu_layer: CanvasLayer
var selected_world: String = ""

var get_worlds_fn: Callable
var get_world_fn: Callable
var set_world_fn: Callable
var set_worlds_fn: Callable
var set_last_world_id_fn: Callable
var load_map_fn: Callable
var save_world_data_fn: Callable
var seed_for_new_record_fn: Callable
var create_map_record_fn: Callable
var create_water_map_record_fn: Callable
var create_arctic_map_record_fn: Callable
var create_cave_map_record_fn: Callable
var new_id_fn: Callable
var moon_seed_fn: Callable
var create_gate_room_map_record_fn: Callable
var create_map_nexus_map_record_fn: Callable
var close_main_menu_fn: Callable
var get_e_key_gate_enabled_fn: Callable
var set_e_key_gate_enabled_fn: Callable
var get_gate_debug_hud_enabled_fn: Callable
var set_gate_debug_hud_enabled_fn: Callable
var toggle_day_night_fn: Callable

var current_world_id: String = ""
var current_map_id: String = ""
var world_seed: int = 12345
var _session_authenticated: bool = false


func show_login() -> void:
	if dev_menu_layer != null:
		close()
		return
	if _session_authenticated:
		close_main_menu_fn.call()
		_show_menu()
		return
	close_main_menu_fn.call()

	dev_menu_layer = CanvasLayer.new()
	dev_menu_layer.name = "DevMenuLayer"
	dev_menu_layer.layer = 35
	add_child(dev_menu_layer)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.50)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dev_menu_layer.add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -150.0
	panel.offset_top = -80.0
	panel.offset_right = 150.0
	panel.offset_bottom = 80.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.075, 0.085, 0.96)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	dev_menu_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Dev Access"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var prompt := Label.new()
	prompt.text = "Enter password:"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	vbox.add_child(prompt)

	var line_edit := LineEdit.new()
	line_edit.secret = true
	line_edit.placeholder_text = "password"
	line_edit.custom_minimum_size = Vector2(200.0, 0.0)
	vbox.add_child(line_edit)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	button_row.alignment = 1
	vbox.add_child(button_row)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.pressed.connect(_on_login_attempt.bind(line_edit))
	button_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(close)
	button_row.add_child(cancel_btn)

	line_edit.text_submitted.connect(func(_text: String) -> void: _on_login_attempt(line_edit))
	line_edit.grab_focus()


func _on_login_attempt(line_edit: LineEdit) -> void:
	if line_edit.text == "1215":
		_session_authenticated = true
		_show_menu()
	else:
		line_edit.text = ""
		line_edit.placeholder_text = "wrong password"


func close() -> void:
	if dev_menu_layer != null:
		dev_menu_layer.queue_free()
		dev_menu_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _clear() -> void:
	if dev_menu_layer == null:
		return
	for child in dev_menu_layer.get_children():
		dev_menu_layer.remove_child(child)
		child.queue_free()


func _show_menu() -> void:
	_clear()

	if dev_menu_layer == null:
		dev_menu_layer = CanvasLayer.new()
		dev_menu_layer.name = "DevMenuLayer"
		dev_menu_layer.layer = 35
		add_child(dev_menu_layer)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dev_menu_layer.add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -420.0
	panel.offset_top = -280.0
	panel.offset_right = 420.0
	panel.offset_bottom = 280.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.075, 0.085, 0.96)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	dev_menu_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(menu_vbox)

	var top_title := Label.new()
	top_title.text = "Dev Menu"
	top_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_title.add_theme_font_size_override("font_size", 22)
	menu_vbox.add_child(top_title)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_vbox.add_child(main_hbox)

	var worlds: Dictionary = get_worlds_fn.call()
	selected_world = current_world_id if current_world_id != "" else ""
	if selected_world == "" and not worlds.is_empty():
		selected_world = str(worlds.keys()[0])

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)
	left_vbox.custom_minimum_size = Vector2(200.0, 0.0)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_vbox)

	var worlds_label := Label.new()
	worlds_label.text = "Worlds"
	worlds_label.add_theme_font_size_override("font_size", 16)
	left_vbox.add_child(worlds_label)

	var worlds_scroll := ScrollContainer.new()
	worlds_scroll.custom_minimum_size = Vector2(0.0, 160.0)
	worlds_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(worlds_scroll)

	var worlds_list := VBoxContainer.new()
	worlds_list.add_theme_constant_override("separation", 2)
	worlds_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worlds_scroll.add_child(worlds_list)

	for world_key in worlds.keys():
		var wid: String = str(world_key)
		var w: Dictionary = worlds[wid]
		var btn := Button.new()
		var is_current: bool = wid == selected_world
		btn.text = ("> " if is_current else "  ") + str(w.get("name", wid))
		btn.flat = not is_current
		btn.pressed.connect(_on_world_selected.bind(wid))
		btn.add_theme_font_size_override("font_size", 11)
		worlds_list.add_child(btn)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_vbox.custom_minimum_size = Vector2(380.0, 0.0)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_vbox)

	_populate_right(right_vbox)

	var close_row := HBoxContainer.new()
	close_row.alignment = 1
	close_row.add_theme_constant_override("separation", 8)
	menu_vbox.add_child(close_row)

	if get_e_key_gate_enabled_fn.is_valid() and set_e_key_gate_enabled_fn.is_valid():
		var e_btn := Button.new()
		var enabled: bool = bool(get_e_key_gate_enabled_fn.call())
		e_btn.text = "E-key Gates: " + ("ON" if enabled else "OFF")
		e_btn.pressed.connect(_toggle_e_key_gate_use)
		close_row.add_child(e_btn)
	if get_gate_debug_hud_enabled_fn.is_valid() and set_gate_debug_hud_enabled_fn.is_valid():
		var dbg_btn := Button.new()
		var dbg_enabled: bool = bool(get_gate_debug_hud_enabled_fn.call())
		dbg_btn.text = "Gate HUD Debug: " + ("ON" if dbg_enabled else "OFF")
		dbg_btn.pressed.connect(_toggle_gate_hud_debug)
		close_row.add_child(dbg_btn)
	if toggle_day_night_fn.is_valid():
		var dn_btn := Button.new()
		dn_btn.text = "Toggle Day/Night"
		dn_btn.pressed.connect(_on_toggle_day_night)
		close_row.add_child(dn_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	close_row.add_child(close_btn)


func _on_world_selected(wid: String) -> void:
	selected_world = wid
	_show_menu()


func _populate_right(vbox: VBoxContainer) -> void:
	if selected_world == "":
		var no_world := Label.new()
		no_world.text = "No world selected"
		no_world.add_theme_font_size_override("font_size", 14)
		vbox.add_child(no_world)
		return

	var world: Dictionary = get_world_fn.call(selected_world)
	var maps: Dictionary = world.get("maps", {})
	var world_name: String = str(world.get("name", selected_world))

	var info := Label.new()
	info.text = world_name + "  —  " + str(maps.size()) + " maps"
	info.add_theme_font_size_override("font_size", 14)
	vbox.add_child(info)

	var maps_scroll := ScrollContainer.new()
	maps_scroll.custom_minimum_size = Vector2(0.0, 100.0)
	maps_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(maps_scroll)

	var maps_list := VBoxContainer.new()
	maps_list.add_theme_constant_override("separation", 2)
	maps_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maps_scroll.add_child(maps_list)

	for map_key in maps.keys():
		var mid: String = str(map_key)
		var rec: Dictionary = maps[mid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		maps_list.add_child(row)

		var map_label := Label.new()
		var map_type: String = str(rec.get("type", "normal"))
		var is_current: bool = current_world_id == selected_world and current_map_id == mid
		map_label.text = ("> " if is_current else "  ") + mid + "  [" + map_type + "]"
		map_label.add_theme_font_size_override("font_size", 10)
		map_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(map_label)

		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.pressed.connect(_on_load_map.bind(selected_world, mid))
		row.add_child(load_btn)

	var actions_label := Label.new()
	actions_label.text = "Quick Create and Go:"
	actions_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(actions_label)

	var actions_grid := VBoxContainer.new()
	actions_grid.add_theme_constant_override("separation", 4)
	vbox.add_child(actions_grid)

	var quick_data: Array[Dictionary] = [
		{"id": "normal", "label": "New Normal Map"},
		{"id": "water", "label": "New Water Map"},
		{"id": "cave", "label": "New Cave Map"},
		{"id": "ruined_city", "label": "New Ruined City"},
		{"id": "skyscraper", "label": "New Skyscraper"},
		{"id": "liner", "label": "New Ocean Liner"},
		{"id": "moon", "label": "Go to Moon"},
		{"id": "gate_room", "label": "Go to Gate Room"},
		{"id": "map_nexus", "label": "Go to Map Nexus"},
	]

	for qa in quick_data:
		var btn := Button.new()
		btn.text = qa["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_quick_map.bind(qa["id"], selected_world))
		actions_grid.add_child(btn)


func _on_load_map(world_id: String, map_id: String) -> void:
	close()
	load_map_fn.call(world_id, map_id)


# Helper: given a record-returning callback, convert to dict for storage
func _store_map(maps: Dictionary, map_id: String, record: Variant) -> void:
	if record is MapRecord:
		maps[map_id] = record.to_dict()
	else:
		maps[map_id] = record


func _on_quick_map(map_type: String, world_id: String) -> void:
	close()
	var world: Dictionary = get_world_fn.call(world_id)
	var maps: Dictionary = world.get("maps", {})

	match map_type:
		"moon":
			if not maps.has("moon"):
				var seed_val: int = moon_seed_fn.call(world)
				_store_map(maps, "moon", _create_moon_map_record(seed_val))
			world["maps"] = maps
			set_world_fn.call(world_id, world)
			save_world_data_fn.call()
			load_map_fn.call(world_id, "moon")
			return
		"gate_room":
			if not maps.has("gate_room"):
				var gate_seed: int = int((world_seed ^ 0x47415445) & 0x7fffffff)
				if gate_seed == 0:
					gate_seed = 98765
				_store_map(maps, "gate_room", create_gate_room_map_record_fn.call(gate_seed))
			world["maps"] = maps
			set_world_fn.call(world_id, world)
			save_world_data_fn.call()
			load_map_fn.call(world_id, "gate_room")
			return
		"map_nexus":
			if not maps.has("map_nexus"):
				var nex_seed: int = int((world_seed ^ 0x4E455855) & 0x7fffffff)
				if nex_seed == 0:
					nex_seed = 54321
				_store_map(maps, "map_nexus", create_map_nexus_map_record_fn.call(nex_seed))
			world["maps"] = maps
			set_world_fn.call(world_id, world)
			save_world_data_fn.call()
			load_map_fn.call(world_id, "map_nexus")
			return
		"normal", "water", "cave", "ruined_city", "skyscraper", "liner":
			var mid: String = new_id_fn.call("map")
			var seed_val: int = seed_for_new_record_fn.call(mid)
			match map_type:
				"normal": _store_map(maps, mid, create_map_record_fn.call(seed_val))
				"water": _store_map(maps, mid, create_water_map_record_fn.call(seed_val))
				"cave": _store_map(maps, mid, create_cave_map_record_fn.call(seed_val))
				"ruined_city": _store_map(maps, mid, WorldGraph.create_map_record(seed_val, WorldGraph.MAP_RUINED_CITY))
				"skyscraper": _store_map(maps, mid, WorldGraph.create_map_record(seed_val, WorldGraph.MAP_SKYSCRAPER))
				"liner": _store_map(maps, mid, WorldGraph.create_map_record(seed_val, WorldGraph.MAP_LINER))
			world["maps"] = maps
			set_world_fn.call(world_id, world)
			save_world_data_fn.call()
			load_map_fn.call(world_id, mid)
			return


func _toggle_e_key_gate_use() -> void:
	if not get_e_key_gate_enabled_fn.is_valid() or not set_e_key_gate_enabled_fn.is_valid():
		return
	var current: bool = bool(get_e_key_gate_enabled_fn.call())
	set_e_key_gate_enabled_fn.call(not current)
	_show_menu()


func _toggle_gate_hud_debug() -> void:
	if not get_gate_debug_hud_enabled_fn.is_valid() or not set_gate_debug_hud_enabled_fn.is_valid():
		return
	var current: bool = bool(get_gate_debug_hud_enabled_fn.call())
	set_gate_debug_hud_enabled_fn.call(not current)
	_show_menu()


func _on_toggle_day_night() -> void:
	if toggle_day_night_fn.is_valid():
		toggle_day_night_fn.call()


func _create_moon_map_record(seed_value: int) -> MapRecord:
	return WorldGraph.create_map_record(seed_value, WorldGraph.MAP_MOON)
