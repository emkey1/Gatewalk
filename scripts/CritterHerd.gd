class_name CritterHerd
extends Node3D

const StableRng = preload("res://scripts/core/StableRng.gd")

# A small herd of grazing land critters that wander the terrain near their spawn,
# following the ground via the map's height function. Land counterpart to BirdFlock
# (air) and FishSchool (water); bioscannable like both (species_name + catalog_id).

var critter_count: int = 4
var rng_seed: int = 1
var species_name: String = ""
var catalog_id: String = ""
var height_fn: Callable  # height_fn.call(world_x, world_z) -> float; supplied by the factory

var _critters: Array[Node3D] = []
var _legs: Array = []          # per critter: Array of 4 hip Node3D (legs[0]=FL,1=FR,2=BL,3=BR)
var _homes: Array[Vector2] = []
var _radii: Array[float] = []
var _wspeeds: Array[float] = []
var _phases: Array[float] = []
var _prev: Array[Vector2] = []
var _yaw: Array[float] = []
var _origin_xz: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	var rng := StableRng.new(rng_seed)
	_origin_xz = Vector2(global_position.x, global_position.z)
	var hue: float = fmod(float(rng_seed) * 0.61803398875, 1.0)
	var body_col := Color.from_hsv(hue, 0.32, rng.randf_range(0.5, 0.72))
	var leg_col := body_col.darkened(0.3)

	for i in range(critter_count):
		var scale: float = rng.randf_range(0.8, 1.3)
		var critter := Node3D.new()
		add_child(critter)
		_critters.append(critter)
		_legs.append(_build_critter(critter, body_col, leg_col, scale))
		_homes.append(Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0)))
		_radii.append(rng.randf_range(2.0, 5.0))
		_wspeeds.append(rng.randf_range(0.25, 0.55))
		_phases.append(rng.randf_range(0.0, TAU))
		_prev.append(_homes[i])
		_yaw.append(rng.randf_range(0.0, TAU))


func _process(delta: float) -> void:
	_time += delta
	if not height_fn.is_valid():
		return
	for i in range(critter_count):
		var ph: float = _phases[i]
		var r: float = _radii[i]
		var ws: float = _wspeeds[i]
		# Smooth meander around home (Lissajous-ish) — varied, no RNG at runtime.
		var rel := _homes[i] + Vector2(
			sin(_time * ws + ph) * r + sin(_time * ws * 0.43 + ph * 2.1) * r * 0.4,
			cos(_time * ws * 0.87 + ph * 1.3) * r + cos(_time * ws * 0.51 + ph) * r * 0.4)
		var critter: Node3D = _critters[i]
		var gy: float = float(height_fn.call(_origin_xz.x + rel.x, _origin_xz.y + rel.y)) - global_position.y
		critter.position = Vector3(rel.x, gy, rel.y)

		var vel := rel - _prev[i]
		if vel.length() > 0.0008:
			_yaw[i] = lerp_angle(_yaw[i], atan2(vel.x, vel.y), 0.12)
			critter.rotation.y = _yaw[i]
		_prev[i] = rel

		# Diagonal-pair walk cycle, faster as they move faster.
		var legs: Array = _legs[i]
		if legs.size() == 4:
			var step: float = sin(_time * (4.0 + ws * 6.0) + ph) * 0.5
			legs[0].rotation.x = step
			legs[3].rotation.x = step
			legs[1].rotation.x = -step
			legs[2].rotation.x = -step


# Builds one critter under `parent` (origin at the feet) and returns its 4 hip nodes.
func _build_critter(parent: Node3D, body_col: Color, leg_col: Color, scale: float) -> Array:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_col
	body_mat.roughness = 0.85
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = leg_col
	leg_mat.roughness = 0.9

	var leg_len: float = 0.32 * scale
	var body_y: float = leg_len + 0.18 * scale

	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.22 * scale
	bm.height = 0.40 * scale
	body.mesh = bm
	body.material_override = body_mat
	body.scale = Vector3(1.0, 0.9, 1.7)  # stretched front-to-back
	body.position = Vector3(0.0, body_y, 0.0)
	parent.add_child(body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13 * scale
	hm.height = 0.24 * scale
	head.mesh = hm
	head.material_override = body_mat
	head.position = Vector3(0.0, body_y + 0.10 * scale, 0.42 * scale)
	parent.add_child(head)

	var legs: Array = []
	var lx: float = 0.13 * scale
	var lz: float = 0.28 * scale
	for corner in [Vector2(-lx, lz), Vector2(lx, lz), Vector2(-lx, -lz), Vector2(lx, -lz)]:
		var hip := Node3D.new()
		hip.position = Vector3(corner.x, leg_len, corner.y)
		parent.add_child(hip)
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.07 * scale, leg_len, 0.07 * scale)
		leg.mesh = lm
		leg.material_override = leg_mat
		leg.position = Vector3(0.0, -leg_len * 0.5, 0.0)  # hangs from the hip to the foot at y=0
		hip.add_child(leg)
		legs.append(hip)
	return legs
