extends SceneTree

# Scene-driven integration checks: boots the real main.tscn and drives it over frames
# to exercise gameplay end-to-end (map load + gate transition), which the static
# run_checks.gd can't. This is the safety net for refactoring the gate-detection
# system — if a gate transition still fires after a change, the core loop survives.
#
# Run:
#   <godot> --headless --path . --script res://tools/validation/integration_checks.gd
# Pass = prints "INTEGRATION OK: ..." and exits 0.


func _init() -> void:
	var failures: Array[String] = []
	await _run_load_and_gate_checks(failures)
	if failures.is_empty():
		print("INTEGRATION OK: scene load and gate transition checks passed")
		quit(0)
		return
	for failure in failures:
		printerr("INTEGRATION FAIL: ", failure)
	quit(1)


func _run_load_and_gate_checks(failures: Array[String]) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)

	# (1) Initial map finishes loading. Use _get_player() (the authoritative _player_ref)
	# rather than the "Player" node path: _spawn_player queue_free()s the old player and
	# adds a new one same-frame, so Godot name-collides and the node is renamed.
	var loaded: bool = await _await_until(
		func() -> bool: return not bool(main.get("_map_loading")) and main.call("_get_player") != null,
		300
	)
	if not loaded:
		failures.append("initial map did not finish loading (player missing or still loading)")
		main.free()
		return

	var player: Node3D = main.call("_get_player") as Node3D
	var generated_root: Node = main.get("generated_root")
	if generated_root == null or generated_root.get_child_count() <= 0:
		failures.append("generated map is empty after initial load")
		main.free()
		return

	# (2) Placing the player on a gate triggers a transition end-to-end.
	var gates_root: Node = generated_root.get_node_or_null("Gates")
	if gates_root == null:
		failures.append("no Gates node in the starting map")
		main.free()
		return
	var gate: Node3D = null
	for child in gates_root.get_children():
		if str(child.name).begins_with("Gate_"):
			gate = child as Node3D
			break
	if gate == null:
		failures.append("no Gate_ node found in the starting map")
		main.free()
		return

	var before_map: String = str(main.get("current_map_id"))
	# Bypass the post-load warmup/cooldown so detection can fire immediately.
	main.set("_gate_trigger_enable_time_msec", 0)
	main.set("_gate_auto_retry_time_msec", 0)
	main.set("_gate_auto_cooldown_until_msec", 0)
	player.global_position = gate.global_position

	var transitioned: bool = await _await_until(
		func() -> bool: return str(main.get("current_map_id")) != before_map,
		300
	)
	if not transitioned:
		failures.append("standing on a gate did not trigger a map transition")
		main.free()
		return

	# (3) The destination map finishes loading too.
	var post_loaded: bool = await _await_until(
		func() -> bool: return not bool(main.get("_map_loading")) and main.call("_get_player") != null,
		300
	)
	if not post_loaded:
		failures.append("destination map did not finish loading after the gate transition")

	main.free()


func _await_until(cond: Callable, max_frames: int) -> bool:
	for i in range(max_frames):
		if bool(cond.call()):
			return true
		await process_frame
	return bool(cond.call())
