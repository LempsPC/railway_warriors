class_name Health
extends Node

## Hit points for one unit. It hangs as a child node off whatever it protects
## (a wagon, an enemy), so damage sources never need to know the unit's type:
## they call Health.find_in(body) and talk to this instead.

enum Faction { PLAYER, ENEMY }

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died

@export var max_hp: float = 100.0
@export var faction: Faction = Faction.PLAYER
## Free the node this component hangs off when hp reaches zero. Turn it off for
## units something else keeps references to (a wagon a Train has in its list).
@export var free_unit_on_death: bool = true

var current_hp: float = 0.0

var _dead := false

func _ready() -> void:
	current_hp = max_hp

## The node this component protects.
func unit() -> Node3D:
	return get_parent() as Node3D

func is_alive() -> bool:
	return not _dead and current_hp > 0.0

func fraction() -> float:
	return clamp(current_hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0

func take_damage(amount: float, source: Node = null) -> void:
	if amount <= 0.0 or not is_alive():
		return
	current_hp = max(current_hp - amount, 0.0)
	damaged.emit(amount, source)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		_die()

func heal(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	current_hp = min(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)

func _die() -> void:
	_dead = true
	died.emit()
	var owner_unit := unit()
	if free_unit_on_death and owner_unit != null:
		owner_unit.queue_free()

## Damage sources and detectors use this to ask "does this body have hit points?"
static func find_in(node: Node) -> Health:
	if node == null:
		return null
	for child in node.get_children():
		if child is Health:
			return child
	return null
