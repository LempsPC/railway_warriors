extends Area3D

var connections_ids = []
@export var connections_list: Array[Node3D] = []

func _ready() -> void:
	connections_ids = []
	for object in connections_list:
		add_connection(object)
	connect("area_entered", Callable(self, "_on_area_entered"))

func blink_blue():
	var material = get_child(0).get_active_material(0)
	var new_material = material.duplicate()
	get_child(0).set_surface_override_material(0, new_material)
	new_material.albedo_color = Color.BLUE
	await get_tree().create_timer(2.0).timeout
	new_material.albedo_color = Color.RED

func add_connection(object: Node3D) -> void:
	connections_ids.append(object.global_transform.origin)

func _on_area_entered(area: Area3D) -> void:
	add_connection(area)
