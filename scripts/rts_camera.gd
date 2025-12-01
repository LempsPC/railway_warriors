extends Node3D

@onready var rotation_x = $CameraRotationX
@onready var zoom_pivot = $CameraRotationX/CameraZoomPivot
@onready var camera = $CameraRotationX/CameraZoomPivot/Camera3D

#variables
var move_speed = 0.6
var move_target: Vector3
var rotate_keys_speed = 1.5
var rotate_keys_target: float
var zoom_speed = 3.0
var zoom_target: float
var min_zoom = -20.0
var max_zoom = 20.0

func _ready() -> void:
	move_target = position
	rotate_keys_speed = rotation_degrees.y
	zoom_target = camera.position.z
	
func _process(delta: float) -> void:
	# get input directions
	var input_direction = Input.get_vector("left", "right", "up", "down")
	var movement_direction = (transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	var rotate_keys = Input.get_axis("rotate_left", "rotate_right")
	var zoom_dir = (int(Input.is_action_just_released("camera_zoom_out")) -
					int(Input.is_action_just_released("camera_zoom_in")))
	# set movement targets
	move_target += move_speed * movement_direction
	rotate_keys_target += rotate_keys * rotate_keys_speed
	zoom_target	+= zoom_dir * zoom_speed
	zoom_target = clamp(zoom_target, min_zoom, max_zoom)
	# lerp to movement targets
	position = lerp(position, move_target, 0.08)
	rotation_degrees.y = lerp(rotation_degrees.y, rotate_keys_target, 0.2)
	camera.position.z = lerp(camera.position.z, zoom_target, 0.10)
