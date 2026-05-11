extends Node3D

const WonderGenerator = preload("res://scripts/WonderGenerator.gd")

const GRID_SIZE: int = 224
const CELL_SIZE: float = 2.0

# Larger worlds need broader terrain forms so the space does not feel flat.
const HEIGHT_SCALE: float = 15.0
const WATER_LEVEL: float = -1.7

const TREE_COUNT: int = 720
const ROCK_COUNT: int = 260
const FLOWER_COUNT: int = 520
const CRYSTAL_COUNT: int = 42
const RUIN_COUNT: int = 14
const GATE_COUNT: int = 4
const WONDER_CELL_SIZE: float = 96.0
const WONDER_CHANCE: float = 0.20
const SAVE_PATH: String = "user://world_graphs.json"

var noise: FastNoiseLite = FastNoiseLite.new()
var world_seed: int = 12345
var height_values: PackedFloat32Array = PackedFloat32Array()
var generated_root: Node3D
var menu_layer: CanvasLayer
var hud_layer: CanvasLayer
var hud_label: Label
var stamina_bar: ProgressBar
var minimap_panel: PanelContainer
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
	_load_save_data()
	_ensure_default_world()
	var last_world_id: String = str(save_data.get("last_world_id", ""))
	if last_world_id != "":
		_load_world_from_menu(last_world_id)
	_show_main_menu()

	print("Random World Explorer v6: worlds are saved to ", SAVE_PATH)
	print("Random World Explorer v6: press F11 to toggle fullscreen")
	print("Random World Explorer v6: press F10 to force 1280x720 windowed mode")


func _process(_delta: float) -> void:
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

		if event.keycode == KEY_M:
			_show_main_menu()


func _load_save_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				save_data = parsed

	if not save_data.has("worlds"):
		save_data = {"worlds": {}, "last_world_id": ""}


func _save_world_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing: " + SAVE_PATH)
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


func _show_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu_layer != null:
		menu_layer.queue_free()

	menu_layer = CanvasLayer.new()
	menu_layer.name = "WorldMenuLayer"
	menu_layer.layer = 30
	add_child(menu_layer)

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

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	margin.add_child(list)

	var title := Label.new()
	title.text = "Random World Explorer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	list.add_child(title)

	var story := Label.new()
	story.text = _backstory_text()
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 14)
	list.add_child(story)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	list.add_child(button_row)

	var new_button := Button.new()
	new_button.text = "Create New World"
	new_button.pressed.connect(_create_new_world)
	button_row.add_child(new_button)

	var worlds: Dictionary = save_data.get("worlds", {})
	for world_key in worlds.keys():
		var world_id: String = str(world_key)
		var world: Dictionary = worlds[world_id]
		var button := Button.new()
		button.text = "Load " + str(world.get("name", world_id))
		button.pressed.connect(_load_world_from_menu.bind(world_id))
		button_row.add_child(button)

	if current_world_id != "":
		var resume_button := Button.new()
		resume_button.text = "Resume Current Map"
		resume_button.pressed.connect(_close_menu)
		button_row.add_child(resume_button)

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

	list.add_child(_create_atlas_graph_view())

	var hint := Label.new()
	hint.text = "Objective: restore the Atlas by finding wonders and gates.\nM: menu  |  F10: windowed  |  F11: fullscreen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	list.add_child(hint)


func _close_menu() -> void:
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _create_new_world() -> void:
	var world_id: String = _new_id("world")
	var root_map_id: String = _new_id("map")
	var world_name: String = "World " + str(save_data.get("worlds", {}).size() + 1)

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


func _create_map_record(map_seed: int) -> Dictionary:
	return {"seed": map_seed, "gates": {}, "discoveries": {}, "type": "normal"}


func _create_moon_map_record(map_seed: int) -> Dictionary:
	return {"seed": map_seed, "gates": {}, "discoveries": {}, "type": "moon"}


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
	return "The old Atlas of Gates broke apart, leaving whole worlds adrift behind forgotten portals. You are a field cartographer for the last observatory, sent to cross the gates, name what remains, and stitch the lost routes back into a living map."


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


func _create_atlas_graph_view() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(700.0, 240.0)
	container.stretch = true

	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	container.add_child(viewport)

	var root := Node3D.new()
	viewport.add_child(root)

	var world_3d := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.008, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.16, 0.22)
	world_3d.environment = env
	viewport.world_3d = world_3d

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
	return container


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


func _is_current_map_moon() -> bool:
	if current_world_id == "" or current_map_id == "":
		return false

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	return str(map_record.get("type", "normal")) == "moon"


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


func _on_discovery_body_entered(body: Node3D, discovery_id: String, title: String, kind: String, discovery_position: Vector3) -> void:
	if body.name == "Player":
		_record_discovery(discovery_id, title, kind, discovery_position)


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
	_clear_generated_map()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedMap"
	add_child(generated_root)
	_apply_map_atmosphere()

	_setup_noise()
	_build_height_values()
	_create_terrain_mesh()
	_create_terrain_collision()
	_create_world_bounds()
	if not _is_current_map_moon():
		_create_water()
	else:
		_create_moon_sky()
	_spawn_player()
	if _is_current_map_moon():
		_scatter_moon_lichen()
	else:
		_scatter_trees()
		_scatter_rocks()
		_scatter_flowers()
		_spawn_wonders()
		_scatter_crystals()
		_scatter_ruins()
	_create_gates()
	_store_current_map_available_discoveries()

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
	env.fog_enabled = true
	env.fog_density = 0.010
	env.fog_light_color = Color(0.65, 0.75, 0.85)
	world_environment = env

	env_node.environment = env
	add_child(env_node)


func _apply_map_atmosphere() -> void:
	if world_environment == null:
		return

	if _is_current_map_moon():
		world_environment.background_color = Color(0.006, 0.008, 0.020)
		world_environment.ambient_light_color = Color(0.20, 0.24, 0.34)
		world_environment.ambient_light_energy = 0.38
		world_environment.fog_density = 0.004
		world_environment.fog_light_color = Color(0.18, 0.22, 0.34)
		if sun_light != null:
			sun_light.light_color = Color(0.78, 0.86, 1.0)
			sun_light.light_energy = 1.45
			sun_light.rotation_degrees = Vector3(-28.0, -62.0, 0.0)
	else:
		world_environment.background_color = Color(0.55, 0.72, 0.95)
		world_environment.ambient_light_color = Color(0.7, 0.78, 0.86)
		world_environment.ambient_light_energy = 0.8
		world_environment.fog_density = 0.010
		world_environment.fog_light_color = Color(0.65, 0.75, 0.85)
		if sun_light != null:
			sun_light.light_color = Color.WHITE
			sun_light.light_energy = 3.0
			sun_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)


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
	panel.offset_right = 360.0
	panel.offset_bottom = 425.0
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
	hud_label.add_theme_font_size_override("font_size", 14)
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stack.add_child(hud_label)

	var stamina_label := Label.new()
	stamina_label.text = "Sprint"
	stamina_label.add_theme_font_size_override("font_size", 12)
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

	minimap_panel = PanelContainer.new()
	minimap_panel.custom_minimum_size = Vector2(160.0, 160.0)
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_stack.add_child(minimap_panel)

	minimap_marker_layer = Control.new()
	minimap_marker_layer.custom_minimum_size = Vector2(160.0, 160.0)
	minimap_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(minimap_marker_layer)


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
		var half: float = float(GRID_SIZE) * CELL_SIZE * 0.5
		var distance_to_edge: float = half - max(abs(player.global_position.x), abs(player.global_position.z))
		position_text = "Position: " + str(int(player.global_position.x)) + ", " + str(int(player.global_position.z)) + " | edge " + str(max(int(distance_to_edge), 0)) + "m"
		if is_underwater:
			warning_text = "Underwater: Space swims upward"
		elif distance_to_edge < 18.0:
			warning_text = "Edge barrier nearby"

		if stamina_bar != null and player.get("sprint_stamina") != null:
			stamina_bar.value = float(player.get("sprint_stamina"))

	var discovery_line: String = last_discovery_text
	if discovery_line == "":
		discovery_line = "Seek gates, ruins, and wonders."

	hud_label.text = _atlas_summary_text() + "\nMap " + map_short + ": " + _map_completion_text(current_map_id) + "\n" + position_text + "\n" + discovery_line
	if warning_text != "":
		hud_label.text += "\n" + warning_text

	_update_minimap()


func _update_minimap() -> void:
	if minimap_marker_layer == null:
		return

	for child in minimap_marker_layer.get_children():
		child.queue_free()

	var size: float = 160.0
	var half: float = float(GRID_SIZE) * CELL_SIZE * 0.5
	var player: CharacterBody3D = _get_player()
	if player != null:
		_add_minimap_dot(_world_to_minimap(player.global_position.x, player.global_position.z, size, half), Color.WHITE, 5.0)

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
		_add_minimap_dot(pos, color, 4.0)


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
	if _is_current_map_moon():
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

	if player.global_position.y < WATER_LEVEL - 45.0:
		var spawn: Vector3 = _find_spawn_position()
		player.global_position = Vector3(spawn.x, spawn.y + 6.0, spawn.z)
		player.velocity = Vector3.ZERO
		last_discovery_text = "Recovered from the edge of the world."


func _build_height_values() -> void:
	height_values.clear()
	height_values.resize((GRID_SIZE + 1) * (GRID_SIZE + 1))

	for z in range(GRID_SIZE + 1):
		for x in range(GRID_SIZE + 1):
			height_values[_height_index(x, z)] = _raw_height_at_grid(x, z)


func _height_index(x: int, z: int) -> int:
	return z * (GRID_SIZE + 1) + x


func _grid_to_world_x(x: int) -> float:
	return (float(x) - float(GRID_SIZE) * 0.5) * CELL_SIZE


func _grid_to_world_z(z: int) -> float:
	return (float(z) - float(GRID_SIZE) * 0.5) * CELL_SIZE


func _raw_height_at_grid(x: int, z: int) -> float:
	var wx: float = _grid_to_world_x(x)
	var wz: float = _grid_to_world_z(z)
	return _height_at_world(wx, wz)


func _height_at_world(wx: float, wz: float) -> float:
	if _is_current_map_moon():
		var lunar_broad: float = noise.get_noise_2d(wx * 0.45 + 600.0, wz * 0.45 - 1200.0) * 5.0
		var lunar_craters: float = noise.get_noise_2d(wx * 2.8 - 400.0, wz * 2.8 + 700.0) * 1.4
		var crater_bowls: float = abs(noise.get_noise_2d(wx * 0.12 + 330.0, wz * 0.12 - 510.0)) * -4.2
		return lunar_broad + lunar_craters + crater_bowls

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

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
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
	terrain_mat.roughness = 1.0
	terrain.material_override = terrain_mat

	_add_generated_child(terrain)


func _create_terrain_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := HeightMapShape3D.new()
	shape.map_width = GRID_SIZE + 1
	shape.map_depth = GRID_SIZE + 1
	shape.map_data = height_values

	var collision := CollisionShape3D.new()
	collision.name = "TerrainHeightMapCollision"
	collision.shape = shape
	collision.scale = Vector3(CELL_SIZE, 1.0, CELL_SIZE)

	body.add_child(collision)
	_add_generated_child(body)


func _create_world_bounds() -> void:
	var half: float = float(GRID_SIZE) * CELL_SIZE * 0.5
	var wall_height: float = 80.0
	var wall_thickness: float = 4.0
	var wall_center_y: float = 18.0
	var wall_length: float = float(GRID_SIZE) * CELL_SIZE + wall_thickness * 2.0

	var bounds := Node3D.new()
	bounds.name = "WorldEdgeBarriers"
	_add_box_collision(bounds, Vector3(half, wall_center_y, 0.0), Vector3(wall_thickness, wall_height, wall_length))
	_add_box_collision(bounds, Vector3(-half, wall_center_y, 0.0), Vector3(wall_thickness, wall_height, wall_length))
	_add_box_collision(bounds, Vector3(0.0, wall_center_y, half), Vector3(wall_length, wall_height, wall_thickness))
	_add_box_collision(bounds, Vector3(0.0, wall_center_y, -half), Vector3(wall_length, wall_height, wall_thickness))
	_add_generated_child(bounds)


func _create_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "RiverAndLakeWater"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(float(GRID_SIZE) * CELL_SIZE * 0.94, float(GRID_SIZE) * CELL_SIZE * 0.94)
	water.mesh = mesh
	water.position.y = WATER_LEVEL

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.42, 0.75, 0.58)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.18
	mat.metallic = 0.0
	water.material_override = mat

	_add_generated_child(water)


func _create_moon_sky() -> void:
	var sky := Node3D.new()
	sky.name = "MoonSkyDetails"

	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(0.75, 0.86, 1.0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.7, 0.85, 1.0)
	star_mat.emission_energy_multiplier = 1.8
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(140):
		var star := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.10, 0.26)
		mesh.height = mesh.radius * 2.0
		star.mesh = mesh
		star.material_override = star_mat
		star.position = Vector3(randf_range(-220.0, 220.0), randf_range(55.0, 135.0), randf_range(-240.0, -120.0))
		sky.add_child(star)

	var earth := MeshInstance3D.new()
	earth.name = "DistantBlueWorld"
	var earth_mesh := SphereMesh.new()
	earth_mesh.radius = 13.0
	earth_mesh.height = 26.0
	earth.mesh = earth_mesh
	earth.position = Vector3(-115.0, 60.0, -185.0)
	var earth_mat := StandardMaterial3D.new()
	earth_mat.albedo_color = Color(0.25, 0.55, 0.95)
	earth_mat.emission_enabled = true
	earth_mat.emission = Color(0.10, 0.32, 0.75)
	earth_mat.emission_energy_multiplier = 0.75
	earth.material_override = earth_mat
	sky.add_child(earth)

	var rim := MeshInstance3D.new()
	rim.name = "MoonHorizonGlow"
	var rim_mesh := TorusMesh.new()
	rim_mesh.outer_radius = 125.0
	rim_mesh.inner_radius = 123.5
	rim.mesh = rim_mesh
	rim.position = Vector3(0.0, -2.5, -95.0)
	rim.rotation_degrees.x = 90.0
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.18, 0.45, 0.95, 0.35)
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.08, 0.22, 0.65)
	rim_mat.emission_energy_multiplier = 1.2
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.material_override = rim_mat
	sky.add_child(rim)

	_add_generated_child(sky)


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
	for i in range(TREE_COUNT):
		var pos: Vector3 = _random_land_position(WATER_LEVEL + 0.35)
		if pos.distance_to(Vector3.ZERO) < 8.0:
			continue

		var tree := Node3D.new()
		tree.name = "Tree"

		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.18
		trunk_mesh.bottom_radius = 0.30
		trunk_mesh.height = randf_range(2.0, 3.3)
		trunk.mesh = trunk_mesh
		trunk.position.y = trunk_mesh.height * 0.5

		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.32, 0.19, 0.09)
		trunk.material_override = trunk_mat

		var leaves := MeshInstance3D.new()
		var leaves_mesh := SphereMesh.new()
		leaves_mesh.radius = randf_range(1.0, 1.6)
		leaves_mesh.height = leaves_mesh.radius * 1.8
		leaves.mesh = leaves_mesh
		leaves.position.y = trunk_mesh.height + 0.9

		var leaves_mat := StandardMaterial3D.new()
		var biome: float = _biome_value(pos.x, pos.z)
		if pos.y > 8.0:
			leaves_mat.albedo_color = Color(0.18, 0.32, 0.15)
		elif biome > 0.25:
			leaves_mat.albedo_color = Color(0.08, randf_range(0.34, 0.50), 0.12)
		else:
			leaves_mat.albedo_color = Color(0.10, randf_range(0.24, 0.38), 0.09)
		leaves.material_override = leaves_mat

		tree.add_child(trunk)
		tree.add_child(leaves)
		_add_cylinder_collision(tree, Vector3(0.0, trunk_mesh.height * 0.5, 0.0), 0.34, trunk_mesh.height)
		tree.position = pos
		tree.rotation_degrees.y = randf_range(0.0, 360.0)
		tree.scale = Vector3.ONE * randf_range(0.8, 1.25)
		_add_generated_child(tree)


func _scatter_rocks() -> void:
	for i in range(ROCK_COUNT):
		var pos: Vector3 = _random_land_position(WATER_LEVEL + 0.2)
		if pos.distance_to(Vector3.ZERO) < 6.0:
			continue

		var rock := Node3D.new()
		rock.name = "Rock"

		var visual := MeshInstance3D.new()
		visual.name = "RockVisual"
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = randf_range(0.4, 1.2)
		rock_mesh.height = rock_mesh.radius * randf_range(0.65, 1.1)
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
	for i in range(90):
		var pos: Vector3 = _random_land_position(-9999.0)
		if pos.distance_to(Vector3.ZERO) < 10.0:
			continue

		var body := RigidBody3D.new()
		body.name = "FloatingLichen"
		body.collision_layer = 1
		body.collision_mask = 1
		body.gravity_scale = 0.0
		body.linear_damp = 1.2
		body.angular_damp = 2.0
		body.mass = 0.45
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
		_add_generated_child(body)


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

		for j in range(randi_range(3, 7)):
			var stem := MeshInstance3D.new()
			var stem_mesh := CylinderMesh.new()
			stem_mesh.top_radius = 0.025
			stem_mesh.bottom_radius = 0.035
			stem_mesh.height = randf_range(0.25, 0.55)
			stem.mesh = stem_mesh
			stem.material_override = stem_mat
			stem.position = Vector3(randf_range(-0.35, 0.35), stem_mesh.height * 0.5, randf_range(-0.35, 0.35))

			var blossom := MeshInstance3D.new()
			var blossom_mesh := SphereMesh.new()
			blossom_mesh.radius = randf_range(0.07, 0.13)
			blossom_mesh.height = blossom_mesh.radius * 0.6
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

			var wonder: Node3D = WonderGenerator.create_wonder(world_seed, wonder_pos, 0, true)
			var discovery_id: String = "wonder_" + str(cell_x) + "_" + str(cell_z)
			var title: String = _wonder_title(wonder.name)
			_add_discovery_area(wonder, Vector3(0.0, 2.0, 0.0), 12.0, discovery_id, title, "wonder")
			if title == "Moon Gate":
				_add_moon_gate_area(wonder)
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
			mesh.radial_segments = 6
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
		glow.material_override = _gate_glow_material(gate_index)

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

		_add_generated_child(gate)


func _on_gate_body_entered(body: Node3D, gate_index: int) -> void:
	if body.name != "Player" or current_world_id == "" or current_map_id == "":
		return

	var world: Dictionary = _get_world(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(current_map_id, {})
	var gates: Dictionary = map_record.get("gates", {})
	var gate_key: String = str(gate_index)
	var target_map_id: String = str(gates.get(gate_key, ""))

	if target_map_id == "":
		target_map_id = _new_id("map")
		var target_record: Dictionary = _create_map_record(_preview_gate_seed(gate_index))
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


func _terrain_color(pos: Vector3) -> Color:
	if _is_current_map_moon():
		if pos.y > 4.0:
			return Color(0.34, 0.36, 0.43)
		if pos.y < -2.0:
			return Color(0.16, 0.17, 0.21)
		return Color(0.25, 0.26, 0.31)

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
