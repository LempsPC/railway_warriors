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

# The train is modelled as arc-length positions along one shared polyline
# ("route" = track already under the train + the computed path ahead).
# Every wagon samples the same polyline at head_s - i * wagon_spacing,
# so trailing units follow the rails instead of chasing the wagon ahead
# in a straight line (car-trailer behaviour).
var route: Array[Vector3] = []
var route_cum: Array[float] = []   # cumulative arc length at each route point
var head_s: float = 0.0            # lead wagon's arc-length position on route
var current_speed: float = 0.0

var detached_wagons: Array[Node3D] = []
var initial_facing := Vector3.RIGHT

var selected := false
var pending_attach: Node3D = null  # detached wagon we are driving to couple with
var select_material: StandardMaterial3D

func _ready() -> void:
	for child in get_children():
		if child is CharacterBody3D:
			wagons.append(child)

	if wagons.is_empty():
		push_error("Train has no wagon children")
		return

	var lead_pos = wagons[0].global_position
	for i in range(1, wagons.size()):
		wagons[i].global_position = lead_pos - initial_facing * wagon_spacing * i

	select_material = StandardMaterial3D.new()
	select_material.albedo_color = Color(0.55, 1.0, 0.55)

	_set_route([])

# TODO move input and raycasting out of here
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var result = shoot_ray_from_mouse(event.position)
			set_selected(result != null and result.collider in wagons)
		elif event.button_index == MOUSE_BUTTON_RIGHT and selected:
			var result = shoot_ray_from_mouse(event.position)
			if result == null:
				return
			var col = result.collider
			if col in wagons:
				_detach_clicked(col)
			elif col in detached_wagons:
				_command_attach(col)
			else:
				pending_attach = null
				set_destination(result.position)

func set_selected(value: bool) -> void:
	selected = value
	_refresh_selection_tint()

func _refresh_selection_tint() -> void:
	for w in wagons:
		_tint(w, selected)
	for w in detached_wagons:
		_tint(w, false)

func _tint(wagon: Node3D, on: bool) -> void:
	var mesh: MeshInstance3D = wagon.get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.material_override = select_material if on else null

# Parked wagons block the track; a coupling target must stay passable so we
# can path right up to it.
func set_destination(target_pos: Vector3, exclude_obstacle: Node3D = null) -> bool:
	if wagons.is_empty():
		return false
	var obstacles: Array = []
	for w in detached_wagons:
		if w != exclude_obstacle:
			obstacles.append(w.global_position)
	# Whichever end of the train is closer to the target leads.
	var d_front = wagons[0].global_position.distance_squared_to(target_pos)
	var d_back = wagons[-1].global_position.distance_squared_to(target_pos)
	var reverse: bool = d_back < d_front
	var lead = wagons[-1] if reverse else wagons[0]
	var new_path = track_pathfinding.shortest_path(target_pos, lead.global_position, obstacles)
	if new_path == null:
		return false
	if reverse:
		wagons.reverse()
	_set_route(new_path)
	return true

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

# Build the route polyline: current wagon positions (rear to front, so the
# train keeps standing on the track it already occupies) followed by the
# path ahead. head_s = arc length up to the lead wagon.
func _set_route(path_ahead: Array) -> void:
	var behind: Array[Vector3] = []
	for i in range(wagons.size() - 1, -1, -1):
		var p = wagons[i].global_position
		if behind.is_empty() or behind.back().distance_to(p) > 0.01:
			behind.append(p)

	head_s = 0.0
	for i in range(1, behind.size()):
		head_s += behind[i - 1].distance_to(behind[i])

	route = behind.duplicate()
	for p in path_ahead:
		if route.is_empty() or route.back().distance_to(p) > 0.01:
			route.append(p)
	_recompute_cum()

func _recompute_cum() -> void:
	route_cum = []
	var total := 0.0
	for i in range(route.size()):
		if i > 0:
			total += route[i - 1].distance_to(route[i])
		route_cum.append(total)

func _route_pos(s: float) -> Vector3:
	if route.is_empty():
		return global_position
	if route.size() == 1:
		return route[0]
	s = clamp(s, 0.0, route_cum.back())
	var i = clamp(route_cum.bsearch(s), 1, route.size() - 1)
	var seg_len = route_cum[i] - route_cum[i - 1]
	if seg_len < 0.0001:
		return route[i]
	var t = (s - route_cum[i - 1]) / seg_len
	return route[i - 1].lerp(route[i], t)

func _route_dir(s: float) -> Vector3:
	if route.size() < 2:
		return initial_facing
	s = clamp(s, 0.0, route_cum.back())
	var i = clamp(route_cum.bsearch(s), 1, route.size() - 1)
	# Skip zero-length segments in either direction.
	while i < route.size() - 1 and route_cum[i] - route_cum[i - 1] < 0.0001:
		i += 1
	while i > 1 and route_cum[i] - route_cum[i - 1] < 0.0001:
		i -= 1
	var d = route[i] - route[i - 1]
	if d.length() < 0.0001:
		return initial_facing
	return d.normalized()

func _physics_process(delta: float) -> void:
	_prune_freed_wagons()
	if wagons.is_empty() or route.size() < 2:
		return

	# When driving up to a wagon to couple, stop one coupling-length short
	# of the route end (the route ends at the wagon's spot on the track).
	var stop_s: float = route_cum.back()
	if pending_attach != null:
		stop_s = max(head_s, stop_s - wagon_spacing)
	var remaining = stop_s - head_s

	var target_speed := 0.0
	if remaining > 0.001:
		target_speed = move_speed
		# Kinematic braking: start decelerating when remaining distance equals stopping distance (v²/2a)
		var stop_dist = (current_speed * current_speed) / (2.0 * deceleration)
		if remaining <= stop_dist:
			target_speed = 0.0

	var rate = deceleration if current_speed > target_speed else acceleration
	current_speed = move_toward(current_speed, target_speed, rate * delta)
	head_s = min(head_s + current_speed * delta, stop_s)

	if pending_attach != null and stop_s - head_s <= 0.01 and current_speed < 0.01:
		_complete_attach()

	for i in range(wagons.size()):
		var w = wagons[i]
		var s = head_s - i * wagon_spacing
		w.global_position = _route_pos(s)
		var dir = _route_dir(s)
		# Wagons are symmetric, so a 180° flip looks identical. Keep the existing
		# heading when travel direction reverses instead of spinning the model.
		var current_face = Vector3(cos(w.rotation.y), 0.0, -sin(w.rotation.y))
		var face = dir if dir.dot(current_face) >= 0.0 else -dir
		w.rotation.y = lerp_angle(w.rotation.y, atan2(-face.z, face.x), min(rotation_speed * delta, 1.0))

# Units can be destroyed now (Health.free_unit_on_death), so the lists can hold
# freed nodes. Player wagons currently opt out of that, but a dangling entry
# here would crash the position loop, so drop them before touching anything.
func _prune_freed_wagons() -> void:
	for i in range(wagons.size() - 1, -1, -1):
		if not is_instance_valid(wagons[i]):
			wagons.remove_at(i)
	for i in range(detached_wagons.size() - 1, -1, -1):
		if not is_instance_valid(detached_wagons[i]):
			detached_wagons.remove_at(i)
	if pending_attach != null and not is_instance_valid(pending_attach):
		pending_attach = null

# --- Coupling ---

# Right-clicked one of our own units: uncouple it (and everything behind it).
# Clicking the lead unit leaves the lead solo and drops the rest.
func _detach_clicked(unit: Node3D) -> void:
	if wagons.size() < 2:
		return
	var idx = wagons.find(unit)
	if idx == 0:
		detach_rear(wagons.size() - 1)
	else:
		detach_wagon(unit)

# Right-clicked a detached wagon: drive to it, then couple on arrival.
func _command_attach(wagon: Node3D) -> void:
	if set_destination(wagon.global_position, wagon):
		pending_attach = wagon

# The train has stopped one coupling-length from the target wagon:
# put the wagon on the route end and make it the new front unit.
func _complete_attach() -> void:
	var wagon = pending_attach
	pending_attach = null
	detached_wagons.erase(wagon)
	var wpos = wagon.global_position
	if route.back().distance_to(wpos) > 0.01:
		route.append(wpos)
		_recompute_cum()
	head_s = route_cum.back()
	wagons.insert(0, wagon)
	_refresh_selection_tint()

# Couple a wagon to the rear of the train. The wagon should be at/near the
# rear; coupling from far away draws a straight connector on the route.
func attach_wagon(wagon: Node3D) -> void:
	if wagon in wagons:
		return
	detached_wagons.erase(wagon)
	if wagon.get_parent() != self:
		var xform = wagon.global_transform
		if wagon.get_parent():
			wagon.get_parent().remove_child(wagon)
		add_child(wagon)
		wagon.global_transform = xform
	# Extend the route backwards so the new rear wagon has polyline to sit on.
	var tail_pos = wagon.global_position
	if route.is_empty():
		route = [tail_pos]
		_recompute_cum()
		head_s = 0.0
	elif tail_pos.distance_to(route[0]) > 0.01:
		head_s += tail_pos.distance_to(route[0])
		route.insert(0, tail_pos)
		_recompute_cum()
	wagons.append(wagon)
	_refresh_selection_tint()

# Uncouple the last `count` wagons (the lead always stays). They keep their
# position on the track and can be re-coupled later.
func detach_rear(count: int = 1) -> Array[Node3D]:
	var freed: Array[Node3D] = []
	count = min(count, wagons.size() - 1)
	for i in range(count):
		var w = wagons.pop_back()
		freed.push_front(w)
		detached_wagons.append(w)
	_refresh_selection_tint()
	return freed

# Uncouple the given wagon and everything behind it.
func detach_wagon(wagon: Node3D) -> Array[Node3D]:
	var idx = wagons.find(wagon)
	if idx <= 0:
		return []
	return detach_rear(wagons.size() - idx)
