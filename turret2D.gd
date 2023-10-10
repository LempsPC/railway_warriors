extends Node2D

var detection_range = 300;
var shooting_range = 250;

var enemy = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	detectEnemy()


func aim():
	print("Aiming")
	
func shoot():
	print("Pew")
	
func return_to_default():
	print("rotating turret to default position")
	
	
func detectEnemy():
	#distance function
	#var enemy = self.get_parent().train.getTree().current_scene.find_child("enemies", true, false)
	#print(enemy)
	#print("My location:")
	#print(self.global_transform.get_origin())
	var min_distance = 99999999999999
	var min_enemy = null
	for enemy in self.get_parent().train.getTree().current_scene.find_child("enemies", true, false).get_children():
		#print(enemy)
		#print(self.global_transform.get_origin())

		if self.global_position.distance_to(enemy.global_position) < min_distance:
			min_distance = self.global_position.distance_to(enemy.global_position)
			min_enemy = enemy
			
		
	
	#print("Closest is ", min_enemy)
	#print(min_distance)
	var angle = self.get_angle_to(min_enemy.global_position)
	var train_rotation = self.get_parent().get_parent().rotation
	print(train_rotation)
	var add90 = deg_to_rad(90)
	
	self.rotate(angle-train_rotation+add90)
