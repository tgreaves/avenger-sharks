extends Node

@export var enemy_scene: PackedScene
@export var fish_scene: PackedScene;
@export var dinosaur_scene: PackedScene;
@export var game_status = INTRO_SCREEN;
var score = 0;
var wave_number = 1;
var high_score = 0;
var enemies_left_this_wave = 0;

enum {
    INTRO_SCREEN,
    WAVE_START,
    WAVE_END,
    GAME_RUNNING,
    GAME_PAUSED,
    GAME_OVER
}

var ITEMS = {
    "health": Vector2i(9,8),
    "big_spray": Vector2i(7,9),
    "dinosaur": Vector2i(99,99)
};

# Called when the node enters the scene tree for the first time.
func _ready():
    game_status = INTRO_SCREEN;
    score=0;
    wave_number=1;
    
    if $AudioStreamPlayerMusic.playing == false:
        $AudioStreamPlayerMusic.play();
        
    $HUD.get_node("CanvasLayer/Energy").visible = true;
    $HUD.get_node("CanvasLayer/Score").visible = true;
    $HUD.get_node("CanvasLayer/Label").visible = true;
    $HUD.get_node("CanvasLayer/Label").text = "AVENGER SHARKS!";
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = false;
    
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
    
    for enemy_trap in get_tree().get_nodes_in_group('enemyTrap'):
        enemy_trap.queue_free()
    
    for fish in get_tree().get_nodes_in_group('fishGroup'):
        fish.queue_free()
        
    for dinosaur in get_tree().get_nodes_in_group('dinosaurGroup'):
        dinosaur.queue_free()	
        
    wave_number=wave_number+1;
    wave_start();

func start_game():
    game_status = GAME_RUNNING;
    var i = 0;
    $HUD.get_node("CanvasLayer/Energy").visible = true;
    $HUD.get_node("CanvasLayer/Score").visible = true;
    $HUD.get_node("CanvasLayer/Label").visible = false;
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = true;
    $Player.set_process(true);
    $Player.set_physics_process(true);
    $Player.get_node("AnimatedSprite2D").animation = 'default';
    $Player.visible = true;
    
    $ItemSpawnTimer.start(randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS,constants.ITEM_SPAWN_MAXIMUM_SECONDS));
    $EnemySpawnTimer.start(randf_range(constants.ENEMY_SPAWN_MINIMUM_SECONDS,
                                                constants.ENEMY_SPAWN_MAXIMUM_SECONDS));
    
    _on_player_update_energy();
    _on_enemy_update_score_display();
    
    while (i < wave_number * constants.ENEMY_MULTIPLIER_AT_WAVE_START):
        spawn_enemy();
        i=i+1;
        
    enemies_left_this_wave = (wave_number * constants.ENEMY_MULTIPLIER_AT_WAVE_START) + (wave_number * constants.ENEMY_MULTIPLIER_DURING_WAVE);
    update_enemies_left_display();

    i=0;

    while (i < constants.FISH_TO_SPAWN):
        spawn_fish();
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
    
    for enemy_trap in get_tree().get_nodes_in_group('enemyTrap'):
        enemy_trap.queue_free()
        
    for fish in get_tree().get_nodes_in_group('fishGroup'):
        fish.queue_free()
        
    for dinosaur in get_tree().get_nodes_in_group('dinosaurGroup'):
        dinosaur.queue_free()
    
    _ready();
    
func spawn_item():	
    var spawned_item = ITEMS[ ITEMS.keys()[ randi() % ITEMS.size() ] ];

    if spawned_item == Vector2i(99,99):
        var dinosaur = dinosaur_scene.instantiate();
        dinosaur.get_node('.').set_position (Vector2(randf_range(120,2500),randf_range(300,1250)));
        dinosaur.add_to_group('dinosaurGroup');
        add_child(dinosaur)
    else:
        $Arena.set_cell(1, Vector2i(randi_range(3,20),randi_range(3,20)),0,spawned_item);
    
    $ItemSpawnTimer.start(randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS,constants.ITEM_SPAWN_MAXIMUM_SECONDS));

func spawn_enemy():
    var mob = enemy_scene.instantiate();
    mob.get_node('.').set_position (Vector2(randf_range(120,2500),randf_range(300,1250)));
    mob.add_to_group('enemyGroup');	
    add_child(mob);
    
func spawn_fish():
    var mob = fish_scene.instantiate();
    mob.get_node('.').set_position (Vector2(randf_range(120,2500),randf_range(300,1250)));
    mob.add_to_group('fishGroup');	
    add_child(mob);

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if game_status == WAVE_START:
        if $WaveIntroTimer.time_left == 0:
            start_game();
            
    if game_status == GAME_RUNNING:
        if enemies_left_this_wave == 0:
            wave_end();
            
        if $ItemSpawnTimer.time_left == 0:
            spawn_item();
            
        if $EnemySpawnTimer.time_left == 0:
            if enemies_left_this_wave > get_tree().get_nodes_in_group("enemyGroup").size():
                
                var enemies_to_spawn = randi_range(1, constants.ENEMY_SPAWN_MAX_BATCH_SIZE);
                if enemies_to_spawn > enemies_left_this_wave - get_tree().get_nodes_in_group("enemyGroup").size():
                    enemies_to_spawn = enemies_left_this_wave - get_tree().get_nodes_in_group("enemyGroup").size()
                
                print ("Enemies left this wave: " + str(enemies_left_this_wave))	
                print ("Enemies on screen: " + str(get_tree().get_nodes_in_group("enemyGroup").size()))
                print ("Enemies to spawn: " + str(enemies_to_spawn))
                    
                var i = 0;
                
                while i < enemies_to_spawn:
                    spawn_enemy()
                    i=i+1
                
                $EnemySpawnTimer.start(randf_range(constants.ENEMY_SPAWN_MINIMUM_SECONDS,
                                                constants.ENEMY_SPAWN_MAXIMUM_SECONDS));
            
    if game_status == GAME_OVER:
        if $GameOverTimer.time_left == 0:
            return_to_main_screen();
        
func _input(_ev):
    # Game start.
    if  Input.is_action_just_pressed('shark_fire') or Input.is_action_just_pressed('start'):	
        if game_status == INTRO_SCREEN:
            wave_start();
            
    # Insta-quit.		
    if Input.is_action_just_pressed("quit"):
            get_tree().quit();
                    
    if Input.is_action_just_pressed('start'):
        match game_status:
            GAME_RUNNING:
                print ("PAUSING")
                game_status = GAME_PAUSED;
                $Pause.show();
                get_tree().paused = true;
            GAME_PAUSED:
                print ("UNPAUSING")
                game_status = GAME_RUNNING;
                $Pause.hide();
                get_tree().paused = false;
        

func _on_player_update_energy():
    $HUD.get_node('CanvasLayer').get_node('Energy').text = "ENERGY\n" + str($Player.player_energy);
    
func _on_enemy_update_score(score_to_add):
    enemies_left_this_wave = enemies_left_this_wave - 1;
    score = score + score_to_add;
    if score > high_score:
        high_score = score;
    _on_enemy_update_score_display();
    update_enemies_left_display();

func _on_enemy_update_score_display():
    $HUD.get_node('CanvasLayer').get_node('Score').text = "SCORE\n" + str(score);
    $HUD.get_node('CanvasLayer').get_node('HighScore').text = "HIGH SCORE\n" + str(high_score);

func update_enemies_left_display():
    $HUD.get_node('CanvasLayer').get_node('EnemiesLeft').text = "ENEMIES\n" + str(enemies_left_this_wave);
    

func _on_player_player_died():
    game_over();

func _on_player_player_got_fish():
    score = score + constants.GET_FISH_SCORE;
    if score > high_score:
        high_score = score;
    _on_enemy_update_score_display();
