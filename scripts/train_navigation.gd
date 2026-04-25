class_name Train
extends Node3D

@export var camera_position_node: Node3D = null
@export var track_pathfinding: Node3D
@export var move_speed := 8.0
@export var acceleration := 4.0
@export var deceleration := 8.0
@export var rotation_speed := 10.0
@export var wagon_spacing := 2.5

var wagons: Array[Node3D] = []
var path: Array = []
var path_index: int = 0
var current_speed: float = 0.0
var facing_dir := Vector3.RIGHT

func _ready() -> void:
	for child in get_children():
		if child is CharacterBody3D:
			wagons.append(child)

	if wagons.is_empty():
		push_error("Train has no wagon children")
		return

	var lead_pos = wagons[0].global_position
	for i in range(1, wagons.size()):
		wagons[i].global_position = lead_pos - facing_dir * wagon_spacing * i

# TODO move input and raycasting out of here
func _input(event):
	if event.is_action_pressed("R"):
		print("todo print graph")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var result = shoot_ray_from_mouse(event.position)
			if result:
				# Whichever end of the train is closer to the target leads.
				# Reversing the wagons array makes the rear end the new lead, and
				# flipping facing_dir keeps the chain's heading consistent with motion.
				var front = wagons[0]
				var back = wagons[-1]
				var d_front = front.global_position.distance_squared_to(result.position)
				var d_back = back.global_position.distance_squared_to(result.position)
				if d_back < d_front:
					wagons.reverse()
				var lead = wagons[0]
				var new_path = track_pathfinding.shortest_path(result.position, lead.global_position)
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
	if wagons.is_empty():
		return
	var lead = wagons[0]

	if path.is_empty():
		current_speed = move_toward(current_speed, 0.0, deceleration * delta)
	else:
		var target = path[path_index]
		var to_target = target - lead.global_position
		var dist = to_target.length()

		if dist < 0.05:
			lead.global_position = target
			path_index += 1
			if path_index >= path.size():
				path = []
				path_index = 0
		else:
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
				lead.global_position = target
				path_index += 1
				if path_index >= path.size():
					path = []
					path_index = 0
			else:
				lead.global_position += dir * move_dist

			if current_speed > 0.1:
				facing_dir = dir if dir.dot(facing_dir) >= 0.0 else -dir

	lead.rotation.y = lerp_angle(lead.rotation.y, atan2(-facing_dir.z, facing_dir.x), min(rotation_speed * delta, 1.0))

	# Each trailing wagon stays at fixed distance from the wagon ahead.
	# When the lead reverses, this rule shifts the whole chain rigidly along its current heading,
	# so the rear wagon naturally ends up leading in the new direction.
	for i in range(1, wagons.size()):
		var prev_w = wagons[i - 1]
		var w = wagons[i]
		var to_prev = prev_w.global_position - w.global_position
		var d = to_prev.length()
		if d > 0.0001:
			var dir_to_prev = to_prev / d
			w.global_position = prev_w.global_position - dir_to_prev * wagon_spacing
			# Wagons are symmetric, so a 180° flip looks identical. Keep the existing
			# heading when the chain reverses (after swap) instead of spinning the model.
			var current_face = Vector3(cos(w.rotation.y), 0.0, -sin(w.rotation.y))
			var face = dir_to_prev if dir_to_prev.dot(current_face) >= 0.0 else -dir_to_prev
			w.rotation.y = lerp_angle(w.rotation.y, atan2(-face.z, face.x), min(rotation_speed * delta, 1.0))
