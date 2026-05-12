extends Node3D

const WonderGenerator = preload("res://scripts/WonderGenerator.gd")


const GRID_SIZE: int = 224
const CELL_SIZE: float = 2.0

# Larger worlds need broader terrain forms so the space does not feel flat.
const HEIGHT_SCALE: float = 15.0
const WATER_LEVEL: float = -1.7

var TREE_COUNT: int = 720
var ROCK_COUNT: int = 260
var FLOWER_COUNT: int = 520
var CRYSTAL_COUNT: int = 42
var RUIN_COUNT: int = 14
const GATE_COUNT: int = 4
const WONDER_CELL_SIZE: float = 96.0
const WONDER_CHANCE: float = 0.20

const ACHIEVEMENT_DEFS := {
	"first_wonder": {"name": "First Discovery", "desc": "Find your first wonder on any map"},
	"all_wonders_map": {"name": "Map Scholar", "desc": "Find all wonders on a single map"},
	"all_wonders_world": {"name": "World Scholar", "desc": "Find all wonders across a whole world"},
	"lichen_catcher": {"name": "Frisbee Catcher", "desc": "Catch a thrown lichen"},
	"moon_visitor": {"name": "Moon Visitor", "desc": "Travel to the moon"},
	"gate_room_finder": {"name": "Gate Room Discoverer", "desc": "Find a gate room"},
	"world_traveler": {"name": "World Traveler", "desc": "Visit 5 different maps"},
	"cavern_explorer": {"name": "Cavern Explorer", "desc": "Discover a cave map"},
	"island_hopper": {"name": "Island Hopper", "desc": "Discover a water map"},
	"collector_50": {"name": "Lichensmith", "desc": "Collect 50 lichen"},
	"moon_pilgrim": {"name": "Moon Pilgrim", "desc": "Complete all 9 moon shrines"},
	"gate_crasher": {"name": "Gate Crasher", "desc": "Travel through your first gate"},
}

const SLOT_INDEX_PATH: String = "user://save_index.json"

var noise: FastNoiseLite = FastNoiseLite.new()
var world_seed: int = 12345
var height_values: PackedFloat32Array = PackedFloat32Array()
var generated_root: Node3D
var menu_layer: CanvasLayer
var dev_menu_layer: CanvasLayer
var dev_menu_selected_world: String = ""
var hud_layer: CanvasLayer
var hud_label: Label
var stamina_bar: ProgressBar
var breath_bar: ProgressBar
var minimap_panel: PanelContainer
var atlas_layer: CanvasLayer
var show_atlas: bool = false
var show_hud: bool = true
var minimap_marker_layer: Control
var underwater_layer: CanvasLayer
var underwater_overlay: ColorRect
var world_environment: Environment
var sun_light: DirectionalLight3D
var save_data: Dictionary = {}
var current_world_id: String = ""
var current_map_id: String = ""
var is_underwater: bool = false
var last_discovery_text: String = ""
var current_map_available_discoveries: int = 0
var moon_map_return_map_id: String = ""
var graphics_level: int = 0
var density_level: int = 2
var lichen_count: int = 0
var current_slot: int = 0
var slot_count: int = 0
var tree_materials: Dictionary = {}
var show_fps: bool = false
var fps_label: Label
var _moon_grid_scale: int = 1
var _cycle_time: float = 0.0
var cycle_speed_multiplier: float = 1.0
const CYCLE_HOURS_PER_SECOND: float = 1.0
const CYCLE_LENGTH: float = 24.0 / CYCLE_HOURS_PER_SECOND


func _ready() -> void:
	print("Random World Explorer v6: starting")

	call_deferred("_configure_fullscreen")

	var preview := get_node_or_null("EditorPreviewGround")
	if preview != null:
		preview.queue_free()

	_setup_environment()
	_setup_hud()
	_setup_underwater_overlay()
	randomize()
	_load_slot_index()
	_load_save_data()
	_apply_graphics_level()
	_ensure_default_world()
	var last_world_id: String = str(save_data.get("last_world_id", ""))
	if last_world_id != "":
		_load_world_from_menu(last_world_id)
	_show_main_menu()

	print("Random World Explorer v6: slot ", current_slot, " saved to ", _slot_path(current_slot))
	print("Random World Explorer v6: press F11 to toggle fullscreen")
	print("Random World Explorer v6: press F10 to force 1280x720 windowed mode")


func _process(_delta: float) -> void:
	if not _is_current_map_gate_room() and not _is_current_map_cave() and not _is_current_map_map_nexus():
		_cycle_time += _delta * cycle_speed_multiplier
		if _cycle_time >= CYCLE_LENGTH:
			_cycle_time = fmod(_cycle_time, CYCLE_LENGTH)
		_update_day_night_cycle()
	_update_underwater_state()
	_recover_fallen_player()
	_update_hud()


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
			if fps_label != null:
				fps_label.visible = show_fps

		if event.keycode == KEY_M:
			if menu_layer != null:
				_close_menu()
			else:
				_show_main_menu()

		if event.keycode == KEY_G:
			if Input.is_key_pressed(KEY_SHIFT):
				_return_to_gate_room()
			else:
				if atlas_layer != null and atlas_layer.visible:
					atlas_layer.visible = false
					show_atlas = false
				else:
					show_atlas = true
					_refresh_atlas_graph()
					if atlas_layer != null:
						atlas_layer.visible = true

		if event.keycode == KEY_H:
			show_hud = not show_hud
			if hud_layer != null:
				hud_layer.visible = show_hud

		if event.keycode == KEY_C:
			_try_grab_lichen()

		if event.keycode == KEY_T:
			_throw_lichen()

		if event.keycode == KEY_S and event.shift_pressed:
			_show_secret_login()


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
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				save_data = parsed

	if not save_data.has("worlds"):
		save_data = {"worlds": {}, "last_world_id": ""}
	cycle_speed_multiplier = float(save_data.get("cycle_speed_multiplier", 1.0))
	graphics_level = int(save_data.get("graphics_level", 0))
	density_level = int(save_data.get("density_level", 2))
	lichen_count = int(save_data.get("lichen_count", 0))


func _save_world_data() -> void:
	save_data["lichen_count"] = lichen_count
	save_data["density_level"] = density_level
	save_data["cycle_speed_multiplier"] = cycle_speed_multiplier
	var path: String = _slot_path(current_slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing: " + path)
		return

	file.store_string(JSON.stringify(save_data, "\t"))


func _ensure_default_world() -> void:
	var worlds: Dictionary = save_data.get("worlds", {})
	if not worlds.is_empty():
		return

	var world_id: String = _new_id("world")
	var root_map_id: String = _new_id("map")
	worlds[world_id] = _create_world_record("Default World", root_map_id, randi())
	save_data["worlds"] = worlds
	save_data["last_world_id"] = world_id
	_save_world_data()


func _apply_detail_counts() -> void:
	var gmult: float = 1.0
	if graphics_level == 1:
		gmult = 1.5
	elif graphics_level == 2:
		gmult = 2.5
	elif graphics_level == 3:
		gmult = 4.0

	var dmult: float = 1.0
	match density_level:
		0: dmult = 0.4
		1: dmult = 0.7
		2: dmult = 1.0

	var mult: float = gmult * dmult
	TREE_COUNT = int(720.0 * mult)
	ROCK_COUNT = int(260.0 * mult)
	FLOWER_COUNT = int(520.0 * mult)
	CRYSTAL_COUNT = int(42.0 * mult)
	RUIN_COUNT = int(14.0 * mult)


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
		1:
			get_viewport().msaa_3d = Viewport.MSAA_2X
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			get_viewport().use_taa = false
			if world_environment != null:
				world_environment.glow_enabled = true
				world_environment.glow_intensity = 0.6
				world_environment.glow_strength = 0.8
				world_environment.ssao_enabled = false
				world_environment.ssil_enabled = false
				world_environment.ssr_enabled = false
		2:
			get_viewport().msaa_3d = Viewport.MSAA_4X
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
			get_viewport().use_taa = false
			if world_environment != null:
				world_environment.glow_enabled = true
				world_environment.glow_intensity = 0.8
				world_environment.glow_strength = 1.0
				world_environment.ssao_enabled = true
				world_environment.ssao_radius = 0.75
				world_environment.ssao_intensity = 1.4
				world_environment.ssil_enabled = true
				world_environment.ssil_radius = 1.5
				world_environment.ssil_intensity = 0.8
				world_environment.ssr_enabled = true
		3:
			get_viewport().msaa_3d = Viewport.MSAA_8X
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			get_viewport().use_taa = true
			if world_environment != null:
				world_environment.glow_enabled = true
				world_environment.glow_intensity = 1.0
				world_environment.glow_strength = 1.2
				world_environment.ssao_enabled = true
				world_environment.ssao_radius = 1.0
				world_environment.ssao_intensity = 1.6
				world_environment.ssil_enabled = true
				world_environment.ssil_radius = 2.0
				world_environment.ssil_intensity = 1.0
				world_environment.ssr_enabled = true


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
	save_data["graphics_level"] = level
	_save_world_data()
	_apply_graphics_level()
	if current_world_id != "" and current_map_id != "":
		_load_map(current_world_id, current_map_id)
	else:
		_show_main_menu()


func _set_density_level(level: int) -> void:
	density_level = level
	save_data["density_level"] = level
	_save_world_data()
	if current_world_id != "" and current_map_id != "":
		_load_map(current_world_id, current_map_id)
	else:
		_show_main_menu()


func _on_time_speed_changed(value: float) -> void:
	cycle_speed_multiplier = value
	_update_time_speed_label()


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

	var world_header := Label.new()
	world_header.text = "Worlds:"
	world_header.add_theme_font_size_override("font_size", 13)
	list.add_child(world_header)

	var world_list := VBoxContainer.new()
	world_list.add_theme_constant_override("separation", 4)
	list.add_child(world_list)

	var worlds: Dictionary = save_data.get("worlds", {})
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

	var new_world_btn := Button.new()
	new_world_btn.text = "New World"
	new_world_btn.pressed.connect(_start_new_game)
	world_list.add_child(new_world_btn)

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
	time_slider.min_value = 0.01
	time_slider.max_value = 2.0
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
	var saved_achs: Dictionary = save_data.get("achievements", {})
	for ak in ACHIEVEMENT_DEFS.keys():
		if saved_achs.has(ak):
			ach_earned += 1
	var ach_btn := Button.new()
	ach_btn.text = "Achievements (" + str(ach_earned) + "/" + str(ACHIEVEMENT_DEFS.size()) + ")"
	ach_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_btn.pressed.connect(_show_achievements_dialog)
	ach_row.add_child(ach_btn)

	var hint := Label.new()
	hint.text = "Objective: restore the Atlas by finding wonders and gates.\nM: menu | G: atlas graph | H: HUD | F10: windowed | F11: fullscreen"
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

	var earned_achs: Dictionary = save_data.get("achievements", {})
	for akey in ACHIEVEMENT_DEFS.keys():
		var def: Dictionary = ACHIEVEMENT_DEFS[akey]
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


func _show_secret_login() -> void:
	if dev_menu_layer != null:
		_close_dev_menu()
		return
	_close_menu()

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
	ok_btn.pressed.connect(_on_dev_login_attempt.bind(line_edit))
	button_row.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_close_dev_menu)
	button_row.add_child(cancel_btn)

	line_edit.text_submitted.connect(_on_dev_login_attempt.bind(line_edit))
	line_edit.grab_focus()


func _clear_dev_menu() -> void:
	if dev_menu_layer == null:
		return
	for child in dev_menu_layer.get_children():
		dev_menu_layer.remove_child(child)
		child.queue_free()


func _on_dev_login_attempt(line_edit: LineEdit) -> void:
	if line_edit.text == "1215":
		_show_secret_menu()
	else:
		line_edit.text = ""
		line_edit.placeholder_text = "wrong password"


func _close_dev_menu() -> void:
	if dev_menu_layer != null:
		dev_menu_layer.queue_free()
		dev_menu_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_secret_menu() -> void:
	_clear_dev_menu()

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

	var worlds: Dictionary = save_data.get("worlds", {})
	dev_menu_selected_world = current_world_id if current_world_id != "" else ""
	if dev_menu_selected_world == "" and not worlds.is_empty():
		dev_menu_selected_world = str(worlds.keys()[0])

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
		var is_current: bool = wid == dev_menu_selected_world
		btn.text = ("> " if is_current else "  ") + str(w.get("name", wid))
		btn.flat = not is_current
		btn.pressed.connect(_on_dev_world_selected.bind(wid))
		btn.add_theme_font_size_override("font_size", 11)
		worlds_list.add_child(btn)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_vbox.custom_minimum_size = Vector2(380.0, 0.0)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_vbox)

	_populate_dev_menu_right(right_vbox)

	var close_row := HBoxContainer.new()
	close_row.alignment = 1
	menu_vbox.add_child(close_row)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_dev_menu)
	close_row.add_child(close_btn)


func _on_dev_world_selected(wid: String) -> void:
	dev_menu_selected_world = wid
	_show_secret_menu()


func _populate_dev_menu_right(vbox: VBoxContainer) -> void:
	if dev_menu_selected_world == "":
		var no_world := Label.new()
		no_world.text = "No world selected"
		no_world.add_theme_font_size_override("font_size", 14)
		vbox.add_child(no_world)
		return

	var world: Dictionary = _get_world(dev_menu_selected_world)
	var maps: Dictionary = world.get("maps", {})
	var world_name: String = str(world.get("name", dev_menu_selected_world))

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
		var is_current: bool = current_world_id == dev_menu_selected_world and current_map_id == mid
		map_label.text = ("> " if is_current else "  ") + mid + "  [" + map_type + "]"
		map_label.add_theme_font_size_override("font_size", 10)
		map_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(map_label)

		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.pressed.connect(_on_dev_load_map.bind(dev_menu_selected_world, mid))
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
		{"id": "moon", "label": "Go to Moon"},
		{"id": "gate_room", "label": "Go to Gate Room"},
		{"id": "map_nexus", "label": "Go to Map Nexus"},
	]

	for qa in quick_data:
		var btn := Button.new()
		btn.text = qa["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_dev_quick_map.bind(qa["id"], dev_menu_selected_world))
		actions_grid.add_child(btn)


func _on_dev_load_map(world_id: String, map_id: String) -> void:
	_close_dev_menu()
	_load_map(world_id, map_id)


func _on_dev_quick_map(map_type: String, world_id: String) -> void:
	_close_dev_menu()
	var world: Dictionary = _get_world(world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_id: String = ""
	var map_record: Dictionary = {}

	match map_type:
		"moon":
			if maps.has("moon"):
				map_id = "moon"
			else:
				var seed_val: int = _moon_seed(world)
				maps["moon"] = _create_moon_map_record(seed_val)
				map_id = "moon"
		"gate_room":
			if maps.has("gate_room"):
				map_id = "gate_room"
			else:
				var gate_seed: int = int((world_seed ^ 0x47415445) & 0x7fffffff)
				if gate_seed == 0:
					gate_seed = 98765
				maps["gate_room"] = _create_gate_room_map_record(gate_seed)
				map_id = "gate_room"
		"map_nexus":
			if maps.has("map_nexus"):
				map_id = "map_nexus"
			else:
				var nex_seed: int = int((world_seed ^ 0x4E455855) & 0x7fffffff)
				if nex_seed == 0:
					nex_seed = 54321
				maps["map_nexus"] = _create_map_nexus_map_record(nex_seed)
				map_id = "map_nexus"
		"normal", "water", "cave":
			map_id = _new_id("map")
			var seed_val: int = randi()
			match map_type:
				"normal": maps[map_id] = _create_map_record(seed_val)
				"water": maps[map_id] = _create_water_map_record(seed_val)
				"cave": maps[map_id] = _create_cave_map_record(seed_val)

	if map_id == "":
		return

	world["maps"] = maps
	_set_world(world_id, world)
	_save_world_data()
	_load_map(world_id, map_id)


func _create_new_world(name_input: LineEdit) -> void:
	var world_id: String = _new_id("world")
	var root_map_id: String = _new_id("map")
	var raw: String = name_input.text.strip_edges()
	var world_name: String = raw if raw != "" else "World " + str(save_data.get("worlds", {}).size() + 1)

	var worlds: Dictionary = save_data.get("worlds", {})
	worlds[world_id] = _create_world_record(world_name, root_map_id, randi())
	save_data["worlds"] = worlds
	save_data["last_world_id"] = world_id
	_save_world_data()
	_load_map(world_id, root_map_id)


func _load_world_from_menu(world_id: String) -> void:
	var world: Dictionary = _get_world(world_id)
	if world.is_empty():
		return

	var map_id: String = str(world.get("current_map", world.get("root_map", "")))
	if map_id == "":
		return

	_load_map(world_id, map_id)


func _start_new_game() -> void:
	_close_menu()
	save_data = {"worlds": {}, "last_world_id": "", "cycle_speed_multiplier": cycle_speed_multiplier, "graphics_level": graphics_level, "density_level": density_level}
	var world_id: String = _new_id("world")
	var root_map_id: String = _new_id("map")
	var worlds: Dictionary = {}
	worlds[world_id] = _create_world_record("Default World", root_map_id, randi())
	save_data["worlds"] = worlds
	save_data["last_world_id"] = world_id
	_save_world_data()
	_load_map(world_id, root_map_id)


func _create_new_slot() -> void:
	_close_menu()
	_save_world_data()
	slot_count += 1
	current_slot = slot_count - 1
	_save_slot_index()
	save_data = {"worlds": {}, "last_world_id": "", "cycle_speed_multiplier": cycle_speed_multiplier, "graphics_level": graphics_level, "density_level": density_level}
	var world_id: String = _new_id("world")
	var root_map_id: String = _new_id("map")
	var worlds: Dictionary = {}
	worlds[world_id] = _create_world_record("Slot " + str(current_slot + 1), root_map_id, randi())
	save_data["worlds"] = worlds
	save_data["last_world_id"] = world_id
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
	var last_world_id: String = str(save_data.get("last_world_id", ""))
	if last_world_id != "":
		_load_world_from_menu(last_world_id)
	else:
		_ensure_default_world()
		_load_world_from_menu(str(save_data.get("last_world_id", "")))


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


func _create_map_record(map_seed: int) -> Dictionary:
	return {"seed": map_seed, "gates": {}, "discoveries": {}, "type": "normal"}


func _create_moon_map_record(map_seed: int) -> Dictionary:
	return {"seed": map_seed, "gates": {}, "discoveries": {}, "type": "moon"}


func _create_water_map_record(map_seed: int) -> Dictionary:
	return {"seed": map_seed, "gates": {}, "discoveries": {}, "type": "water"}


func _create_gate_room_map_record(map_seed: int) -> Dictionary:
	return {"seed": map_seed, "gates": {}, "discoveries": {}, "type": "gate_room", "gate_room_slots": {}}


func _create_cave_map_record(map_seed: int) -> Dictionary:
	return {"seed": map_seed, "gates": {}, "discoveries": {}, "type": "cave"}


func _create_map_nexus_map_record(map_seed: int) -> Dictionary:
	return {"seed": map_seed, "gates": {}, "discoveries": {}, "type": "map_nexus", "nexus_slots": {}}


func _create_world_record(world_name: String, root_map_id: String, map_seed: int) -> Dictionary:
	return {
		"name": world_name,
		"root_map": root_map_id,
		"current_map": root_map_id,
		"maps": {
			root_map_id: _create_map_record(map_seed)
		}
	}


func _new_id(prefix: String) -> String:
	return prefix + "_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())


func _get_world(world_id: String) -> Dictionary:
	var worlds: Dictionary = save_data.get("worlds", {})
	return worlds.get(world_id, {})


func _set_world(world_id: String, world: Dictionary) -> void:
	var worlds: Dictionary = save_data.get("worlds", {})
	worlds[world_id] = world
	save_data["worlds"] = worlds


func _backstory_text() -> String:
	return "The Atlas of Gates once held every world together, but it shattered during the Convergence Collapse. Fragments of reality drifted apart, each sealed behind a dormant gate.\n\nYou are the last field cartographer of the Celestial Survey, dispatched from the floating observatory to cross the gates, map the splintered territories, and reassemble the Atlas one discovery at a time.\n\nOn the far side of certain gates lies the Moon — a silent world of glass craters and drifting lichen, where ancient shrines float in the void. Pilgrims who reach them all earn the title Moon Pilgrim.\n\nThe Survey's old handbooks speak of a limit: no more than thirty-two maps can be opened from a single world before the local gate-network saturates. Choose your path wisely."


func _atlas_summary_text() -> String:
	var worlds: Dictionary = save_data.get("worlds", {})
	var world_count: int = worlds.size()
	var map_count: int = 0
	var discovery_count: int = 0
	for world_key in worlds.keys():
		var world: Dictionary = worlds[world_key]
		var maps: Dictionary = world.get("maps", {})
		map_count += maps.size()
		for map_key in maps.keys():
			var map_record: Dictionary = maps[map_key]
			var discoveries: Dictionary = map_record.get("discoveries", {})
			discovery_count += discoveries.size()

	var current_completion: String = ""
	if current_map_id != "":
		current_completion = " Current map: " + _map_completion_text(current_map_id) + "."

	return "Atlas: " + str(world_count) + " worlds, " + str(map_count) + " maps, " + str(discovery_count) + " discoveries." + current_completion


func _store_current_map_available_discoveries() -> void:
	if current_world_id == "" or current_map_id == "":
		return

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	map_record["available_discoveries"] = current_map_available_discoveries
	maps[current_map_id] = map_record
	world["maps"] = maps
	_set_world(current_world_id, world)
	_save_world_data()


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


func _atlas_graph_text() -> String:
	var worlds: Dictionary = save_data.get("worlds", {})
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
			var gates: Dictionary = map_record.get("gates", {})
			var marker: String = ""
			if world_id == current_world_id and map_id == current_map_id:
				marker = " <- current"

			lines.append("  " + _short_id(map_id) + marker + " | discoveries " + str(discoveries.size()) + " | gates " + str(gates.size()) + "/" + str(GATE_COUNT))
			for gate_key in gates.keys():
				var target_map_id: String = str(gates[gate_key])
				lines.append("    gate " + str(int(str(gate_key)) + 1) + " -> " + _short_id(target_map_id))

		lines.append("")

	return "\n".join(lines)


func _refresh_atlas_graph() -> void:
	if atlas_layer != null:
		atlas_layer.queue_free()

	atlas_layer = CanvasLayer.new()
	atlas_layer.name = "AtlasLayer"
	atlas_layer.layer = 25
	add_child(atlas_layer)

	var overlay := ColorRect.new()
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	atlas_layer.add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -370.0
	panel.offset_top = -150.0
	panel.offset_right = 370.0
	panel.offset_bottom = 150.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.07, 0.98)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	atlas_layer.add_child(panel)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.anchors_preset = Control.PRESET_FULL_RECT
	panel.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 260)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	container.add_child(viewport)

	var world_3d := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.008, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.16, 0.22)
	world_3d.environment = env
	viewport.world_3d = world_3d

	var root := Node3D.new()
	viewport.add_child(root)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 17.0, 25.0)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.current = true
	root.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	light.light_energy = 2.2
	root.add_child(light)

	_build_atlas_graph_3d(root)

	atlas_layer.visible = false


func _build_atlas_graph_3d(root: Node3D) -> void:
	var world: Dictionary = _get_world(current_world_id)
	if world.is_empty():
		return

	var maps: Dictionary = world.get("maps", {})
	if maps.is_empty():
		return

	var map_ids: Array[String] = []
	for map_key in maps.keys():
		map_ids.append(str(map_key))
	map_ids.sort()

	var positions: Dictionary = {}
	var gate_positions: Dictionary = {}
	var radius: float = 7.0 + float(map_ids.size()) * 0.45
	for i in range(map_ids.size()):
		var angle: float = TAU * float(i) / float(max(map_ids.size(), 1))
		positions[map_ids[i]] = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		for gate_index in range(GATE_COUNT):
			gate_positions[_gate_graph_key(map_ids[i], gate_index)] = positions[map_ids[i]] + _atlas_gate_offset(gate_index)

	var drawn_links: Dictionary = {}
	for map_id in map_ids:
		var map_record: Dictionary = maps[map_id]
		var gates: Dictionary = map_record.get("gates", {})
		for gate_key in gates.keys():
			var gate_index: int = int(str(gate_key))
			var target_id: String = str(gates[gate_key])
			if not positions.has(target_id):
				continue
			var link_key: String = map_id + ":" + str(gate_index) + "->" + target_id
			var reverse_key: String = target_id + ":" + str(_opposite_gate_index(gate_index)) + "->" + map_id
			if drawn_links.has(link_key) or drawn_links.has(reverse_key):
				continue
			drawn_links[link_key] = true
			var target_record: Dictionary = maps[target_id]
			var start_pos: Vector3 = gate_positions[_gate_graph_key(map_id, gate_index)]
			var end_pos: Vector3 = gate_positions[_gate_graph_key(target_id, _opposite_gate_index(gate_index))]
			_add_atlas_link(root, start_pos, end_pos, _seed_color(int(target_record.get("seed", 0))))

	for map_id in map_ids:
		var map_record: Dictionary = maps[map_id]
		var discoveries: Dictionary = map_record.get("discoveries", {})
		var available: int = int(map_record.get("available_discoveries", 0))
		var pos: Vector3 = positions[map_id]

		for gate_index in range(GATE_COUNT):
			var gate_pos: Vector3 = gate_positions[_gate_graph_key(map_id, gate_index)]
			var gate_marker := MeshInstance3D.new()
			gate_marker.name = "AtlasGatePoint"
			var gate_mesh := SphereMesh.new()
			gate_mesh.radius = 0.22 if map_id == current_map_id else 0.17
			gate_mesh.height = gate_mesh.radius * 2.0
			gate_marker.mesh = gate_mesh
			gate_marker.position = gate_pos
			var gate_mat := StandardMaterial3D.new()
			gate_mat.albedo_color = _atlas_gate_color(map_record, maps, gate_index)
			if map_id == current_map_id and gate_mat.albedo_color == Color(0.25, 0.28, 0.32):
				gate_mat.albedo_color = Color(1.0, 0.82, 0.28)
			gate_mat.emission_enabled = true
			gate_mat.emission = gate_mat.albedo_color * (1.0 if map_id == current_map_id else 0.6)
			gate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gate_marker.material_override = gate_mat
			root.add_child(gate_marker)

		var label := Label3D.new()
		label.text = ("current\n" if map_id == current_map_id else "map\n") + _completion_text(discoveries.size(), available)
		label.position = pos + Vector3(0.0, -1.45, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 24
		label.modulate = Color(1.0, 0.86, 0.35) if map_id == current_map_id else Color(0.72, 0.80, 0.88)
		root.add_child(label)


func _gate_graph_key(map_id: String, gate_index: int) -> String:
	return map_id + ":" + str(gate_index)


func _atlas_gate_offset(gate_index: int) -> Vector3:
	if gate_index == 0:
		return Vector3(1.0, 0.0, 0.0)
	if gate_index == 1:
		return Vector3(-1.0, 0.0, 0.0)
	if gate_index == 2:
		return Vector3(0.0, 0.0, 1.0)
	return Vector3(0.0, 0.0, -1.0)


func _atlas_gate_color(map_record: Dictionary, maps: Dictionary, gate_index: int) -> Color:
	var gates: Dictionary = map_record.get("gates", {})
	var target_id: String = str(gates.get(str(gate_index), ""))
	if target_id != "" and maps.has(target_id):
		var target_record: Dictionary = maps[target_id]
		return _seed_color(int(target_record.get("seed", 0)))

	return Color(0.25, 0.28, 0.32)


func _add_atlas_link(root: Node3D, start_pos: Vector3, end_pos: Vector3, color: Color) -> void:
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	line_mesh.surface_add_vertex(start_pos)
	line_mesh.surface_add_vertex(end_pos)
	line_mesh.surface_end()

	var line_instance := MeshInstance3D.new()
	line_instance.name = "AtlasGateLink"
	line_instance.mesh = line_mesh
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = color
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.emission_enabled = true
	line_mat.emission = color * 0.75
	line_instance.material_override = line_mat
	root.add_child(line_instance)


func _completion_text(found: int, available: int) -> String:
	if available <= 0:
		return str(found) + " found"
	var percent: int = int(round(float(found) / float(available) * 100.0))
	return str(percent) + "% " + str(found) + "/" + str(available)


func _short_id(value: String) -> String:
	if value.length() <= 12:
		return value
	return value.substr(0, 12)


func _current_map_discovery_count() -> int:
	if current_world_id == "" or current_map_id == "":
		return 0

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	return discoveries.size()


func _current_world_map_count() -> int:
	if current_world_id == "":
		return 0
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	return maps.size()


func _is_current_map_moon() -> bool:
	if current_world_id == "" or current_map_id == "":
		return false

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	return str(map_record.get("type", "normal")) == "moon"


func _is_current_map_water() -> bool:
	if current_world_id == "" or current_map_id == "":
		return false

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	return str(map_record.get("type", "normal")) == "water"


func _is_current_map_cave() -> bool:
	if current_world_id == "" or current_map_id == "":
		return false
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	return str(map_record.get("type", "normal")) == "cave"


func _is_current_map_map_nexus() -> bool:
	if current_world_id == "" or current_map_id == "":
		return false
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	return str(map_record.get("type", "normal")) == "map_nexus"


func _is_current_map_gate_room() -> bool:
	if current_world_id == "" or current_map_id == "":
		return false

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	return str(map_record.get("type", "normal")) == "gate_room"


func _record_discovery(discovery_id: String, title: String, kind: String, discovery_position: Vector3) -> void:
	if current_world_id == "" or current_map_id == "":
		return

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	if discoveries.has(discovery_id):
		return

	discoveries[discovery_id] = {
		"title": title,
		"kind": kind,
		"found_at": Time.get_unix_time_from_system(),
		"x": discovery_position.x,
		"z": discovery_position.z
	}
	map_record["discoveries"] = discoveries
	maps[current_map_id] = map_record
	world["maps"] = maps
	_set_world(current_world_id, world)
	_save_world_data()
	last_discovery_text = "New discovery: " + title
	print("Atlas discovery: ", title, " [", kind, "]")
	if kind == "wonder":
		_award_achievement("first_wonder")
		_check_map_wonders_complete()
		_check_world_wonders_complete()
	if kind == "orb":
		_check_moon_shrine_completion()


func _on_discovery_body_entered(body: Node3D, discovery_id: String, title: String, kind: String, discovery_position: Vector3) -> void:
	if body.name == "Player":
		_record_discovery(discovery_id, title, kind, discovery_position)


func _award_achievement(id: String) -> void:
	var achievements: Dictionary = save_data.get("achievements", {})
	if achievements.has(id):
		return
	achievements[id] = Time.get_unix_time_from_system()
	save_data["achievements"] = achievements
	_save_world_data()
	var def: Dictionary = ACHIEVEMENT_DEFS.get(id, {})
	var name: String = def.get("name", id)
	last_discovery_text = "Achievement: " + name + "!"
	print("Achievement unlocked: ", name)


func _check_map_wonders_complete() -> void:
	if current_world_id == "" or current_map_id == "":
		return
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var wonder_count: int = int(map_record.get("wonder_count", 0))
	if wonder_count <= 0:
		return
	var discoveries: Dictionary = map_record.get("discoveries", {})
	var wonder_found := 0
	for key in discoveries.keys():
		if discoveries[key].get("kind", "") == "wonder":
			wonder_found += 1
	if wonder_found >= wonder_count:
		_award_achievement("all_wonders_map")


func _check_world_wonders_complete() -> void:
	if current_world_id == "":
		return
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var total_wonders := 0
	var total_found := 0
	for map_key in maps.keys():
		var mr: Dictionary = maps[map_key]
		total_wonders += int(mr.get("wonder_count", 0))
		var disc: Dictionary = mr.get("discoveries", {})
		for dk in disc.keys():
			if disc[dk].get("kind", "") == "wonder":
				total_found += 1
	if total_wonders > 0 and total_found >= total_wonders:
		_award_achievement("all_wonders_world")


func _check_map_visit_achievements() -> void:
	var visited: Array = save_data.get("maps_visited", [])
	if current_map_id != "" and not visited.has(current_map_id):
		visited.append(current_map_id)
		save_data["maps_visited"] = visited
		_save_world_data()
	if visited.size() >= 5:
		_award_achievement("world_traveler")


func _load_map(world_id: String, map_id: String) -> void:
	_close_menu()
	current_world_id = world_id
	current_map_id = map_id

	var world: Dictionary = _get_world(world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(map_id, {})
	if map_record.is_empty():
		push_error("Missing map record: " + map_id)
		return

	world["current_map"] = map_id
	_set_world(world_id, world)
	save_data["last_world_id"] = world_id
	_save_world_data()

	world_seed = int(map_record.get("seed", 12345))
	seed(world_seed)
	current_map_available_discoveries = 0
	_moon_grid_scale = 1
	if _is_current_map_moon():
		_moon_grid_scale = 2
	_clear_generated_map()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedMap"
	add_child(generated_root)
	_apply_map_atmosphere()
	_setup_music()
	_create_visible_sun()

	if _is_current_map_gate_room():
		_create_gate_room_terrain()
		_create_world_bounds()
		_spawn_player()
		_scatter_gate_room_gates()
	elif _is_current_map_cave():
		_create_cave_terrain()
		_create_world_bounds()
		_spawn_player()
		_scatter_cave_items()
	elif _is_current_map_map_nexus():
		_create_map_nexus_terrain()
		_create_world_bounds()
		_spawn_player()
		_scatter_map_nexus_gates()
	else:
		_apply_detail_counts()
		_setup_noise()
		_build_height_values()
		_create_terrain_mesh()
		_create_terrain_collision()
		_create_world_bounds()
		if not _is_current_map_moon():
			_create_water()
			_setup_water_audio()
			_create_sky_clouds()
		else:
			_create_moon_sky()
			_setup_moon_audio()
		_spawn_player()
		if _is_current_map_moon():
			_scatter_moon_lichen()
			_scatter_moon_glass_craters()
			_scatter_moon_platforms()
		elif _is_current_map_water():
			_scatter_rocks()
			_scatter_crystals()
			_scatter_ruins()
			_scatter_bird_flocks()
			_scatter_underwater_plants()
			_scatter_fish_schools()
		else:
			_scatter_trees()
			_scatter_rocks()
			_scatter_flowers()
			_spawn_wonders()
			_scatter_crystals()
			_scatter_ruins()
			_scatter_bird_flocks()
			_scatter_underwater_plants()
			_scatter_fish_schools()
		_create_gates()
	_store_current_map_available_discoveries()

	_check_map_visit_achievements()
	if _is_current_map_moon():
		_award_achievement("moon_visitor")
	if _is_current_map_gate_room():
		_award_achievement("gate_room_finder")
	if _is_current_map_water():
		_award_achievement("island_hopper")
	if _is_current_map_cave():
		_award_achievement("cavern_explorer")

	print("Random World Explorer v6: loaded map ", map_id, " with seed ", world_seed)


func _clear_generated_map() -> void:
	if generated_root != null:
		generated_root.queue_free()
		generated_root = null


func _add_generated_child(node: Node) -> void:
	if generated_root != null:
		generated_root.add_child(node)
	else:
		add_child(node)


func _setup_noise() -> void:
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.020
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 1.9
	noise.fractal_gain = 0.45


func _setup_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 3.0
	sun_light = sun
	add_child(sun)

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.78, 0.86)
	env.ambient_light_energy = 0.8
	world_environment = env

	env_node.environment = env
	add_child(env_node)


func _apply_map_atmosphere() -> void:
	if world_environment == null:
		return

	if minimap_panel != null:
		var moon_size: float = 100.0
		var normal_size: float = 80.0
		minimap_panel.custom_minimum_size = Vector2(moon_size if _is_current_map_moon() else normal_size, moon_size if _is_current_map_moon() else normal_size)
		minimap_marker_layer.custom_minimum_size = minimap_panel.custom_minimum_size

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
		world_environment.background_color = Color(0.004, 0.006, 0.012)
		world_environment.ambient_light_color = Color(0.30, 0.22, 0.45)
		world_environment.ambient_light_energy = 0.55
		world_environment.fog_density = 0.002
		world_environment.fog_light_color = Color(0.25, 0.18, 0.40)
		if sun_light != null:
			if _is_current_map_map_nexus():
				sun_light.light_color = Color(0.70, 0.60, 1.0)
				sun_light.light_energy = 1.8
			else:
				sun_light.light_color = Color(0.60, 0.50, 0.90)
				sun_light.light_energy = 1.2
			sun_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	elif _is_current_map_moon():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.006, 0.008, 0.020)
		world_environment.ambient_light_color = Color(0.20, 0.24, 0.34)
		world_environment.ambient_light_energy = 0.38
		world_environment.fog_density = 0.0
		world_environment.fog_light_color = Color(0.18, 0.22, 0.34)
		if sun_light != null:
			sun_light.light_color = Color(0.78, 0.86, 1.0)
			sun_light.light_energy = 1.45
			sun_light.rotation_degrees = Vector3(-28.0, -62.0, 0.0)
	elif _is_current_map_water():
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.45, 0.65, 0.88)
		world_environment.ambient_light_color = Color(0.55, 0.70, 0.82)
		world_environment.ambient_light_energy = 0.75
		world_environment.fog_density = 0.002
		world_environment.fog_light_color = Color(0.50, 0.68, 0.82)
		if sun_light != null:
			sun_light.light_color = _sun_color_for_world()
			sun_light.light_energy = 2.6
			sun_light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	else:
		world_environment.background_mode = Environment.BG_COLOR
		world_environment.background_color = Color(0.55, 0.72, 0.95)
		world_environment.ambient_light_color = Color(0.7, 0.78, 0.86)
		world_environment.ambient_light_energy = 0.8
		world_environment.fog_density = 0.002
		world_environment.fog_light_color = Color(0.65, 0.75, 0.85)
		if sun_light != null:
			sun_light.light_color = _sun_color_for_world()
			sun_light.light_energy = 3.0
			sun_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)


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


func _update_day_night_cycle() -> void:
	if sun_light == null or world_environment == null:
		return
	if _is_current_map_moon() or _is_current_map_water():
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
		if hour >= 21.5:
			is_night = true

	sun_elevation = clamp(sun_elevation, -1.0, 1.0)
	sun_light.rotation_degrees.x = lerp(-90.0, 90.0, (sun_elevation + 1.0) * 0.5)

	var sun_base: Color = _sun_color_for_world()

	if is_night and not is_dawn:
		sun_light.light_energy = 0.08
		world_environment.ambient_light_energy = 0.08
		world_environment.ambient_light_color = Color(0.04, 0.04, 0.08)
		world_environment.fog_density = 0.002
		world_environment.fog_light_color = Color(0.01, 0.01, 0.02)
		_set_sky_cycle_colors(Color(0.005, 0.005, 0.02), Color(0.02, 0.02, 0.06), Color(0.01, 0.01, 0.02))
		sun_light.light_color = Color(0.15, 0.18, 0.35)
	elif is_dawn:
		var p: float = 0.0
		if hour >= 5.5 and hour < 6.0:
			p = (hour - 5.5) / 0.5
		elif hour >= 6.0 and hour < 7.0:
			p = 0.5 + (hour - 6.0) * 0.5
		else:
			p = 1.0 if hour >= 7.0 else 0.0
		p = clamp(p, 0.0, 1.0)
		sun_light.light_energy = lerp(0.08, 2.8, p)
		world_environment.ambient_light_energy = lerp(0.08, 0.65, p)
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
		sun_light.light_energy = lerp(3.0, 0.12, p)
		world_environment.ambient_light_energy = lerp(0.72, 0.08, p)
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


func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 10
	add_child(hud_layer)

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


func _update_hud() -> void:
	if hud_label == null:
		return

	var map_short: String = "none"
	if current_map_id.length() > 8:
		map_short = current_map_id.substr(0, 8)
	elif current_map_id != "":
		map_short = current_map_id

	var player: CharacterBody3D = _get_player()
	var position_text: String = "No active player"
	var warning_text: String = ""
	if player != null:
		var half: float = _world_half_size()
		var distance_to_edge: float = half - max(abs(player.global_position.x), abs(player.global_position.z))
		position_text = "Position: " + str(int(player.global_position.x)) + ", " + str(int(player.global_position.z)) + " | edge " + str(max(int(distance_to_edge), 0)) + "m"
		if is_underwater:
			warning_text = "Underwater: Space swims upward"
		elif distance_to_edge < 18.0:
			warning_text = "Edge barrier nearby"

		if stamina_bar != null and player.get("sprint_stamina") != null:
			stamina_bar.value = float(player.get("sprint_stamina"))
		if breath_bar != null and player.get("breath") != null:
			var p_breath: float = float(player.get("breath"))
			breath_bar.value = p_breath
			breath_bar.visible = p_breath < 60.0

	var flashlight_text: String = ""
	if player != null and player.get("flashlight_on") != null:
		var f_on: bool = bool(player.get("flashlight_on"))
		if f_on:
			var f_charge: float = float(player.get("flashlight_charge"))
			flashlight_text = "Flashlight: " + str(int(f_charge)) + "s"
		else:
			flashlight_text = "[F] Flashlight"

	var world_name: String = "?"
	if current_world_id != "":
		var w: Dictionary = _get_world(current_world_id)
		world_name = str(w.get("name", current_world_id))

	var discovery_line: String = last_discovery_text
	if discovery_line == "":
		discovery_line = "Seek gates, ruins, and wonders."

	var world_map_count: int = _current_world_map_count()
	var maps_line: String = "Maps in world: " + str(world_map_count)

	if _is_current_map_gate_room():
		hud_label.text = "World: " + world_name + " — Gate Room\n" + _atlas_summary_text() + "\n" + maps_line + "\n" + position_text + "\n" + discovery_line
		var src_world: String = str(_get_current_map_record().get("gate_room_return_world", ""))
		if src_world != "":
			hud_label.text += "\nWalk to Return portal to exit."
	else:
		hud_label.text = "World: " + world_name + "\n" + _atlas_summary_text() + "\n" + maps_line + "\nMap " + map_short + ": " + _map_completion_text(current_map_id) + "\n" + position_text + "\n" + discovery_line
		var world: Dictionary = _get_world(current_world_id)
		if str(world.get("gate_room_source_world", "")) != "" and str(world.get("gate_room_source_map", "")) != "":
			hud_label.text += "\n[G] Return to Gate Room"

	if lichen_count > 0:
		hud_label.text += "\nLichen: " + str(lichen_count) + " [C] grab [T] throw"

	if flashlight_text != "":
		hud_label.text += "\n" + flashlight_text

	if warning_text != "":
		hud_label.text += "\n" + warning_text

	_update_minimap()

	if fps_label != null and fps_label.visible:
		fps_label.text = str(Engine.get_frames_per_second()) + " FPS"


func _update_minimap() -> void:
	if minimap_marker_layer == null:
		return

	for child in minimap_marker_layer.get_children():
		child.queue_free()

	var size: float = 80.0 if not _is_current_map_moon() else 100.0
	var half: float = _world_half_size()
	var player: CharacterBody3D = _get_player()
	if player != null:
		var player_pos: Vector2 = _world_to_minimap(player.global_position.x, player.global_position.z, size, half)
		var fwd: Vector3 = -player.global_transform.basis.z
		var angle: float = atan2(fwd.x, -fwd.z)

		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(0.0, -5.0), Vector2(-4.0, 4.0), Vector2(4.0, 4.0)])
		arrow.color = Color(1.0, 0.55, 0.0)
		arrow.position = player_pos
		arrow.rotation = angle
		minimap_marker_layer.add_child(arrow)

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var discoveries: Dictionary = map_record.get("discoveries", {})
	for discovery_key in discoveries.keys():
		var discovery: Dictionary = discoveries[discovery_key]
		if not discovery.has("x") or not discovery.has("z"):
			continue
		var x: float = float(discovery["x"])
		var z: float = float(discovery["z"])
		var pos: Vector2 = _world_to_minimap(x, z, size, half)
		var kind: String = str(discovery.get("kind", "wonder"))
		var color: Color = Color(0.35, 0.85, 1.0)
		if kind == "gate":
			color = Color(1.0, 0.7, 0.2)
		elif kind == "ruin":
			color = Color(0.75, 0.6, 1.0)
		elif kind == "orb":
			color = Color(0.3, 1.0, 0.6)
		_add_minimap_dot(pos, color, 1.5)


func _world_to_minimap(x: float, z: float, size: float, half: float) -> Vector2:
	return Vector2((x / half) * size * 0.5 + size * 0.5, (z / half) * size * 0.5 + size * 0.5)


func _add_minimap_dot(pos: Vector2, color: Color, radius: float) -> void:
	var dot := ColorRect.new()
	dot.color = color
	dot.position = pos - Vector2(radius, radius)
	dot.size = Vector2(radius * 2.0, radius * 2.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_marker_layer.add_child(dot)


func _setup_underwater_overlay() -> void:
	underwater_layer = CanvasLayer.new()
	underwater_layer.name = "UnderwaterLayer"
	underwater_layer.layer = 20
	add_child(underwater_layer)

	underwater_overlay = ColorRect.new()
	underwater_overlay.name = "UnderwaterOverlay"
	underwater_overlay.anchor_right = 1.0
	underwater_overlay.anchor_bottom = 1.0
	underwater_overlay.color = Color(0.02, 0.22, 0.36, 0.34)
	underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underwater_overlay.visible = false
	underwater_layer.add_child(underwater_overlay)


func _update_underwater_state() -> void:
	if _is_current_map_moon() or _is_current_map_gate_room():
		if is_underwater:
			is_underwater = false
			if underwater_overlay != null:
				underwater_overlay.visible = false
		return

	var camera := get_viewport().get_camera_3d()
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


func _get_player() -> CharacterBody3D:
	if generated_root == null:
		return null

	var player: Node = generated_root.get_node_or_null("Player")
	if player is CharacterBody3D:
		return player

	return null


func _recover_fallen_player() -> void:
	var player: CharacterBody3D = _get_player()
	if player == null:
		return

	player.set("lichen_count", lichen_count)

	if player.global_position.y < WATER_LEVEL - 40.0:
		var spawn: Vector3 = _find_spawn_position()
		player.global_position = Vector3(spawn.x, spawn.y + 6.0, spawn.z)
		player.velocity = Vector3.ZERO
		last_discovery_text = "Recovered from the edge of the world."


func _build_height_values() -> void:
	var g: int = _effective_grid_size()
	height_values.clear()
	height_values.resize((g + 1) * (g + 1))

	for z in range(g + 1):
		for x in range(g + 1):
			height_values[_height_index(x, z)] = _raw_height_at_grid(x, z)


func _effective_grid_size() -> int:
	if _is_current_map_moon():
		return GRID_SIZE * _moon_grid_scale
	return GRID_SIZE


func _world_half_size() -> float:
	return float(_effective_grid_size()) * CELL_SIZE * 0.5


func _height_index(x: int, z: int) -> int:
	var g: int = GRID_SIZE + 1
	if _is_current_map_moon():
		g = (GRID_SIZE * _moon_grid_scale) + 1
	return z * g + x


func _grid_to_world_x(x: int) -> float:
	var g: float = float(GRID_SIZE)
	var c: float = float(CELL_SIZE)
	if _is_current_map_moon():
		g = float(GRID_SIZE * _moon_grid_scale)
		c = float(CELL_SIZE)
	return (float(x) - g * 0.5) * c


func _grid_to_world_z(z: int) -> float:
	var g: float = float(GRID_SIZE)
	var c: float = float(CELL_SIZE)
	if _is_current_map_moon():
		g = float(GRID_SIZE * _moon_grid_scale)
		c = float(CELL_SIZE)
	return (float(z) - g * 0.5) * c


func _raw_height_at_grid(x: int, z: int) -> float:
	var wx: float = _grid_to_world_x(x)
	var wz: float = _grid_to_world_z(z)
	return _height_at_world(wx, wz)


func _height_at_world(wx: float, wz: float) -> float:
	if _is_current_map_gate_room() or _is_current_map_cave() or _is_current_map_map_nexus():
		return 0.0

	if _is_current_map_moon():
		var scale: float = 1.0 / float(_moon_grid_scale)
		var lunar_broad: float = noise.get_noise_2d(wx * 0.45 * scale + 600.0, wz * 0.45 * scale - 1200.0) * 5.0
		var lunar_craters: float = noise.get_noise_2d(wx * 2.8 * scale - 400.0, wz * 2.8 * scale + 700.0) * 1.4
		var crater_bowls: float = abs(noise.get_noise_2d(wx * 0.12 * scale + 330.0, wz * 0.12 * scale - 510.0)) * -4.2
		return lunar_broad + lunar_craters + crater_bowls

	if _is_current_map_water():
		var islands: float = noise.get_noise_2d(wx * 0.12, wz * 0.12) * 15.0
		var detail_islands: float = noise.get_noise_2d(wx * 0.4 + 500.0, wz * 0.4 + 1000.0) * 5.0
		return islands + detail_islands - 7.0

	var broad: float = noise.get_noise_2d(wx * 0.35 + 1200.0, wz * 0.35 - 800.0) * HEIGHT_SCALE
	var hills: float = noise.get_noise_2d(wx, wz) * 5.5
	var details: float = noise.get_noise_2d(wx * 2.1 + 900.0, wz * 2.1 - 900.0) * 1.1
	var river_carve: float = _smooth_falloff(_river_distance(wx, wz), 0.0, 16.0) * 5.5
	var height: float = broad + hills + details - river_carve

	if _river_distance(wx, wz) < 6.0:
		height = min(height, WATER_LEVEL - 0.45 + abs(_river_distance(wx, wz)) * 0.05)

	return height


func _create_terrain_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g: int = _effective_grid_size()
	for z in range(g):
		for x in range(g):
			var p00: Vector3 = Vector3(_grid_to_world_x(x), height_values[_height_index(x, z)], _grid_to_world_z(z))
			var p10: Vector3 = Vector3(_grid_to_world_x(x + 1), height_values[_height_index(x + 1, z)], _grid_to_world_z(z))
			var p01: Vector3 = Vector3(_grid_to_world_x(x), height_values[_height_index(x, z + 1)], _grid_to_world_z(z + 1))
			var p11: Vector3 = Vector3(_grid_to_world_x(x + 1), height_values[_height_index(x + 1, z + 1)], _grid_to_world_z(z + 1))

			_add_triangle(st, p00, p10, p11, _terrain_color(p00), _terrain_color(p10), _terrain_color(p11))
			_add_triangle(st, p00, p11, p01, _terrain_color(p00), _terrain_color(p11), _terrain_color(p01))

	st.generate_normals()
	var terrain_mesh := st.commit()

	var terrain := MeshInstance3D.new()
	terrain.name = "GeneratedTerrain"
	terrain.mesh = terrain_mesh

	var terrain_mat := StandardMaterial3D.new()
	terrain_mat.vertex_color_use_as_albedo = true
	if graphics_level >= 2:
		terrain_mat.roughness = 0.75
		terrain_mat.normal_enabled = true
		terrain_mat.normal_scale = 0.25
		var terrain_noise := FastNoiseLite.new()
		terrain_noise.seed = world_seed
		terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		terrain_noise.frequency = 0.015
		var noise_tex := NoiseTexture2D.new()
		noise_tex.noise = terrain_noise
		noise_tex.normalize = true
		terrain_mat.normal_texture = noise_tex
	else:
		terrain_mat.roughness = 1.0
	terrain.material_override = terrain_mat

	_add_generated_child(terrain)


func _create_terrain_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := HeightMapShape3D.new()
	var g: int = _effective_grid_size()
	shape.map_width = g + 1
	shape.map_depth = g + 1
	shape.map_data = height_values

	var collision := CollisionShape3D.new()
	collision.name = "TerrainHeightMapCollision"
	collision.shape = shape
	collision.scale = Vector3(CELL_SIZE, 1.0, CELL_SIZE)

	body.add_child(collision)
	_add_generated_child(body)


func _create_gate_room_terrain() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.09, 0.12)
	floor_mat.roughness = 0.80

	var floor := MeshInstance3D.new()
	floor.name = "GateRoomFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 32.0
	floor_mesh.bottom_radius = 32.0
	floor_mesh.height = 0.6
	floor_mesh.radial_segments = 32
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.position.y = -0.3
	_add_generated_child(floor)

	var body := StaticBody3D.new()
	body.name = "GateRoomFloorBody"
	var col_shape := CollisionShape3D.new()
	var col_cyl := CylinderShape3D.new()
	col_cyl.radius = 32.0
	col_cyl.height = 0.6
	col_shape.shape = col_cyl
	col_shape.position.y = -0.3
	body.add_child(col_shape)
	_add_generated_child(body)

	for i in range(24):
		var angle: float = TAU * float(i) / 24.0
		var wall_mat := StandardMaterial3D.new()
		wall_mat.albedo_color = Color(0.12, 0.13, 0.18)
		wall_mat.roughness = 0.9
		var wall := MeshInstance3D.new()
		wall.name = "GateRoomWall_" + str(i)
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(2.5, 8.0, 0.6)
		wall.mesh = wall_mesh
		wall.material_override = wall_mat
		wall.position = Vector3(cos(angle) * 31.5, 4.0, sin(angle) * 31.5)
		wall.rotation_degrees.y = -rad_to_deg(angle) + 90.0
		_add_generated_child(wall)


func _create_cave_terrain() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.12, 0.10, 0.08)
	stone_mat.roughness = 0.95
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.20, 0.70, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.10, 0.50, 0.90)
	glow_mat.emission_energy_multiplier = 1.5

	var floor := MeshInstance3D.new()
	floor.name = "CaveFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 45.0
	floor_mesh.bottom_radius = 45.0
	floor_mesh.height = 0.8
	floor_mesh.radial_segments = 32
	floor.mesh = floor_mesh
	floor.material_override = stone_mat
	floor.position.y = -0.4
	_add_generated_child(floor)

	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_cyl := CylinderShape3D.new()
	floor_cyl.radius = 45.0
	floor_cyl.height = 0.8
	floor_col.shape = floor_cyl
	floor_col.position.y = -0.4
	floor_body.add_child(floor_col)
	_add_generated_child(floor_body)

	var ceiling_mat := StandardMaterial3D.new()
	ceiling_mat.albedo_color = Color(0.10, 0.08, 0.06)
	ceiling_mat.roughness = 1.0
	var ceiling := MeshInstance3D.new()
	ceiling.name = "CaveCeiling"
	var ceiling_mesh := CylinderMesh.new()
	ceiling_mesh.top_radius = 44.0
	ceiling_mesh.bottom_radius = 44.0
	ceiling_mesh.height = 0.5
	ceiling_mesh.radial_segments = 32
	ceiling.mesh = ceiling_mesh
	ceiling.material_override = ceiling_mat
	ceiling.position.y = 8.0
	_add_generated_child(ceiling)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.14, 0.11, 0.09)
	wall_mat.roughness = 1.0
	for i in range(32):
		var angle: float = TAU * float(i) / 32.0
		var wall := MeshInstance3D.new()
		wall.name = "CaveWall_" + str(i)
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(3.0, 9.0, 0.8)
		wall.mesh = wall_mesh
		wall.material_override = wall_mat
		wall.position = Vector3(cos(angle) * 44.5, 4.0, sin(angle) * 44.5)
		wall.rotation_degrees.y = -rad_to_deg(angle) + 90.0
		_add_generated_child(wall)

	var tunnel_data: Array[Dictionary] = [
		{"x": -20.0, "z": -20.0, "angle": 0.0, "len": 25.0},
		{"x": 18.0, "z": -18.0, "angle": 45.0, "len": 22.0},
		{"x": -15.0, "z": 22.0, "angle": -30.0, "len": 28.0},
		{"x": 22.0, "z": 15.0, "angle": 120.0, "len": 20.0},
		{"x": -25.0, "z": 5.0, "angle": 80.0, "len": 18.0},
		{"x": 8.0, "z": -25.0, "angle": -60.0, "len": 24.0},
	]
	for td in tunnel_data:
		var cx: float = float(td["x"])
		var cz: float = float(td["z"])
		var a: float = deg_to_rad(float(td["angle"]))
		var length: float = float(td["len"])
		var segments: int = maxi(3, int(length / 3.0))
		for j in range(segments):
			var t: float = float(j) / float(segments)
			var px: float = cx + cos(a) * t * length
			var pz: float = cz + sin(a) * t * length
			for side in [-1, 1]:
				var tunnel_wall := MeshInstance3D.new()
				var tw := BoxMesh.new()
				tw.size = Vector3(0.3, 3.5, 3.0)
				tunnel_wall.mesh = tw
				tunnel_wall.material_override = wall_mat
				var perp: float = a + PI * 0.5
				tunnel_wall.position = Vector3(px + cos(perp) * 1.8 * side, 1.8, pz + sin(perp) * 1.8 * side)
				tunnel_wall.rotation.y = a
				_add_generated_child(tunnel_wall)
			var arch_box := MeshInstance3D.new()
			var ab := BoxMesh.new()
			ab.size = Vector3(3.6, 0.3, 0.3)
			arch_box.mesh = ab
			arch_box.material_override = wall_mat
			arch_box.position = Vector3(px, 3.6, pz)
			arch_box.rotation.y = a
			_add_generated_child(arch_box)

	for i in range(14):
		var pillar_mat := StandardMaterial3D.new()
		pillar_mat.albedo_color = Color(0.15, 0.12, 0.10)
		pillar_mat.roughness = 1.0
		var pillar := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.3
		pm.bottom_radius = 0.5
		pm.height = 8.0
		pillar.mesh = pm
		pillar.material_override = pillar_mat
		var a2: float = TAU * float(i) / 14.0
		var r2: float = randf_range(12.0, 35.0)
		pillar.position = Vector3(cos(a2) * r2, 4.0, sin(a2) * r2)
		_add_generated_child(pillar)

	var glow_pillar_mat := StandardMaterial3D.new()
	glow_pillar_mat.albedo_color = Color(0.18, 0.75, 1.0)
	glow_pillar_mat.emission_enabled = true
	glow_pillar_mat.emission = Color(0.10, 0.60, 0.95)
	glow_pillar_mat.emission_energy_multiplier = 1.8
	for i in range(5):
		var gp := MeshInstance3D.new()
		var gpm := CylinderMesh.new()
		gpm.top_radius = 0.15
		gpm.bottom_radius = 0.25
		gpm.height = randf_range(2.0, 4.0)
		gp.mesh = gpm
		gp.material_override = glow_pillar_mat
		var a3: float = TAU * float(i) / 5.0
		gp.position = Vector3(cos(a3) * 8.0, gpm.height * 0.5, sin(a3) * 8.0)
		_add_generated_child(gp)

		var gl := OmniLight3D.new()
		gl.light_color = Color(0.15, 0.70, 1.0)
		gl.light_energy = 1.5
		gl.omni_range = 10.0
		gl.position = Vector3(cos(a3) * 8.0, 1.5, sin(a3) * 8.0)
		_add_generated_child(gl)


func _scatter_cave_items() -> void:
	var discovered: int = 0
	for i in range(8):
		var a: float = TAU * float(i) / 8.0 + randf_range(-0.2, 0.2)
		var r: float = randf_range(6.0, 38.0)
		var pos: Vector3 = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var kind: String = ["cave_crystal", "glyph", "geode"][i % 3]

		var item_mat := StandardMaterial3D.new()
		item_mat.albedo_color = Color(0.20, 0.75, 1.0)
		item_mat.emission_enabled = true
		item_mat.emission = Color(0.10, 0.55, 0.95)
		item_mat.emission_energy_multiplier = 2.0

		var item_name: String = ""
		var discovery_kind: String = "wonder"
		var mesh: MeshInstance3D = MeshInstance3D.new()
		match kind:
			"cave_crystal":
				var cm := CylinderMesh.new()
				cm.top_radius = 0.05
				cm.bottom_radius = 0.5
				cm.height = randf_range(2.0, 4.0)
				cm.radial_segments = 8
				mesh.mesh = cm
				mesh.material_override = item_mat
				mesh.position.y = cm.height * 0.5
				item_name = "Luminous Cave Crystal"
				discovery_kind = "wonder"
			"glyph":
				var gm := BoxMesh.new()
				gm.size = Vector3(0.8, 0.6, 0.05)
				mesh.mesh = gm
				mesh.material_override = item_mat
				mesh.position.y = 1.5
				item_mat.emission_energy_multiplier = 1.2
				item_name = "Ancient Cave Glyph"
				discovery_kind = "ruin"
			"geode":
				var gm2 := SphereMesh.new()
				gm2.radius = randf_range(0.4, 0.8)
				gm2.height = gm2.radius * 1.2
				mesh.mesh = gm2
				mesh.material_override = item_mat
				mesh.position.y = gm2.radius
				item_mat.emission_energy_multiplier = 0.8
				item_name = "Glowing Geode"
				discovery_kind = "wonder"

		var item := Node3D.new()
		item.name = kind
		item.position = pos
		item.add_child(mesh)

		_add_discovery_area(item, Vector3(0.0, 1.0, 0.0), 4.0, "cave_item_" + str(i), item_name, discovery_kind)
		_add_generated_child(item)
		discovered += 1

	current_map_available_discoveries += discovered


func _create_map_nexus_terrain() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.09, 0.14)
	floor_mat.roughness = 0.80

	var floor := MeshInstance3D.new()
	floor.name = "MapNexusFloor"
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 48.0
	floor_mesh.bottom_radius = 48.0
	floor_mesh.height = 0.6
	floor_mesh.radial_segments = 40
	floor.mesh = floor_mesh
	floor.material_override = floor_mat
	floor.position.y = -0.3
	_add_generated_child(floor)

	var body := StaticBody3D.new()
	body.name = "MapNexusFloorBody"
	var col_shape := CollisionShape3D.new()
	var col_cyl := CylinderShape3D.new()
	col_cyl.radius = 48.0
	col_cyl.height = 0.6
	col_shape.shape = col_cyl
	col_shape.position.y = -0.3
	body.add_child(col_shape)
	_add_generated_child(body)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.12, 0.13, 0.20)
	wall_mat.roughness = 0.9
	for i in range(36):
		var angle: float = TAU * float(i) / 36.0
		var wall := MeshInstance3D.new()
		wall.name = "MapNexusWall_" + str(i)
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(2.5, 8.0, 0.6)
		wall.mesh = wall_mesh
		wall.material_override = wall_mat
		wall.position = Vector3(cos(angle) * 47.5, 4.0, sin(angle) * 47.5)
		wall.rotation_degrees.y = -rad_to_deg(angle) + 90.0
		_add_generated_child(wall)


func _scatter_map_nexus_gates() -> void:
	var slot_count: int = 32
	var rows: Array[Dictionary] = [
		{"count": 8, "radius": 25.0, "start_angle": -0.7, "end_angle": 0.7},
		{"count": 8, "radius": 32.0, "start_angle": -0.7, "end_angle": 0.7},
		{"count": 8, "radius": 39.0, "start_angle": -0.7, "end_angle": 0.7},
		{"count": 8, "radius": 46.0, "start_angle": -0.7, "end_angle": 0.7},
	]
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.20, 0.18, 0.30)
	gate_mat.roughness = 0.9
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.6, 0.5, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.4, 0.3, 0.8)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var map_record: Dictionary = _get_current_map_record()
	var slots: Dictionary = map_record.get("nexus_slots", {})
	var maps: Dictionary = (_get_world(current_world_id)).get("maps", {})

	var slot_idx: int = 0
	for row in rows:
		var count: int = int(row["count"])
		var radius: float = float(row["radius"])
		var start_angle: float = float(row["start_angle"])
		var end_angle: float = float(row["end_angle"])
		for i in range(count):
			var t: float = float(i) / float(count - 1)
			var angle: float = lerp(start_angle, end_angle, t)
			var x: float = sin(angle) * radius
			var z: float = cos(angle) * radius

			var gate := Node3D.new()
			gate.name = "NexusGate" + str(slot_idx)
			gate.position = Vector3(x, 0.0, z)
			gate.rotation.y = -angle

			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.2, 2.5, 0.2)
			var left_post := MeshInstance3D.new()
			left_post.mesh = post_mesh
			left_post.position = Vector3(-0.7, 1.25, 0.0)
			left_post.material_override = gate_mat
			gate.add_child(left_post)
			var right_post := MeshInstance3D.new()
			right_post.mesh = post_mesh
			right_post.position = Vector3(0.7, 1.25, 0.0)
			right_post.material_override = gate_mat
			gate.add_child(right_post)

			var arch_mesh := BoxMesh.new()
			arch_mesh.size = Vector3(1.8, 0.15, 0.2)
			var arch := MeshInstance3D.new()
			arch.mesh = arch_mesh
			arch.position = Vector3(0.0, 2.6, 0.0)
			arch.material_override = gate_mat
			gate.add_child(arch)

			var g := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(1.2, 1.8, 0.04)
			g.mesh = gm
			g.position = Vector3(0.0, 1.4, 0.05)
			g.material_override = glow_mat
			gate.add_child(g)

			var slot_key: String = str(slot_idx)
			var target_map_id: String = str(slots.get(slot_key, ""))
			var label_text: String = "Slot " + str(slot_idx + 1)
			if target_map_id != "" and maps.has(target_map_id):
				label_text = str(slot_idx + 1)

			var label := Label3D.new()
			label.text = label_text
			label.font_size = 12
			label.modulate = Color(0.8, 0.75, 1.0)
			label.position = Vector3(0.0, 3.3, 0.0)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.no_depth_test = true
			gate.add_child(label)

			var area := Area3D.new()
			area.name = "NexusGateTrigger"
			area.collision_layer = 0
			area.collision_mask = 2
			var area_shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.8, 2.4, 1.0)
			area_shape.shape = box
			area_shape.position = Vector3(0.0, 1.4, 0.0)
			area.add_child(area_shape)
			area.body_entered.connect(_on_map_nexus_gate_body_entered.bind(slot_idx))
			gate.add_child(area)

			_add_generated_child(gate)
			slot_idx += 1


func _on_map_nexus_gate_body_entered(body: Node3D, slot_index: int) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		return
	if not _is_current_map_map_nexus():
		return

	var map_record: Dictionary = _get_current_map_record()
	var slots: Dictionary = map_record.get("nexus_slots", {})
	var slot_key: String = str(slot_index)
	var target_map_id: String = str(slots.get(slot_key, ""))
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})

	if target_map_id == "" or not maps.has(target_map_id):
		if maps.size() >= 32:
			last_discovery_text = "No more maps can be opened in this world."
			return
		target_map_id = _new_id("map")
		var map_seed: int = int((world_seed ^ ((slot_index + 1) * 991948531) ^ 412038719) & 0x7fffffff)
		if map_seed == 0:
			map_seed = 54321 + slot_index
		maps[target_map_id] = _create_map_record(map_seed)
		slots[slot_key] = target_map_id
		map_record["nexus_slots"] = slots
		var w: Dictionary = _get_world(current_world_id)
		var ms: Dictionary = w.get("maps", {})
		ms[current_map_id] = map_record
		w["maps"] = ms
		_set_world(current_world_id, w)
		_save_world_data()
		last_discovery_text = "Unfolding map " + str(slot_index + 1) + "..."

	_load_map(current_world_id, target_map_id)


func _create_world_bounds() -> void:
	var half: float = _world_half_size()
	var wall_height: float = 80.0
	var wall_thickness: float = 4.0
	var wall_center_y: float = 18.0
	var wall_length: float = float(_effective_grid_size()) * CELL_SIZE + wall_thickness * 2.0

	var bounds := Node3D.new()
	bounds.name = "WorldEdgeBarriers"
	_add_box_collision(bounds, Vector3(half, wall_center_y, 0.0), Vector3(wall_thickness, wall_height, wall_length))
	_add_box_collision(bounds, Vector3(-half, wall_center_y, 0.0), Vector3(wall_thickness, wall_height, wall_length))
	_add_box_collision(bounds, Vector3(0.0, wall_center_y, half), Vector3(wall_length, wall_height, wall_thickness))
	_add_box_collision(bounds, Vector3(0.0, wall_center_y, -half), Vector3(wall_length, wall_height, wall_thickness))
	_add_box_collision(bounds, Vector3(0.0, -45.0, 0.0), Vector3(wall_length * 2.0, 0.2, wall_length * 2.0))
	_add_generated_child(bounds)


func _create_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "RiverAndLakeWater"

	var water_size: float = float(_effective_grid_size()) * CELL_SIZE * 0.94

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(water_size, water_size)

	if graphics_level <= 0:
		mesh.subdivide_width = 32
		mesh.subdivide_depth = 32
	elif graphics_level == 1:
		mesh.subdivide_width = 64
		mesh.subdivide_depth = 64
	else:
		mesh.subdivide_width = 128
		mesh.subdivide_depth = 128

	water.mesh = mesh
	water.position.y = WATER_LEVEL

	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.34, 0.52, 0.34);
uniform vec4 deep_color : source_color = vec4(0.03, 0.16, 0.32, 0.44);
uniform vec3 sky_tint : source_color = vec3(0.34, 0.56, 0.82);

uniform float wave_speed : hint_range(0.0, 5.0) = 0.65;
uniform float wave_height : hint_range(0.0, 0.5) = 0.045;
uniform float wave_scale : hint_range(0.1, 20.0) = 4.0;
uniform float normal_strength : hint_range(0.0, 5.0) = 0.85;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.28;
uniform float alpha_boost : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_normal;
varying vec3 v_world_position;

float wave_value(vec2 p, float t) {
	float a = sin(p.x * wave_scale + t * wave_speed);
	float b = sin(p.y * wave_scale * 1.37 + t * wave_speed * 1.11);
	float c = sin((p.x + p.y) * wave_scale * 0.71 + t * wave_speed * 0.63);
	return (a + b + c * 0.65) / 2.65;
}

void vertex() {
	float t = TIME;
	vec2 p = VERTEX.xz * 0.08;

	float h = wave_value(p, t) * wave_height;
	VERTEX.y += h;

	float e = 0.08;
	float hx = wave_value(p + vec2(e, 0.0), t) * wave_height;
	float hz = wave_value(p + vec2(0.0, e), t) * wave_height;

	vec3 local_normal = normalize(vec3(
		-(hx - h) * normal_strength,
		1.0,
		-(hz - h) * normal_strength
	));

	NORMAL = local_normal;
	v_normal = normalize((MODEL_MATRIX * vec4(local_normal, 0.0)).xyz);
	v_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(v_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_position);

	float fresnel = pow(1.0 - clamp(dot(n, view_dir), 0.0, 1.0), 3.0);

	float ripple = sin(v_world_position.x * 0.32 + TIME * wave_speed * 1.4)
		* sin(v_world_position.z * 0.25 - TIME * wave_speed * 1.0);
	ripple = ripple * 0.5 + 0.5;

	vec3 base_color = mix(shallow_color.rgb, deep_color.rgb, 0.45);
	base_color += vec3(ripple * 0.018);

	// Do NOT add sky color directly. Mix toward it gently.
	float sheen = clamp(fresnel * sheen_strength, 0.0, 0.35);
	ALBEDO = mix(base_color, sky_tint, sheen);

	ALPHA = mix(shallow_color.a, deep_color.a, 0.45) + fresnel * 0.08 + alpha_boost;
	ALPHA = clamp(ALPHA, 0.24, 0.52);

	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
"""

	var mat := ShaderMaterial.new()
	mat.shader = water_shader

	if _is_current_map_water():
		mat.set_shader_parameter("shallow_color", Color(0.08, 0.30, 0.50, 0.36))
		mat.set_shader_parameter("deep_color", Color(0.02, 0.13, 0.30, 0.48))
		mat.set_shader_parameter("sky_tint", Color(0.32, 0.54, 0.82))
		mat.set_shader_parameter("wave_height", 0.075 if graphics_level >= 2 else 0.045)
		mat.set_shader_parameter("wave_speed", 0.90 if graphics_level >= 2 else 0.65)
		mat.set_shader_parameter("wave_scale", 3.1)
		mat.set_shader_parameter("normal_strength", 1.05 if graphics_level >= 2 else 0.75)
		mat.set_shader_parameter("sheen_strength", 0.28)
		mat.set_shader_parameter("alpha_boost", 0.02)
	else:
		mat.set_shader_parameter("shallow_color", Color(0.10, 0.36, 0.56, 0.30))
		mat.set_shader_parameter("deep_color", Color(0.03, 0.18, 0.36, 0.40))
		mat.set_shader_parameter("sky_tint", Color(0.36, 0.60, 0.88))
		mat.set_shader_parameter("wave_height", 0.045 if graphics_level >= 2 else 0.025)
		mat.set_shader_parameter("wave_speed", 0.60 if graphics_level >= 2 else 0.40)
		mat.set_shader_parameter("wave_scale", 4.4)
		mat.set_shader_parameter("normal_strength", 0.85 if graphics_level >= 2 else 0.60)
		mat.set_shader_parameter("sheen_strength", 0.32)
		mat.set_shader_parameter("alpha_boost", 0.0)

	water.material_override = mat
	_add_generated_child(water)

	var water_collision := StaticBody3D.new()
	water_collision.name = "WaterCollision"
	water_collision.collision_layer = 4
	water_collision.collision_mask = 0

	var water_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(water_size, 0.2, water_size)
	water_shape.shape = box

	water_collision.add_child(water_shape)
	water_collision.position.y = WATER_LEVEL
	_add_generated_child(water_collision)

func _create_sky_clouds() -> void:
	if _is_current_map_moon() or _is_current_map_cave():
		return
	if graphics_level == 0:
		return

	var cloud_root := Node3D.new()
	cloud_root.name = "SkyClouds"

	var cloud_shader := Shader.new()
	cloud_shader.code = """
shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform float time_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float time_scale : hint_range(0.0, 1.0) = 0.025;
uniform float density : hint_range(0.0, 1.0) = 0.38;
uniform float coverage : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.0, 1.0) = 0.25;
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.92);
uniform vec3 cloud_shadow_color : source_color = vec3(0.70, 0.74, 0.78);

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;

	for (int i = 0; i < 5; i++) {
		v += amp * noise2(p);
		p = p * 2.05 + vec2(13.2, 7.1);
		amp *= 0.5;
	}

	return v;
}

void fragment() {
	float t = TIME * time_scale + time_offset;

	vec2 p = UV * 5.0;
	p += vec2(t * 0.35, t * 0.10);

	float large = fbm(p);
	float detail = fbm(p * 2.7 + vec2(31.7, 19.4));
	float cloud = large * 0.75 + detail * 0.25;

	float threshold = 1.0 - coverage;
	float alpha = smoothstep(threshold, threshold + softness, cloud) * density;

	vec2 centered = UV * 2.0 - 1.0;
	float edge = max(abs(centered.x), abs(centered.y));
	alpha *= 1.0 - smoothstep(0.72, 1.0, edge);

	vec3 color = mix(cloud_shadow_color, cloud_color, clamp(cloud + 0.12, 0.0, 1.0));

	ALBEDO = color;
	ALPHA = alpha;
}
"""

	var near_clouds := MeshInstance3D.new()
	near_clouds.name = "CloudLayerNear"
	var near_mesh := PlaneMesh.new()
	near_mesh.size = Vector2(900.0, 900.0)
	near_clouds.mesh = near_mesh
	near_clouds.position = Vector3(0.0, 115.0, 0.0)

	var mat := ShaderMaterial.new()
	mat.shader = cloud_shader
	mat.set_shader_parameter("time_offset", float(world_seed % 1000))
	mat.set_shader_parameter("time_scale", 0.025)
	mat.set_shader_parameter("density", 0.42 if graphics_level >= 2 else 0.28)
	mat.set_shader_parameter("coverage", 0.56)
	mat.set_shader_parameter("softness", 0.25)
	mat.set_shader_parameter("cloud_color", Color(1.0, 0.98, 0.92))
	mat.set_shader_parameter("cloud_shadow_color", Color(0.70, 0.74, 0.78))
	near_clouds.material_override = mat
	cloud_root.add_child(near_clouds)

	var far_clouds := MeshInstance3D.new()
	far_clouds.name = "CloudLayerFar"
	var far_mesh := PlaneMesh.new()
	far_mesh.size = Vector2(1300.0, 1300.0)
	far_clouds.mesh = far_mesh
	far_clouds.position = Vector3(0.0, 170.0, 0.0)

	var mat2 := ShaderMaterial.new()
	mat2.shader = cloud_shader
	mat2.set_shader_parameter("time_offset", float(world_seed % 1000) + 250.0)
	mat2.set_shader_parameter("time_scale", 0.014)
	mat2.set_shader_parameter("density", 0.22 if graphics_level >= 2 else 0.12)
	mat2.set_shader_parameter("coverage", 0.62)
	mat2.set_shader_parameter("softness", 0.35)
	mat2.set_shader_parameter("cloud_color", Color(1.0, 0.98, 0.94))
	mat2.set_shader_parameter("cloud_shadow_color", Color(0.72, 0.76, 0.82))
	far_clouds.material_override = mat2
	cloud_root.add_child(far_clouds)

	_add_generated_child(cloud_root)


func _create_visible_sun() -> void:
	if sun_light == null:
		return
	if _is_current_map_cave() or _is_current_map_gate_room() or _is_current_map_map_nexus():
		return

	var sun_disc := MeshInstance3D.new()
	sun_disc.name = "VisibleSun"

	var mesh := SphereMesh.new()
	mesh.radius = 18.0
	mesh.height = 36.0
	mesh.radial_segments = 24
	mesh.rings = 12
	sun_disc.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.35)
	mat.emission_energy_multiplier = 2.5
	sun_disc.material_override = mat

	var dir := -sun_light.global_transform.basis.z.normalized()
	sun_disc.position = dir * 650.0

	_add_generated_child(sun_disc)

func _create_moon_sky() -> void:
	var sky := Node3D.new()
	sky.name = "MoonSkyDetails"

	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(0.75, 0.86, 1.0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.7, 0.85, 1.0)
	star_mat.emission_energy_multiplier = 1.8
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(200):
		var angle := randf_range(0.0, TAU)
		var elev := randf_range(15.0, 75.0)
		var dist := randf_range(600.0, 1000.0)
		var star := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.3, 0.8)
		mesh.height = mesh.radius * 2.0
		star.mesh = mesh
		star.material_override = star_mat
		var sx := cos(angle) * cos(deg_to_rad(elev)) * dist
		var sy := sin(deg_to_rad(elev)) * dist
		var sz := sin(angle) * cos(deg_to_rad(elev)) * dist
		star.position = Vector3(sx, sy, sz)
		sky.add_child(star)

	var earth := Node3D.new()
	earth.name = "DistantBlueWorld"
	earth.position = Vector3(500.0, 100.0, -240.0)

	var earth_mesh := SphereMesh.new()
	earth_mesh.radius = 80.0
	earth_mesh.height = 160.0
	earth_mesh.radial_segments = 32
	earth_mesh.rings = 16
	var earth_surf := SurfaceTool.new()
	earth_surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e_verts: Array[Vector3] = []
	var e_colors: Array[Color] = []
	var e_normals: Array[Vector3] = []
	var e_u: Array[Vector2] = []
	for lat in range(17):
		var theta1: float = float(lat) / 16.0 * PI
		var theta2: float = float(lat + 1) / 16.0 * PI
		for lon in range(33):
			var phi1: float = float(lon) / 32.0 * TAU
			var phi2: float = float(lon + 1) / 32.0 * TAU
			var p1 := _sphere_point(80.0, theta1, phi1)
			var p2 := _sphere_point(80.0, theta2, phi1)
			var p3 := _sphere_point(80.0, theta2, phi2)
			var p4 := _sphere_point(80.0, theta1, phi2)
			var c1 := _earth_color(p1, world_seed)
			var c2 := _earth_color(p2, world_seed)
			var c3 := _earth_color(p3, world_seed)
			var c4 := _earth_color(p4, world_seed)
			var n := p1.normalized()
			e_verts.push_back(p1); e_verts.push_back(p2); e_verts.push_back(p3)
			e_colors.push_back(c1); e_colors.push_back(c2); e_colors.push_back(c3)
			e_normals.push_back(n); e_normals.push_back(n); e_normals.push_back(n)
			e_u.push_back(Vector2(0,0)); e_u.push_back(Vector2(0,0)); e_u.push_back(Vector2(0,0))
			e_verts.push_back(p1); e_verts.push_back(p3); e_verts.push_back(p4)
			e_colors.push_back(c1); e_colors.push_back(c3); e_colors.push_back(c4)
			e_normals.push_back(n); e_normals.push_back(n); e_normals.push_back(n)
			e_u.push_back(Vector2(0,0)); e_u.push_back(Vector2(0,0)); e_u.push_back(Vector2(0,0))
	for i in range(e_verts.size()):
		earth_surf.set_uv(e_u[i])
		earth_surf.set_color(e_colors[i])
		earth_surf.set_normal(e_normals[i])
		earth_surf.add_vertex(e_verts[i])
	earth_surf.generate_normals()
	var earth_body := MeshInstance3D.new()
	earth_body.mesh = earth_surf.commit()
	var earth_mat := StandardMaterial3D.new()
	earth_mat.vertex_color_use_as_albedo = true
	earth_mat.roughness = 0.85
	earth_body.material_override = earth_mat
	earth.add_child(earth_body)

	var atmos_mat := StandardMaterial3D.new()
	atmos_mat.albedo_color = Color(0.35, 0.65, 1.0, 0.35)
	atmos_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmos_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	atmos_mat.emission_enabled = true
	atmos_mat.emission = Color(0.15, 0.40, 0.90)
	atmos_mat.emission_energy_multiplier = 0.6
	atmos_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var atmos_mesh := SphereMesh.new()
	atmos_mesh.radius = 83.0
	atmos_mesh.height = 166.0
	var atmos := MeshInstance3D.new()
	atmos.mesh = atmos_mesh
	atmos.material_override = atmos_mat
	earth.add_child(atmos)

	for ci in range(8):
		var c_angle := randf_range(0.0, TAU)
		var c_lat := randf_range(-PI * 0.35, PI * 0.35)
		var c_dist := randf_range(0.6, 0.85)
		var c_pt := _sphere_point(82.5, c_lat, c_angle) * c_dist
		var cloud_mat := StandardMaterial3D.new()
		cloud_mat.albedo_color = Color(0.95, 0.97, 1.0, 0.55)
		cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloud_mat.emission_enabled = true
		cloud_mat.emission = Color(0.8, 0.85, 0.95)
		cloud_mat.emission_energy_multiplier = 0.4
		cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c_mesh := SphereMesh.new()
		c_mesh.radius = randf_range(4.0, 12.0)
		c_mesh.height = c_mesh.radius * randf_range(0.3, 0.6)
		var cloud := MeshInstance3D.new()
		cloud.mesh = c_mesh
		cloud.material_override = cloud_mat
		cloud.position = c_pt
		cloud.rotation_degrees = Vector3(randf_range(-20, 20), randf_range(0, 360), randf_range(-10, 10))
		earth.add_child(cloud)

	sky.add_child(earth)

	var rim := MeshInstance3D.new()
	rim.name = "MoonHorizonGlow"
	var rim_mesh := TorusMesh.new()
	rim_mesh.outer_radius = 600.0
	rim_mesh.inner_radius = 598.0
	rim.mesh = rim_mesh
	rim.position = Vector3(0.0, -6.0, -900.0)
	rim.rotation_degrees.x = 90.0
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.18, 0.45, 0.95, 0.20)
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.08, 0.22, 0.65)
	rim_mat.emission_energy_multiplier = 0.8
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.material_override = rim_mat
	sky.add_child(rim)

	_add_generated_child(sky)


static func _sphere_point(r: float, theta: float, phi: float) -> Vector3:
	return Vector3(r * sin(theta) * cos(phi), r * cos(theta), r * sin(theta) * sin(phi))


func _earth_color(p: Vector3, seed: int) -> Color:
	var n: Vector3 = p.normalized()
	var lon := atan2(n.z, n.x)
	var lat := acos(n.y)
	var sx := cos(lat) * 3.5 + 1000.0
	var sz := sin(lat) * 2.8 + float(seed) * 0.1
	var noise_val := sin(lon * 3.0 + sx) * 0.5 + sin(lon * 7.0 + sx * 1.3) * 0.25 + sin(lon * 13.0 + sx * 0.7) * 0.15
	noise_val += sin(lat * 4.0 + sz) * 0.3 + sin(lat * 8.0 + sz * 1.5) * 0.15
	var land: float = clamp((noise_val + 1.0) * 0.5, 0.0, 1.0)
	if land > 0.52:
		var green: float = 0.45 + sin(noise_val * 17.0) * 0.10
		return Color(0.12, green, 0.08)
	elif land > 0.44:
		return Color(0.72, 0.68, 0.52)
	elif land > 0.38:
		return Color(0.30, 0.38, 0.48)
	return Color(0.08, 0.22, 0.55)


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color_a: Color, color_b: Color, color_c: Color) -> void:
	st.set_uv(Vector2(a.x, a.z) * 0.04)
	st.set_color(color_a)
	st.add_vertex(a)
	st.set_uv(Vector2(b.x, b.z) * 0.04)
	st.set_color(color_b)
	st.add_vertex(b)
	st.set_uv(Vector2(c.x, c.z) * 0.04)
	st.set_color(color_c)
	st.add_vertex(c)


func _spawn_player() -> void:
	var player: CharacterBody3D = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/Player.gd"))
	if _is_current_map_moon():
		player.set("gravity_multiplier", 0.25)
		player.set("jump_multiplier", 4.0)
		player.set("water_level", -100000.0)
	else:
		player.set("gravity_multiplier", 1.0)
		player.set("jump_multiplier", 1.0)
		player.set("water_level", WATER_LEVEL)

	var spawn: Vector3 = _find_spawn_position()
	var spawn_x: float = spawn.x
	var spawn_z: float = spawn.z
	var spawn_ground_height: float = _height_at_world(spawn_x, spawn_z)
	if spawn_ground_height < WATER_LEVEL + 0.5:
		spawn_ground_height = WATER_LEVEL + 0.5
	var spawn_y: float = spawn_ground_height + 6.0

	# Use local position here. global_position/global_transform can complain before
	# the node is inside the scene tree.
	player.position = Vector3(spawn_x, spawn_y, spawn_z)

	_add_generated_child(player)


func _find_spawn_position() -> Vector3:
	if _is_current_map_gate_room():
		return Vector3(0.0, _height_at_world(0.0, 0.0), 28.0)

	if _is_current_map_cave():
		return Vector3(0.0, _height_at_world(0.0, 0.0), 0.0)

	if _is_current_map_map_nexus():
		return Vector3(0.0, _height_at_world(0.0, 0.0), 40.0)

	if _is_current_map_water():
		var half: float = float(GRID_SIZE) * CELL_SIZE * 0.5
		for attempt in range(200):
			var x: float = randf_range(-half + 20.0, half - 20.0)
			var z: float = randf_range(-half + 20.0, half - 20.0)
			var y: float = _height_at_world(x, z)
			if y > WATER_LEVEL + 1.0:
				return Vector3(x, y, z)
		return Vector3(0.0, _height_at_world(0.0, 0.0), 0.0)

	var spawn_radii: Array[float] = [0.0, 10.0, 18.0, 28.0, 40.0]
	for radius_value in spawn_radii:
		var radius: float = float(radius_value)
		for i in range(12):
			var angle: float = TAU * float(i) / 12.0
			var x: float = cos(angle) * radius
			var z: float = sin(angle) * radius
			var pos: Vector3 = Vector3(x, _height_at_world(x, z), z)
			if pos.y > WATER_LEVEL + 1.0 and _river_distance(x, z) > 9.0:
				return pos

	return Vector3(0.0, _height_at_world(0.0, 0.0), 0.0)


func _scatter_trees() -> void:
	var trunk_seg: int = [8, 14, 22, 32][clampi(graphics_level, 0, 3)]
	var leaf_seg: int = [12, 18, 28, 40][clampi(graphics_level, 0, 3)]
	var leaf_rings: int = [6, 10, 16, 24][clampi(graphics_level, 0, 3)]

	for i in range(TREE_COUNT):
		var pos: Vector3 = _random_land_position(WATER_LEVEL + 0.35)
		if pos.distance_to(Vector3.ZERO) < 8.0:
			continue

		var tree := Node3D.new()
		tree.name = "Tree"
		tree.position = Vector3(pos.x, pos.y - 0.15, pos.z)
		tree.rotation_degrees.y = randf_range(0.0, 360.0)
		tree.scale = Vector3.ONE * randf_range(0.8, 1.25)

		var kind: String = _tree_kind_for_position(pos)
		_build_tree_visual(tree, kind, trunk_seg, leaf_seg, leaf_rings, pos)

		var trunk_h: float = float(tree.get_meta("trunk_height", 2.5))
		_add_cylinder_collision(tree, Vector3(0.0, trunk_h * 0.5, 0.0), 0.34, trunk_h)
		_add_generated_child(tree)


func _tree_kind_for_position(pos: Vector3) -> String:
	var biome: float = _biome_value(pos.x, pos.z)
	if pos.y > 9.0:
		return "pine"
	if biome > 0.35:
		return "broadleaf"
	if biome < -0.35:
		return "sparse"
	return "round"


func _build_tree_visual(tree: Node3D, kind: String, trunk_seg: int, leaf_seg: int, leaf_rings: int, pos: Vector3) -> void:
	match kind:
		"pine":
			_build_pine_tree(tree, trunk_seg, leaf_seg, leaf_rings, pos)
		"broadleaf":
			_build_broadleaf_tree(tree, trunk_seg, leaf_seg, leaf_rings, pos)
		"sparse":
			_build_sparse_tree(tree, trunk_seg, leaf_seg, leaf_rings, pos)
		_:
			_build_round_tree(tree, trunk_seg, leaf_seg, leaf_rings, pos)


func _get_tree_material(key: String, color: Color) -> StandardMaterial3D:
	if tree_materials.has(key):
		return tree_materials[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	tree_materials[key] = mat
	return mat


func _build_trunk(tree: Node3D, height: float, trunk_seg: int, color: Color) -> StandardMaterial3D:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.30
	trunk_mesh.height = height
	trunk_mesh.radial_segments = trunk_seg

	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position.y = height * 0.5
	trunk.scale.x = randf_range(0.85, 1.15)
	trunk.scale.z = randf_range(0.85, 1.15)
	trunk.rotation_degrees.x = randf_range(-2.0, 2.0)
	trunk.rotation_degrees.z = randf_range(-2.0, 2.0)

	var mat_key: String = "trunk_" + str(color)
	var mat := _get_tree_material(mat_key, color)
	trunk.material_override = mat
	tree.add_child(trunk)
	tree.set_meta("trunk_height", height)
	return mat


func _build_branches(tree: Node3D, trunk_height: float, trunk_seg: int, trunk_mat: StandardMaterial3D) -> void:
	var branch_count: int = [0, 4, 6, 9][clampi(graphics_level, 0, 3)]
	var branch_seg: int = [6, 8, 10, 14][clampi(graphics_level, 0, 3)]
	for b in range(branch_count):
		var branch_mesh := CylinderMesh.new()
		branch_mesh.top_radius = 0.04
		branch_mesh.bottom_radius = 0.10
		branch_mesh.height = randf_range(0.8, 1.8)
		branch_mesh.radial_segments = branch_seg
		var branch := MeshInstance3D.new()
		branch.mesh = branch_mesh
		branch.material_override = trunk_mat
		var angle := randf_range(0.0, TAU)
		var y_frac := randf_range(0.35, 0.85)
		var tilt := deg_to_rad(randf_range(25.0, 50.0))
		var dir := Vector3(cos(angle) * cos(tilt), sin(tilt), sin(angle) * cos(tilt))
		var half_len: float = branch_mesh.height * 0.5
		branch.position = Vector3(cos(angle) * 0.19 + dir.x * half_len, trunk_height * y_frac + dir.y * half_len, sin(angle) * 0.19 + dir.z * half_len)
		branch.quaternion = Quaternion(Vector3(0.0, 1.0, 0.0), dir)
		tree.add_child(branch)


func _build_leaf_blobs(tree: Node3D, count: int, center_y: float, spread: float, leaf_seg: int, leaf_rings: int, leaf_mat: StandardMaterial3D) -> void:
	for b in range(count):
		var blob := MeshInstance3D.new()
		var blob_mesh := SphereMesh.new()
		blob_mesh.radius = randf_range(0.75, 1.35) * spread
		blob_mesh.height = blob_mesh.radius * randf_range(1.1, 1.7)
		blob_mesh.radial_segments = leaf_seg
		blob_mesh.rings = leaf_rings
		blob.mesh = blob_mesh
		blob.material_override = leaf_mat
		blob.position = Vector3(randf_range(-0.5, 0.5), center_y + randf_range(-0.2, 1.0), randf_range(-0.5, 0.5))
		blob.scale = Vector3(randf_range(0.8, 1.35), randf_range(0.7, 1.15), randf_range(0.8, 1.35))
		tree.add_child(blob)


func _build_leaf_color(pos: Vector3) -> Color:
	var biome: float = _biome_value(pos.x, pos.z)
	var hue_shift: float = randf_range(-0.035, 0.035)
	var sat: float = randf_range(0.65, 0.95)
	var val: float = randf_range(0.55, 0.85)
	if pos.y > 8.0:
		return Color.from_hsv(0.30 + hue_shift, sat * 0.8, val * 0.7)
	if biome > 0.25:
		return Color.from_hsv(0.28 + hue_shift, sat, val)
	return Color.from_hsv(0.32 + hue_shift, sat * 0.8, val * 0.8)


func _build_round_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, pos: Vector3) -> void:
	var trunk_h: float = randf_range(2.0, 3.3)
	var trunk_mat := _build_trunk(tree, trunk_h, trunk_seg, Color(0.32, 0.19, 0.09))
	_build_branches(tree, trunk_h, trunk_seg, trunk_mat)
	var blob_count: int = [2, 3, 5, 7][clampi(graphics_level, 0, 3)]
	var leaf_color: Color = _build_leaf_color(pos)
	var leaf_key: String = "leaf_" + str(leaf_color)
	var leaf_mat := _get_tree_material(leaf_key, leaf_color)
	_build_leaf_blobs(tree, blob_count, trunk_h * 0.925 + 0.25, 1.0, leaf_seg, leaf_rings, leaf_mat)


func _build_pine_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, pos: Vector3) -> void:
	var trunk_h: float = randf_range(2.5, 4.0)
	var trunk_mat := _build_trunk(tree, trunk_h, trunk_seg, Color(0.38, 0.22, 0.10))
	var leaf_color: Color = _build_leaf_color(pos)
	leaf_color = Color.from_hsv(0.30, randf_range(0.50, 0.75), randf_range(0.35, 0.55))
	var leaf_key: String = "leaf_" + str(leaf_color)
	var leaf_mat := _get_tree_material(leaf_key, leaf_color)
	var layer_count: int = [3, 4, 5, 6][clampi(graphics_level, 0, 3)]
	var cone_seg: int = [8, 12, 18, 26][clampi(graphics_level, 0, 3)]
	for i in range(layer_count):
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = randf_range(0.8, 1.4) * (1.0 - float(i) * 0.10)
		cone_mesh.height = randf_range(1.0, 1.6)
		cone_mesh.radial_segments = cone_seg
		var cone := MeshInstance3D.new()
		cone.mesh = cone_mesh
		cone.material_override = leaf_mat
		cone.position.y = trunk_h * 0.5 + float(i) * 0.7
		tree.add_child(cone)


func _build_broadleaf_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, pos: Vector3) -> void:
	var trunk_h: float = randf_range(2.8, 4.0)
	var trunk_mat := _build_trunk(tree, trunk_h, trunk_seg, Color(0.35, 0.20, 0.08))
	_build_branches(tree, trunk_h, trunk_seg, trunk_mat)
	var blob_count: int = [3, 4, 6, 9][clampi(graphics_level, 0, 3)]
	var leaf_color: Color = _build_leaf_color(pos)
	leaf_color.s = randf_range(0.75, 1.0)
	leaf_color.v = randf_range(0.60, 0.90)
	var leaf_key: String = "leaf_" + str(leaf_color)
	var leaf_mat := _get_tree_material(leaf_key, leaf_color)
	_build_leaf_blobs(tree, blob_count, trunk_h * 0.925 + 0.25, 1.3, leaf_seg, leaf_rings, leaf_mat)


func _build_sparse_tree(tree: Node3D, trunk_seg: int, leaf_seg: int, leaf_rings: int, pos: Vector3) -> void:
	var trunk_h: float = randf_range(1.8, 2.8)
	var trunk_mat := _build_trunk(tree, trunk_h, trunk_seg, Color(0.28, 0.16, 0.07))
	var blob_count: int = [1, 2, 3, 4][clampi(graphics_level, 0, 3)]
	var leaf_color: Color = _build_leaf_color(pos)
	leaf_color.s *= 0.6
	leaf_color.v *= 0.7
	var leaf_key: String = "leaf_" + str(leaf_color)
	var leaf_mat := _get_tree_material(leaf_key, leaf_color)
	_build_leaf_blobs(tree, blob_count, trunk_h * 0.925 + 0.25, 0.7, leaf_seg, leaf_rings, leaf_mat)


func _scatter_rocks() -> void:
	for i in range(ROCK_COUNT):
		var pos: Vector3 = _random_land_position(WATER_LEVEL + 0.2)
		if pos.distance_to(Vector3.ZERO) < 6.0:
			continue

		var rseg: int = [12, 18, 28][clampi(graphics_level, 0, 2)]
		var rrings: int = [6, 10, 16][clampi(graphics_level, 0, 2)]
		var rock := Node3D.new()
		rock.name = "Rock"

		var visual := MeshInstance3D.new()
		visual.name = "RockVisual"
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = randf_range(0.4, 1.2)
		rock_mesh.height = rock_mesh.radius * randf_range(0.65, 1.1)
		rock_mesh.radial_segments = rseg
		rock_mesh.rings = rrings
		visual.mesh = rock_mesh

		var rock_mat := StandardMaterial3D.new()
		var gray: float = randf_range(0.25, 0.5)
		rock_mat.albedo_color = Color(gray, gray, gray)
		rock_mat.roughness = 1.0
		visual.material_override = rock_mat

		rock.position = pos
		visual.position.y = rock_mesh.height * 0.25
		visual.scale = Vector3(randf_range(1.0, 1.8), randf_range(0.55, 1.0), randf_range(1.0, 1.8))
		visual.rotation_degrees = Vector3(randf_range(-12.0, 12.0), randf_range(0.0, 360.0), randf_range(-12.0, 12.0))
		rock.add_child(visual)

		var collision_height: float = rock_mesh.height * 0.45
		if collision_height < 0.3:
			collision_height = 0.3
		_add_cylinder_collision(rock, Vector3(0.0, collision_height * 0.5, 0.0), rock_mesh.radius * 0.55, collision_height)
		_add_generated_child(rock)


func _scatter_moon_lichen() -> void:
	for i in range(180):
		var pos: Vector3 = _random_land_position(-9999.0)
		if pos.distance_to(Vector3.ZERO) < 10.0:
			continue

		var body := RigidBody3D.new()
		body.name = "FloatingLichen"
		body.collision_layer = 1
		body.collision_mask = 1 | 2
		body.gravity_scale = 0.0
		body.linear_damp = 0.25
		body.angular_damp = 0.4
		body.mass = 0.2

		var physics_mat := PhysicsMaterial.new()
		physics_mat.bounce = 0.75
		physics_mat.friction = 0.1
		body.physics_material_override = physics_mat
		body.position = pos + Vector3(0.0, randf_range(1.4, 5.5), 0.0)

		var visual := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.45, 1.0)
		mesh.height = mesh.radius * randf_range(0.55, 0.9)
		visual.mesh = mesh
		visual.scale = Vector3(randf_range(1.0, 1.8), randf_range(0.45, 0.8), randf_range(1.0, 1.8))

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
		body.apply_impulse(Vector3(randf_range(-0.8, 0.8), randf_range(-0.15, 0.15), randf_range(-0.8, 0.8)))
		body.set_script(preload("res://scripts/FloatingLichen.gd"))
		body.add_to_group("floating_lichen")
		_add_generated_child(body)


func _scatter_moon_glass_craters() -> void:
	var half: float = _world_half_size()
	var cell_size: float = 100.0
	var min_cell: int = int(floor(-half / cell_size))
	var max_cell: int = int(ceil(half / cell_size))

	for cell_z in range(min_cell, max_cell + 1):
		for cell_x in range(min_cell, max_cell + 1):
			_try_place_glass_crater(cell_x, cell_z, half, cell_size)


func _try_place_glass_crater(cell_x: int, cell_z: int, half: float, cell_size: float) -> void:
	var s: int = _crater_seed(cell_x, cell_z)
	s = _lcg(s)
	var chance: float = float(s) / 4294967296.0
	if chance > 0.25:
		return

	s = _lcg(s)
	var ox: float = (float(s) / 4294967296.0) * 60.0 + 20.0
	s = _lcg(s)
	var oz: float = (float(s) / 4294967296.0) * 60.0 + 20.0
	var wx: float = float(cell_x) * cell_size + ox
	var wz: float = float(cell_z) * cell_size + oz

	if abs(wx) > half - 30.0 or abs(wz) > half - 30.0:
		return
	if sqrt(wx * wx + wz * wz) < 35.0:
		return
	var ground_y: float = _height_at_world(wx, wz)

	s = _lcg(s)
	var radius: float = (float(s) / 4294967296.0) * 5.0 + 4.0

	_create_glass_crater(Vector3(wx, ground_y, wz), radius, s)


func _crater_seed(cell_x: int, cell_z: int) -> int:
	return int((world_seed ^ (cell_x * 747796405) ^ (cell_z * 963546583) ^ 0x43724154) & 0xffffffff)


func _lcg(state: int) -> int:
	return int((1664525 * state + 1013904223) & 0xffffffff)


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
	if orb_count >= 9 and not discoveries.has("moon_pilgrim"):
		discoveries["moon_pilgrim"] = {
			"title": "Moon Pilgrim",
			"kind": "shrine_complete",
			"found_at": Time.get_unix_time_from_system(),
			"x": 0.0, "z": 0.0
		}
		map_record["discoveries"] = discoveries
		maps[current_map_id] = map_record
		world["maps"] = maps
		_set_world(current_world_id, world)
		_save_world_data()
		last_discovery_text = "Moon Pilgrim: all shrines completed!"
		_award_achievement("moon_pilgrim")


func _scatter_moon_platforms() -> void:
	var count := 9
	var spiral_turns := 2.5
	var rng_state: int = world_seed ^ 0x4D4F4F4E
	var half: float = _world_half_size()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.30, 0.28)
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.04, 0.10)
	mat.emission_energy_multiplier = 0.3

	for i in range(count):
		rng_state = _lcg(rng_state)
		var t: float = (float(i) + 1.0) / (float(count) + 1.0)
		var angle: float = t * TAU * spiral_turns
		var radius: float = 45.0 + t * 40.0
		var height: float = 8.0 + t * 35.0

		rng_state = _lcg(rng_state)
		var jx: float = (float(rng_state) / 4294967296.0 - 0.5) * 6.0
		rng_state = _lcg(rng_state)
		var jz: float = (float(rng_state) / 4294967296.0 - 0.5) * 6.0

		var wx: float = cos(angle) * radius + jx
		var wz: float = sin(angle) * radius + jz
		if abs(wx) > half - 20.0 or abs(wz) > half - 20.0:
			continue

		var plat := StaticBody3D.new()
		plat.name = "FloatingPlatform" + str(i)
		plat.position = Vector3(wx, height, wz)

		var col_shape := CollisionShape3D.new()
		var col := CylinderShape3D.new()
		col.radius = 2.5
		col.height = 0.4
		col_shape.shape = col
		plat.add_child(col_shape)

		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 2.2
		dm.bottom_radius = 2.5
		dm.height = 0.4
		disc.mesh = dm
		disc.material_override = mat
		plat.add_child(disc)

		var orb_mat := StandardMaterial3D.new()
		var hue: float = (float(i) / float(count)) * 0.3 + 0.55
		orb_mat.albedo_color = Color.from_hsv(hue, 0.8, 1.0)
		orb_mat.emission_enabled = true
		orb_mat.emission = orb_mat.albedo_color * 0.8
		orb_mat.emission_energy_multiplier = 2.0
		orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		orb_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		var orb := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.35
		om.height = 0.7
		orb.mesh = om
		orb.material_override = orb_mat
		orb.position = Vector3(0.0, 0.5, 0.0)
		plat.add_child(orb)

		var glow_ring := MeshInstance3D.new()
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.1, 0.2, 0.3, 0.2)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(0.05, 0.15, 0.30)
		ring_mat.emission_energy_multiplier = 1.5
		var rm := CylinderMesh.new()
		rm.top_radius = 1.5
		rm.bottom_radius = 1.5
		rm.height = 0.05
		glow_ring.mesh = rm
		glow_ring.material_override = ring_mat
		glow_ring.position = Vector3(0.0, -0.2, 0.0)
		plat.add_child(glow_ring)

		var base_pos := plat.position
		var bob_amp: float = randf_range(0.6, 1.2)
		var period: float = randf_range(2.0, 3.5)
		var tween := plat.create_tween()
		tween.set_loops()
		tween.tween_property(plat, "position", base_pos + Vector3(0.0, bob_amp, 0.0), period * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(plat, "position", base_pos - Vector3(0.0, bob_amp, 0.0), period * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		_add_discovery_area(plat, Vector3(0.0, 0.7, 0.0), 2.0, "moon_orb_" + str(i), "Moon Shrine " + str(i + 1), "orb")
		_add_generated_child(plat)


func _create_glass_crater(position: Vector3, radius: float, rng_seed: int) -> void:
	var crater := Node3D.new()
	crater.name = "GlassCrater"
	crater.position = position

	var s: int = rng_seed
	s = _lcg(s)
	var hue_shift: float = float(s) / 4294967296.0

	var glass := MeshInstance3D.new()
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = radius
	glass_mesh.bottom_radius = radius
	glass_mesh.height = 0.12
	glass.mesh = glass_mesh
	glass.position.y = 0.06

	var glass_mat := StandardMaterial3D.new()
	var glass_color := Color(0.12 + hue_shift * 0.15, 0.55 - hue_shift * 0.15, 0.78 - hue_shift * 0.2, 0.45)
	glass_mat.albedo_color = glass_color
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(glass_color.r * 0.4, glass_color.g * 0.6, glass_color.b * 0.8)
	glass_mat.emission_energy_multiplier = 0.6
	glass_mat.metallic = 0.3
	glass_mat.roughness = 0.15
	glass.material_override = glass_mat
	crater.add_child(glass)

	s = _lcg(s)
	var rim_thickness: float = (float(s) / 4294967296.0) * 0.6 + 0.4

	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.outer_radius = radius + rim_thickness
	rim_mesh.inner_radius = radius - rim_thickness * 0.5
	rim.mesh = rim_mesh
	rim.position.y = 0.04
	rim.rotation_degrees.x = 90.0
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.26, 0.28, 0.32)
	rim_mat.roughness = 1.0
	rim.material_override = rim_mat
	crater.add_child(rim)

	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.25 + hue_shift * 0.3, 0.65 - hue_shift * 0.2, 1.0)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.10, 0.35, 0.85)
	crystal_mat.emission_energy_multiplier = 0.8
	crystal_mat.roughness = 0.2

	s = _lcg(s)
	var shard_count: int = int((float(s) / 4294967296.0) * 3.0) + 2

	for i in range(shard_count):
		s = _lcg(s)
		var angle: float = (float(s) / 4294967296.0) * TAU
		s = _lcg(s)
		var shard_radius: float = (float(s) / 4294967296.0) * 0.25 + 0.15
		s = _lcg(s)
		var shard_height: float = (float(s) / 4294967296.0) * 1.2 + 0.6
		s = _lcg(s)
		var tilt: float = (float(s) / 4294967296.0) * 20.0 - 10.0

		var shard := MeshInstance3D.new()
		var shard_mesh := CylinderMesh.new()
		shard_mesh.top_radius = shard_radius * 0.3
		shard_mesh.bottom_radius = shard_radius
		shard_mesh.height = shard_height
		shard_mesh.radial_segments = 6
		shard.mesh = shard_mesh
		var dist: float = radius + rim_thickness * 2.0
		shard.position = Vector3(cos(angle) * dist, shard_height * 0.5, sin(angle) * dist)
		shard.rotation_degrees = Vector3(tilt, rad_to_deg(angle) + 90.0, tilt * 0.5)
		shard.material_override = crystal_mat

		_add_cylinder_collision(crater, shard.position, shard_radius, shard_height)
		crater.add_child(shard)

	_add_cylinder_collision(crater, Vector3(0.0, 0.06, 0.0), radius, 0.12)
	_add_discovery_area(crater, Vector3(0.0, 1.0, 0.0), radius * 0.8, "glass_crater_" + str(int(position.x)) + "_" + str(int(position.z)), "Glass Crater", "wonder")
	_add_generated_child(crater)


func _scatter_flowers() -> void:
	for i in range(FLOWER_COUNT):
		var pos: Vector3 = _random_land_position(WATER_LEVEL + 0.45)
		if pos.distance_to(Vector3.ZERO) < 7.0 or pos.y > 9.0:
			continue

		var flower := Node3D.new()
		flower.name = "WildflowerPatch"
		flower.position = pos
		flower.rotation_degrees.y = randf_range(0.0, 360.0)

		var stem_mat := StandardMaterial3D.new()
		stem_mat.albedo_color = Color(0.12, 0.35, 0.09)

		var blossom_mat := StandardMaterial3D.new()
		var palette: Array[Color] = [Color(0.95, 0.78, 0.18), Color(0.8, 0.25, 0.75), Color(0.95, 0.35, 0.25), Color(0.85, 0.9, 1.0)]
		blossom_mat.albedo_color = palette[randi_range(0, palette.size() - 1)]

		var f_seg: int = [6, 10, 16][clampi(graphics_level, 0, 2)]
		var f_rings: int = [4, 6, 10][clampi(graphics_level, 0, 2)]
		for j in range(randi_range(3, 7)):
			var stem := MeshInstance3D.new()
			var stem_mesh := CylinderMesh.new()
			stem_mesh.top_radius = 0.025
			stem_mesh.bottom_radius = 0.035
			stem_mesh.height = randf_range(0.25, 0.55)
			stem_mesh.radial_segments = f_seg
			stem.mesh = stem_mesh
			stem.material_override = stem_mat
			stem.position = Vector3(randf_range(-0.35, 0.35), stem_mesh.height * 0.5, randf_range(-0.35, 0.35))

			var blossom := MeshInstance3D.new()
			var blossom_mesh := SphereMesh.new()
			blossom_mesh.radius = randf_range(0.07, 0.13)
			blossom_mesh.height = blossom_mesh.radius * 0.6
			blossom_mesh.radial_segments = f_seg
			blossom_mesh.rings = f_rings
			blossom.mesh = blossom_mesh
			blossom.material_override = blossom_mat
			blossom.position = stem.position + Vector3(0.0, stem_mesh.height * 0.55, 0.0)

			flower.add_child(stem)
			flower.add_child(blossom)

		_add_generated_child(flower)


func _spawn_wonders() -> void:
	var half: float = float(GRID_SIZE) * CELL_SIZE * 0.5
	var min_cell: int = int(floor(-half / WONDER_CELL_SIZE))
	var max_cell: int = int(ceil(half / WONDER_CELL_SIZE))
	var wonder_count_local := 0

	for cell_z in range(min_cell, max_cell + 1):
		for cell_x in range(min_cell, max_cell + 1):
			if not WonderGenerator.cell_has_wonder(world_seed, cell_x, cell_z, WONDER_CHANCE):
				continue

			var wonder_pos: Vector3 = WonderGenerator.get_cell_wonder_position(world_seed, cell_x, cell_z, Callable(self, "_height_at_world"), WONDER_CELL_SIZE)
			if abs(wonder_pos.x) > half - 28.0 or abs(wonder_pos.z) > half - 28.0:
				continue
			if wonder_pos.y < WATER_LEVEL + 0.4 or _river_distance(wonder_pos.x, wonder_pos.z) < 9.0:
				continue
			if wonder_pos.distance_to(Vector3.ZERO) < 25.0:
				continue

			wonder_count_local += 1
			var wonder: Node3D = WonderGenerator.create_wonder(world_seed, wonder_pos, 0, true)
			var discovery_id: String = "wonder_" + str(cell_x) + "_" + str(cell_z)
			var title: String = _wonder_title(wonder.name)
			_add_discovery_area(wonder, Vector3(0.0, 2.0, 0.0), 12.0, discovery_id, title, "wonder")
			if title == "Moon Gate":
				_add_moon_gate_area(wonder)
			if title == "Gate Portal":
				_add_gate_portal_area(wonder)
			_add_generated_child(wonder)

	if wonder_count_local > 0 and current_world_id != "" and current_map_id != "":
		var w_world: Dictionary = _get_world(current_world_id)
		var w_maps: Dictionary = w_world.get("maps", {})
		var w_map_record: Dictionary = w_maps.get(current_map_id, {})
		w_map_record["wonder_count"] = wonder_count_local
		w_maps[current_map_id] = w_map_record
		w_world["maps"] = w_maps
		_set_world(current_world_id, w_world)
		_save_world_data()


func _wonder_title(wonder_name: String) -> String:
	if wonder_name.contains("moon_gate"):
		return "Moon Gate"
	if wonder_name.contains("crystal_spire"):
		return "Crystal Spire"
	if wonder_name.contains("runestone_circle"):
		return "Runestone Circle"
	if wonder_name.contains("floating_shrine"):
		return "Floating Shrine"
	if wonder_name.contains("gate_portal"):
		return "Gate Portal"
	return "Uncatalogued Wonder"


func _add_gate_portal_area(parent: Node3D) -> void:
	var area := Area3D.new()
	area.name = "GatePortalTrigger"
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector3(0.0, 2.0, 0.0)
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.5
	shape.height = 5.0
	shape_node.shape = shape
	area.add_child(shape_node)
	area.body_entered.connect(_on_gate_portal_body_entered)
	parent.add_child(area)


func _on_gate_portal_body_entered(body: Node3D) -> void:
	if body.name != "Player" or current_world_id == "":
		return
	if _is_current_map_gate_room() or _is_current_map_moon() or _is_current_map_water():
		return

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	if not maps.has("gate_room"):
		var gate_seed: int = int((world_seed ^ 0x47415445) & 0x7fffffff)
		if gate_seed == 0:
			gate_seed = 98765
		maps["gate_room"] = _create_gate_room_map_record(gate_seed)
		maps["gate_room"]["gate_room_return_world"] = current_world_id
		maps["gate_room"]["gate_room_return_map"] = current_map_id
		maps["gate_room"]["gate_room_slots"] = {}
		world["maps"] = maps
		_set_world(current_world_id, world)
		_save_world_data()

	last_discovery_text = "Stepping through the Gate Portal..."
	_load_map(current_world_id, "gate_room")


func _add_moon_gate_area(parent: Node3D) -> void:
	var area := Area3D.new()
	area.name = "MoonGateTrigger"
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector3(0.0, 3.0, 0.0)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 5.0, 2.2)
	shape_node.shape = shape
	area.add_child(shape_node)
	area.body_entered.connect(_on_moon_gate_body_entered)
	parent.add_child(area)


func _on_moon_gate_body_entered(body: Node3D) -> void:
	if body.name != "Player" or current_world_id == "" or _is_current_map_moon():
		return

	moon_map_return_map_id = current_map_id
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	if not maps.has("moon"):
		maps["moon"] = _create_moon_map_record(_moon_seed(world))
		world["maps"] = maps
		_set_world(current_world_id, world)
		_save_world_data()

	_load_map(current_world_id, "moon")


func _moon_seed(world: Dictionary) -> int:
	var root_map_id: String = str(world.get("root_map", ""))
	var maps: Dictionary = world.get("maps", {})
	var root_record: Dictionary = maps.get(root_map_id, {})
	var root_seed: int = int(root_record.get("seed", 12345))
	return int((root_seed ^ 0x4d4f4f4e) & 0x7fffffff)


func _scatter_crystals() -> void:
	for i in range(CRYSTAL_COUNT):
		var pos: Vector3 = _random_land_position(1.5)
		if pos.distance_to(Vector3.ZERO) < 15.0:
			continue

		var cluster := Node3D.new()
		cluster.name = "CrystalCluster"
		cluster.position = pos
		cluster.rotation_degrees.y = randf_range(0.0, 360.0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.85, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.08, 0.45, 0.75)
		mat.roughness = 0.25

		for j in range(randi_range(3, 6)):
			var crystal := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = randf_range(0.04, 0.10)
			mesh.bottom_radius = randf_range(0.22, 0.42)
			mesh.height = randf_range(1.0, 2.4)
			mesh.radial_segments = [6, 10, 16][clampi(graphics_level, 0, 2)]
			crystal.mesh = mesh
			crystal.material_override = mat
			crystal.position = Vector3(randf_range(-1.0, 1.0), mesh.height * 0.5, randf_range(-1.0, 1.0))
			crystal.rotation_degrees = Vector3(randf_range(-8.0, 8.0), randf_range(0.0, 360.0), randf_range(-8.0, 8.0))
			cluster.add_child(crystal)
			_add_cylinder_collision(cluster, crystal.position, mesh.bottom_radius, mesh.height)

		_add_discovery_area(cluster, Vector3(0.0, 1.0, 0.0), 5.5, "crystal_" + str(i), "Glimmering Crystal Cluster", "wonder")
		_add_generated_child(cluster)


func _scatter_ruins() -> void:
	for i in range(RUIN_COUNT):
		var pos: Vector3 = _random_land_position(WATER_LEVEL + 1.0)
		if pos.distance_to(Vector3.ZERO) < 30.0:
			continue

		var ruin := Node3D.new()
		ruin.name = "AncientRuin"
		ruin.position = pos
		ruin.rotation_degrees.y = randf_range(0.0, 360.0)

		var mat := StandardMaterial3D.new()
		var tone: float = randf_range(0.38, 0.52)
		mat.albedo_color = Color(tone, tone * 0.95, tone * 0.85)
		mat.roughness = 1.0

		var pillar_count: int = randi_range(3, 6)
		for j in range(pillar_count):
			var angle: float = TAU * float(j) / float(pillar_count)
			var radius: float = randf_range(2.2, 3.8)
			var height: float = randf_range(1.2, 3.6)

			var pillar := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(randf_range(0.45, 0.75), height, randf_range(0.45, 0.75))
			pillar.mesh = mesh
			pillar.material_override = mat
			pillar.position = Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius)
			pillar.rotation_degrees = Vector3(randf_range(-5.0, 5.0), randf_range(0.0, 360.0), randf_range(-5.0, 5.0))
			ruin.add_child(pillar)
			_add_box_collision(ruin, pillar.position, mesh.size)

		var platform := MeshInstance3D.new()
		var platform_mesh := CylinderMesh.new()
		platform_mesh.top_radius = randf_range(3.0, 4.5)
		platform_mesh.bottom_radius = platform_mesh.top_radius * 1.05
		platform_mesh.height = 0.25
		platform.mesh = platform_mesh
		platform.material_override = mat
		platform.position.y = 0.12
		ruin.add_child(platform)
		_add_cylinder_collision(ruin, Vector3(0.0, platform.position.y, 0.0), platform_mesh.top_radius, platform_mesh.height)
		_add_discovery_area(ruin, Vector3.ZERO, 7.0, "ruin_" + str(i), "Weathered Gate-Ruin", "ruin")

		_add_generated_child(ruin)


const _BirdFlockScene := preload("res://scripts/BirdFlock.gd")
const _FishSchoolScene := preload("res://scripts/FishSchool.gd")


func _scatter_bird_flocks() -> void:
	var placed := 0
	var attempts := 0
	while placed < 4 and attempts < 60:
		attempts += 1
		var pos: Vector3 = _random_land_position(WATER_LEVEL + 1.0)
		if pos.distance_to(Vector3.ZERO) < 60.0:
			continue
		var flock: Node3D = _BirdFlockScene.new()
		flock.set("bird_count", randi_range(8, 15))
		flock.set("mesh_quality", graphics_level)
		flock.position = Vector3(pos.x, randf_range(8.0, 18.0), pos.z)
		_add_generated_child(flock)
		placed += 1


func _scatter_underwater_plants() -> void:
	var plant_count: int = 180 if _is_current_map_water() else 100
	for i in range(plant_count):
		var pos: Vector3 = _random_underwater_position(WATER_LEVEL - 0.2)
		if pos.y < WATER_LEVEL - 7.0:
			continue
		if _river_distance(pos.x, pos.z) < 8.0:
			continue
		if pos.distance_to(Vector3.ZERO) < 20.0:
			continue

		var plant := Node3D.new()
		plant.name = "WaterPlant"
		plant.position = pos

		var height: float = randf_range(0.6, 1.8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(randf_range(0.06, 0.20), randf_range(0.20, 0.40), randf_range(0.04, 0.12))

		var stem := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.02
		sm.bottom_radius = 0.04
		sm.height = height
		sm.radial_segments = [4, 6, 8][clampi(graphics_level, 0, 2)]
		stem.mesh = sm
		stem.material_override = mat
		stem.position.y = height * 0.5
		plant.add_child(stem)

		var frond := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = randf_range(0.06, 0.12)
		fm.height = fm.radius * 0.7
		fm.radial_segments = 6
		fm.rings = 4
		frond.mesh = fm
		frond.material_override = mat
		frond.position.y = height
		plant.add_child(frond)

		var sway := plant.create_tween()
		sway.set_loops()
		var amp: float = randf_range(0.04, 0.10)
		var per: float = randf_range(2.0, 4.0)
		sway.tween_property(plant, "rotation:z", amp, per * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		sway.tween_property(plant, "rotation:z", -amp, per * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		_add_generated_child(plant)


func _scatter_fish_schools() -> void:
	var target: int = 12 if _is_current_map_water() else 5
	var placed := 0
	var attempts := 0
	while placed < target and attempts < target * 15:
		attempts += 1
		var ground: Vector3 = _random_underwater_position(WATER_LEVEL - 0.5)
		if ground.y < WATER_LEVEL - 8.0:
			continue
		if _river_distance(ground.x, ground.z) < 8.0:
			continue
		var school: Node3D = _FishSchoolScene.new()
		school.set("fish_count", randi_range(10, 18))
		school.set("mesh_quality", graphics_level)
		var water_depth: float = WATER_LEVEL - ground.y
		var height_offset: float = randf_range(0.3, 0.7)
		school.position = Vector3(ground.x, ground.y + water_depth * height_offset, ground.z)
		_add_generated_child(school)
		placed += 1


func _scatter_gate_room_gates() -> void:
	var slot_count: int = 12
	var half_spread: float = 1.1
	var radius: float = 22.0
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(0.22, 0.18, 0.28)
	gate_mat.roughness = 0.9
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.6, 0.5, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.4, 0.3, 0.8)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var map_record: Dictionary = _get_current_map_record()
	var slots: Dictionary = map_record.get("gate_room_slots", {})
	var worlds: Dictionary = save_data.get("worlds", {})

	for i in range(slot_count):
		var t: float = float(i) / float(slot_count - 1)
		var angle: float = lerp(-half_spread, half_spread, t)
		var x: float = sin(angle) * radius
		var z: float = cos(angle) * radius

		var gate := Node3D.new()
		gate.name = "GateRoomGate" + str(i)
		gate.position = Vector3(x, 0.0, z)
		gate.rotation.y = -angle

		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.25, 3.5, 0.25)
		var left_post := MeshInstance3D.new()
		left_post.mesh = post_mesh
		left_post.position = Vector3(-1.0, 1.75, 0.0)
		left_post.material_override = gate_mat
		gate.add_child(left_post)
		var right_post := MeshInstance3D.new()
		right_post.mesh = post_mesh
		right_post.position = Vector3(1.0, 1.75, 0.0)
		right_post.material_override = gate_mat
		gate.add_child(right_post)

		var arch_mesh := BoxMesh.new()
		arch_mesh.size = Vector3(2.5, 0.2, 0.25)
		var arch := MeshInstance3D.new()
		arch.mesh = arch_mesh
		arch.position = Vector3(0.0, 3.6, 0.0)
		arch.material_override = gate_mat
		gate.add_child(arch)

		var glow := MeshInstance3D.new()
		var glow_mesh := BoxMesh.new()
		glow_mesh.size = Vector3(1.8, 2.8, 0.05)
		glow.mesh = glow_mesh
		glow.position = Vector3(0.0, 2.0, 0.06)
		glow.material_override = glow_mat
		gate.add_child(glow)

		var slot_key: String = str(i)
		var target_world_id: String = str(slots.get(slot_key, ""))
		var world_name: String = "Gate " + str(i + 1)
		if target_world_id != "" and worlds.has(target_world_id):
			world_name = str(worlds[target_world_id].get("name", "Gate " + str(i + 1)))

		var label := Label3D.new()
		label.text = world_name
		label.font_size = 16
		label.modulate = Color(0.9, 0.85, 1.0)
		label.position = Vector3(0.0, 4.6, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.no_depth_test = true
		gate.add_child(label)

		var area := Area3D.new()
		area.name = "GateRoomGateTrigger"
		area.collision_layer = 0
		area.collision_mask = 2
		var area_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.2, 3.0, 1.2)
		area_shape.shape = box
		area_shape.position = Vector3(0.0, 1.8, 0.0)
		area.add_child(area_shape)
		area.body_entered.connect(_on_gate_room_gate_body_entered.bind(i))
		area.add_to_group("gate_room_gates")
		gate.add_child(area)

		var discovery_id: String = "gate_room_gate_" + str(i)
		var discovery_title: String = "World Gate " + str(i + 1) + " (" + world_name + ")"
		_add_discovery_area(gate, Vector3(0.0, 2.0, 0.0), 5.0, discovery_id, discovery_title, "gate")

		_add_generated_child(gate)

	var return_mat := StandardMaterial3D.new()
	return_mat.albedo_color = Color(0.25, 0.18, 0.35)
	return_mat.roughness = 0.85
	var return_area := Area3D.new()
	return_area.name = "GateRoomReturnTrigger"
	return_area.collision_layer = 0
	return_area.collision_mask = 2
	var return_shape := CollisionShape3D.new()
	var return_box := BoxShape3D.new()
	return_box.size = Vector3(6.0, 4.0, 2.0)
	return_shape.shape = return_box
	return_area.add_child(return_shape)
	return_area.position = Vector3(0.0, 2.0, 30.0)
	return_area.body_entered.connect(_on_gate_room_return_body_entered)
	_add_generated_child(return_area)

	var return_mesh := MeshInstance3D.new()
	var return_mesh_shape := BoxMesh.new()
	return_mesh_shape.size = Vector3(6.0, 4.0, 0.3)
	return_mesh.mesh = return_mesh_shape
	return_mesh.material_override = return_mat
	return_mesh.position = Vector3(0.0, 2.0, 30.0)
	_add_generated_child(return_mesh)

	var return_label := Label3D.new()
	return_label.text = "Return"
	return_label.font_size = 20
	return_label.modulate = Color(0.7, 0.6, 1.0)
	return_label.position = Vector3(0.0, 4.5, 30.0)
	return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_label.no_depth_test = true
	_add_generated_child(return_label)


func _get_current_map_record() -> Dictionary:
	if current_world_id == "" or current_map_id == "":
		return {}
	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	return maps.get(current_map_id, {})


func _create_gates() -> void:
	var gate_positions: Array[Vector3] = [
		_find_gate_position(Vector3(1.0, 0.0, 0.0)),
		_find_gate_position(Vector3(-1.0, 0.0, 0.0)),
		_find_gate_position(Vector3(0.0, 0.0, 1.0)),
		_find_gate_position(Vector3(0.0, 0.0, -1.0))
	]

	for gate_index in range(GATE_COUNT):
		var gate := Node3D.new()
		gate.name = "WorldGate" + str(gate_index + 1)
		gate.position = gate_positions[gate_index]
		var to_center: Vector3 = Vector3.ZERO - gate.position
		gate.rotation.y = atan2(to_center.x, to_center.z)

		var left_post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.22
		post_mesh.bottom_radius = 0.28
		post_mesh.height = 4.0
		left_post.mesh = post_mesh
		left_post.position = Vector3(-1.1, 2.0, 0.0)
		left_post.material_override = _gate_material()

		var right_post := MeshInstance3D.new()
		right_post.mesh = post_mesh
		right_post.position = Vector3(1.1, 2.0, 0.0)
		right_post.material_override = left_post.material_override

		var arch := MeshInstance3D.new()
		var arch_mesh := BoxMesh.new()
		arch_mesh.size = Vector3(2.8, 0.35, 0.5)
		arch.mesh = arch_mesh
		arch.position = Vector3(0.0, 4.0, 0.0)
		arch.material_override = left_post.material_override

		var glow := MeshInstance3D.new()
		var glow_mesh := PlaneMesh.new()
		glow_mesh.size = Vector2(1.6, 2.7)
		glow.mesh = glow_mesh
		glow.position = Vector3(0.0, 2.0, 0.03)
		glow.rotation_degrees.x = 90.0
		var glow_mat: StandardMaterial3D = _gate_glow_material(gate_index)
		glow.material_override = glow_mat
		var shimmer_tween := gate.create_tween()
		shimmer_tween.set_loops()
		var sh_dur: float = randf_range(0.8, 1.4)
		shimmer_tween.tween_property(glow_mat, "emission_energy_multiplier", 2.5, sh_dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		shimmer_tween.tween_property(glow_mat, "emission_energy_multiplier", 0.8, sh_dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		gate.add_child(left_post)
		gate.add_child(right_post)
		gate.add_child(arch)
		gate.add_child(glow)
		_add_cylinder_collision(gate, left_post.position, 0.32, post_mesh.height)
		_add_cylinder_collision(gate, right_post.position, 0.32, post_mesh.height)
		_add_box_collision(gate, arch.position, arch_mesh.size)

		var area := Area3D.new()
		area.name = "GateTrigger"
		area.collision_layer = 0
		area.collision_mask = 2
		var area_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.5, 2.6, 1.2)
		area_shape.shape = box
		area_shape.position = Vector3(0.0, 1.6, 0.0)
		area.add_child(area_shape)
		area.body_entered.connect(_on_gate_body_entered.bind(gate_index))
		gate.add_child(area)
		_add_discovery_area(gate, Vector3(0.0, 1.8, 0.0), 5.0, "gate_" + str(gate_index), "World Gate " + str(gate_index + 1), "gate")
		_add_gate_audio(gate, gate_index)

		_add_generated_child(gate)


func _on_gate_body_entered(body: Node3D, gate_index: int) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		return

	_award_achievement("gate_crasher")

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var gates: Dictionary = map_record.get("gates", {})
	var gate_key: String = str(gate_index)
	var target_map_id: String = str(gates.get(gate_key, ""))

	if target_map_id == "":
		if maps.size() >= 32:
			last_discovery_text = "Atlas saturated — no more maps can unfold in this world."
			return

		var gate_seed: int = _preview_gate_seed(gate_index)

		if not maps.has("gate_room") and (gate_seed % 20) == 0:
			target_map_id = "gate_room"
			maps[target_map_id] = _create_gate_room_map_record(gate_seed)
			maps[target_map_id]["gate_room_return_world"] = current_world_id
			maps[target_map_id]["gate_room_return_map"] = current_map_id
			maps[target_map_id]["gate_room_slots"] = {}
			gates[gate_key] = target_map_id
			map_record["gates"] = gates
			maps[current_map_id] = map_record
			world["maps"] = maps
			_set_world(current_world_id, world)
			_save_world_data()
			_load_map(current_world_id, target_map_id)
			return

		target_map_id = _new_id("map")
		var is_water: bool = (gate_seed % 100) < 25
		var target_record: Dictionary = _create_water_map_record(gate_seed) if is_water else _create_map_record(gate_seed)
		var target_gates: Dictionary = target_record.get("gates", {})
		target_gates[str(_opposite_gate_index(gate_index))] = current_map_id
		target_record["gates"] = target_gates
		maps[target_map_id] = target_record
		gates[gate_key] = target_map_id
		map_record["gates"] = gates
		maps[current_map_id] = map_record
		world["maps"] = maps
		_set_world(current_world_id, world)
		_save_world_data()

	_load_map(current_world_id, target_map_id)


func _opposite_gate_index(gate_index: int) -> int:
	if gate_index == 0:
		return 1
	if gate_index == 1:
		return 0
	if gate_index == 2:
		return 3
	return 2


func _find_gate_position(direction: Vector3) -> Vector3:
	var max_distance: float = float(GRID_SIZE) * CELL_SIZE * 0.36
	for step in range(8):
		var distance: float = max_distance - float(step) * 12.0
		var x: float = direction.x * distance
		var z: float = direction.z * distance
		var pos: Vector3 = Vector3(x, _height_at_world(x, z) + 0.65, z)
		if pos.y > WATER_LEVEL + 0.5 and _river_distance(x, z) > 9.0:
			return pos

	var fallback_x: float = direction.x * max_distance
	var fallback_z: float = direction.z * max_distance
	return Vector3(fallback_x, _height_at_world(fallback_x, fallback_z) + 0.65, fallback_z)


func _on_gate_room_gate_body_entered(body: Node3D, slot_index: int) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		return
	if not _is_current_map_gate_room():
		return

	var map_record: Dictionary = _get_current_map_record()
	var slots: Dictionary = map_record.get("gate_room_slots", {})
	var slot_key: String = str(slot_index)
	var target_world_id: String = str(slots.get(slot_key, ""))
	var worlds: Dictionary = save_data.get("worlds", {})

	if target_world_id == "" or not worlds.has(target_world_id):
		var map_seed: int = int((world_seed ^ ((slot_index + 1) * 747796405) ^ 912839201) & 0x7fffffff)
		if map_seed == 0:
			map_seed = 12345 + slot_index
		var root_map_id: String = _new_id("map")
		target_world_id = _new_id("world")
		var world_name: String = "World " + str(slot_index + 1)
		var world_record: Dictionary = _create_world_record(world_name, root_map_id, map_seed)
		var root_map: Dictionary = world_record["maps"][root_map_id]
		world_record["maps"][root_map_id] = root_map
		world_record["gate_room_source_world"] = current_world_id
		world_record["gate_room_source_map"] = current_map_id
		worlds[target_world_id] = world_record
		save_data["worlds"] = worlds
		_save_world_data()

		slots[slot_key] = target_world_id
		map_record["gate_room_slots"] = slots
		var current_maps: Dictionary = (_get_world(current_world_id)).get("maps", {})
		current_maps[current_map_id] = map_record
		var w: Dictionary = _get_world(current_world_id)
		w["maps"] = current_maps
		_set_world(current_world_id, w)
		_save_world_data()

		var target_maps: Dictionary = world_record.get("maps", {})
		var target_map_record: Dictionary = target_maps.get(root_map_id, {})
		target_map_record["gate_room_slot_gate_0"] = current_world_id
		target_map_record["gate_room_slot_gate_1"] = current_map_id
		target_map_record["gate_room_slot_gate_2"] = str(slot_index)
		target_maps[root_map_id] = target_map_record
		world_record["maps"] = target_maps
		worlds[target_world_id] = world_record
		save_data["worlds"] = worlds
		_save_world_data()

		last_discovery_text = "World " + world_name + " unfolded from the Gate Room."
		_load_map(target_world_id, root_map_id)
	else:
		var world_record: Dictionary = worlds[target_world_id]
		var root_map_id: String = str(world_record.get("root_map", ""))
		last_discovery_text = "Returning to " + str(world_record.get("name", target_world_id))
		_load_map(target_world_id, root_map_id)


func _on_gate_room_return_body_entered(body: Node3D) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		return
	if not _is_current_map_gate_room():
		return

	var map_record: Dictionary = _get_current_map_record()
	var return_world: String = str(map_record.get("gate_room_return_world", ""))
	var return_map: String = str(map_record.get("gate_room_return_map", ""))
	if return_world != "" and return_map != "":
		last_discovery_text = "Returning from Gate Room."
		_load_map(return_world, return_map)


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
			_award_achievement("lichen_catcher")
		closest.queue_free()
		lichen_count += 1
		if is_instance_valid(player) and player.has_method(&"set"):
			player.set("lichen_count", lichen_count)
		last_discovery_text = "Grabbed lichen. Carry: " + str(lichen_count)
		if lichen_count >= 50:
			_award_achievement("collector_50")


func _throw_lichen() -> void:
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

	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.75
	phys_mat.friction = 0.1
	body.physics_material_override = phys_mat

	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = randf_range(0.4, 0.8)
	mesh.height = mesh.radius * randf_range(0.55, 0.9)
	visual.mesh = mesh
	visual.scale = Vector3(randf_range(1.0, 1.5), randf_range(0.45, 0.8), randf_range(1.0, 1.5))

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


func _find_closest_lichen(from: Vector3, max_dist: float) -> Node3D:
	if generated_root == null:
		return null
	var closest: Node3D = null
	var closest_dist: float = max_dist
	for child in generated_root.get_children():
		if child.is_in_group("floating_lichen") and is_instance_valid(child):
			var dist: float = child.global_position.distance_to(from)
			if dist < closest_dist:
				closest_dist = dist
				closest = child
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
		last_discovery_text = "Returning to Gate Room."
		_load_map(src_world, src_map)


func _gate_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.24, 0.30)
	mat.roughness = 0.95
	return mat


func _gate_glow_material(gate_index: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _seed_color(_gate_target_seed(gate_index), 0.50)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b)
	mat.emission_energy_multiplier = 1.6
	return mat


func _gate_target_seed(gate_index: int) -> int:
	if current_world_id == "" or current_map_id == "":
		return _preview_gate_seed(gate_index)

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var gates: Dictionary = map_record.get("gates", {})
	var target_map_id: String = str(gates.get(str(gate_index), ""))
	if target_map_id != "" and maps.has(target_map_id):
		var target_record: Dictionary = maps[target_map_id]
		return int(target_record.get("seed", _preview_gate_seed(gate_index)))

	return _preview_gate_seed(gate_index)


func _preview_gate_seed(gate_index: int) -> int:
	var value: int = int((world_seed ^ ((gate_index + 1) * 747796405) ^ 2891336453) & 0x7fffffff)
	if value == 0:
		value = 12345 + gate_index
	return value


func _seed_color(seed_value: int, alpha: float = 1.0) -> Color:
	var hue: float = float(abs(seed_value) % 360) / 360.0
	return Color.from_hsv(hue, 0.72, 1.0, alpha)


func _setup_music() -> void:
	var dir := DirAccess.open("res://audio/music")
	if dir == null:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".ogg") or fname.ends_with(".mp3") or fname.ends_with(".wav"):
			files.append("res://audio/music/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	if files.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.stream = load(files[randi() % files.size()])
	player.autoplay = true
	player.volume_db = -14.0
	_add_generated_child(player)


func _generate_wav_stream(freqs: Array[float], duration: float, vol: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var fade: int = int(sample_rate * 0.02)
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var s: float = 0.0
		for f in freqs:
			s += sin(TAU * f * t)
		s /= float(freqs.size())
		var env: float = 1.0
		if i < fade:
			env = float(i) / float(fade)
		elif i > num_samples - fade:
			env = float(num_samples - i) / float(fade)
		s *= env * vol
		data.encode_s16(i * 2, int(clamp(s * 30000.0, -32768.0, 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _setup_moon_audio() -> void:
	var p := AudioStreamPlayer.new()
	p.name = "MoonDrone"
	p.volume_db = -2.0
	p.stream = _generate_wav_stream([55.0, 72.0, 88.0, 105.0, 220.0, 330.0, 440.0], 8.0, 0.50)
	_add_generated_child(p)
	p.play()


func _setup_water_audio() -> void:
	var p := AudioStreamPlayer.new()
	p.name = "WaterAmbient"
	p.volume_db = -3.0
	p.stream = _generate_wav_stream([75.0, 92.0, 110.0, 220.0, 440.0, 660.0], 6.0, 0.50)
	_add_generated_child(p)
	p.play()


func _add_gate_audio(gate: Node3D, _gate_index: int) -> void:
	var p := AudioStreamPlayer3D.new()
	p.name = "GateHum"
	p.volume_db = -2.0
	p.max_distance = 100.0
	p.attenuation_model = 1
	p.position = Vector3(0.0, 2.0, 0.0)
	p.stream = _generate_wav_stream([330.0, 440.0, 550.0], 4.0, 0.25)
	gate.add_child(p)
	p.call_deferred("play")


func _add_box_collision(parent: Node3D, local_position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = local_position
	body.add_child(shape_node)
	parent.add_child(body)


func _add_cylinder_collision(parent: Node3D, local_position: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	shape_node.shape = shape
	shape_node.position = local_position
	body.add_child(shape_node)
	parent.add_child(body)


func _add_sphere_collision(parent: Node3D, local_position: Vector3, radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	shape_node.shape = shape
	shape_node.position = local_position
	body.add_child(shape_node)
	parent.add_child(body)


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


func _random_position() -> Vector3:
	var half: float = float(GRID_SIZE) * CELL_SIZE * 0.44
	var x: float = randf_range(-half, half)
	var z: float = randf_range(-half, half)
	return Vector3(x, _height_at_world(x, z), z)


func _random_land_position(min_height: float) -> Vector3:
	for i in range(18):
		var pos: Vector3 = _random_position()
		if pos.y >= min_height:
			return pos

	return _random_position()


func _random_underwater_position(max_height: float) -> Vector3:
	for i in range(30):
		var pos: Vector3 = _random_position()
		if pos.y <= max_height:
			return pos
	return _random_position()


func _terrain_color(pos: Vector3) -> Color:
	if _is_current_map_gate_room() or _is_current_map_map_nexus():
		return Color(0.10, 0.11, 0.14)

	if _is_current_map_cave():
		return Color(0.12, 0.10, 0.08)

	if _is_current_map_moon():
		if pos.y > 4.0:
			return Color(0.34, 0.36, 0.43)
		if pos.y < -2.0:
			return Color(0.16, 0.17, 0.21)
		return Color(0.25, 0.26, 0.31)

	if _is_current_map_water():
		if pos.y > WATER_LEVEL + 0.25:
			return Color(0.62, 0.55, 0.34)
		return Color(0.28, 0.25, 0.18)

	var river: float = _river_distance(pos.x, pos.z)
	if pos.y <= WATER_LEVEL + 0.25 or river < 7.5:
		return Color(0.42, 0.34, 0.18)
	if pos.y > 12.0:
		return Color(0.48, 0.48, 0.44)
	if pos.y > 7.5:
		return Color(0.30, 0.38, 0.22)
	if _biome_value(pos.x, pos.z) > 0.28:
		return Color(0.18, 0.47, 0.17)
	return Color(0.24, 0.43, 0.18)


func _biome_value(wx: float, wz: float) -> float:
	return noise.get_noise_2d(wx * 0.28 - 2500.0, wz * 0.28 + 1700.0)


func _river_distance(wx: float, wz: float) -> float:
	var curve: float = sin(wx * 0.025) * 22.0 + noise.get_noise_2d(wx * 0.2 + 3200.0, 410.0) * 16.0
	return abs(wz - curve)


func _smooth_falloff(value: float, edge0: float, edge1: float) -> float:
	var t: float = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)
