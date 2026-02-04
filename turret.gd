extends Area3D

@onready var bullet_scene = preload("bullet.tscn")

func _process(_delta: float) -> void:
	# Restart scene
	if Input.is_action_just_pressed("space"):
		get_tree().reload_current_scene()


func _on_area_entered(area: Area3D) -> void:
	# If enemy enters range, shoot at it
	var bullet = bullet_scene.instantiate()
	add_child(bullet)
	bullet.init_movement(global_position, area.global_position)
