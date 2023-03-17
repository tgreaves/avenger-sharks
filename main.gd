extends Node

@export var enemy_scene: PackedScene
var score = 0;

# Called when the node enters the scene tree for the first time.
func _ready():
	
	var i = 0;
	_on_player_update_energy();
	_on_enemy_update_score_display();
	
	while (i < 30):
		var mob = enemy_scene.instantiate();
		#mob.get_node('.').set_position (Vector2(150*i,50*i));
		mob.get_node('.').set_position (Vector2(randf_range(0,2000),randf_range(0,1000)));
		
		#print(test);
				
		add_child(mob);
		i=i+1;
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_player_update_energy():
	print("Update energy called.");
	$HUD.get_node('CanvasLayer').get_node('Energy').text = "ENERGY:\n" + str($Player.player_energy);

func _on_enemy_update_score():
	score = score + 1;
	_on_enemy_update_score_display();

func _on_enemy_update_score_display():
	$HUD.get_node('CanvasLayer').get_node('Score').text = "SCORE:\n" + str(score);
