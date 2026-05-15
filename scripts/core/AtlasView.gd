extends Node
class_name AtlasView

var atlas_layer: CanvasLayer
var show_atlas: bool = false

var get_worlds_fn: Callable
var get_world_fn: Callable
var seed_color_fn: Callable
var short_id_fn: Callable
var completion_text_fn: Callable
var opposite_gate_index_fn: Callable
var set_map_name_fn: Callable

var current_world_id: String = ""
var current_map_id: String = ""
var gate_count: int = 4
var focused_map_id: String = ""
var _graph_viewport: SubViewport
var _graph_camera: Camera3D
var _graph_container: SubViewportContainer
var _graph_root: Node3D
var _hover_label: Label
var _hover_map_names: Dictionary = {}
var _hover_map_positions: Dictionary = {}


func toggle() -> void:
	show_atlas = not show_atlas
	if show_atlas:
		refresh()
		if is_instance_valid(atlas_layer):
			atlas_layer.visible = true
	else:
		if is_instance_valid(atlas_layer):
			atlas_layer.visible = false


func is_open() -> bool:
	return is_instance_valid(atlas_layer) and atlas_layer.visible


func refresh() -> void:
	if is_instance_valid(atlas_layer):
		atlas_layer.queue_free()
	if focused_map_id == "":
		focused_map_id = current_map_id

	atlas_layer = CanvasLayer.new()
	atlas_layer.name = "AtlasLayer"
	atlas_layer.layer = 25
	add_child(atlas_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.05, 0.88)
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
	panel.offset_left = -620.0
	panel.offset_top = -340.0
	panel.offset_right = 620.0
	panel.offset_bottom = 340.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	atlas_layer.add_child(panel)

	var root_margin := MarginContainer.new()
	root_margin.anchors_preset = Control.PRESET_FULL_RECT
	root_margin.add_theme_constant_override("margin_left", 12)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_right", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(root_margin)

	var split := HSplitContainer.new()
	split.anchors_preset = Control.PRESET_FULL_RECT
	split.split_offset = 860
	root_margin.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(container)
	_graph_container = container

	var viewport := SubViewport.new()
	viewport.size = Vector2i(860, 570)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	container.add_child(viewport)
	_graph_viewport = viewport

	var world_3d := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.06, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.54, 0.72)
	env.ambient_light_energy = 1.3
	world_3d.environment = env
	viewport.world_3d = world_3d

	var root := Node3D.new()
	root.name = "Atlas3DRoot"
	viewport.add_child(root)
	_graph_root = root

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 20.0, 39.0)
	camera.rotation_degrees = Vector3(-40.0, 0.0, 0.0)
	camera.current = true
	root.add_child(camera)
	_graph_camera = camera

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -20.0, 0.0)
	light.light_energy = 3.6
	root.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 8.0, 0.0)
	fill.light_energy = 0.75
	fill.omni_range = 120.0
	fill.light_color = Color(0.45, 0.58, 0.90)
	root.add_child(fill)

	var grid_floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(56.0, 56.0)
	grid_floor.mesh = floor_mesh
	grid_floor.position = Vector3(0.0, -2.2, 0.0)
	grid_floor.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.06, 0.08, 0.12)
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(0.08, 0.12, 0.20)
	floor_mat.emission_energy_multiplier = 0.22
	grid_floor.material_override = floor_mat
	root.add_child(grid_floor)

	_build_graph_3d(root)

	var legend := Label.new()
	legend.text = "Node color = map type. Node size = completion. Gold gate dots = linked. Gray = unopened. [TAB] close."
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", Color(0.66, 0.73, 0.86))
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(legend)

	var world_info := Label.new()
	var world: Dictionary = get_world_fn.call(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_count: int = maps.size()
	var linked_gates: int = 0
	for map_key in maps.keys():
		var raw = maps[map_key]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var gates: Dictionary = raw.get("gates", {})
		for gate_key in gates.keys():
			if str(gates[gate_key]) != "":
				linked_gates += 1
	world_info.text = "Atlas: " + str(world.get("name", current_world_id)) + " | maps " + str(map_count) + " | linked gates " + str(linked_gates)
	world_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	world_info.add_theme_font_size_override("font_size", 11)
	world_info.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	world_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(world_info)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340.0, 0.0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	right.add_child(header_row)

	var maps_title := Label.new()
	maps_title.text = "Map List"
	maps_title.add_theme_font_size_override("font_size", 14)
	maps_title.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	maps_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(maps_title)

	var help_btn := Button.new()
	help_btn.text = "Help"
	help_btn.custom_minimum_size = Vector2(72.0, 0.0)
	help_btn.pressed.connect(_show_help_dialog.bind(panel))
	header_row.add_child(help_btn)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(list_scroll)

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	list_scroll.add_child(list_box)
	_build_map_list(list_box, world)

	_hover_label = Label.new()
	_hover_label.visible = false
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.add_theme_font_size_override("font_size", 12)
	_hover_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.04, 0.07, 0.12, 0.92)
	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.border_color = Color(0.35, 0.52, 0.76, 0.90)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	_hover_label.add_theme_stylebox_override("normal", hover_style)
	_hover_label.offset_left = 8
	_hover_label.offset_right = 8
	_hover_label.offset_top = 4
	_hover_label.offset_bottom = 4
	panel.add_child(_hover_label)

	atlas_layer.visible = show_atlas
	set_process(show_atlas)


func get_text() -> String:
	var worlds: Dictionary = get_worlds_fn.call()
	if worlds.is_empty():
		return "No worlds discovered yet."

	var lines: Array[String] = []
	for world_key in worlds.keys():
		var world_id: String = str(world_key)
		var world: Dictionary = get_world_fn.call(world_id)
		var maps: Dictionary = world.get("maps", {})
		lines.append(str(world.get("name", world_id)) + " (" + str(maps.size()) + " maps)")

		for map_key in maps.keys():
			var map_id: String = str(map_key)
			var raw = maps[map_id]
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var map_record: Dictionary = raw
			var discoveries: Dictionary = map_record.get("discoveries", {})
			var pins: Dictionary = map_record.get("pins", {})
			var gates: Dictionary = map_record.get("gates", {})
			var marker: String = ""
			if world_id == current_world_id and map_id == current_map_id:
				marker = " <- current"

			lines.append("  " + short_id_fn.call(map_id) + marker + " | discoveries " + str(discoveries.size()) + " | pins " + str(pins.size()) + " | gates " + str(gates.size()) + "/" + str(gate_count))
			for gate_key in gates.keys():
				var target_map_id: String = str(gates[gate_key])
				lines.append("    gate " + str(int(str(gate_key)) + 1) + " -> " + short_id_fn.call(target_map_id))

		lines.append("")

	return "\n".join(lines)


func _build_graph_3d(root: Node3D) -> void:
	var world: Dictionary = get_worlds_fn.call().get(current_world_id, {})
	if world.is_empty():
		return

	var maps: Dictionary = world.get("maps", {})
	if maps.is_empty():
		return

	var map_ids: Array[String] = []
	for map_key in maps.keys():
		var raw = maps[map_key]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		map_ids.append(str(map_key))
	map_ids.sort()

	if map_ids.is_empty():
		return

	var positions: Dictionary = {}
	var gate_positions: Dictionary = {}
	_hover_map_names.clear()
	_hover_map_positions.clear()
	for i in range(map_ids.size()):
		positions[map_ids[i]] = _atlas_layout_point(i, map_ids.size())
		for gate_index in range(gate_count):
			gate_positions[_gate_graph_key(map_ids[i], gate_index)] = positions[map_ids[i]] + _gate_offset(gate_index)

	var drawn_links: Dictionary = {}
	for map_id in map_ids:
		var raw = maps[map_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var map_record: Dictionary = raw
		var gates: Dictionary = map_record.get("gates", {})
		for gate_key in gates.keys():
			var gate_index: int = int(str(gate_key))
			var target_id: String = str(gates[gate_key])
			if not positions.has(target_id):
				continue
			var link_key: String = map_id + ":" + str(gate_index) + "->" + target_id
			var reverse_key: String = target_id + ":" + str(opposite_gate_index_fn.call(gate_index)) + "->" + map_id
			if drawn_links.has(link_key) or drawn_links.has(reverse_key):
				continue
			drawn_links[link_key] = true
			var target_raw = maps[target_id]
			if typeof(target_raw) != TYPE_DICTIONARY:
				continue
			var target_record: Dictionary = target_raw
			var start_pos: Vector3 = gate_positions[_gate_graph_key(map_id, gate_index)]
			var end_pos: Vector3 = gate_positions[_gate_graph_key(target_id, opposite_gate_index_fn.call(gate_index))]
			_add_link(root, start_pos, end_pos, seed_color_fn.call(int(target_record.get("seed", 0))))

	for map_id in map_ids:
		var raw = maps[map_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var map_record: Dictionary = raw
		var discoveries: Dictionary = map_record.get("discoveries", {})
		var pins: Dictionary = map_record.get("pins", {})
		var available: int = int(map_record.get("available_discoveries", 0))
		var map_type: String = str(map_record.get("type", WorldGraph.MAP_NORMAL))
		var pos: Vector3 = positions[map_id]
		var is_current: bool = map_id == current_map_id
		var is_focused: bool = map_id == focused_map_id

		var node_mesh := SphereMesh.new()
		var completion_ratio: float = 0.0
		if available > 0:
			completion_ratio = clamp(float(discoveries.size()) / float(available), 0.0, 1.0)
		var node_radius: float = (0.70 + completion_ratio * 0.35)
		if is_current:
			node_radius += 0.35
		if is_focused and not is_current:
			node_radius += 0.20
		node_mesh.radius = node_radius
		node_mesh.height = node_radius * 2.0
		node_mesh.radial_segments = 32
		node_mesh.rings = 16
		var node_instance := MeshInstance3D.new()
		node_instance.name = "AtlasMapNode"
		node_instance.mesh = node_mesh
		node_instance.position = pos
		var node_mat := StandardMaterial3D.new()
		node_mat.albedo_color = _map_node_color(map_type, is_current)
		node_mat.emission_enabled = true
		node_mat.emission = node_mat.albedo_color * 0.7
		node_mat.emission_energy_multiplier = 1.55 if is_current else (1.25 if is_focused else 0.85)
		node_instance.material_override = node_mat
		root.add_child(node_instance)
		_hover_map_names[map_id] = _display_map_name(map_id, map_record)
		_hover_map_positions[map_id] = pos

		var hover_area := Area3D.new()
		hover_area.name = "AtlasHover_" + map_id
		hover_area.position = pos
		hover_area.set_meta("map_id", map_id)
		hover_area.collision_layer = 1
		hover_area.collision_mask = 0
		var hover_shape := CollisionShape3D.new()
		var hover_sphere := SphereShape3D.new()
		hover_sphere.radius = node_radius + 0.45
		hover_shape.shape = hover_sphere
		hover_area.add_child(hover_shape)
		root.add_child(hover_area)

		for gate_index in range(gate_count):
			var gate_pos: Vector3 = gate_positions[_gate_graph_key(map_id, gate_index)]
			var gate_marker := MeshInstance3D.new()
			gate_marker.name = "AtlasGatePoint"
			var gate_mesh := SphereMesh.new()
			gate_mesh.radius = 0.40 if is_current else 0.30
			gate_mesh.height = gate_mesh.radius * 2.0
			gate_mesh.radial_segments = 16
			gate_marker.mesh = gate_mesh
			gate_marker.position = gate_pos
			var gate_mat := StandardMaterial3D.new()
			gate_mat.albedo_color = _gate_color(map_record, maps, gate_index)
			if is_current and gate_mat.albedo_color == Color(0.25, 0.28, 0.32):
				gate_mat.albedo_color = Color(1.0, 0.85, 0.40)
			gate_mat.emission_enabled = true
			gate_mat.emission = gate_mat.albedo_color * 2.0
			gate_mat.emission_energy_multiplier = 1.0
			gate_marker.material_override = gate_mat
			root.add_child(gate_marker)

		if is_current or is_focused:
			var beacon_mesh := CylinderMesh.new()
			beacon_mesh.top_radius = 0.08
			beacon_mesh.bottom_radius = 0.08
			beacon_mesh.height = 3.2 if is_current else 2.6
			var beacon := MeshInstance3D.new()
			beacon.mesh = beacon_mesh
			beacon.position = pos + Vector3(0.0, 1.9 if is_current else 1.5, 0.0)
			var beacon_mat := StandardMaterial3D.new()
			beacon_mat.albedo_color = Color(1.0, 0.88, 0.42) if is_current else Color(0.70, 0.84, 1.0)
			beacon_mat.emission_enabled = true
			beacon_mat.emission = beacon_mat.albedo_color
			beacon_mat.emission_energy_multiplier = 1.2 if is_current else 0.85
			beacon.material_override = beacon_mat
			root.add_child(beacon)


func _gate_graph_key(map_id: String, gate_index: int) -> String:
	return map_id + ":" + str(gate_index)


func _gate_offset(gate_index: int) -> Vector3:
	match gate_index:
		0: return Vector3(1.4, 0.0, 0.0)
		1: return Vector3(-1.4, 0.0, 0.0)
		2: return Vector3(0.0, 0.0, 1.4)
		_: return Vector3(0.0, 0.0, -1.4)


func _atlas_layout_point(index: int, count: int) -> Vector3:
	if count <= 1:
		return Vector3.ZERO
	var cols: int = int(ceil(sqrt(float(count))))
	var row: int = index / cols
	var col: int = index % cols
	var spacing: float = 9.0
	var x: float = (float(col) - float(cols - 1) * 0.5) * spacing
	var z: float = (float(row) - float(cols - 1) * 0.5) * spacing
	return Vector3(x, 0.0, z)


func _build_map_list(parent: VBoxContainer, world: Dictionary) -> void:
	var maps: Dictionary = world.get("maps", {})
	var map_ids: Array[String] = []
	var current_links: Dictionary = {}
	var current_map_record: Dictionary = maps.get(current_map_id, {}) if maps.has(current_map_id) else {}
	if not current_map_record.is_empty():
		var current_gates: Dictionary = current_map_record.get("gates", {})
		for gate_key in current_gates.keys():
			var target_id: String = str(current_gates[gate_key])
			if target_id != "":
				current_links[target_id] = true
	for map_key in maps.keys():
		if typeof(maps[map_key]) == TYPE_DICTIONARY:
			map_ids.append(str(map_key))
	map_ids.sort_custom(func(a: String, b: String) -> bool:
		return _map_sort_key(a, maps, current_links) < _map_sort_key(b, maps, current_links)
	)

	var summary := Label.new()
	summary.text = "Current: " + short_id_fn.call(current_map_id) + " | Total maps: " + str(map_ids.size())
	summary.add_theme_font_size_override("font_size", 10)
	summary.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	parent.add_child(summary)

	var current_added: bool = false
	var linked_added: bool = false
	var explored_added: bool = false

	for map_id in map_ids:
		var map_record: Dictionary = maps[map_id]
		var is_current: bool = map_id == current_map_id
		var is_focused: bool = map_id == focused_map_id
		var is_linked: bool = current_links.has(map_id)
		var discoveries: Dictionary = map_record.get("discoveries", {})
		var available: int = int(map_record.get("available_discoveries", 0))
		var pins: Dictionary = map_record.get("pins", {})
		var gates: Dictionary = map_record.get("gates", {})
		var map_type: String = str(map_record.get("type", WorldGraph.MAP_NORMAL))

		if is_current and not current_added:
			_add_map_section_header(parent, "Current Map")
			current_added = true
		elif is_linked and not linked_added:
			_add_map_section_header(parent, "Directly Linked")
			linked_added = true
		elif not is_current and not is_linked and not explored_added:
			_add_map_section_header(parent, "Other Explored Maps")
			explored_added = true

		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.11, 0.14, 0.19, 0.92)
		if is_current:
			row_style.bg_color = Color(0.22, 0.19, 0.10, 0.98)
			row_style.border_width_left = 2
			row_style.border_width_top = 2
			row_style.border_width_right = 2
			row_style.border_width_bottom = 2
			row_style.border_color = Color(1.0, 0.86, 0.40, 0.95)
		elif is_focused:
			row_style.bg_color = Color(0.12, 0.18, 0.25, 0.98)
			row_style.border_width_left = 1
			row_style.border_width_top = 1
			row_style.border_width_right = 1
			row_style.border_width_bottom = 1
			row_style.border_color = Color(0.66, 0.82, 1.0, 0.95)
		elif is_linked:
			row_style.bg_color = Color(0.13, 0.17, 0.23, 0.95)
		row_style.corner_radius_top_left = 4
		row_style.corner_radius_top_right = 4
		row_style.corner_radius_bottom_left = 4
		row_style.corner_radius_bottom_right = 4
		row.add_theme_stylebox_override("panel", row_style)
		parent.add_child(row)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 4)
		row.add_child(margin)

		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 2)
		margin.add_child(content)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 6)
		content.add_child(top_row)

		var info := Label.new()
		var marker: String = " [current]" if is_current else (" [focused]" if is_focused else (" [linked]" if is_linked else ""))
		info.text = _compact_label(_display_map_name(map_id, map_record), 24) + marker + " | " + map_type + " | " + completion_text_fn.call(discoveries.size(), available)
		info.autowrap_mode = TextServer.AUTOWRAP_OFF
		info.clip_text = true
		info.add_theme_font_size_override("font_size", 9)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(info)

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		top_row.add_child(actions)
		var focus_btn := Button.new()
		focus_btn.text = "Go"
		focus_btn.disabled = is_focused
		focus_btn.custom_minimum_size = Vector2(48, 0)
		focus_btn.pressed.connect(_focus_map.bind(map_id))
		actions.add_child(focus_btn)
		var name_btn := Button.new()
		name_btn.text = "Name"
		name_btn.custom_minimum_size = Vector2(58, 0)
		name_btn.pressed.connect(_prompt_rename_map.bind(map_id))
		actions.add_child(name_btn)

		var linked_targets: Array[String] = []
		for gate_key in gates.keys():
			var target: String = str(gates[gate_key])
			if target != "":
				linked_targets.append(short_id_fn.call(target))
		if not linked_targets.is_empty():
			var links := Label.new()
			links.text = "Links: " + _compact_label(", ".join(linked_targets), 42)
			links.autowrap_mode = TextServer.AUTOWRAP_OFF
			links.clip_text = true
			links.add_theme_font_size_override("font_size", 8)
			links.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92))
			content.add_child(links)


func _map_sort_key(map_id: String, maps: Dictionary, current_links: Dictionary) -> String:
	var map_record: Dictionary = maps.get(map_id, {})
	var is_current: int = 0 if map_id == current_map_id else 1
	var is_linked: int = 0 if current_links.has(map_id) else 1
	var map_type: String = str(map_record.get("type", WorldGraph.MAP_NORMAL))
	return str(is_current) + "_" + str(is_linked) + "_" + map_type + "_" + map_id


func _add_map_section_header(parent: VBoxContainer, text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.86, 0.90, 0.97))
	parent.add_child(header)


func _focus_map(map_id: String) -> void:
	if map_id == "":
		return
	focused_map_id = map_id
	show_atlas = true
	refresh()
	if is_instance_valid(atlas_layer):
		atlas_layer.visible = true


func _show_help_dialog(parent: Control) -> void:
	if parent == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Atlas Guide"
	dialog.min_size = Vector2(760.0, 500.0)
	dialog.size = Vector2(760.0, 500.0)
	dialog.dialog_hide_on_ok = true
	dialog.exclusive = true
	parent.add_child(dialog)

	var body := RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(700.0, 420.0)
	body.text = "How to read the Atlas:\n\n" + \
		"1) Every sphere is a discovered map in the current world.\n" + \
		"2) Sphere color shows map type:\n" + \
		"   - blue: normal\n" + \
		"   - brown/stone: cave\n" + \
		"   - pale cyan: moon\n" + \
		"   - bright cyan: arctic\n" + \
		"   - sea blue: water\n" + \
		"   - violet: gate room\n" + \
		"   - amber: nexus\n\n" + \
		"3) Sphere size shows completion on that map.\n" + \
		"4) Gold gate dots mean linked/known routes. Gray dots are unopened routes.\n" + \
		"5) Bright vertical beam marks the current map. Blue beam marks the focused map.\n" + \
		"6) In the map list:\n" + \
		"   - Current Map: where you are now\n" + \
		"   - Directly Linked: one gate away\n" + \
		"   - Other Explored Maps: known but not directly linked from current map\n\n" + \
		"Controls:\n" + \
		"- Tab: open/close Atlas\n" + \
		"- Focus button: highlight one map and its immediate route context\n\n" + \
		"Practical navigation:\n" + \
		"- Use Focus on a low-completion map.\n" + \
		"- Prefer linked maps with remaining discoveries first.\n" + \
		"- Use gate counts to find maps with unopened exits."
	dialog.add_child(body)
	dialog.popup_centered()


func _prompt_rename_map(map_id: String) -> void:
	if map_id == "" or not set_map_name_fn.is_valid() or atlas_layer == null:
		return
	var world: Dictionary = get_world_fn.call(current_world_id)
	var maps: Dictionary = world.get("maps", {})
	var map_record: Dictionary = maps.get(map_id, {}) if maps.has(map_id) else {}
	var current_name: String = str(map_record.get("name", ""))
	var dialog := AcceptDialog.new()
	dialog.title = "Name Map"
	dialog.min_size = Vector2(420.0, 0.0)
	atlas_layer.add_child(dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	dialog.add_child(box)
	var prompt := Label.new()
	prompt.text = "Map " + short_id_fn.call(map_id)
	box.add_child(prompt)
	var edit := LineEdit.new()
	edit.placeholder_text = "Enter map name"
	edit.text = current_name
	edit.select_all()
	box.add_child(edit)
	dialog.confirmed.connect(_confirm_rename_map.bind(map_id, edit, dialog))
	dialog.popup_centered()
	edit.grab_focus()


func _confirm_rename_map(map_id: String, edit: LineEdit, dialog: AcceptDialog) -> void:
	if set_map_name_fn.is_valid() and edit != null:
		set_map_name_fn.call(current_world_id, map_id, edit.text)
	if dialog != null:
		dialog.queue_free()
	show_atlas = true
	refresh()
	if is_instance_valid(atlas_layer):
		atlas_layer.visible = true


func _display_map_name(map_id: String, map_record: Dictionary) -> String:
	var custom_name: String = str(map_record.get("name", "")).strip_edges()
	if custom_name != "":
		return custom_name
	return short_id_fn.call(map_id)


func _compact_label(text: String, max_chars: int) -> String:
	if max_chars <= 0:
		return ""
	var clean: String = text.replace("\n", " ").strip_edges()
	if clean.length() <= max_chars:
		return clean
	return clean.substr(0, max_chars - 1) + "…"


func _process(_delta: float) -> void:
	if not is_open():
		if _hover_label != null:
			_hover_label.visible = false
		return
	_update_graph_hover()


func _update_graph_hover() -> void:
	if _hover_label == null or _graph_container == null or _graph_viewport == null or _graph_camera == null:
		return
	var mouse_global: Vector2 = get_viewport().get_mouse_position()
	var container_rect: Rect2 = _graph_container.get_global_rect()
	if not container_rect.has_point(mouse_global):
		_hover_label.visible = false
		return
	var local: Vector2 = mouse_global - container_rect.position
	var container_size: Vector2 = container_rect.size
	if container_size.x <= 0.0 or container_size.y <= 0.0:
		_hover_label.visible = false
		return
	var viewport_size: Vector2 = Vector2(_graph_viewport.size)
	var vp_pos := Vector2(
		clamp(local.x / container_size.x, 0.0, 1.0) * viewport_size.x,
		clamp(local.y / container_size.y, 0.0, 1.0) * viewport_size.y
	)
	var origin: Vector3 = _graph_camera.project_ray_origin(vp_pos)
	var dir: Vector3 = _graph_camera.project_ray_normal(vp_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 200.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = _graph_viewport.world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_hover_label.visible = false
		return
	var collider: Object = hit.get("collider")
	if not (collider is Area3D):
		_hover_label.visible = false
		return
	var area := collider as Area3D
	if not area.has_meta("map_id"):
		_hover_label.visible = false
		return
	var map_id: String = str(area.get_meta("map_id", ""))
	if map_id == "":
		_hover_label.visible = false
		return
	var map_name: String = str(_hover_map_names.get(map_id, short_id_fn.call(map_id)))
	var world_pos: Vector3 = area.global_position
	var stored_pos = _hover_map_positions.get(map_id, null)
	if stored_pos is Vector3:
		world_pos = stored_pos as Vector3
	var label_vp_pos: Vector2 = _graph_camera.unproject_position(world_pos + Vector3(0.0, 2.0, 0.0))
	var label_panel_pos := container_rect.position + Vector2(
		label_vp_pos.x / viewport_size.x * container_size.x,
		label_vp_pos.y / viewport_size.y * container_size.y
	)
	_hover_label.text = " " + map_name + " "
	_hover_label.reset_size()
	_hover_label.position = label_panel_pos - Vector2(_hover_label.size.x * 0.5, _hover_label.size.y + 8.0)
	_hover_label.visible = true


func _map_node_color(map_type: String, is_current: bool) -> Color:
	var base: Color = Color(0.42, 0.52, 0.66)
	match map_type:
		WorldGraph.MAP_CAVE:
			base = Color(0.45, 0.40, 0.34)
		WorldGraph.MAP_MOON:
			base = Color(0.62, 0.76, 0.92)
		WorldGraph.MAP_ARCTIC:
			base = Color(0.68, 0.86, 0.92)
		WorldGraph.MAP_GATE_ROOM:
			base = Color(0.82, 0.68, 0.96)
		WorldGraph.MAP_NEXUS:
			base = Color(0.96, 0.75, 0.52)
		WorldGraph.MAP_WATER:
			base = Color(0.40, 0.70, 0.92)
	if is_current:
		return base.lightened(0.28)
	return base


func _gate_color(map_record: Dictionary, maps: Dictionary, gate_index: int) -> Color:
	var gates: Dictionary = map_record.get("gates", {})
	var target_id: String = str(gates.get(str(gate_index), ""))
	if target_id != "" and maps.has(target_id):
		var raw = maps[target_id]
		if typeof(raw) == TYPE_DICTIONARY:
			return seed_color_fn.call(int(raw.get("seed", 0)))
	return Color(0.25, 0.28, 0.32)


func _add_link(root: Node3D, start_pos: Vector3, end_pos: Vector3, color: Color) -> void:
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var mid: Vector3 = (start_pos + end_pos) * 0.5 + Vector3(0.0, 1.2, 0.0)
	var segments: int = 8
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var a: Vector3 = start_pos.lerp(mid, t)
		var b: Vector3 = mid.lerp(end_pos, t)
		line_mesh.surface_add_vertex(a.lerp(b, t))
	line_mesh.surface_end()

	var line_instance := MeshInstance3D.new()
	line_instance.name = "AtlasGateLink"
	line_instance.mesh = line_mesh
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = color
	line_mat.emission_enabled = true
	line_mat.emission = color * 2.0
	line_mat.emission_energy_multiplier = 1.0
	line_instance.material_override = line_mat
	root.add_child(line_instance)
