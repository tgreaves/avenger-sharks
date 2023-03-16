extends Node

@export var enemy_scene: PackedScene
var score = 0;

# Called when the node enters the scene tree for the first time.
func _ready():
	
	var i = 0;
	
	while (i < 50):
		var mob = enemy_scene.instantiate();
		#mob.get_node('.').set_position (Vector2(150*i,50*i));
		mob.get_node('.').set_position (Vector2(randf_range(0,2000),randf_range(0,1000)));
		
		#print(test);
				
		add_child(mob);
		i=i+1;
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_player_enemy_eaten():
	score = score + 1;
	print("CHOMP! " + str(score))
