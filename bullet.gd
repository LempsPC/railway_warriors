extends Node3D

var height = 5
var time_total = 2
var time_passed = 0
var start_pos = Vector3.ZERO
var end_pos = Vector3.ZERO
var dist = 0
@onready var turret = get_node("/root/Main/Turret")
@onready var target = get_node("/root/Main/Target")

func _ready() -> void:
	start_pos = turret.global_position
	end_pos = target.global_position
	# rotation = start_pos.direction_to(end_pos)
	global_position = start_pos
	dist = start_pos.distance_to(end_pos)
	
func _process(delta: float) -> void:
	time_passed += delta
	global_position = global_position.move_toward(end_pos, delta/time_total*dist)
	global_position.y = start_pos.y + sin(time_passed / time_total * PI) * height
	
	if time_passed >= time_total:
		queue_free()
