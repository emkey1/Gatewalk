extends CharacterBody3D

const WALK_SPEED: float = 8.0
const SPRINT_SPEED: float = 13.0
const JUMP_VELOCITY: float = 6.0
const MOUSE_SENSITIVITY: float = 0.0025
const GRAVITY: float = 20.0
const SWIM_UP_SPEED: float = 3.2
const MAX_SPRINT_STAMINA: float = 15.0

# Godot's default is around 45 degrees. That is sensible for real legs,
# less sensible for a prototype explorer where hills are mostly noise.
const WALKABLE_SLOPE_DEGREES: float = 72.0

var camera: Camera3D
var pitch: float = 0.0
var gravity_multiplier: float = 1.0
var jump_multiplier: float = 1.0
var water_level: float = -1.7
var sprint_stamina: float = MAX_SPRINT_STAMINA


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
	capsule.position.y = 0.9
	add_child(capsule)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.position = Vector3(0.0, 1.65, 0.0)
	add_child(camera)


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


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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
