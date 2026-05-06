@tool
class_name TrackSpline
extends Path3D

const SPHERE_SCENE = preload("res://scenes/sphere.tscn")

@export_tool_button("Rebuild Track") var rebuild_btn = rebuild_track

@export_group("Mesh")
@export_range(0.1, 5.0, 0.05) var sample_step: float = 0.5
@export_range(0.5, 5.0, 0.05) var ballast_width: float = 2.0
@export_range(0.05, 0.5, 0.01) var ballast_height: float = 0.1
@export_range(0.5, 2.0, 0.05) var rail_offset: float = 0.7
@export_range(0.05, 0.5, 0.01) var rail_width: float = 0.1
@export_range(0.05, 0.5, 0.01) var rail_height: float = 0.1

@export_group("Navigation")
@export_range(0.5, 10.0, 0.1) var nav_spacing: float = 2.5
@export_range(0.05, 1.0, 0.01) var nav_sphere_scale: float = 0.2

@export_group("Materials")
@export var ballast_material: Material
@export var rail_material: Material


func _ready() -> void:
	if not Engine.is_editor_hint():
		rebuild_track()


func rebuild_track() -> void:
	if curve == null or curve.point_count < 2:
		push_warning("TrackSpline: needs a Curve3D with at least 2 points")
		return
	_build_mesh()
	_build_navigation()


func _build_mesh() -> void:
	var mesh_node: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		mesh_node = MeshInstance3D.new()
		mesh_node.name = "Mesh"
		add_child(mesh_node)
		_set_owner_for_editor(mesh_node)

	var baked_len = curve.get_baked_length()
	if baked_len < 0.01:
		mesh_node.mesh = null
		return

	var sample_count = max(2, int(baked_len / sample_step) + 1)
	var samples: Array = []
	for i in range(sample_count):
		var t = float(i) / float(sample_count - 1) * baked_len
		var pos = curve.sample_baked(t)
		var t_ahead = min(t + 0.05, baked_len)
		var t_behind = max(t - 0.05, 0.0)
		var ahead = curve.sample_baked(t_ahead)
		var behind = curve.sample_baked(t_behind)
		var tangent = ahead - behind
		if tangent.length() < 0.0001:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()
		var right = tangent.cross(Vector3.UP)
		if right.length() < 0.0001:
			right = Vector3.RIGHT
		else:
			right = right.normalized()
		samples.append({"pos": pos, "right": right})

	var arr_mesh = ArrayMesh.new()

	# Surface 0: ballast
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_extrude_box(st, samples, ballast_width, ballast_height, 0.0, 0.0)
	st.generate_normals()
	st.commit(arr_mesh)
	arr_mesh.surface_set_material(0, ballast_material if ballast_material else _default_ballast_material())

	# Surface 1: left rail
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_extrude_box(st, samples, rail_width, rail_height, ballast_height, -rail_offset)
	st.generate_normals()
	st.commit(arr_mesh)
	arr_mesh.surface_set_material(1, rail_material if rail_material else _default_rail_material())

	# Surface 2: right rail
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_extrude_box(st, samples, rail_width, rail_height, ballast_height, rail_offset)
	st.generate_normals()
	st.commit(arr_mesh)
	arr_mesh.surface_set_material(2, rail_material if rail_material else _default_rail_material())

	mesh_node.mesh = arr_mesh


func _extrude_box(st: SurfaceTool, samples: Array, w: float, h: float, y_off: float, x_off: float) -> void:
	var hw = w * 0.5
	var sections: Array = []
	for s in samples:
		var center = s.pos + Vector3.UP * y_off + s.right * x_off
		var bl = center - s.right * hw
		var br = center + s.right * hw
		var tl = bl + Vector3.UP * h
		var tr = br + Vector3.UP * h
		sections.append({"bl": bl, "br": br, "tl": tl, "tr": tr})

	for i in range(sections.size() - 1):
		var s0 = sections[i]
		var s1 = sections[i + 1]
		_quad(st, s0.tl, s0.tr, s1.tr, s1.tl)
		_quad(st, s0.br, s0.bl, s1.bl, s1.br)
		_quad(st, s0.bl, s0.tl, s1.tl, s1.bl)
		_quad(st, s0.tr, s0.br, s1.br, s1.tr)

	# End caps
	var first = sections[0]
	var last = sections[-1]
	_quad(st, first.tr, first.tl, first.bl, first.br)
	_quad(st, last.bl, last.tl, last.tr, last.br)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _default_ballast_material() -> Material:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.55, 0.55)
	return m


func _default_rail_material() -> Material:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.34, 0.34, 0.34)
	m.metallic = 0.7
	m.roughness = 0.3
	return m


func _build_navigation() -> void:
	var points_node: Node3D = get_node_or_null("Points") as Node3D
	if points_node == null:
		points_node = Node3D.new()
		points_node.name = "Points"
		add_child(points_node)
		_set_owner_for_editor(points_node)

	# track_pathfinding.gd reads child(0) as the points container
	move_child(points_node, 0)

	for child in points_node.get_children():
		points_node.remove_child(child)
		child.free()

	var baked_len = curve.get_baked_length()
	if baked_len < 0.01:
		return

	var count = max(2, int(baked_len / nav_spacing) + 1)
	var spheres: Array[Node3D] = []
	for i in range(count):
		var t = float(i) / float(count - 1) * baked_len
		var pos = curve.sample_baked(t)

		var sphere = SPHERE_SCENE.instantiate()
		sphere.name = "Sphere_%d" % i
		sphere.transform.origin = pos
		sphere.scale = Vector3.ONE * nav_sphere_scale
		points_node.add_child(sphere)
		_set_owner_for_editor(sphere, true)
		spheres.append(sphere)

	# Wire neighbours after all spheres are in the tree (so global_transform is valid).
	# sphere._ready ran during add_child with an empty connections_list, so connections_ids
	# is currently empty — repopulate both here.
	for i in range(spheres.size()):
		var s = spheres[i]
		var conns: Array[Node3D] = []
		if i > 0:
			conns.append(spheres[i - 1])
		if i < spheres.size() - 1:
			conns.append(spheres[i + 1])
		s.connections_list = conns
		s.connections_ids = []
		for other in conns:
			s.connections_ids.append(other.global_transform.origin)


func _set_owner_for_editor(node: Node, recursive: bool = false) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var root = get_tree().edited_scene_root
	if root == null:
		return
	node.owner = root
	if recursive:
		for c in node.get_children():
			_set_owner_for_editor(c, true)
