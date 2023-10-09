class_name Train extends Node2D

const TRAIN_LOCOMOTIVE = preload("res://train_engine.tscn")
const TRAIN_WAGON = preload("res://train_wagon.tscn")

##Prioerties
#linked list of engines
#linked list of wagons which is TrainNode

var items = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	#Update train position
	for item in self.items:
		item.progress+=1
	pass

func scream():
	print("Yeet")

func _init(parts):
	self.items = parts
	
func deploy(tree):
	var path2D = tree.root.find_child("Path2D", true, false)
	
	for i in range(self.items.size()):
		path2D.add_child(self.items[i])
		#self.items[i].find_child("train_node", true, false).train = self
		self.items[i].progress = -i*32
