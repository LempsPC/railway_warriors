class_name AmmoSupply
extends Area3D

## An infinite, slow resupply source. Mounted on the ammo wagon today; it is a
## plain component, so the repair depot can mount the same node when it exists.
##
## It tops up every friendly unit carrying an Ammo component inside its radius,
## which covers both readings of "refills all ammo": wagons coupled into the
## same train, and friendly units merely parked nearby.

signal supplied(unit: Node3D, rounds: int)

@export var supply_range: float = 12.0:
	set(value):
		supply_range = value
		_apply_radius()
## Rounds per second delivered to each unit in range. Deliberately slower than
## a weapon's fire rate, so a gun that is shooting still drains its magazine.
@export var rounds_per_second: float = 0.5
@export var inherit_faction_from_unit: bool = true
@export var faction: Health.Faction = Health.Faction.PLAYER

var _sphere: SphereShape3D
var _clients: Array[Node3D] = []

func _ready() -> void:
	# See TargetDetector._ready: connections.gd would otherwise swallow this
	# area into the track navigation graph.
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	monitoring = true

	if inherit_faction_from_unit:
		var host_health := _find_host_health()
		if host_health != null:
			faction = host_health.faction

	_sphere = SphereShape3D.new()
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Range"
	shape_node.shape = _sphere
	add_child(shape_node)
	_apply_radius()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Units already inside the radius at spawn never fire body_entered — which
	# is the normal case here, since the wagons start coupled.
	await get_tree().physics_frame
	if is_inside_tree():
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _apply_radius() -> void:
	if _sphere != null:
		_sphere.radius = supply_range

func _physics_process(delta: float) -> void:
	var rounds := rounds_per_second * delta
	var i := _clients.size() - 1
	while i >= 0:
		var unit := _clients[i]
		if not is_instance_valid(unit):
			_clients.remove_at(i)
		else:
			var ammo := Ammo.find_in(unit)
			if ammo == null:
				_clients.remove_at(i)
			elif not ammo.is_full():
				var gained := ammo.supply(rounds)
				if gained > 0:
					supplied.emit(unit, gained)
		i -= 1

func _on_body_entered(body: Node3D) -> void:
	if body in _clients or not _is_client(body):
		return
	_clients.append(body)

func _on_body_exited(body: Node3D) -> void:
	_clients.erase(body)

func _is_client(body: Node3D) -> bool:
	if Ammo.find_in(body) == null:
		return false
	var health := Health.find_in(body)
	return health != null and health.faction == faction

func _find_host_health() -> Health:
	var node := get_parent()
	while node != null:
		var health := Health.find_in(node)
		if health != null:
			return health
		node = node.get_parent()
	return null
