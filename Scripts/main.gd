extends Node

@export var enemy_scene: PackedScene
@export var fish_scene: PackedScene;
@export var dinosaur_scene: PackedScene;
@export var credits_scene: PackedScene;
@export var game_status = INTRO_SCREEN;
@export var cheat_mode = 0

var score = 0;
var wave_number = 1;
var high_score = 0;
var enemies_left_this_wave = 0;
var fish_collected = 0;
var spawned_items_this_wave = []

enum {
    INTRO_SCREEN,
    CREDITS,
    WAVE_START,
    GAME_RUNNING,
    GAME_PAUSED,
    GETTING_KEY,
    WAVE_END,
    PREPARE_FOR_NEXT_WAVE,
    GAME_OVER
}

var ITEMS = {
    "health": Vector2i(9,8),
    "big_spray": Vector2i(7,9),
    "dinosaur": Vector2i(99,99)
};

signal player_hunt_key;
signal player_move_to_starting_position;

# Called when the node enters the scene tree for the first time.
func _ready():
    game_status = INTRO_SCREEN;
    score=0;
    fish_collected=0;
    wave_number=0;
    
    if $AudioStreamPlayerMusic.playing == false:
        $AudioStreamPlayerMusic.play();
 
    $ArenaBlank.visible = false;   
    $MainMenu.get_node('CanvasLayer').visible = true;
    $MainMenu.set_process_input(true);
    $MainMenu._ready();
    $PauseMenu.get_node('CanvasLayer').visible = false;
    $PauseMenu.set_process_input(false);
    $HUD.get_node("CanvasLayer/Energy").visible = true;
    $HUD.get_node("CanvasLayer/Score").visible = true;
    $HUD.get_node("CanvasLayer/Label").visible = true;
    $HUD.get_node("CanvasLayer/Label").text = "";
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = false;
    $HUD.get_node("CanvasLayer/Fish").visible = false;
    
    $Player.set_process(false);
    $Player.set_physics_process(false);
    $Player.visible = false;
    $Player.get_node("CollisionShape2D").disabled = false;
    $Player._ready();
    
    $Player.player_energy = constants.PLAYER_START_GAME_ENERGY;
    $HUD.get_node("CanvasLayer/EnergyProgressBar").max_value = constants.PLAYER_START_GAME_ENERGY
    
    _on_player_update_energy();
    _on_enemy_update_score_display();

func wave_start():
    game_status = WAVE_START;
    $HUD.get_node("CanvasLayer/Label").text = "WAVE " + str(wave_number);
    $HUD.get_node("CanvasLayer/Label").visible = true;
    $WaveIntroTimer.start();

func wave_end():
    game_status = GETTING_KEY;
    
    $HUD.get_node("CanvasLayer/Label").text = "WAVE COMPLETE!"
    $HUD.get_node("CanvasLayer/Label").visible = true;
    
    for enemy_trap in get_tree().get_nodes_in_group('enemyTrap'):
        enemy_trap.queue_free()
    
    despawn_all_items()
    
    # Auto send player to get the key.
    emit_signal('player_hunt_key', $Key.global_position);
    
    for fish in get_tree().get_nodes_in_group('fishGroup'):
        fish.queue_free()
    
func wave_end_cleanup():
    for dinosaur in get_tree().get_nodes_in_group('dinosaurGroup'):
        dinosaur.queue_free()	
        
    $ArenaBlank.visible = true;
    $Arena.visible = false;
    $Player.visible = false;
    $Player.set_process(false);
    $Player.set_physics_process(false);
    $Key.visible = false;
    
    for enemy_attack in get_tree().get_nodes_in_group('enemyAttack'):
        enemy_attack.queue_free()
    
    for dinosaur_attack in get_tree().get_nodes_in_group('dinosaurAttack'):
        dinosaur_attack.queue_free()
    
    game_status = PREPARE_FOR_NEXT_WAVE;
    $WaveEndTimer.start();

func wave_end_prepare_for_next_wave():
    wave_number=wave_number+1;
    
    # Close top door.
    $Arena.set_cell(
        1,
        Vector2(31,2),
        0,
        Vector2i(6,6))
    
    $Arena.set_cell(
        1,
        Vector2(32,2),
        0,
        Vector2i(7,6))
        
    # Open bottom door.
    $Arena.set_cell(
        1,
        Vector2(31,33),
        -1,
        Vector2i(6,6))
    
    $Arena.set_cell(
        1,
        Vector2(32,33),
        -1,
        Vector2i(7,6))
    
    print("Trying to hide menu...")
    $MainMenu.get_node('CanvasLayer').visible = false
    $MainMenu.set_process_input(false)
    $Arena.visible = true;
    $ArenaBlank.visible = false;
    $Player._ready();
    $Player.visible = true
    $Player.position = Vector2(2550, 2500);
    $Player.get_node("AnimatedSprite2D").animation = 'default';
    emit_signal("player_move_to_starting_position");

    $Key/CollisionShape2D.disabled = true;
    
    wave_start()

func start_game():
    game_status = GAME_RUNNING;
    var i = 0;
    $HUD.get_node("CanvasLayer/Energy").visible = true;
    $HUD.get_node("CanvasLayer/Score").visible = true;
    $HUD.get_node("CanvasLayer/Label").visible = false;
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = true;
    $HUD.get_node("CanvasLayer/Fish").visible = true;
    $Player.set_process(true);
    $Player.set_physics_process(true);
    
    $Player.visible = true;
    
    $ItemSpawnTimer.start(randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS,constants.ITEM_SPAWN_MAXIMUM_SECONDS));
    $EnemySpawnTimer.start(randf_range(constants.ENEMY_SPAWN_MINIMUM_SECONDS,
                                                constants.ENEMY_SPAWN_MAXIMUM_SECONDS));
    
    _on_player_update_energy();
    _on_enemy_update_score_display();
    update_fish_display();
    
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
        
    despawn_all_items()
    
    _ready();
    
func spawn_item():	
    var spawned_item = ITEMS[ ITEMS.keys()[ randi() % ITEMS.size() ] ];

    if spawned_item == Vector2i(99,99):
        var dinosaur = dinosaur_scene.instantiate();
        dinosaur.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y)));
        dinosaur.add_to_group('dinosaurGroup');
        add_child(dinosaur)
    else:
        var item_x = randi_range(3,40)
        var item_y = randi_range(3,39)
        spawned_items_this_wave.append(Vector2i(item_x,item_y))
        $Arena.set_cell(1, Vector2i(item_x, item_y),0,spawned_item);
    
    $ItemSpawnTimer.start(randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS,constants.ITEM_SPAWN_MAXIMUM_SECONDS));

func despawn_all_items():
    # FIXME: This does not seem to be working.
    for single_item in spawned_items_this_wave:
        print ("DESPAWNING " + str(single_item))
        $Arena.set_cell(1, single_item,-1, Vector2i(-1, -1));

func spawn_enemy():
    var mob = enemy_scene.instantiate();
    mob.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y)));
    mob.add_to_group('enemyGroup');	
    add_child(mob);
    
func spawn_fish():
    var mob = fish_scene.instantiate();
    mob.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y)));
    mob.add_to_group('fishGroup');	
    add_child(mob);

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if game_status == WAVE_START:
        if $WaveIntroTimer.time_left == 0:
            start_game();
            
    if game_status == PREPARE_FOR_NEXT_WAVE:
        if $WaveEndTimer.time_left == 0:
            wave_end_prepare_for_next_wave();   
    
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
    if Input.is_action_just_pressed('cheat'):
        if game_status == INTRO_SCREEN:
            cheat_mode = 1;
            $MainMenu/CanvasLayer/MainMenuContainer/TitleLabel.text = "CHEAT SHARKS!\n\nBy Tristan Greaves";
            $Player.player_energy = constants.PLAYER_START_GAME_ENERGY_CHEATING;
            $HUD.get_node("CanvasLayer/EnergyProgressBar").max_value = constants.PLAYER_START_GAME_ENERGY
    
            _on_player_update_energy();
            
    if Input.is_action_just_pressed('start') or Input.is_action_just_pressed('quit'):
        match game_status:
            GAME_RUNNING:
                print ("PAUSING")
                game_status = GAME_PAUSED;
                $PauseMenu.get_node('CanvasLayer').visible = true
                $PauseMenu.set_process_input(true)
                $PauseMenu._ready()
                get_tree().paused = true;
                
    if Input.is_action_just_released('shark_fire') or Input.is_action_just_released('shark_fire_mouse'):
        match game_status:
            CREDITS:
                game_status = INTRO_SCREEN
                $Credits.queue_free()
                $MainMenu.get_node("CanvasLayer").visible = true
                
        
func _on_player_update_energy():
    #$HUD.get_node('CanvasLayer').get_node('Energy').text = "ENERGY\n" + str($Player.player_energy);
    $HUD.get_node('CanvasLayer').get_node('EnergyProgressBar').value = $Player.player_energy
    
func _on_enemy_update_score(score_to_add,enemy_global_position):
    enemies_left_this_wave = enemies_left_this_wave - 1;
    score = score + score_to_add;
    if score > high_score:
        high_score = score;
    
    if enemies_left_this_wave == 0:
        # If last wave enemy is dead, spawn the key.
        $Key.global_position = enemy_global_position
        $Key.show();
        $Key/CollisionShape2D.disabled = false;
        $Key/AnimatedSprite2D.play();
            
    _on_enemy_update_score_display();
    update_enemies_left_display();

func _on_enemy_update_score_display():
    $HUD.get_node('CanvasLayer').get_node('Score').text = "SCORE\n" + str(score);
    $HUD.get_node('CanvasLayer').get_node('HighScore').text = "HIGH SCORE\n" + str(high_score);

func update_enemies_left_display():
    $HUD.get_node('CanvasLayer').get_node('EnemiesLeft').text = "ENEMIES\n" + str(enemies_left_this_wave);
    
func update_fish_display():
    $HUD.get_node('CanvasLayer').get_node('Fish').text = "FISH\n" + str(fish_collected);
    
func _on_player_player_died():
    game_over();

func _on_player_player_got_fish():
    score = score + constants.GET_FISH_SCORE;
    if score > high_score:
        high_score = score;
        
    fish_collected = fish_collected + 1;
    _on_enemy_update_score_display();
    update_fish_display();

func _on_player_player_found_exit():
    wave_end_cleanup();
    
func _on_main_menu_start_game_pressed():
    print ("Signal to start OK")
    wave_end_prepare_for_next_wave()

func _on_main_menu_exit_game_pressed():
    get_tree().quit();


func _on_pause_menu_unpause_game_pressed():
    print("UNPAUSING")
    game_status = GAME_RUNNING;
    $PauseMenu.get_node('CanvasLayer').visible = false;
    $PauseMenu.set_process_input(false);
    get_tree().paused = false;
    

func _on_pause_menu_abandon_game_pressed():
    $PauseMenu.get_node('CanvasLayer').visible = false;
    $PauseMenu.set_process_input(false);
    get_tree().paused = false;
    return_to_main_screen();

func _on_main_menu_credits_pressed():
    game_status = CREDITS;
    $MainMenu.get_node("CanvasLayer").visible = false
    var credits = credits_scene.instantiate();
    credits.visible = true
    add_child(credits)
