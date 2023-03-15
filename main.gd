extends Node

@export var enemy_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready():
	var i = 1;
	
	while (i < 6):
		var mob = enemy_scene.instantiate();
		#mob.get_node('Enemy').get_node('AnimatedSprite2D').x += i * 20;
		
		mob.get_node('.').set_position (Vector2(150*i,50*i));
		#print(test);
				
		add_child(mob);
		i=i+1;
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

