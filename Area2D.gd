extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _input_event(viewport, event, shape_idx):
	#print(event)
	if event.is_pressed():
		#self.get_parent().setSelected(true)
		self.get_parent().find_child("SpriteHighlighted", true, false).visible = true
		print("selected")

func _unhandled_input(event):
	if event.is_pressed():
		#self.get_parent().setSelected(false)
		self.get_parent().find_child("SpriteHighlighted", true, false).visible = false
		print("Deselected")
