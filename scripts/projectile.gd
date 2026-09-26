class_name Projectile
extends Area3D

## A lobbed shell. The parabola is the one piece worth keeping from the
## ballistics spike (bullet.gd): interpolate flat from muzzle to target and add
## a parabolic bulge to y, sized so longer shots hang higher and longer.
##
## Differences from the spike: it damages a Health component instead of calling
## clear() on whatever it touched, and it interpolates to the aim point rather
## than integrating a velocity, so a shot that was fired cannot drift past.

@export var speed: float = 16.0
@export var arc_scale: float = 2.0
## Shells ignore collisions for this long so they cannot hit their own wagon.
@export var arm_time: float = 0.05
@export var max_lifetime: float = 8.0

var damage: float = 0.0
var faction: Health.Faction = Health.Faction.PLAYER

var _target: Node3D = null
var _shooter: Node = null
var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _flight_time: float = 0.5
var _arc_height: float = 1.0
var _elapsed: float = 0.0
var _spent := false

func _ready() -> void:
	# See TargetDetector._ready: layer 0 keeps the track graph clean.
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	monitoring = true
	body_entered.connect(_on_body_entered)

func launch(from: Vector3, target: Node3D, shot_damage: float,
		shooter_faction: Health.Faction, shooter: Node = null) -> void:
	_target = target
	_shooter = shooter
	damage = shot_damage
	faction = shooter_faction
	_start = from
	_end = target.global_position if target != null else from
	global_position = _start
	_flight_time = max(_start.distance_to(_end) / (speed + 4.0), 0.1)
	_arc_height = _flight_time * arc_scale

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > max_lifetime:
		queue_free()
		return

	# The shell follows its target while in flight. Properly leading a moving
	# unit needs to know its velocity, which belongs with enemy AI (roadmap
	# step 9); until then a guided shell keeps this slice provable.
	var health := _target_health()
	if health != null:
		_end = _target.global_position
	else:
		_target = null  # died mid-flight: still land where it was last aimed

	var t: float = clamp(_elapsed / _flight_time, 0.0, 1.0)
	var pos := _start.lerp(_end, t)
	pos.y += _arc_height * (1.0 - pow(t * 2.0 - 1.0, 2.0))
	global_position = pos

	if t >= 1.0:
		_impact(health)

func _target_health() -> Health:
	if _target == null or not is_instance_valid(_target):
		return null
	var health := Health.find_in(_target)
	if health == null or not health.is_alive():
		return null
	return health

func _on_body_entered(body: Node3D) -> void:
	if _spent or _elapsed < arm_time:
		return
	var health := Health.find_in(body)
	if health == null:
		return  # terrain and scenery: keep flying towards the aim point
	if health.faction == faction:
		return  # no friendly fire, and never the wagon that fired it
	_impact(health)

func _impact(health: Health) -> void:
	if _spent:
		return
	_spent = true
	if health != null and health.is_alive():
		health.take_damage(damage, _shooter)
	queue_free()
