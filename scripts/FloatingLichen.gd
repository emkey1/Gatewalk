extends RigidBody3D

const StableRng = preload("res://scripts/core/StableRng.gd")

var rng_seed: int = 1
var _drift_target: Vector3 = Vector3.ZERO
var _retarget_timer: float = 0.0
var _rng = null


func _ready() -> void:
	_rng = StableRng.new(rng_seed)
	_retarget_timer = _rng.randf_range(0.0, 5.0)
	_pick_new_drift_target()


func _process(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = _rng.randf_range(3.0, 8.0)
		_pick_new_drift_target()
	apply_central_force(_drift_target * 0.6)


func _pick_new_drift_target() -> void:
	_drift_target = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.6, 0.6)).normalized()
