extends Node2D

var train = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var PathFollow = get_tree().root.find_child("WagonFollow2D", true, false)
	#PathFollow.progress+= 2
	pass

func setTrain(train):
	self.train = train
