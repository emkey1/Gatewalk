extends CharacterBody3D

const WALK_SPEED: float = 8.0
const SPRINT_SPEED: float = 13.0
const JUMP_VELOCITY: float = 6.0
const JUMP_MIN_HEIGHT_SCALE: float = 0.35
const JUMP_MAX_HEIGHT_SCALE: float = 1.5
const JUMP_HOLD_DURATION: float = 0.24
const MOUSE_SENSITIVITY: float = 0.0025
const GRAVITY: float = 20.0
const SWIM_UP_SPEED: float = 3.2
const MAX_SPRINT_STAMINA: float = 15.0
const MAX_BREATH: float = 60.0
const FLASHLIGHT_MAX_CHARGE: float = 30.0
const FLASHLIGHT_RECHARGE_RATE: float = 2.0
const FLASHLIGHT_ENABLE_THRESHOLD: float = 8.0

# Arctic exposure. Warmth drains while out in the open and recovers near shelter
# (warm landmarks like gates and wonders). Only active when warmth_enabled (arctic).
const MAX_WARMTH: float = 50.0
const WARMTH_DRAIN_PER_SEC: float = 1.0
const WARMTH_REGEN_PER_SEC: float = 5.0
const WARMTH_LOW_FRACTION: float = 0.25
const WARMTH_COLD_SPEED_SCALE: float = 0.6

const WALKABLE_SLOPE_DEGREES: float = 72.0

var camera: Camera3D
var pitch: float = 0.0
var gravity_multiplier: float = 1.0
var jump_multiplier: float = 1.0
var water_level: float = -1.7
var sprint_stamina: float = MAX_SPRINT_STAMINA
var breath: float = MAX_BREATH
var lichen_count: int = 0
var flashlight_on: bool = false
var flashlight_charge: float = FLASHLIGHT_MAX_CHARGE
var flashlight: SpotLight3D
var flashlight_requested_on: bool = false

# Tunable capability ceilings. Default to the base consts; ProgressionService
# raises them through apply_capabilities() as the player earns Cartographer's Kit
# upgrades. Physics reads these vars (not the consts) so upgrades take effect live.
var max_sprint_stamina: float = MAX_SPRINT_STAMINA
var sprint_regen_per_sec: float = 1.0 / 3.0
var max_breath: float = MAX_BREATH
var max_flashlight_charge: float = FLASHLIGHT_MAX_CHARGE
var flashlight_base_range: float = 40.0
var flashlight_range_bonus: float = 0.0
var max_warmth: float = MAX_WARMTH
var warmth: float = MAX_WARMTH
var warmth_drain_per_sec: float = WARMTH_DRAIN_PER_SEC
var warmth_enabled: bool = false   # set true by Main on arctic maps
var sheltered: bool = false        # set by Main when near a warm landmark
var _jump_hold_remaining: float = 0.0
var _jump_hold_boost_per_sec: float = 0.0

# Spherical "hollow-planet" gravity (skyscraper outside only): down always points at the nearest
# sphere wall, so you walk the whole inner surface. Main flips this on/off via set_spherical_mode.
var spherical_gravity: bool = false
var sphere_center: Vector3 = Vector3.ZERO
var _look_fwd: Vector3 = Vector3(0.0, 0.0, -1.0)   # heading, kept in the local tangent plane


# Switch hollow-planet gravity on/off, smoothing the orientation handoff both ways.
func set_spherical_mode(on: bool, center: Vector3) -> void:
	sphere_center = center
	if on == spherical_gravity:
		return
	if on:
		# seed the heading from the current facing
		var f: Vector3 = -global_transform.basis.z
		f.y = 0.0
		if f.length() < 0.01:
			f = Vector3(0.0, 0.0, -1.0)
		_look_fwd = f.normalized()
		spherical_gravity = true
	else:
		# back to upright +Y: keep yaw, drop the tilt
		var f2: Vector3 = -global_transform.basis.z
		f2.y = 0.0
		if f2.length() < 0.01:
			f2 = _look_fwd
			f2.y = 0.0
		spherical_gravity = false
		up_direction = Vector3.UP
		global_transform.basis = Basis()
		rotation.y = atan2(-f2.x, -f2.z)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	collision_layer = 2
	collision_mask = 1

	floor_max_angle = deg_to_rad(WALKABLE_SLOPE_DEGREES)
	floor_snap_length = 0.75
	safe_margin = 0.08
	max_slides = 6

	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	capsule.shape = shape
	add_child(capsule)
	capsule.position.y = 0.9

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.position = Vector3(0.0, 1.65, 0.0)
	add_child(camera)

	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.spot_angle = 50.0
	flashlight.spot_angle_attenuation = 1.0
	flashlight.spot_range = 40.0
	flashlight.light_energy = 0.0
	flashlight.light_color = Color(0.95, 0.93, 0.85)
	flashlight.shadow_enabled = false
	flashlight.position = Vector3(0.0, 0.0, -0.15)
	camera.add_child(flashlight)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if spherical_gravity:
			var up: Vector3 = (sphere_center - global_position).normalized()
			_look_fwd = _look_fwd.rotated(up, -event.relative.x * MOUSE_SENSITIVITY).normalized()
		else:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-89.0), deg_to_rad(89.0))
		camera.rotation.x = pitch

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		flashlight_requested_on = not flashlight_requested_on
		if not flashlight_requested_on:
			flashlight_on = false
			flashlight.light_energy = 0.0
		elif flashlight_charge >= FLASHLIGHT_ENABLE_THRESHOLD:
			flashlight_on = true
			flashlight.light_energy = 10.5


func _physics_process(delta: float) -> void:
	if spherical_gravity:
		_physics_spherical(delta)
		return
	var input_dir := Vector2(Input.get_vector("move_left", "move_right", "move_forward", "move_back"))
	var underwater: bool = global_position.y + 1.65 < water_level

	var direction := Vector3.ZERO
	if input_dir.length() > 0.0:
		var forward := -global_transform.basis.z
		var right := global_transform.basis.x
		direction = (right * input_dir.x + forward * -input_dir.y).normalized()

	var speed := WALK_SPEED
	var wants_sprint: bool = Input.is_action_pressed("sprint") and input_dir.length() > 0.0 and sprint_stamina > 0.0
	if wants_sprint:
		speed = SPRINT_SPEED
		sprint_stamina = max(sprint_stamina - delta, 0.0)
	else:
		sprint_stamina = min(sprint_stamina + delta * sprint_regen_per_sec, max_sprint_stamina)
	if underwater:
		speed *= 0.55
		breath = max(breath - delta, 0.0)
	else:
		breath = min(breath + delta * 2.0, max_breath)

	if warmth_enabled:
		if sheltered:
			warmth = min(warmth + delta * WARMTH_REGEN_PER_SEC, max_warmth)
		else:
			warmth = max(warmth - delta * warmth_drain_per_sec, 0.0)
		if warmth <= max_warmth * WARMTH_LOW_FRACTION:
			speed *= WARMTH_COLD_SPEED_SCALE

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if underwater:
		velocity.y -= GRAVITY * gravity_multiplier * 0.18 * delta
		velocity.y *= 0.94
		if Input.is_action_pressed("jump"):
			velocity.y = SWIM_UP_SPEED
	elif is_on_floor():
		if Input.is_action_just_pressed("jump"):
			var min_velocity_scale: float = sqrt(JUMP_MIN_HEIGHT_SCALE)
			var max_velocity_scale: float = sqrt(JUMP_MAX_HEIGHT_SCALE)
			var base_jump_velocity: float = JUMP_VELOCITY * jump_multiplier * min_velocity_scale
			velocity.y = base_jump_velocity
			_jump_hold_remaining = JUMP_HOLD_DURATION
			var target_jump_velocity: float = JUMP_VELOCITY * jump_multiplier * max_velocity_scale
			var extra_velocity: float = max(target_jump_velocity - base_jump_velocity, 0.0)
			_jump_hold_boost_per_sec = extra_velocity / JUMP_HOLD_DURATION
		else:
			velocity.y = -0.1
			_jump_hold_remaining = 0.0
	elif _jump_hold_remaining > 0.0 and velocity.y > 0.0 and Input.is_action_pressed("jump"):
		var hold_step: float = min(delta, _jump_hold_remaining)
		velocity.y += _jump_hold_boost_per_sec * hold_step
		_jump_hold_remaining -= hold_step
	else:
		velocity.y -= GRAVITY * gravity_multiplier * delta
		if not Input.is_action_pressed("jump"):
			_jump_hold_remaining = 0.0

	move_and_slide()

	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is RigidBody3D:
			var push_dir: Vector3 = -collision.get_normal()
			var rigid_body: RigidBody3D = collider as RigidBody3D
			rigid_body.apply_impulse(push_dir * 2.8, collision.get_position() - rigid_body.global_position)

	var horizontal_speed: float = Vector2(get_real_velocity().x, get_real_velocity().z).length()
	var vertical_motion: float = abs(velocity.y)
	var moving: bool = horizontal_speed > 0.35 or (underwater and vertical_motion > 0.2)
	if flashlight_on:
		if moving:
			# Motion charging should beat active drain to avoid "moving but still emptying" behavior.
			flashlight_charge = min(flashlight_charge + delta * FLASHLIGHT_RECHARGE_RATE * 1.25, max_flashlight_charge)
		else:
			flashlight_charge -= delta
	else:
		if moving:
			flashlight_charge = min(flashlight_charge + delta * FLASHLIGHT_RECHARGE_RATE, max_flashlight_charge)
	if flashlight_charge <= 0.0:
		flashlight_charge = 0.0
		flashlight_on = false
		flashlight.light_energy = 0.0
	if flashlight_requested_on and not flashlight_on and flashlight_charge >= FLASHLIGHT_ENABLE_THRESHOLD:
		flashlight_on = true
		flashlight.light_energy = 10.5


# Hollow-planet movement: "up" points from the player toward the sphere centre, so you can walk
# the entire inner surface. Reuses _look_fwd (heading) and the camera pitch.
func _physics_spherical(delta: float) -> void:
	var up: Vector3 = sphere_center - global_position
	if up.length() < 0.05:
		up = Vector3.UP
	up = up.normalized()
	up_direction = up
	# Re-orient: +Y = up, -Z = heading (kept in the tangent plane).
	var f: Vector3 = _look_fwd - up * _look_fwd.dot(up)
	if f.length() < 0.01:
		var bz: Vector3 = -global_transform.basis.z
		f = bz - up * bz.dot(up)
	f = f.normalized()
	_look_fwd = f
	var zaxis: Vector3 = -f
	var xaxis: Vector3 = up.cross(zaxis).normalized()
	var yaxis: Vector3 = zaxis.cross(xaxis).normalized()
	global_transform.basis = Basis(xaxis, yaxis, zaxis)

	var input_dir: Vector2 = Vector2(Input.get_vector("move_left", "move_right", "move_forward", "move_back"))
	var direction: Vector3 = xaxis * input_dir.x + f * -input_dir.y
	if direction.length() > 0.0:
		direction = direction.normalized()

	var speed: float = WALK_SPEED
	var wants_sprint: bool = Input.is_action_pressed("sprint") and input_dir.length() > 0.0 and sprint_stamina > 0.0
	if wants_sprint:
		speed = SPRINT_SPEED
		sprint_stamina = max(sprint_stamina - delta, 0.0)
	else:
		sprint_stamina = min(sprint_stamina + delta * sprint_regen_per_sec, max_sprint_stamina)
	breath = min(breath + delta * 2.0, max_breath)

	var v_up: float = velocity.dot(up)
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			v_up = JUMP_VELOCITY * jump_multiplier
		else:
			v_up = -0.1
	else:
		v_up -= GRAVITY * gravity_multiplier * delta
	velocity = direction * speed + up * v_up
	move_and_slide()


# Raise capability ceilings from a ProgressionService capabilities dict and top up
# the live pools so a freshly earned upgrade is felt immediately. At spawn this runs
# before save-state restore, which re-applies any persisted mid-session values.
func apply_capabilities(caps: Dictionary) -> void:
	max_breath = float(caps.get("max_breath", MAX_BREATH))
	max_sprint_stamina = float(caps.get("max_sprint_stamina", MAX_SPRINT_STAMINA))
	sprint_regen_per_sec = float(caps.get("sprint_regen_per_sec", 1.0 / 3.0))
	max_flashlight_charge = float(caps.get("max_flashlight_charge", FLASHLIGHT_MAX_CHARGE))
	flashlight_range_bonus = float(caps.get("flashlight_range_bonus", 0.0))
	max_warmth = float(caps.get("max_warmth", MAX_WARMTH))
	warmth_drain_per_sec = float(caps.get("warmth_drain_per_sec", WARMTH_DRAIN_PER_SEC))
	if flashlight != null:
		flashlight.spot_range = flashlight_base_range + flashlight_range_bonus
	breath = max_breath
	sprint_stamina = max_sprint_stamina
	flashlight_charge = max_flashlight_charge
	warmth = max_warmth
