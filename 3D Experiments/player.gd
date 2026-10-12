extends CharacterBody3D

@onready var ground_ray: RayCast3D = $RayCast3D
@export var planet_path: NodePath = ^"../Planet"
@onready var planet: Node3D = get_node_or_null(planet_path)
const GRAVITY_STRENGTH = 20.0
var gravity_direction := Vector3.DOWN
var pending_yaw := 0.0

@onready var neck := $Neck
@onready var camera := $Neck/Camera3D
@onready var player_body := $"."
@onready var neck_camera := $Neck/Camera3D

const MIN_ZOOM_FACTOR = 0.3
const MAX_ZOOM_FACTOR = INF
const CAMERA_DISTANCE_SCALE_Y = 1.7
const CAMERA_DISTANCE_SCALE_Z = 3.4
const CAMERA_ZOOM_SENSITIVITY = 1.05
const CAMERA_SENSITIVITY = 0.005
const SPEED = 5.0
const JUMP_VELOCITY = 12


func _ready() -> void:
	floor_snap_length = 0.4
	floor_constant_speed = true
	update_gravity()
	align_with_floor(up_direction)
	reset_physics_interpolation()


func update_gravity() -> void:
	# Keep pulling toward the planet while airborne.
	if is_instance_valid(planet):
		var toward_center := planet.global_position - global_position
		if not toward_center.is_zero_approx():

			gravity_direction = toward_center.normalized()
			ground_ray.target_position = ground_ray.to_local(planet.global_position)

	ground_ray.force_raycast_update()
	if ground_ray.is_colliding():
		var normal := ground_ray.get_collision_normal()
		if not normal.is_zero_approx():
			gravity_direction = -normal.normalized()
	up_direction = -gravity_direction


func _physics_process(delta: float) -> void:
	update_gravity()
	align_with_floor(up_direction)
	rotate_object_local(Vector3.UP, pending_yaw)
	pending_yaw = 0.0

	# Separate walking from falling.
	var fall_speed := velocity.dot(up_direction)
	if is_on_floor():
		fall_speed = minf(fall_speed, 0.0)
	fall_speed -= GRAVITY_STRENGTH * delta

	# Jump away from the surface.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		fall_speed = JUMP_VELOCITY

	# Walk along the surface.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (global_basis * Vector3(input_dir.x, 0, input_dir.y)).slide(up_direction).normalized()
	var walking_velocity := velocity.slide(up_direction)
	if input_dir != Vector2.ZERO:
		walking_velocity = direction * SPEED * input_dir.length()
	else:
		walking_velocity = walking_velocity.move_toward(Vector3.ZERO, 20.0 * delta)
	velocity = walking_velocity + up_direction * fall_speed
		
	move_and_slide()
	
func align_with_floor(floor_normal: Vector3) -> void:
	if floor_normal.is_zero_approx():
		return
	# Carry the heading around the sphere.
	var turn := Quaternion(global_basis.y.normalized(), floor_normal.normalized())
	global_basis = (Basis(turn) * global_basis).orthonormalized()
		
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			pending_yaw -= event.relative.x * CAMERA_SENSITIVITY

			neck.rotation.x = clamp(
				neck.rotation.x - event.relative.y * CAMERA_SENSITIVITY,
				deg_to_rad(-90),
				deg_to_rad(90)
			)
	if event is InputEventMouseButton and event.is_pressed():
		
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			neck_camera.position.y *= CAMERA_ZOOM_SENSITIVITY
			neck_camera.position.z *= CAMERA_ZOOM_SENSITIVITY
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			neck_camera.position.y /= CAMERA_ZOOM_SENSITIVITY
			neck_camera.position.z /= CAMERA_ZOOM_SENSITIVITY
		
		neck_camera.position.z = clamp(
			neck_camera.position.z, 
			CAMERA_DISTANCE_SCALE_Z * MIN_ZOOM_FACTOR, 
			CAMERA_DISTANCE_SCALE_Z * MAX_ZOOM_FACTOR
		)
		neck_camera.position.y = clamp(
			neck_camera.position.y, 
			CAMERA_DISTANCE_SCALE_Y * MIN_ZOOM_FACTOR, 
			CAMERA_DISTANCE_SCALE_Y * MAX_ZOOM_FACTOR
		)
