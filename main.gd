extends Node

@export var enemy_scene: PackedScene
@export var game_status = INTRO_SCREEN;
var score = 0;
var wave_number = 1;
var high_score = 0;

enum {
	INTRO_SCREEN,
	WAVE_START,
	WAVE_END,
	GAME_RUNNING,
	GAME_OVER
}

# Called when the node enters the scene tree for the first time.
func _ready():
	game_status = INTRO_SCREEN;
	score=0;
	wave_number=1;
	
	$HUD.get_node("CanvasLayer/Energy").visible = true;
	$HUD.get_node("CanvasLayer/Score").visible = true;
	$HUD.get_node("CanvasLayer/Label").visible = true;
	$HUD.get_node("CanvasLayer/Label").text = "AVENGER SHARKS!";
	
	$Player.set_process(false);
	$Player.set_physics_process(false);
	$Player.visible = false;
	$Player.get_node("CollisionShape2D").disabled = false;
	$Player._ready();
	
	$Player.player_energy = constants.PLAYER_START_GAME_ENERGY;
	
	_on_player_update_energy();
	_on_enemy_update_score_display();

func wave_start():
	game_status = WAVE_START;
	$HUD.get_node("CanvasLayer/Label").text = "WAVE " + str(wave_number);
	$HUD.get_node("CanvasLayer/Label").visible = true;
	$WaveIntroTimer.start();

func wave_end():
	game_status = WAVE_END;
	# Stub for congratulations message, jingle etc.
	wave_number=wave_number+1;
	wave_start();

func start_game():
	game_status = GAME_RUNNING;
	var i = 0;
	$HUD.get_node("CanvasLayer/Energy").visible = true;
	$HUD.get_node("CanvasLayer/Score").visible = true;
	$HUD.get_node("CanvasLayer/Label").visible = false;
	$Player.set_process(true);
	$Player.set_physics_process(true);
	$Player.get_node("AnimatedSprite2D").animation = 'default';
	$Player.visible = true;
	
	$ItemSpawnTimer.start(randf_range(1,2));
	
	_on_player_update_energy();
	_on_enemy_update_score_display();
	
	while (i < wave_number * 5):
		var mob = enemy_scene.instantiate();
		mob.get_node('.').set_position (Vector2(randf_range(200,2000),randf_range(300,1000)));
		mob.add_to_group('enemyGroup');
				
		add_child(mob);
		i=i+1;

func game_over():
	game_status = GAME_OVER;
	$HUD.get_node("CanvasLayer/Label").visible = true;
	$HUD.get_node("CanvasLayer/Label").text = "GAME OVER";
	$GameOverTimer.start();

func return_to_main_screen():
	# TODO: Remove any Enemies, projectiles on screen.
	for enemy in get_tree().get_nodes_in_group("enemyGroup"):
		enemy.queue_free()
		
	for enemy_attack in get_tree().get_nodes_in_group('enemyAttack'):
		enemy_attack.queue_free()
	
	_ready();
	
func spawn_item():
	print("SPAWNING ITEM!");
	
	$Arena.set_cell(1, Vector2i(randi_range(3,20),randi_range(3,20)),0,Vector2i(9,8));
	$ItemSpawnTimer.start(randf_range(10,20));
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if game_status == WAVE_START:
		if $WaveIntroTimer.time_left == 0:
			start_game();
			
	if game_status == GAME_RUNNING:
		if get_tree().get_nodes_in_group("enemyGroup").size() == 0:
			wave_end();
			
		if $ItemSpawnTimer.time_left == 0:
			spawn_item();
			
	if game_status == GAME_OVER:
		if $GameOverTimer.time_left == 0:
			return_to_main_screen();
		
func _input(ev):
	if Input.is_action_just_pressed('shark_fire'):
		if game_status == INTRO_SCREEN:
			wave_start();
		
func _on_player_update_energy():
	$HUD.get_node('CanvasLayer').get_node('Energy').text = "ENERGY\n" + str($Player.player_energy);
	
func _on_enemy_update_score():
	score = score + constants.KILL_ENEMY_SCORE;
	if score > high_score:
		high_score = score;
	_on_enemy_update_score_display();

func _on_enemy_update_score_display():
	$HUD.get_node('CanvasLayer').get_node('Score').text = "SCORE\n" + str(score);
	$HUD.get_node('CanvasLayer').get_node('HighScore').text = "HIGH SCORE\n" + str(high_score);

func _on_player_player_died():
	game_over();

