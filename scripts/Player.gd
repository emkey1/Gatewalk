extends CharacterBody3D

const WALK_SPEED: float = 8.0
const SPRINT_SPEED: float = 13.0
const JUMP_VELOCITY: float = 6.0
const MOUSE_SENSITIVITY: float = 0.0025
const GRAVITY: float = 20.0
const SWIM_UP_SPEED: float = 3.2
const MAX_SPRINT_STAMINA: float = 15.0
const MAX_BREATH: float = 60.0
const FLASHLIGHT_MAX_CHARGE: float = 30.0
const FLASHLIGHT_RECHARGE_RATE: float = 2.0

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
		if flashlight_charge > 0.0:
			flashlight_on = not flashlight_on
			flashlight.light_energy = 10.5 if flashlight_on else 0.0


func _physics_process(delta: float) -> void:
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
		sprint_stamina = min(sprint_stamina + delta / 3.0, MAX_SPRINT_STAMINA)
	if underwater:
		speed *= 0.55
		breath = max(breath - delta, 0.0)
	else:
		breath = min(breath + delta * 2.0, MAX_BREATH)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if underwater:
		velocity.y -= GRAVITY * gravity_multiplier * 0.18 * delta
		velocity.y *= 0.94
		if Input.is_action_pressed("jump"):
			velocity.y = SWIM_UP_SPEED
	elif is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY * jump_multiplier
		else:
			velocity.y = -0.1
	else:
		velocity.y -= GRAVITY * gravity_multiplier * delta

	move_and_slide()

	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is RigidBody3D:
			var push_dir: Vector3 = -collision.get_normal()
			var rigid_body: RigidBody3D = collider as RigidBody3D
			rigid_body.apply_impulse(push_dir * 2.8, collision.get_position() - rigid_body.global_position)

	if flashlight_on:
		var moving: bool = input_dir.length() > 0.0
		if moving:
			flashlight_charge = min(flashlight_charge + delta * FLASHLIGHT_RECHARGE_RATE, FLASHLIGHT_MAX_CHARGE)
		else:
			flashlight_charge -= delta
			if flashlight_charge <= 0.0:
				flashlight_charge = 0.0
				flashlight_on = false
				flashlight.light_energy = 0.0
