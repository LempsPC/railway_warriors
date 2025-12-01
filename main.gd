extends Node3D

@onready var bullet = preload("bullet.tscn")

func  _process(delta: float) -> void:
	if Input.is_action_just_pressed("space"):
		add_child(bullet.instantiate())
