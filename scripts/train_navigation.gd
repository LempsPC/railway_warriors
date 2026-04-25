extends CharacterBody3D

@export var camera_position_node: Node3D = null
@export var track_pathfinding: Node3D
@export var move_speed := 8.0
@export var acceleration := 4.0
@export var deceleration := 8.0
@export var rotation_speed := 10.0

var path: Array = []
var path_index: int = 0
var current_speed: float = 0.0
var facing_dir := Vector3.RIGHT

# TODO move input and raycasting out of here
func _input(event):
	if event.is_action_pressed("R"):
		print("todo print graph")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var result = shoot_ray_from_mouse(event.position)
			if result:
				var new_path = track_pathfinding.shortest_path(result.position, position)
				if new_path:
					path = new_path
					path_index = 0

func shoot_ray_from_mouse(mouse_pos: Vector2):
	var camera = camera_position_node.get_child(0).get_child(0).get_child(0)
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_direction * 1000

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

func _physics_process(delta: float) -> void:
	if path.is_empty():
		current_speed = move_toward(current_speed, 0.0, deceleration * delta)
		return

	var target = path[path_index]
	var to_target = target - global_position
	var dist = to_target.length()

	if dist < 0.05:
		global_position = target
		path_index += 1
		if path_index >= path.size():
			path = []
			path_index = 0
		return

	var dir = to_target / dist

	# Detect direction reversal at next waypoint
	var must_stop = false
	if path_index + 1 < path.size():
		var next_dir = (path[path_index + 1] - target).normalized()
		if dir.dot(next_dir) < 0.0:
			must_stop = true

	# Kinematic braking: begin decelerating when remaining distance equals stopping distance (v²/2a)
	var target_speed = move_speed
	if must_stop:
		var stop_dist = (current_speed * current_speed) / (2.0 * deceleration)
		if dist <= stop_dist:
			target_speed = 0.0

	var rate = deceleration if current_speed > target_speed else acceleration
	current_speed = move_toward(current_speed, target_speed, rate * delta)

	var move_dist = current_speed * delta
	if dist <= move_dist:
		global_position = target
		path_index += 1
		if path_index >= path.size():
			path = []
			path_index = 0
	else:
		global_position += dir * move_dist

	if current_speed > 0.1:
		facing_dir = dir if dir.dot(facing_dir) >= 0.0 else -dir
	rotation.y = lerp_angle(rotation.y, atan2(-facing_dir.z, facing_dir.x), min(rotation_speed * delta, 1.0))
