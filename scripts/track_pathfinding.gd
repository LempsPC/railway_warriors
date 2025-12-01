extends Node3D

var graph = {}
@export var camera_position_node: Node3D = null
var point_scene = preload("res://scenes/point.tscn")

func _ready() -> void:
	var connections = get_node_data()
	graph = connections_to_graph(connections)

func _process(delta: float) -> void:
	var connections = get_node_data()
	graph = connections_to_graph(connections)

func visualize_path(path):
	var points = []
	for point in path:
		var point_instance = point_scene.instantiate()
		point_instance.position = point
		add_child(point_instance)
		points.append(point_instance)
	await get_tree().create_timer(1.0).timeout
	for point_instance in points:
		point_instance.queue_free()
	

#var graph = {
	#"A": {"B": 3, "E": 3},
	#"B": {"A": 3, "C": 3},
	#"C": {"B": 3, "D": 2},
	#"D": {"C": 2, "H": 1.5},
	#"E": {"A": 3, "G": 3, "F": 3},
	#"F": {"E": 3, "H": 3},
	#"G": {"E": 3, "I": 3},
	#"H": {"F": 3, "D": 1.5},
	#"I": {"G": 3}
#}

#var connections = {
	#"(0.0,0.0,0.0)": ["(0.0,1.0,0.0)"],
	#"(0.0,1.0,0.0)": ["(0.0,0.0,0.0)"]
#}

func _input(event):
	if event.is_action_pressed("R"):
		print(graph)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var collision_pos = shoot_ray_from_mouse(event.position).position
			find_closest_node_to_click(collision_pos)

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

func connections_to_graph(connections):
	var graph = {}
	for item in connections:
		var weghted_dict = {}
		var values = connections[item]
		for value in values:
			weghted_dict[value] = item.distance_to(value)
		graph[item] = weghted_dict
	return graph


func get_node_data() -> Dictionary:
	var connections = {}
	
	for child in get_children():
		var points_parent = child.get_child(0)
		for sphere in points_parent.get_children():
			var current_point_connections = []
			current_point_connections = sphere.connections_ids
			connections[sphere.global_transform.origin] = current_point_connections
	return connections


#func save_data_to_json(filepath, points):
	#var data = {}
	#
	## Check if file exists and copy data
	#if FileAccess.file_exists(filepath):
		#var file = FileAccess.open(filepath, FileAccess.READ)
		#var json_string = file.get_as_text()
		#file.close()
#
		#var result = JSON.parse_string(json_string)
		#if result is Dictionary:
			#data = result  # Keep the existing data
		#else:
			#print("Warning: JSON parse failed. Overwriting with new data.")
	#else:
		#print("File not found. Creating new JSON file.")
#
	## Change data
	#for point in points:
		#add_node_to_json(data, point.name, point.position)
		#for connection in point.connection_ids:
			#add_segment_to_json(data, point.name, connection)
	#
	#
	## Update data
	#var updated_json = JSON.stringify(data, "\t")  # Optional pretty print
	#var save_file = FileAccess.open(filepath, FileAccess.WRITE)
	#save_file.store_string(updated_json)
	#save_file.close()
#
	#print("New node added to JSON.")


#func add_node_to_json(data, id, position_vec3):
	#var new_dictionary = {
		#id: {
			#"x": position_vec3.x, 
			#"y": position_vec3.y, 
			#"z": position_vec3.z
		#}
	#}
	#data["nodes"].merge(new_dictionary)


#func add_segment_to_json(data, start_node_id, end_node_id):
	#var id = start_node_id + "to" + end_node_id
	#var new_dictionary = {
		#id: {
			#"from": start_node_id,
			#"is_bidirectional": true, 
			#"to": end_node_id
		#}
	#}
	#data["segments"].merge(new_dictionary)


func find_closest_node_to_click(click_pos):
	var current_closest_point_dist = INF
	var closest_point = null
	for point in graph:
		var dist_to_point = click_pos.distance_to(point)
		if dist_to_point < current_closest_point_dist:
			current_closest_point_dist = dist_to_point
			closest_point = point
	var goal = closest_point
	#closest_point.blink_blue()
	# Make the first point on graph the navigation starting point
	var temporary_start = (graph.keys()[0])
	var result = dijkstra(temporary_start, goal)
	print(result)
	
	#if result:
		#print("Shortest path from %s to %s: %s" % [temporary_start, goal, result["path"]])
		#print("Total cost: %d" % result["cost"])
	#else:
		#print("No path found.")
	
#Dijkstra’s algorithm (returns Dictionary or null)
func dijkstra(start, goal) -> Variant:
	var unvisited = graph.keys()
	var distances = {}
	var previous = {}

	# Initialize distances
	for node in unvisited:
		distances[node] = INF
		previous[node] = null
	distances[start] = 0
	
	while unvisited.size() > 0:
		var current = get_closest_node_on_path(unvisited, distances)
		unvisited.erase(current)
		
		# If reached goal, reconstruct path
		if current == goal:
			var path = []
			var temp = goal
			while temp != null:
				path.insert(0, temp)
				temp = previous[temp]
			visualize_path(path)
			return {"path": path, "cost": distances[goal]}
		
		# Visit neighbors
		for neighbor in graph[current].keys():
			if neighbor in unvisited:
				var alt = distances[current] + graph[current][neighbor]
				if alt < distances[neighbor]:
					distances[neighbor] = alt
					previous[neighbor] = current
	
	# Goal not reachable
	return null


func get_closest_node_on_path(nodes: Array, distances: Dictionary):
	var min_node = nodes[0]
	var min_distance = distances[min_node]
	for node in nodes:
		if distances[node] < min_distance:
			min_node = node
			min_distance = distances[node]
	return min_node
