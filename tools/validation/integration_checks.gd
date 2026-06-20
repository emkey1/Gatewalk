extends SceneTree

# Scene-driven integration checks: boots the real main.tscn and drives it over frames
# to exercise gameplay end-to-end (map load + gate transitions), which the static
# run_checks.gd can't. This is the safety net for refactoring the gate-detection
# system — if gate transitions still fire after a change, the core loop survives.
#
# Run:
#   <godot> --headless --path . --script res://tools/validation/integration_checks.gd
# Pass = prints "INTEGRATION OK: ..." and exits 0.


func _init() -> void:
	var failures: Array[String] = []
	await _run_checks(failures)
	if failures.is_empty():
		print("INTEGRATION OK: scene load and gate transition checks passed")
		quit(0)
		return
	for failure in failures:
		printerr("INTEGRATION FAIL: ", failure)
	quit(1)


func _run_checks(failures: Array[String]) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)

	# (1) Initial map finishes loading. Use _get_player() (the authoritative _player_ref)
	# rather than the "Player" node path: _spawn_player retires the old player and adds
	# a new one, so the node name can differ from "Player".
	if not await _await_loaded(main):
		failures.append("initial map did not finish loading")
		main.free()
		return
	var generated_root: Node = main.get("generated_root")
	if generated_root == null or generated_root.get_child_count() <= 0:
		failures.append("generated map is empty after initial load")
		main.free()
		return

	# (2) Two gate transitions fire through the real detection path. Two (not one)
	# exercises the alternating respawn that used to leak player nodes.
	if not await _do_gate_transition(main, failures, "first"):
		main.free()
		return
	if not await _do_gate_transition(main, failures, "second"):
		main.free()
		return

	# (3) Exactly one player remains — no leaked player nodes across respawns.
	await _await_frames(3)
	var player_count: int = 0
	for child in main.get_children():
		if child is CharacterBody3D:
			player_count += 1
	if player_count != 1:
		failures.append("expected exactly 1 player after transitions, found %d (leak)" % player_count)

	# (4) The world menu builds and closes. find_child keeps this stable across the
	# MenuController extraction (wherever the layer ends up parented).
	main.call("_show_main_menu")
	await _await_frames(2)
	var menu := main.find_child("WorldMenuLayer", true, false)
	if menu == null:
		failures.append("world menu did not build")
	elif _count_class(menu, "Button") < 6:
		failures.append("world menu built with too few buttons (%d)" % _count_class(menu, "Button"))
	main.call("_close_menu")
	await _await_frames(2)
	if main.find_child("WorldMenuLayer", true, false) != null:
		failures.append("world menu did not close")

	main.free()


func _count_class(node: Node, klass: String) -> int:
	var total: int = 1 if node.is_class(klass) else 0
	for child in node.get_children():
		total += _count_class(child, klass)
	return total


func _do_gate_transition(main: Node, failures: Array[String], label: String) -> bool:
	var generated_root: Node = main.get("generated_root")
	var gates_root: Node = generated_root.get_node_or_null("Gates") if generated_root != null else null
	if gates_root == null:
		failures.append("%s transition: no Gates node in current map" % label)
		return false
	var gate: Node3D = null
	for child in gates_root.get_children():
		if str(child.name).begins_with("Gate_"):
			gate = child as Node3D
			break
	if gate == null:
		failures.append("%s transition: no Gate_ node found" % label)
		return false

	var player: Node3D = main.call("_get_player") as Node3D
	if player == null:
		failures.append("%s transition: no player to move" % label)
		return false

	var before_map: String = str(main.get("current_map_id"))
	# Bypass the post-load warmup/cooldown so detection can fire immediately.
	main.set("_gate_trigger_enable_time_msec", 0)
	main.set("_gate_auto_retry_time_msec", 0)
	main.set("_gate_auto_cooldown_until_msec", 0)
	player.global_position = gate.global_position

	var transitioned: bool = await _await_until(
		func() -> bool: return str(main.get("current_map_id")) != before_map, 300)
	if not transitioned:
		failures.append("%s transition: standing on a gate did not change the map" % label)
		return false
	if not await _await_loaded(main):
		failures.append("%s transition: destination map did not finish loading" % label)
		return false
	return true


func _await_loaded(main: Node) -> bool:
	return await _await_until(
		func() -> bool: return not bool(main.get("_map_loading")) and main.call("_get_player") != null, 300)


func _await_until(cond: Callable, max_frames: int) -> bool:
	for i in range(max_frames):
		if bool(cond.call()):
			return true
		await process_frame
	return bool(cond.call())


func _await_frames(n: int) -> void:
	for i in range(n):
		await process_frame
