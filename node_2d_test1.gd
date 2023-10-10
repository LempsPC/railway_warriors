extends Node2D

var TRAIN_LOCOMOTIVE = load("train_engine.tscn")
var TRAIN_WAGON = load("train_wagon.tscn")

var train_class = load("res://Train.gd")
var train1 = train_class.new([TRAIN_LOCOMOTIVE.instantiate(), TRAIN_WAGON.instantiate(), TRAIN_WAGON.instantiate()])

# Called when the node enters the scene tree for the first time.
func _ready():
	train1.deploy(get_tree())
	print(get_tree())
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	train1._process(delta)
	pass

