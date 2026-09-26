class_name Weapon
extends Node3D

## A mountable gun. Owns range, cooldown and damage, asks its TargetDetector
## what to shoot at, and lobs a Projectile at it.
##
## It does *not* own ammo: rounds belong to the unit carrying the gun (see
## ammo.gd), so a resupply source can top a unit up without knowing what it
## mounts, and a unit that swaps weapons keeps its magazine.
##
## Deliberately a scene mounted on a wagon rather than a method on Train: Train
## already owns movement, coupling and input, and a weapon that is just a child
## node can be dropped on an enemy unit unchanged.

signal fired(target: Node3D)
## The trigger was pulled with an empty magazine. Fires once per dry attempt.
signal dry_fire()

@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
@export var damage: float = 34.0
@export var attack_range: float = 14.0
@export var cooldown: float = 1.2
@export var rounds_per_shot: int = 1
@export var auto_fire: bool = true
@export var turn_speed: float = 6.0
## Read the faction off the Health of the unit this weapon is mounted on, so a
## weapon scene does not have to be re-authored per side.
@export var inherit_faction_from_unit: bool = true
@export var faction: Health.Faction = Health.Faction.PLAYER

var detector: TargetDetector
## The magazine this gun draws from — the host unit's, not its own.
var ammo: Ammo

var _cooldown_left: float = 0.0
var _was_dry := false

func _ready() -> void:
	var host := _find_host_unit()
	if host != null:
		if inherit_faction_from_unit:
			faction = Health.find_in(host).faction
		ammo = Ammo.find_in(host)
	if ammo == null:
		push_warning("Weapon on %s has no Ammo component; firing unlimited" % host)

	# Built in code so attack_range has exactly one source of truth, instead of
	# an exported number that has to be kept in sync with a shape in the scene.
	detector = TargetDetector.new()
	detector.name = "Detector"
	detector.detection_radius = attack_range
	detector.faction = faction
	add_child(detector)

func has_ammo() -> bool:
	return ammo == null or ammo.current >= rounds_per_shot

func _physics_process(delta: float) -> void:
	_cooldown_left = max(_cooldown_left - delta, 0.0)
	if detector == null:
		return
	var target: Node3D = detector.get_target()
	if target == null:
		return

	# Track the target even while reloading or dry, so the barrel reads as aimed.
	_aim_at(target.global_position, delta)

	if not auto_fire or _cooldown_left > 0.0:
		return
	if global_position.distance_to(target.global_position) > attack_range:
		return
	fire_at(target)

func fire_at(target: Node3D) -> bool:
	if target == null or projectile_scene == null:
		return false
	if not has_ammo():
		# One signal per dry spell, not one per frame.
		if not _was_dry:
			_was_dry = true
			dry_fire.emit()
		return false
	_was_dry = false
	if ammo != null:
		ammo.consume(rounds_per_shot)
	_cooldown_left = cooldown

	var projectile: Projectile = projectile_scene.instantiate()
	# Parented to the scene, not to the weapon: a shell must not ride along with
	# the train once it has left the barrel.
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(projectile)
	projectile.launch(_muzzle_position(), target, damage, faction, self)

	fired.emit(target)
	return true

func _aim_at(point: Vector3, delta: float) -> void:
	var dir := point - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	# Node3D forward is -Z, so solve -sin(yaw) = dir.x and -cos(yaw) = dir.z.
	var wanted := atan2(-dir.x, -dir.z)
	global_rotation.y = lerp_angle(global_rotation.y, wanted, min(turn_speed * delta, 1.0))

func _muzzle_position() -> Vector3:
	var muzzle := get_node_or_null("Muzzle") as Node3D
	return muzzle.global_position if muzzle != null else global_position

## The nearest ancestor carrying a Health component — i.e. the unit this gun is
## bolted to. Health and Ammo are both read off that same node.
func _find_host_unit() -> Node:
	var node := get_parent()
	while node != null:
		if Health.find_in(node) != null:
			return node
		node = node.get_parent()
	return null
