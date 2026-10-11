extends CharacterBody3D

@onready var neck := $Neck
@onready var camera := $Neck/Camera3D
@onready var player_body := $"."
@onready var neck_camera := $Neck/Camera3D

var xform : Transform3D

const MIN_ZOOM_FACTOR = 0.3
const MAX_ZOOM_FACTOR = INF
const CAMERA_DISTANCE_SCALE_Y = 1.7
const CAMERA_DISTANCE_SCALE_Z = 3.4
const CAMERA_ZOOM_SENSITIVITY = 1.05
const CAMERA_SENSITIVITY = 0.005
const SPEED = 5.0
const JUMP_VELOCITY = 12


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (player_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	move_and_slide()
	if is_on_floor():
		align_with_floor(get_floor_normal())
		global_transform = global_transform.interpolate_with(xform, 0.3)
	
func align_with_floor(floor_normal: Vector3) -> void:
	xform = global_transform
	if floor_normal.is_zero_approx():
		return
	var right_axis := floor_normal.cross(xform.basis.z)
	if right_axis.is_zero_approx():
		return
	xform.basis.y = floor_normal.normalized()
	xform.basis.x = right_axis.normalized()
	xform.basis.z = xform.basis.x.cross(xform.basis.y).normalized()
	xform.basis = xform.basis.orthonormalized()
		
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			player_body.rotate_y(-event.relative.x * CAMERA_SENSITIVITY)

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
