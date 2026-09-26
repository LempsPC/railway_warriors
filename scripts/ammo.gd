class_name Ammo
extends Node

## Rounds a unit carries. A sibling of Health on the unit itself, not a property
## of the gun: a unit's magazine is part of the unit, and a resupply source
## (ammo wagon, repair depot) tops up units without knowing what they mount.

signal ammo_changed(current: int, maximum: int)
signal depleted
## Emitted when a resupply actually lands whole rounds, not on partial progress.
signal resupplied(rounds: int)

@export var max_ammo: int = 12

var current: int = 0

# Resupply arrives as a slow fractional rate but ammo is whole rounds, so the
# leftover lives here. Keeping it on the receiving unit rather than the supplier
# means partial progress survives driving out of range and back.
var _partial: float = 0.0

func _ready() -> void:
	current = max_ammo

func is_empty() -> bool:
	return current <= 0

func is_full() -> bool:
	return current >= max_ammo

func fraction() -> float:
	return clamp(float(current) / float(max_ammo), 0.0, 1.0) if max_ammo > 0 else 0.0

## Spend rounds. Returns false and spends nothing if there are not enough.
func consume(rounds: int = 1) -> bool:
	if rounds <= 0 or current < rounds:
		return false
	current -= rounds
	ammo_changed.emit(current, max_ammo)
	if current == 0:
		depleted.emit()
	return true

## Add whole rounds. Returns how many actually fit.
func add(rounds: int) -> int:
	if rounds <= 0 or is_full():
		return 0
	var before := current
	current = min(current + rounds, max_ammo)
	var gained := current - before
	if gained > 0:
		ammo_changed.emit(current, max_ammo)
		resupplied.emit(gained)
	return gained

## Trickle resupply: accepts a fractional amount and banks it until it makes up
## whole rounds. Returns the rounds added this call (usually zero).
func supply(rounds: float) -> int:
	if rounds <= 0.0:
		return 0
	if is_full():
		_partial = 0.0
		return 0
	_partial += rounds
	var whole := int(floor(_partial))
	if whole <= 0:
		return 0
	_partial -= float(whole)
	return add(whole)

func refill() -> void:
	_partial = 0.0
	if current < max_ammo:
		current = max_ammo
		ammo_changed.emit(current, max_ammo)

static func find_in(node: Node) -> Ammo:
	if node == null:
		return null
	for child in node.get_children():
		if child is Ammo:
			return child
	return null
