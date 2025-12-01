extends Area3D

@export var connections_ids = []
@export var connections_list: Array[Node3D] = []

func _ready() -> void:
	for object in connections_list:
		add_connection(object)
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))
	#blink_blue()

func blink_blue():
	var material = get_child(0).get_active_material(0)
	var new_material = material.duplicate()
	get_child(0).set_surface_override_material(0, new_material)
	new_material.albedo_color = Color.BLUE
	await get_tree().create_timer(2.0).timeout
	new_material.albedo_color = Color.RED
	

func add_connection(object):
	connections_ids.append(object.global_transform.origin)
	
	
# Used for adding connections between tracks
func _on_area_entered(area):
	add_connection(area)
	
