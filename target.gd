extends Area3D

func _process(delta: float) -> void:
	global_position += Vector3(4, 0, -4) * delta

func clear():
	queue_free()
