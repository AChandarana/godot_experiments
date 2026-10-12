extends AnimatableBody3D

const MOVEMENT_SPEED = 5.0
const HEIGHT_MAX = 10.0
const HEIGHT_MIN = 0.0

var up := true
var starting_height: float


func _ready() -> void:
	starting_height = position.y


func _physics_process(delta: float) -> void:
	var min_height := starting_height + HEIGHT_MIN
	var max_height := starting_height + HEIGHT_MAX
	var target_height := max_height if up else min_height

	position.y = move_toward(
		position.y,
		target_height,
		MOVEMENT_SPEED * delta
	)

	if position.y >= max_height:
		up = false
	elif position.y <= min_height:
		up = true
