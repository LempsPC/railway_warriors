extends Node3D

var height = 2
var time_total = 1
var speed = 10

var time_passed = 0
var start_pos = Vector3.ZERO
var end_pos = Vector3.ZERO

func init_movement(start, end):
	start_pos = start
	end_pos = end
	rotation = start_pos.direction_to(end_pos)
	speed = start_pos.distance_to(end_pos) / time_total - 4
	global_position = start_pos

func _process(delta: float) -> void:
	time_passed += delta
	global_position += rotation * delta * speed
	global_position.y = start_pos.y + height - pow((time_passed / time_total * 2 - 1) , 2) * height 


func _on_area_entered(area: Area3D) -> void:
	if time_passed > 0.1:
		if area.has_method("clear"):
			area.clear()
		print("clear")
		queue_free()
