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

var current_world_id: String = ""
var current_map_id: String = ""
var gate_count: int = 4
var focused_map_id: String = ""


func toggle() -> void:
	if atlas_layer != null and atlas_layer.visible:
		atlas_layer.visible = false
		show_atlas = false
	else:
		show_atlas = true
		refresh()
		if atlas_layer != null:
			atlas_layer.visible = true


func refresh() -> void:
	if atlas_layer != null:
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
	panel.offset_left = -520.0
	panel.offset_top = -280.0
	panel.offset_right = 520.0
	panel.offset_bottom = 280.0
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
	split.split_offset = 700
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

	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 470)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	container.add_child(viewport)

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

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 20.0, 39.0)
	camera.rotation_degrees = Vector3(-40.0, 0.0, 0.0)
	camera.current = true
	root.add_child(camera)

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
	legend.add_theme_font_size_override("font_size", 10)
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
	right.custom_minimum_size = Vector2(280.0, 0.0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	var maps_title := Label.new()
	maps_title.text = "Map List"
	maps_title.add_theme_font_size_override("font_size", 14)
	maps_title.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	right.add_child(maps_title)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(list_scroll)

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	list_scroll.add_child(list_box)
	_build_map_list(list_box, world)

	atlas_layer.visible = false


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
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 6)
		row.add_child(margin)

		var info := Label.new()
		var marker: String = " [current]" if is_current else (" [focused]" if is_focused else (" [linked]" if is_linked else ""))
		info.text = short_id_fn.call(map_id) + marker + "\n" + map_type + " | " + completion_text_fn.call(discoveries.size(), available) + " | pins " + str(pins.size()) + " | gates " + str(gates.size()) + "/" + str(gate_count)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 10)
		margin.add_child(info)

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		margin.add_child(actions)
		var focus_btn := Button.new()
		focus_btn.text = "Focus"
		focus_btn.disabled = is_focused
		focus_btn.pressed.connect(_focus_map.bind(map_id))
		actions.add_child(focus_btn)

		var linked_targets: Array[String] = []
		for gate_key in gates.keys():
			var target: String = str(gates[gate_key])
			if target != "":
				linked_targets.append(short_id_fn.call(target))
		if not linked_targets.is_empty():
			var links := Label.new()
			links.text = "Links: " + ", ".join(linked_targets)
			links.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			links.add_theme_font_size_override("font_size", 9)
			links.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92))
			margin.add_child(links)


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
	refresh()
	if atlas_layer != null:
		atlas_layer.visible = true


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
