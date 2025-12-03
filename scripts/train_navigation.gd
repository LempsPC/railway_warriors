extends CharacterBody3D

@export var camera_position_node: Node3D = null
@export var track_pathfinding: Node3D
@export var move_speed := 8.0
@export var acceleration := 20.0
var path = null

# TODO move input and raycasting out of here
func _input(event):
	if event.is_action_pressed("R"):
		print("todo print graph")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var collision_pos = shoot_ray_from_mouse(event.position).position
			path = track_pathfinding.shortest_path(collision_pos, position)

func shoot_ray_from_mouse(mouse_pos: Vector2):
	var camera = camera_position_node.get_child(0).get_child(0).get_child(0)
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_direction * 1000  # Length of ray

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space_state.intersect_ray(query)

	if result:
		print("Hit at position:", result.position)
		print("Collider:", result.collider)
		return result
	else:
		print("No hit.")
		return null

var i = 0
func _physics_process(delta: float) -> void:
	if path != null:
		if position.distance_to(path[i]) < 1:
			i += 1
		if i >= path.size():
			i = 0
			path = null
			return
		var move_dir = position.direction_to(path[i]).normalized()
		velocity = velocity.move_toward(move_dir * move_speed, delta * acceleration)
		move_and_slide()
