class_name TargetDetector
extends Area3D

## Watches a sphere of ground for hostile units and nominates the nearest one.
##
## The ballistics spike fired at whatever tripped its Area3D. This only *picks*
## a target — deciding whether to shoot it is the weapon's job, which is what
## lets ammo, cooldown and range live in one place.

signal target_acquired(target: Node3D)
signal target_lost()

@export var detection_radius: float = 14.0:
	set(value):
		detection_radius = value
		_apply_radius()
## Units of this faction are ignored; anything else carrying Health is a target.
@export var faction: Health.Faction = Health.Faction.PLAYER

var _sphere: SphereShape3D
var _candidates: Array[Node3D] = []
var _target: Node3D = null

func _ready() -> void:
	# collision_layer = 0 is load-bearing, not tidiness: connections.gd adds
	# *any* overlapping Area3D to the track graph, so a detectable area riding
	# on a wagon would quietly inject junk nodes into pathfinding.
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	monitoring = true

	_sphere = SphereShape3D.new()
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Range"
	shape_node.shape = _sphere
	add_child(shape_node)
	_apply_radius()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Bodies already inside the radius at spawn never fire body_entered.
	await get_tree().physics_frame
	if is_inside_tree():
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _apply_radius() -> void:
	if _sphere != null:
		_sphere.radius = detection_radius

func get_target() -> Node3D:
	return _target

func _on_body_entered(body: Node3D) -> void:
	if body in _candidates or not _is_hostile(body):
		return
	_candidates.append(body)

func _on_body_exited(body: Node3D) -> void:
	_candidates.erase(body)

func _is_hostile(body: Node3D) -> bool:
	var health := Health.find_in(body)
	return health != null and health.faction != faction

# Re-picked every physics frame rather than only on enter/exit: a target can
# also stop being a target by dying, and the nearest one changes as we move.
func _physics_process(_delta: float) -> void:
	var best: Node3D = null
	var best_dist := INF

	var i := _candidates.size() - 1
	while i >= 0:
		var body := _candidates[i]
		var health: Health = null
		if is_instance_valid(body):
			health = Health.find_in(body)
		if health == null or not health.is_alive():
			_candidates.remove_at(i)
		else:
			var d := global_position.distance_squared_to(body.global_position)
			if d < best_dist:
				best_dist = d
				best = body
		i -= 1

	if best == _target:
		return
	_target = best
	if _target == null:
		target_lost.emit()
	else:
		target_acquired.emit(_target)
