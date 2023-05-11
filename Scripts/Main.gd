extends Node

@export var intro_scene: PackedScene
@export var enemy_scene: PackedScene
@export var fish_scene: PackedScene
@export var dinosaur_scene: PackedScene
@export var credits_scene: PackedScene
@export var item_scene: PackedScene
@export var statistics_scene: PackedScene
@export var game_status = INTRO_SEQUENCE
@export var cheat_mode = false
@export var wave_number = 1
@export var enemies_left_this_wave = 0
@export var enemies_on_screen = 0
@export var fish_collected = 0;
@export var fish_left_this_wave = 0
@export var game_mode = 'ARCADE'
@export var wave_special_type = 'STANDARD'
@export var wave_special_data = ''
@export var dropped_items_on_screen = 0

var score = 0;
var score_multiplier = 1

var spawned_items_this_wave = []
var intro
var credits
var statistics
var first_game_played = false

var upgrade_one_index
var upgrade_two_index

enum {
    INTRO_SEQUENCE,
    MAIN_MENU,
    CREDITS,
    STATISTICS,
    OPTIONS,
    WAVE_START,
    GAME_RUNNING,
    GAME_PAUSED,
    GETTING_KEY,
    WAVE_END,
    UPGRADE_SCREEN,
    UPGRADE_WAITING_FOR_CHOICE,
    PREPARE_FOR_WAVE,
    GAME_OVER
}
   
signal player_hunt_key;
signal player_move_to_starting_position;
signal player_enable_fish_frenzy;
signal player_update_energy
signal player_update_fish

# Called when the node enters the scene tree for the first time.
func _ready():
    Storage.load_config()
    
    # Set screen mode based on config.
    if Storage.Config.get_value('config','screen_mode','FULL_SCREEN') == 'FULL_SCREEN':
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        get_window().size = constants.WINDOW_SIZE
    
    get_window().title = constants.WINDOW_TITLE
    
    # Set volume levels from config.
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Master'), linear_to_db(Storage.Config.get_value('config','master_volume',1.0)))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), linear_to_db(Storage.Config.get_value('config','music_volume',1.0)))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Effects'), linear_to_db(Storage.Config.get_value('config','effects_volume',1.0)))
    
    Storage.load_stats()
    
    game_status = INTRO_SEQUENCE;
    
    $Arena.visible = false;
    $HUD/CanvasLayer.visible = false
    $MainMenu.get_node('CanvasLayer').visible = false
    $PauseMenu.get_node('CanvasLayer').visible = false
    $Statistics.get_node('CanvasLayer').visible = false
    $Credits.get_node('CanvasLayer').visible = false
    $Options.get_node('CanvasLayer').visible = false
    $Player.set_process(false);
    $Player.set_physics_process(false);
    $Player.visible = false;
    $Player.get_node("CollisionShape2D").disabled = false
    
    # Ensure we update high score as this may have been located from storage.
    _on_enemy_update_score_display()
    
    if constants.DEV_SKIP_INTRO:
        main_menu()
    else:
        intro = intro_scene.instantiate()
        add_child(intro)
       
func main_menu():
    game_status=MAIN_MENU
    score=0
    score_multiplier=1
    fish_collected=0
    fish_left_this_wave=0
    wave_number= constants.START_WAVE - 1
    enemies_on_screen = 0
    
    if $AudioStreamPlayerMusic.playing == false:
        $AudioStreamPlayerMusic.play(0.6);
 
    $Player/Camera2D.enabled = false
    $Player.set_process(false);
    $Player.set_physics_process(false);
    $Player.visible = false;
    $Player.get_node("CollisionShape2D").disabled = false;
    $Player._ready();

    $UnderwaterFar.visible = true
    $UnderwaterNear.visible = true
    $Arena.visible = false
    $PauseMenu.get_node('CanvasLayer').visible = false;
    $PauseMenu.set_process_input(false);
    
    $MainMenu.get_node('CanvasLayer').visible = true;
    $HUD/CanvasLayer/HighScore.visible = true;
    $MainMenu.set_process_input(true);
    $MainMenu._ready();
    
    $HUD/CanvasLayer.visible = true
    $HUD/CanvasLayer/UpgradeChoiceContainer.visible = false
    $HUD/CanvasLayer/UpgradeSummary.visible = false
    $HUD.get_node("CanvasLayer/Score").visible = false;
    $HUD.get_node("CanvasLayer/Label").visible = true;
    $HUD.get_node("CanvasLayer/Label").text = "";
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = false;
    
    $HUD.hide_powerup_bar()
    
    if constants.DEV_START_GAME_IMMEDIATELY && !first_game_played:
        start_game()
    
func start_game():
    first_game_played = true
    
    Storage.increase_stat('player','games_played',1)
    
    if cheat_mode == true:
        $Player.player_energy = constants.PLAYER_START_GAME_ENERGY_CHEATING
    else:
        $Player.player_energy = constants.PLAYER_START_GAME_ENERGY
        
    $Player.get_node('EnergyProgressBar').max_value = $Player.player_energy
    $Player.get_node("FishProgressBar").max_value = constants.FISH_TO_TRIGGER_FISH_FRENZY
    $Player.prepare_for_new_game()
    
    $HUD/CanvasLayer/UpgradeSummary.text = ""
    $HUD/CanvasLayer/UpgradeSummary.visible = true
    
    enemies_left_this_wave = 0
    
    if game_mode == 'ARCADE':
        update_enemies_left_display()
        #DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
    else:
        update_fish_left_display()
        $Player.get_node('FishProgressBar').visible = false
        
    prepare_for_wave()     

func prepare_for_wave():
    wave_number=wave_number+1;
    
    # Close top door.
    $Arena.set_cell(
        2,
        Vector2(31,2),
        0,
        Vector2i(6,6))
    
    $Arena.set_cell(
        2,
        Vector2(32,2),
        0,
        Vector2i(7,6))
        
    # Open bottom door.
    $Arena.set_cell(
        2,
        Vector2(31,33),
        -1,
        Vector2i(6,6))
    
    $Arena.set_cell(
        2,
        Vector2(32,33),
        -1,
        Vector2i(7,6))
    
    $HUD.get_node("CanvasLayer/Score").visible = true;
    $HUD.get_node("CanvasLayer/Label").visible = false;
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = true;
    
    if game_mode == 'ARCADE':
        $HUD.show_powerup_bar()
    
    $UnderwaterFar.visible = false
    $UnderwaterNear.visible = false
    $MainMenu.get_node('CanvasLayer').visible = false
    $MainMenu.set_process_input(false)
    $Arena.visible = true;
    $Player.set_process(true);
    $Player.set_physics_process(true);
    $Player.prepare_for_new_wave()
    $Player/Camera2D.enabled = true
    $Player.visible = true
    $Player.position = Vector2(2650, 2500);
    $Player.get_node("AnimatedSprite2D").animation = 'default';
    $Player.get_node("AnimatedSprite2D").play()
    
    var tween = get_tree().create_tween()
    tween.tween_property(self, "modulate", Color(1,1,1,1), 0.5)
    
    emit_signal("player_move_to_starting_position");

    _on_enemy_update_score_display()
    
    emit_signal('player_update_energy')
    emit_signal('player_update_fish')

    $Key/CollisionShape2D.disabled = true;
    
    wave_intro()

func wave_intro():
    game_status = WAVE_START;
    
    var wave_text
    
    if wave_number == 1:
        match game_mode:
            'ARCADE':
                wave_text = 'CLEAR ALL ENEMIES FOR NEXT WAVE!'
            'PACIFIST':
                wave_text = 'COLLECT ALL FISH FOR NEXT WAVE!' 
    else:
        wave_text = "WAVE " + str(wave_number)
    
    var spawn_text = ''
    
    # Determine if this is a 'special' wave as this will influece things....
    if wave_number >= constants.ENEMY_SPAWN_WAVE_SPECIAL_MIN_WAVE:
        var spawn_choice = randi_range(1,100)
    
        for spawn_key in constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION:
            if spawn_choice <= spawn_key:
                wave_special_type = constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][0]
                wave_special_data = constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][1]
                spawn_text = constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][2]
                
                break
    else:
        wave_special_type = 'STANDARD'
            
    $HUD.get_node("CanvasLayer/Label").text = wave_text

    if spawn_text:
        $HUD.get_node("CanvasLayer/Label").text += '\n\n' + spawn_text
    
    $HUD.get_node("CanvasLayer/Label").visible = true;
    $WaveIntroTimer.start();

func start_wave():
    game_status = GAME_RUNNING;
    var i = 0;
    
    if wave_number > Storage.Stats.get_value('player','furthest_wave',0):
        Storage.increase_stat('player','furthest_wave',1)
    
    $HUD.get_node("CanvasLayer/Score").visible = true;
    $HUD.get_node("CanvasLayer/Label").visible = false;
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = true;

    dropped_items_on_screen = 0
    
    $ItemSpawnTimer.start(randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS,constants.ITEM_SPAWN_MAXIMUM_SECONDS));
    $EnemySpawnTimer.start(constants.ENEMY_REINFORCEMENTS_SPAWN_BASE_SECONDS);
    
    enemies_left_this_wave = (wave_number * constants.ENEMY_MULTIPLIER_AT_WAVE_START) + (wave_number * constants.ENEMY_MULTIPLIER_DURING_WAVE);
    spawn_enemy(wave_number * constants.ENEMY_MULTIPLIER_AT_WAVE_START, '')   

    # Fish spawning
    if game_mode == 'ARCADE':
        fish_left_this_wave = constants.FISH_TO_SPAWN_ARCADE
    else:
        fish_left_this_wave = constants.FISH_TO_SPAWN_PACIFIST_BASE + ( (wave_number-1) * constants.FISH_TO_SPAWN_PACIFIST_WAVE_MULTIPLIER )
    
    i=0;

    while (i < fish_left_this_wave):
        spawn_fish();
        i=i+1;
    
    if game_mode == 'ARCADE':
        update_enemies_left_display()
    else:
        update_fish_left_display()

func wave_end():
    
    # Don't let wave end if the player beat it by dying!
    if !$Player.is_player_alive():
        return
    
    game_status = GETTING_KEY;
    
    $HUD.get_node("CanvasLayer/Label").text = "WAVE COMPLETE!"
    $HUD.get_node("CanvasLayer/Label").visible = true;
    
    for enemy_trap in get_tree().get_nodes_in_group('enemyTrap'):
        enemy_trap.queue_free()
    
    despawn_all_items()
    
    # Auto send player to get the key.
    emit_signal('player_hunt_key', $Key.global_position);
    
    if game_mode == 'PACIFIST':
        for enemy in get_tree().get_nodes_in_group('enemyGroup'):
            enemy.queue_free()
    
    for fish in get_tree().get_nodes_in_group('fishGroup'):
        fish.queue_free()
        
    for dinosaur in get_tree().get_nodes_in_group('dinosaurGroup'):
        dinosaur.queue_free()
    
func wave_end_cleanup():
        
    $Player.visible = false;
    $Player.set_process(false);
    $Player.set_physics_process(false);
    $Key.visible = false;
    
    for enemy_attack in get_tree().get_nodes_in_group('enemyAttack'):
        enemy_attack.queue_free()
    
    for dinosaur_attack in get_tree().get_nodes_in_group('dinosaurAttack'):
        dinosaur_attack.queue_free()
    
    if game_mode == 'ARCADE':
        game_status = UPGRADE_SCREEN
    else:
        game_status = PREPARE_FOR_WAVE
    
    $WaveEndTimer.start();

func game_over():
    game_status = GAME_OVER;
    $HUD.get_node("CanvasLayer/Label").visible = true;
    $HUD.get_node("CanvasLayer/Label").text = "GAME OVER";
    $AudioStreamPlayerMusic.pitch_scale = 1.0
    
    $GameOverTimer.start();

func return_to_main_screen():
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
    
    Storage.save_stats()
    
    main_menu();
    
func spawn_item():	
    
    var ITEMS
    
    if game_mode == 'ARCADE':
        ITEMS = constants.ARCADE_SPAWNING_ITEMS
    else:
        ITEMS = constants.PACIFIST_SPAWNING_ITEMS
       
    var spawned_item = ITEMS[randi() % ITEMS.size()]
    
    if spawned_item == 'dinosaur':
        var dinosaur = dinosaur_scene.instantiate();
        dinosaur.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y)));
        dinosaur.add_to_group('dinosaurGroup');
        add_child(dinosaur)
    else:
        var item = item_scene.instantiate()
        item.spawn_specific(spawned_item, false)
        item.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y)));
        item.add_to_group('itemGroup')
        add_child(item)
        
    $ItemSpawnTimer.start(randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS,constants.ITEM_SPAWN_MAXIMUM_SECONDS));

func despawn_all_items():
    for item in get_tree().get_nodes_in_group('itemGroup'):
        item.queue_free()

func spawn_enemy(number_to_spawn, previous_spawn_pattern):
        
    var spawn_choice = 0
    var spawn_pattern = ''
    
    var acceptable_choice = false
    
    print("spawn_enemy() called with " + str(number_to_spawn) + " and " + str(previous_spawn_pattern))
    
    # If we have been passed the previous_spawn_pattern, do not allow the same pattern to be used
    # again.
    while (!acceptable_choice):
        spawn_choice = randi_range(1,100)
            
        for spawn_key in constants.ENEMY_SPAWN_PLACEMENT_CONFIGURATION:
            if spawn_choice <= spawn_key:
                spawn_pattern = constants.ENEMY_SPAWN_PLACEMENT_CONFIGURATION[spawn_key]
                break
        
        print("Spawn pattern suggsted: " + str(spawn_pattern))
                
        if spawn_pattern != previous_spawn_pattern:
            acceptable_choice=true
    
    # If this is the final spawn this wave, AND it is considered a 'low population' spawn, surround the player.
    # Why? Stops the end of the wave being boring with the player having to wait to find the enemies.
    if (enemies_on_screen+number_to_spawn <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW) && (enemies_left_this_wave <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW):
        spawn_pattern = 'CIRCLE_SURROUND_PLAYER'

    # Uncomment this to force a spawn pattern for testing.
    #spawn_pattern='RANDOM'
    
    print("SPAWN: Using pattern " + str(spawn_pattern))
    
    match spawn_pattern:
        'RANDOM':
            var i=0
            while (i < number_to_spawn):
                spawn_enemy_random_position()
                i+=1
        'CIRCLE_SURROUND_PLAYER':
            var i=0
            while (i < number_to_spawn):
                var angle_degrees = ( 360 / number_to_spawn ) * (i+1)
                var angle_rad = deg_to_rad(angle_degrees)
                var offset = Vector2(sin(angle_rad), cos(angle_rad)) * 600;       
                var enemy_position = $Player.position + offset
                
                spawn_enemy_set_position(enemy_position,'',Vector2(0,0).normalized(), false)
                i+=1
        'HARD_TOP':
            var i=0
            var y_pos = constants.ARENA_SPAWN_MIN_Y
            var x_step = (constants.ARENA_SPAWN_MAX_X - constants.ARENA_SPAWN_MIN_X) / number_to_spawn
            while (i < number_to_spawn):
                spawn_enemy_set_position(Vector2(constants.ARENA_SPAWN_MIN_X + (i*x_step), y_pos), 'DEFERRED_UNTIL_WALL', Vector2(0,1).normalized(), false)
                i+=1
        'HARD_BOTTOM':
            var i=0
            var y_pos = constants.ARENA_SPAWN_MAX_Y
            var x_step = (constants.ARENA_SPAWN_MAX_X - constants.ARENA_SPAWN_MIN_X) / number_to_spawn
            while (i < number_to_spawn):
                spawn_enemy_set_position(Vector2(constants.ARENA_SPAWN_MIN_X + (i*x_step), y_pos), 'DEFERRED_UNTIL_WALL', Vector2(0,-1).normalized(), false)
                i+=1
        'HARD_LEFT':
            var i=0
            var x_pos = constants.ARENA_SPAWN_MIN_X
            var y_step = (constants.ARENA_SPAWN_MAX_Y - constants.ARENA_SPAWN_MIN_Y) / number_to_spawn
            while (i < number_to_spawn):
                spawn_enemy_set_position(Vector2(x_pos, constants.ARENA_SPAWN_MIN_Y + (i*y_step)), 'DEFERRED_UNTIL_WALL', Vector2(1,0).normalized(), false)
                i+=1
        'HARD_RIGHT':
            var i=0
            var x_pos = constants.ARENA_SPAWN_MAX_X
            var y_step = (constants.ARENA_SPAWN_MAX_Y - constants.ARENA_SPAWN_MIN_Y) / number_to_spawn
            while (i < number_to_spawn):
                spawn_enemy_set_position(Vector2(x_pos, constants.ARENA_SPAWN_MIN_Y + (i*y_step)), 'DEFERRED_UNTIL_WALL', Vector2(-1,0).normalized(), false)
                i+=1
                
    return spawn_pattern
      
func spawn_enemy_random_position():
    var mob = enemy_scene.instantiate()
    mob.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y)));
    mob.add_to_group('enemyGroup');	
    add_child(mob); 

    if wave_special_type == 'ALL_THE_SAME':
        mob.spawn_specific(wave_special_data)
    else:
        mob.spawn_random()
        
    enemies_on_screen+=1
    
func spawn_enemy_set_position(enemy_position,ai_mode,initial_direction,instant_spawn):
    enemy_position.x = clamp(enemy_position.x, constants.ARENA_SPAWN_MIN_X, constants.ARENA_SPAWN_MAX_X )        
    enemy_position.y = clamp(enemy_position.y, constants.ARENA_SPAWN_MIN_Y, constants.ARENA_SPAWN_MAX_Y )   
    
    var mob = enemy_scene.instantiate()
    mob.get_node('.').set_position (enemy_position);
    mob.set_ai_mode(ai_mode)
    
    if initial_direction:
        mob.set_initial_direction(initial_direction)
    
    mob.add_to_group('enemyGroup');	
    add_child(mob)  
    
    if instant_spawn:
        mob.set_instant_spawn(true)
        mob.set_enemy_is_split(true)
        mob.spawn_specific('skeleton')
    else:
        if wave_special_type == 'ALL_THE_SAME':
            mob.spawn_specific(wave_special_data)
        else:
            mob.spawn_random()
        
    enemies_on_screen+=1
        
func spawn_fish():
    var mob = fish_scene.instantiate();
    mob.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y)));
    mob.add_to_group('fishGroup');	
    add_child(mob);

func _process(_delta):
    if game_status == WAVE_START:
        if $WaveIntroTimer.time_left == 0:
            start_wave()
    
    if game_status == UPGRADE_SCREEN:
        if $WaveEndTimer.time_left == 0:
            upgrade_screen()
            
    if game_status == PREPARE_FOR_WAVE:
        if $WaveEndTimer.time_left == 0:
            prepare_for_wave()
    
    if game_status == GAME_RUNNING:
        if enemies_left_this_wave == 0:
            wave_end();
            
        if fish_left_this_wave == 0 && game_mode == 'PACIFIST':
            # Spawn key where player is.
            $Key.global_position = $Player.global_position
            $Key.show();
            $Key/CollisionShape2D.disabled = false;
            $Key/AnimatedSprite2D.play();
            
            wave_end()
            
        if $ItemSpawnTimer.time_left == 0:
            spawn_item();
            
        if $EnemySpawnTimer.time_left == 0:
            if enemies_left_this_wave > enemies_on_screen:
                
                var enemies_to_spawn = constants.ENEMY_REINFORCEMENTS_SPAWN_BATCH_SIZE + (wave_number * constants.ENEMY_REINFORCEMENTS_SPAWN_BATCH_MULTIPLIER)
                if enemies_to_spawn > enemies_left_this_wave - enemies_on_screen:
                    enemies_to_spawn = enemies_left_this_wave - enemies_on_screen
                    
                var how_many_left_to_spawn = enemies_left_this_wave - (enemies_to_spawn + enemies_on_screen)
                
                if how_many_left_to_spawn < constants.ENEMY_REINFORCEMENTS_SPAWN_MINIMUM_NUMBER:
                    enemies_to_spawn += how_many_left_to_spawn
    
                print("REINFORCEMENTS - I want to spawn " + str(enemies_to_spawn))
    
                # Multi-wave spawn at the same time?
                if ( randi_range(1,100) <= constants.ENEMY_REINFORCEMENTS_SPAWN_MULTI_PLACEMENT_PERCENTAGE):
                    var spawn_a = int(enemies_to_spawn/2)
                    var spawn_b = enemies_to_spawn - spawn_a
                    print("MULTI-SPAWN: Using " + str(spawn_a) + " and " + str(spawn_b))
                    
                    var first_spawn_result = spawn_enemy(spawn_a,'')
                    spawn_enemy(spawn_b, first_spawn_result)
                    
                else:
                    spawn_enemy(enemies_to_spawn,'')
                
            $EnemySpawnTimer.start(constants.ENEMY_REINFORCEMENTS_SPAWN_BASE_SECONDS);
            
    if game_status == GAME_OVER:
        if $GameOverTimer.time_left == 0:
            return_to_main_screen();
        
func _input(_ev):
    if Input.is_action_just_pressed('start') or Input.is_action_just_pressed('quit'):
        match game_status:
            GAME_RUNNING:
                game_status = GAME_PAUSED;
                $PauseMenu.get_node('CanvasLayer').visible = true
                $PauseMenu.set_process_input(true)
                $PauseMenu._ready()
                get_tree().paused = true;
                            
    if Input.is_action_just_released('shark_fire') or Input.is_action_just_released('shark_fire_mouse') or Input.is_action_just_released('quit'):
        match game_status:
            INTRO_SEQUENCE:
                intro.queue_free()
                main_menu()
            
func _on_enemy_update_score(score_to_add,enemy_global_position,death_source,enemy_type,enemy_is_split):
    enemies_left_this_wave = enemies_left_this_wave - 1
    enemies_on_screen = enemies_on_screen - 1
    score = score + (score_to_add*score_multiplier);
    var score_to_return = score_to_add*score_multiplier
    
    # Don't increase multiplier for dinosaur kills
    if death_source == 'PLAYER-SHOT':
        score_multiplier+= 1
    
    if score > Storage.Stats.get_value('player','high_score'):
        Storage.Stats.set_value('player','high_score', score)
        
    Storage.increase_stat('player', 'enemies_defeated', 1)
    
    if enemy_type == 'skeleton' && !enemy_is_split:
        spawn_enemy_set_position(enemy_global_position, 'SPAWN_OUTWARDS', Vector2(-1,+1).normalized(), true)
        spawn_enemy_set_position(enemy_global_position, 'SPAWN_OUTWARDS', Vector2(+1,+1).normalized(), true)
        spawn_enemy_set_position(enemy_global_position, 'SPAWN_OUTWARDS', Vector2(+1,-1).normalized(), true)
        spawn_enemy_set_position(enemy_global_position, 'SPAWN_OUTWARDS', Vector2(-1,-1).normalized(), true)
        enemies_left_this_wave+=4
    
    if enemies_left_this_wave == 0:
        # If last wave enemy is dead, spawn the key.
        $Key.global_position = enemy_global_position
        $Key.show();
        $Key/CollisionShape2D.disabled = false;
        $Key/AnimatedSprite2D.play();
            
    _on_enemy_update_score_display();
    
    if game_mode == 'ARCADE':
        update_enemies_left_display();

    return score_to_return

func _on_enemy_update_score_display():
    $HUD.get_node('CanvasLayer').get_node('Score').text = "SCORE\n" + str(score);
    
    if score_multiplier > 1:
        $HUD.get_node('CanvasLayer').get_node('Score').text += " x" + str(score_multiplier)
    
    $HUD.get_node('CanvasLayer').get_node('HighScore').text = "HIGH SCORE\n" + str(Storage.Stats.get_value('player','high_score'));

func _reset_score_multiplier():
    score_multiplier=1
    _on_enemy_update_score_display()

func update_enemies_left_display():
    $HUD.get_node('CanvasLayer').get_node('EnemiesLeft').text = "ENEMIES\n" + str(enemies_left_this_wave);

func update_fish_left_display():
    $HUD.get_node('CanvasLayer').get_node('EnemiesLeft').text = "FISH\n" + str(fish_left_this_wave);
    

func _on_player_player_died():
    game_over();

func _on_player_player_got_fish():
    score = score + constants.GET_FISH_SCORE;
    if score > Storage.Stats.get_value('player','high_score'):
        Storage.Stats.set_value('player','high_score',score)
        
    Storage.increase_stat('player', 'fish_rescued', 1)    
        
    fish_collected += 1
    fish_left_this_wave -= 1
    _on_enemy_update_score_display();
    emit_signal('player_update_fish')
    
    if game_mode == 'PACIFIST':
        update_fish_left_display()
    else:
        if fish_collected == $Player.get_node('FishProgressBar').max_value:
            emit_signal('player_enable_fish_frenzy')

func _on_player_player_found_exit():
    wave_end_cleanup();
    
func _on_main_menu_start_game_pressed():
    start_game()

func _on_main_menu_exit_game_pressed():
    get_tree().quit();

func _on_pause_menu_unpause_game_pressed():
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
    $Credits/CanvasLayer/VBoxContainer/ReturnButton.grab_focus()
    $HUD/CanvasLayer/HighScore.visible = false;
    $Credits/CanvasLayer.visible = true
    $Credits.commence_scroll()

func intro_has_finished():
    intro.queue_free()
    main_menu()

func _on_main_menu_cheats_pressed():
    cheat_mode = true
    
func _on_player_player_low_energy():
    $AudioStreamPlayerMusic.pitch_scale = 1.2
    
func _on_player_player_no_longer_low_energy():
    $AudioStreamPlayerMusic.pitch_scale = 1.0
    
func upgrade_screen():
    # Select two upgrades to offer the player at random.
    
    # 'MAGNET':       [ 0, 1, 'res://Images/placeholder.png', 'A powerful magnet which does magnet things.'],
    # 'ARMOUR':       [ 0, 3, 'Images/placeholder.png', 'Decrease incoming damage by 10%']
    
    upgrade_one_index = 0
    upgrade_two_index = 0
    
    var deadlock_solved = false
    
    while (!deadlock_solved):
        upgrade_one_index = $Player.upgrades.keys()[ randi() % $Player.upgrades.size() ]
        upgrade_two_index = $Player.upgrades.keys()[ randi() % $Player.upgrades.size() ]
        
        # 1st check: Don't suggest identical upgrades.
        if upgrade_one_index != upgrade_two_index:
            
            # 2nd check: Don't suggest upgrades that are at max level already
            # (Option for future: Ability to swap out upgrades?)
            
            if $Player.upgrades[upgrade_one_index][0] < $Player.upgrades[upgrade_one_index][1] and $Player.upgrades[upgrade_two_index][0] < $Player.upgrades[upgrade_two_index][1]:
                deadlock_solved = true
         
    # Uncomment to force a certain upgrade to be offered (Testing)       
    #upgrade_one_index = 'LOOT LOVER'
       
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/TextureRect.texture = load($Player.upgrades[upgrade_one_index][2])
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/TextureRect.texture = load($Player.upgrades[upgrade_two_index][2])
    
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/Title.text = upgrade_one_index
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/Title.text = upgrade_two_index
    
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/Description.text = $Player.upgrades[upgrade_one_index][3]
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/Description.text = $Player.upgrades[upgrade_two_index][3]
    
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/Button.grab_focus()
    
    $HUD/CanvasLayer/UpgradeChoiceContainer.modulate = Color(0,0,0,0)
    $HUD/CanvasLayer/UpgradeChoiceContainer.visible = true
    
    var tween = get_tree().create_tween()
    tween.tween_property($HUD/CanvasLayer/UpgradeChoiceContainer, "modulate", Color(1,1,1,1), 0.5)
    
    game_status = UPGRADE_WAITING_FOR_CHOICE

func _on_player_player_made_upgrade_choice():
    $HUD/CanvasLayer/UpgradeChoiceContainer.visible = false
    game_status = PREPARE_FOR_WAVE
    
func _on_main_menu_game_mode_pressed():
    if game_mode == 'ARCADE':
        game_mode = 'PACIFIST'
    else:
        game_mode = 'ARCADE'
        
    $MainMenu/CanvasLayer/MainMenuContainer/GameMode.text = 'MODE: ' + str(game_mode)
    
func _on_main_menu_statistics_pressed():
    game_status = STATISTICS
    $MainMenu.get_node("CanvasLayer").visible = false
    $HUD/CanvasLayer/HighScore.visible = false;
    $Statistics.build_statistics_screen()
    $Statistics/CanvasLayer.visible = true

func _on_statistics_statistics_return_button_pressed():
    game_status = MAIN_MENU
    $MainMenu.get_node("CanvasLayer").visible = true
    $MainMenu/CanvasLayer/MainMenuContainer/Statistics.grab_focus()
    $HUD/CanvasLayer/HighScore.visible = true
    $Statistics/CanvasLayer.visible = false

func _on_credits_credits_return_button_pressed():
    game_status = MAIN_MENU
    $MainMenu.get_node("CanvasLayer").visible = true
    $MainMenu/CanvasLayer/MainMenuContainer/Credits.grab_focus()
    $HUD/CanvasLayer/HighScore.visible = true
    $Credits/CanvasLayer.visible = false

func _on_main_menu_options_pressed():
    game_status = OPTIONS
    $MainMenu.get_node("CanvasLayer").visible = false
    $HUD/CanvasLayer/HighScore.visible = false;
    $Options.build_options_screen()
    $Options/CanvasLayer.visible = true

func _on_options_options_return_button_pressed():
    Storage.save_config()
    
    game_status = MAIN_MENU
    $MainMenu.get_node("CanvasLayer").visible = true
    $MainMenu/CanvasLayer/MainMenuContainer/Options.grab_focus()
    $HUD/CanvasLayer/HighScore.visible = true
    $Options/CanvasLayer.visible = false
