extends Node2D

var train = null
var selected = false;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func setSelected(selected):
	self.selected = selected

func setTrain(train):
	self.train = train
