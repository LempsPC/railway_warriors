class_name UnitStatusBars
extends Node3D

## Floating bars over a unit: a health bar on every rail unit, plus an ammo bar
## on the ones that can shoot. Built at runtime from a tiny generated image — no
## assets and no UI layer, per the budget constraint in the roadmap.
##
## Why one Sprite3D with a redrawn texture rather than two quads, a background
## and a fill: billboarding replaces the node basis with the camera's and keeps
## the node's *world* translation, so a child offset for "the left end of the
## bar" would rotate with the wagon instead of facing the camera. Encoding the
## fill in the image sidesteps that entirely. Redraws only happen when a value
## actually changes, which for ammo means per whole round.

const BAR_WIDTH := 64
const BAR_HEIGHT := 7
const BAR_GAP := 2

const COLOR_BORDER := Color(0.05, 0.05, 0.07, 0.95)
const COLOR_EMPTY := Color(0.12, 0.12, 0.15, 0.8)
const COLOR_HEALTH_FULL := Color(0.35, 0.9, 0.4)
const COLOR_HEALTH_LOW := Color(0.95, 0.25, 0.25)
const COLOR_AMMO := Color(0.98, 0.76, 0.25)
const COLOR_AMMO_EMPTY := Color(0.45, 0.35, 0.18)

@export var height: float = 1.5
@export var pixel_size: float = 0.005
@export var flash_time: float = 0.12
@export var flash_color: Color = Color(1.0, 0.35, 0.2)

var _health: Health
var _ammo: Ammo
var _shows_ammo := false

var _sprite: Sprite3D
var _image: Image
var _texture: ImageTexture

var _mesh: MeshInstance3D
var _flash_material: StandardMaterial3D
var _saved_override: Material = null
var _flash_left: float = 0.0

func _ready() -> void:
	var unit := get_parent()
	_health = Health.find_in(unit)
	_ammo = Ammo.find_in(unit)
	# The ammo bar is shown for units that can actually shoot. Every unit
	# carries ammo, but a bar on a wagon with no gun would be noise.
	_shows_ammo = _ammo != null and _find_weapon(unit) != null
	_mesh = unit.get_node_or_null("MeshInstance3D") as MeshInstance3D

	if _health == null:
		push_warning("UnitStatusBars: no Health component on %s" % unit)
		set_process(false)
		return

	_flash_material = StandardMaterial3D.new()
	_flash_material.albedo_color = flash_color
	_flash_material.emission_enabled = true
	_flash_material.emission = flash_color

	_build_sprite()

	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	if _shows_ammo:
		_ammo.ammo_changed.connect(_on_ammo_changed)
	# Deferred so it does not matter whether Health._ready ran before ours.
	_redraw.call_deferred()

func _build_sprite() -> void:
	var rows := BAR_HEIGHT * 2 + BAR_GAP if _shows_ammo else BAR_HEIGHT
	_image = Image.create_empty(BAR_WIDTH, rows, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)

	_sprite = Sprite3D.new()
	_sprite.texture = _texture
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = true
	_sprite.fixed_size = true
	_sprite.shaded = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.pixel_size = pixel_size
	_sprite.position = Vector3.UP * height
	add_child(_sprite)

func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left > 0.0 or not is_instance_valid(_mesh):
		return
	# Only undo our own flash: Train's selection tint writes the same property,
	# and if it changed during the flash its value is the one that should stand.
	if _mesh.material_override == _flash_material:
		_mesh.material_override = _saved_override

func _redraw() -> void:
	if _health == null or _image == null:
		return
	var hp := _health.fraction()
	_draw_bar(0, hp, COLOR_HEALTH_LOW.lerp(COLOR_HEALTH_FULL, hp))
	if _shows_ammo:
		var rounds := _ammo.fraction()
		_draw_bar(BAR_HEIGHT + BAR_GAP, rounds, COLOR_AMMO if rounds > 0.0 else COLOR_AMMO_EMPTY)
	_texture.update(_image)

func _draw_bar(y0: int, fraction: float, fill: Color) -> void:
	var inner := BAR_WIDTH - 2
	var filled := int(round(clamp(fraction, 0.0, 1.0) * inner))
	for y in range(y0, y0 + BAR_HEIGHT):
		var edge_row := y == y0 or y == y0 + BAR_HEIGHT - 1
		for x in range(BAR_WIDTH):
			var color: Color
			if edge_row or x == 0 or x == BAR_WIDTH - 1:
				color = COLOR_BORDER
			elif x - 1 < filled:
				color = fill
			else:
				color = COLOR_EMPTY
			_image.set_pixel(x, y, color)

func _on_health_changed(_current: float, _maximum: float) -> void:
	_redraw()

func _on_ammo_changed(_current: int, _maximum: int) -> void:
	_redraw()

func _on_damaged(_amount: float, _source: Node) -> void:
	if _mesh == null:
		return
	if _flash_left <= 0.0:
		_saved_override = _mesh.material_override
	_flash_left = flash_time
	_mesh.material_override = _flash_material

func _on_died() -> void:
	if _sprite != null:
		_sprite.visible = false

func _find_weapon(unit: Node) -> Weapon:
	for child in unit.get_children():
		if child is Weapon:
			return child
	return null
