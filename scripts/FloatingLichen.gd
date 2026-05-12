extends RigidBody3D

var _drift_target: Vector3 = Vector3.ZERO
var _retarget_timer: float = 0.0


func _ready() -> void:
	_retarget_timer = randf_range(0.0, 5.0)
	_pick_new_drift_target()


func _process(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = randf_range(3.0, 8.0)
		_pick_new_drift_target()
	apply_central_force(_drift_target * 0.6)


func _pick_new_drift_target() -> void:
	_drift_target = Vector3(randf_range(-0.6, 0.6), randf_range(-0.1, 0.1), randf_range(-0.6, 0.6)).normalized()
