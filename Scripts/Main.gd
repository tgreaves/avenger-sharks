extends Node

@export var dedication_scene: PackedScene
@export var intro_scene: PackedScene
@export var enemy_scene: PackedScene
@export var fish_scene: PackedScene
@export var dinosaur_scene: PackedScene
@export var credits_scene: PackedScene
@export var item_scene: PackedScene
@export var statistics_scene: PackedScene
@export var artillery_scene: PackedScene
@export var game_status = INTRO_SEQUENCE
@export var cheat_mode = false
@export var wave_number = 1
@export var enemies_left_this_wave = 0
@export var enemies_on_screen = 0
@export var fish_collected = 0;
@export var fish_left_this_wave = 0
@export var game_mode = 'ARCADE'
@export var dropped_items_on_screen = 0
@export var grouped_enemy_id = 0

var game_status_before_pause

var score = 0;
var score_multiplier = 1
var spawn_number = 0

var spawned_items_this_wave = []
var upgrade_focus_memory_left_button
var upgrade_focus_memory_middle_button
var upgrade_focus_memory_right_button
var intro
var dedication
var credits
var statistics
var first_game_played = false

var upgrade_one_index
var upgrade_two_index
var upgrade_three_index

var accept_pause = true

enum {
    DEDICATION,
    INTRO_SEQUENCE,
    MAIN_MENU,
    CREDITS,
    STATISTICS,
    OPTIONS,
    HOW_TO_PLAY,
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
    randomize()
    
    $ArtilleryTimer.connect('timeout', _on_artillery_timer)
    
    if Engine.has_singleton("Steam") && (OS.has_feature('steam') or constants.DEV_STEAM_TESTING):
        SteamClient.SteamSetup()
        Steam.overlay_toggled.connect(_on_steam_overlay_toggled)
        Steam.input_device_connected.connect(_on_steam_input_device_connected)
        Steam.input_device_disconnected.connect(_on_steam_input_device_disconnected)
        Steam.current_stats_received.connect(_on_steam_stats_ready)
            
    Storage.load_config()
    
    # Set screen mode based on config.
    if Storage.Config.get_value('config','screen_mode','FULL_SCREEN') == 'FULL_SCREEN':
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        get_window().size = constants.WINDOW_SIZE
    
    get_window().title = constants.WINDOW_TITLE
    DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
    
    # Set volume levels from config.
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Master'), linear_to_db(Storage.Config.get_value('config','master_volume',1.0)))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), linear_to_db(Storage.Config.get_value('config','music_volume',1.0)))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Effects'), linear_to_db(Storage.Config.get_value('config','effects_volume',1.0)))
    
    $WaveTimeLeftTimer.connect('timeout', _on_wave_time_left_timer_timeout)
    $AcceptPauseTimer.connect('timeout', _on_accept_pause_timer_timeout)
    
    Storage.load_stats()
    
    game_status = DEDICATION
    
    $Arena.visible = false;
    $HUD/CanvasLayer.visible = false
    $MainMenu.get_node('CanvasLayer').visible = false
    $PauseMenu.get_node('CanvasLayer').visible = false
    $Statistics.get_node('CanvasLayer').visible = false
    $Credits.get_node('CanvasLayer').visible = false
    $HowToPlay.get_node('CanvasLayer').visible = false
    $Options.get_node('CanvasLayer').visible = false
    $Player.set_process(false);
    $Player.set_physics_process(false);
    $Player.visible = false;
    $Player.get_node("CollisionShape2D").disabled = false
    
    # Ensure we update high score as this may have been located from storage.
    _on_enemy_update_score_display()
    
    if constants.DEV_DELAY_ON_START:
        await get_tree().create_timer(5.0).timeout
    
    if constants.DEV_SKIP_INTRO:
        main_menu()
    else:
        dedication = dedication_scene.instantiate()
        add_child(dedication)
       
func main_menu():
    game_status=MAIN_MENU
    score=0
    score_multiplier=1
    fish_collected=0
    fish_left_this_wave=0
    wave_number= constants.START_WAVE - 1
    enemies_on_screen = 0
     
    $SharkAttackMusic.stop()
    $AudioStreamPlayerMusic.stop()
    
    if !$MenuMusic.is_playing():
        $MenuMusic.play()

    # Ensure music speed is always at normal.
    _on_player_player_no_longer_low_energy()

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
    
    var tween = get_tree().create_tween()
    tween.tween_property(self, "modulate", Color(1,1,1,1), 0.5)
    
    $HUD/CanvasLayer.visible = true
    $HUD/CanvasLayer/UpgradeChoiceContainer.visible = false
    $HUD/CanvasLayer/UpgradeSummary.visible = false
    $HUD/CanvasLayer/BossHealthBar.visible = false
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
    
    if $MenuMusic.is_playing():
        $MenuMusic.stop()
        $AudioStreamPlayerMusic.play()
    
    enemies_left_this_wave = 0
    grouped_enemy_id = 0
    
    if game_mode == 'ARCADE':
        update_time_left_display()
    else:
        update_fish_left_display()
        $Player.get_node('FishProgressBar').visible = false
        
    prepare_for_wave()     

func prepare_for_wave():
    wave_number += 1
    
    if $WaveEndMusic.is_playing():
        $WaveEndMusic.stop()
    
    if !$AudioStreamPlayerMusic.is_playing():
        $AudioStreamPlayerMusic.play()
    
    TheDirector.design_wave(wave_number)
    
    $Arena.close_top_door()
    $Arena.open_bottom_door()
    
    $HUD.get_node("CanvasLayer/Score").visible = true;
    $HUD.get_node("CanvasLayer/Label").visible = false;
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = true;
    
    if game_mode == 'ARCADE':
        $HUD.show_powerup_bar()
    
    $UnderwaterFar.visible = false
    $UnderwaterNear.visible = false
    $MainMenu.get_node('CanvasLayer').visible = false
    $MainMenu.set_process_input(false)
    $Arena.visible = true
    
    $Arena.reset_arena_floor()
    
    for i in range(1, TheDirector.WaveDesign.get('obstacle_number', 0)):
        $Arena.add_obstacle()
    
    # Fish spawning
    if game_mode == 'ARCADE':
        fish_left_this_wave = constants.FISH_TO_SPAWN_ARCADE
    else:
        fish_left_this_wave = constants.FISH_TO_SPAWN_PACIFIST_BASE + ( (wave_number-1) * constants.FISH_TO_SPAWN_PACIFIST_WAVE_MULTIPLIER )
    
    $Player.set_process(true);
    $Player.set_physics_process(true);
    $Player.prepare_for_new_wave()
    $Player/Camera2D.enabled = true
    $Player.visible = true
    #$Player.position = Vector2(2650, 2500)
    $Player.position = Vector2(2650, 2600)
    $Player.get_node("AnimatedSprite2D").animation = 'default';
    $Player.get_node("AnimatedSprite2D").play()
    
    var tween = get_tree().create_tween()
    tween.tween_property(self, "modulate", Color(1,1,1,1), 0.5)
    
    if constants.CAMERA_ZOOM_EFFECTS and wave_number == 1:
        $Player/Camera2D.set_zoom(Vector2(4.0,4.0))
        var tween_camera = get_tree().create_tween()   
        tween_camera.tween_property($Player/Camera2D, "zoom", Vector2(1.0,1.0), 2.5).set_trans(tween_camera.EASE_OUT)
    
    emit_signal("player_move_to_starting_position");

    _on_enemy_update_score_display()
    
    if game_mode == 'ARCADE':
        update_time_left_display()
    else:
        update_fish_left_display()
    
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
                wave_text = 'SURVIVE ' + str( TheDirector.WaveDesign.get('wave_time')) + " SECONDS FOR NEXT WAVE!"
            'PACIFIST':
                wave_text = 'COLLECT ALL FISH FOR NEXT WAVE!' 
    else:
        wave_text = "[center]WAVE " + str(wave_number) + "\n\nSURVIVE " + str( TheDirector.WaveDesign.get('wave_time')) + " SECONDS!"
    
    var spawn_text = TheDirector.WaveDesign.get('spawn_text', '')
                
    $HUD.get_node("CanvasLayer/Label").text = wave_text

    if spawn_text:
        $HUD.get_node("CanvasLayer/Label").text += '\n\n' + spawn_text
    
    $HUD.get_node("CanvasLayer/Label").visible = true;
    $WaveIntroTimer.start();

func start_wave():
    game_status = GAME_RUNNING;
    var i = 0;
    
    if $SharkAttackMusic.is_playing():
        $SharkAttackMusic.stop()
    
    if wave_number > Storage.Stats.get_value('player','furthest_wave',0):
        Storage.increase_stat('player','furthest_wave',1)
    
    $HUD.get_node("CanvasLayer/Score").visible = true;
    $HUD.get_node("CanvasLayer/Label").visible = false;
    $HUD.get_node("CanvasLayer/EnemiesLeft").visible = true;

    dropped_items_on_screen = 0

    $WaveTimeLeftTimer.start(TheDirector.WaveDesign.get('wave_time'))    
    $ItemSpawnTimer.start(randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS,constants.ITEM_SPAWN_MAXIMUM_SECONDS));
    $EnemySpawnTimer.start(TheDirector.WaveDesign.get('reinforcements_timer', 0));

    spawn_number=0
    enemies_left_this_wave = TheDirector.WaveDesign.get('total_enemies')
    
    if TheDirector.WaveDesign.get('boss_wave', false):
        $HUD.boss_health_reveal()
    else:
        spawn_enemy('start_spawn','spawn_pattern',false)   

    i=0;

    while (i < fish_left_this_wave):
        spawn_fish();
        i=i+1;
    
    if game_mode == 'PACIFST':
        update_fish_left_display()
        
    # Artillery
    if TheDirector.WaveDesign.get('artillery', false):
        $ArtilleryTimer.start(randf_range(constants.ARTILLERY_MINIMUM_TIME, constants.ARTILLERY_MAXIMUM_TIME))

func wave_end():
    
    # Don't let wave end if the player beat it by dying!
    if !$Player.is_player_alive():
        return
    
    game_status = GETTING_KEY
    
    if $Player.power_pellet_enabled:
        $Player.power_pellet_enabled = false
        $Player.power_pellet_warning_running = false
        $Player.end_shark_attack()
    
    for enemy in get_tree().get_nodes_in_group("enemyGroup"):
        enemy.swim_escape()
        
    $HUD.get_node("CanvasLayer/Label").text = "WAVE COMPLETE!"
    $HUD.get_node("CanvasLayer/Label").visible = true;
    
    if constants.PLAY_WAVE_END_MUSIC:
        $AudioStreamPlayerMusic.stop()
        $WaveEndMusic.play()
    
    for enemy_trap in get_tree().get_nodes_in_group('enemyTrap'):
        enemy_trap.queue_free()
    
    despawn_all_items()
    $ArtilleryTimer.stop()
    
    emit_signal('player_hunt_key', $Key.global_position);
    
    for fish in get_tree().get_nodes_in_group('fishGroup'):
        fish.queue_free()
        
    for dinosaur in get_tree().get_nodes_in_group('dinosaurGroup'):
        dinosaur.queue_free()
        
    for artillery in get_tree().get_nodes_in_group('artilleryGroup'):
        artillery.queue_free()
        
    # Pop Steam achievement if appropriate.
    if SteamClient.STEAM_RUNNING:
        if game_mode == 'ARCADE':
            match wave_number:
                1:
                    Steam.setAchievement('ACH_ARCADE_BEAT_1_WAVE')
                    Steam.storeStats()
                5:
                    Steam.setAchievement('ACH_ARCADE_BEAT_5_WAVES')
                10:
                    Steam.setAchievement('ACH_ARCADE_BEAT_10_WAVES')
        
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
    $HUD.get_node("CanvasLayer/Label").text = "[center]GAME OVER";
    $AudioStreamPlayerMusic.pitch_scale = 1.0
    
    if SteamClient.STEAM_RUNNING:
        if wave_number == 1:
            Steam.setAchievement('ACH_ARCADE_NAME_IS_BRUCE')
    
        # Done at end of game to play nicely with Steam rate limiting.
        var fish_hold = Storage.Stats.get_value('player','fish_rescued',0)
        
        # To catch players that hit achievements BEFORE they were introduced, check all of them.
        if fish_hold >=100:
            Steam.setAchievement('ACH_RESCUE_100_FISH')
        
        if fish_hold >=500:
            Steam.setAchievement('ACH_RESCUE_500_FISH')
            
        if fish_hold >= 1000:
            Steam.setAchievement('ACH_RESCUE_1000_FISH')
            
        Steam.storeStats()
    
    $AudioStreamPlayerMusic.stop()
    $MenuMusic.play()
    
    $GameOverTimer.start()

func return_to_main_screen():
    for shark_spray in get_tree().get_nodes_in_group("sharkSprayGroup"):
        shark_spray.queue_free()
    
    for mini_shark_spray in get_tree().get_nodes_in_group("miniSharkSprayGroup"):
        mini_shark_spray.queue_free()
    
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
        
    for dinosaur_attack in get_tree().get_nodes_in_group('dinosaurAttack'):
        dinosaur_attack.queue_free()
        
    for artillery in get_tree().get_nodes_in_group('artilleryGroup'):
        artillery.queue_free()
        
    $ArtilleryTimer.stop() 
    $Key.hide()
    despawn_all_items()
    $Player.stop_fish_frenzy()
    $CountdownEffect.stop()
    $Player/HungryParticles.set_emitting(false)
    
    Storage.save_stats()
    
    main_menu();
    
func spawn_item():	
    
    var ITEMS
    var spawn_position
    var valid_spawn = false
    
    while !valid_spawn:
        spawn_position = Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y))
        if !$Arena.conflict_with_obstacle(spawn_position):
            valid_spawn=true
    
    if game_mode == 'ARCADE':
        ITEMS = constants.ARCADE_SPAWNING_ITEMS
    else:
        ITEMS = constants.PACIFIST_SPAWNING_ITEMS
       
    var spawned_item = ITEMS[randi() % ITEMS.size()]
    
    if spawned_item == 'dinosaur':
        var dinosaur = dinosaur_scene.instantiate()
        dinosaur.get_node('.').set_position (spawn_position);
        dinosaur.add_to_group('dinosaurGroup');
        add_child(dinosaur)
    else:
        var item = item_scene.instantiate()
        item.spawn_specific(spawned_item, false)
        item.get_node('.').set_position (spawn_position);
        item.add_to_group('itemGroup')
        add_child(item)
        
        # If a power pellet, due to their blinking nature, reset all pellet animations to be in sync.
        if spawned_item == 'power-pellet':
            for single_item in get_tree().get_nodes_in_group('itemGroup'):
                if single_item.item_type == 'power_pellet':
                    single_item.get_node('AnimatedSprite2D').stop()
                    single_item.get_node('AnimatedSprite2D').start()
        
    $ItemSpawnTimer.start(randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS,constants.ITEM_SPAWN_MAXIMUM_SECONDS));

func despawn_all_items():
    for item in get_tree().get_nodes_in_group('itemGroup'):
        item.queue_free()

func spawn_enemy(spawn_to_use,spawn_pattern_to_use,half_spawn_boolean):  
    var spawn_pattern = TheDirector.WaveDesign.get(spawn_to_use).get(spawn_pattern_to_use)
    var spawn_array = TheDirector.WaveDesign.get(spawn_to_use).get('spawn_array')
    var number_to_spawn = spawn_array.size()
    
    if half_spawn_boolean:
        @warning_ignore("integer_division")
        var spawn_a = int(number_to_spawn/2)
        var spawn_b = number_to_spawn - spawn_a
        
        if spawn_pattern_to_use == 'spawn_pattern':
            spawn_array = spawn_array.slice(0, spawn_a)
        else:
            spawn_array = spawn_array.slice(spawn_a, spawn_a+spawn_b)
            
        number_to_spawn = spawn_array.size()
    
    # If this is the final spawn this wave, AND it is considered a 'low population' spawn, surround the player.
    # Why? Stops the end of the wave being boring with the player having to wait to find the enemies.
    if (enemies_on_screen+number_to_spawn <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW) && (enemies_left_this_wave <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW):
        spawn_pattern = 'CIRCLE_SURROUND_PLAYER'

    # Uncomment this to force a spawn pattern for testing.
    #spawn_pattern='RANDOM'
    
    match spawn_pattern:
        'RANDOM':
            var i=0
            while (i < number_to_spawn):
                spawn_enemy_random_position(spawn_array[i])
                i+=1
        'CIRCLE_SURROUND_PLAYER':
            var i=0
            while (i < number_to_spawn):
                var angle_degrees = ( 360 / number_to_spawn ) * (i+1)
                var angle_rad = deg_to_rad(angle_degrees)
                var offset = Vector2(sin(angle_rad), cos(angle_rad)) * 600;       
                var enemy_position = $Player.position + offset
                
                spawn_enemy_set_position(spawn_array[i], enemy_position,'',Vector2(0,0).normalized(), false)
                i+=1
        'HARD_TOP':
            var i=0
            var y_pos = constants.ARENA_SPAWN_MIN_Y
            var x_step = (constants.ARENA_SPAWN_MAX_X - constants.ARENA_SPAWN_MIN_X) / number_to_spawn
            while (i < number_to_spawn):
                spawn_enemy_set_position(spawn_array[i], Vector2(constants.ARENA_SPAWN_MIN_X + (i*x_step), y_pos), 'DEFERRED_UNTIL_WALL', Vector2(0,1).normalized(), false)
                i+=1
        'HARD_BOTTOM':
            var i=0
            var y_pos = constants.ARENA_SPAWN_MAX_Y
            var x_step = (constants.ARENA_SPAWN_MAX_X - constants.ARENA_SPAWN_MIN_X) / number_to_spawn
            while (i < number_to_spawn):
                spawn_enemy_set_position(spawn_array[i], Vector2(constants.ARENA_SPAWN_MIN_X + (i*x_step), y_pos), 'DEFERRED_UNTIL_WALL', Vector2(0,-1).normalized(), false)
                i+=1
        'HARD_LEFT':
            var i=0
            var x_pos = constants.ARENA_SPAWN_MIN_X
            var y_step = (constants.ARENA_SPAWN_MAX_Y - constants.ARENA_SPAWN_MIN_Y) / number_to_spawn
            while (i < number_to_spawn):
                spawn_enemy_set_position(spawn_array[i], Vector2(x_pos, constants.ARENA_SPAWN_MIN_Y + (i*y_step)), 'DEFERRED_UNTIL_WALL', Vector2(1,0).normalized(), false)
                i+=1
        'HARD_RIGHT':
            var i=0
            var x_pos = constants.ARENA_SPAWN_MAX_X
            var y_step = (constants.ARENA_SPAWN_MAX_Y - constants.ARENA_SPAWN_MIN_Y) / number_to_spawn
            while (i < number_to_spawn):
                spawn_enemy_set_position(spawn_array[i], Vector2(x_pos, constants.ARENA_SPAWN_MIN_Y + (i*y_step)), 'DEFERRED_UNTIL_WALL', Vector2(-1,0).normalized(), false)
                i+=1
                
    return spawn_pattern
      
func spawn_enemy_random_position(enemy_type):
    var mob = enemy_scene.instantiate()
    
    var spawn_position
    var valid_spawn = false
    
    while !valid_spawn:
        spawn_position = Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y))
        if !$Arena.conflict_with_obstacle(spawn_position):
            valid_spawn=true

    mob.get_node('.').set_position(spawn_position)
    mob.add_to_group('enemyGroup');	
    add_child(mob, true); 

    mob.spawn_specific(enemy_type)
        
    enemies_on_screen+=1
    
func spawn_enemy_set_position(enemy_type,enemy_position,ai_mode,initial_direction,instant_spawn):
    enemy_position.x = clamp(enemy_position.x, constants.ARENA_SPAWN_MIN_X, constants.ARENA_SPAWN_MAX_X )        
    enemy_position.y = clamp(enemy_position.y, constants.ARENA_SPAWN_MIN_Y, constants.ARENA_SPAWN_MAX_Y )   
    
    var valid_spawn = false
    
    while !valid_spawn:
        if !$Arena.conflict_with_obstacle(enemy_position):
            valid_spawn=true
            
        # Fuzz enemy_position
        enemy_position = enemy_position + Vector2(50,50)
    
    var mob = enemy_scene.instantiate()
    mob.get_node('.').set_position (enemy_position);
    mob.set_ai_mode(ai_mode)
    
    if initial_direction:
        mob.set_initial_direction(initial_direction)
    
    mob.add_to_group('enemyGroup');	
    add_child(mob, true)  
    
    if instant_spawn:
        mob.set_instant_spawn(true)
        mob.set_enemy_is_split(true)
        mob.spawn_specific(enemy_type)
    else:
        mob.spawn_specific(enemy_type)
        
    enemies_on_screen+=1
        
func spawn_fish():
    var mob = fish_scene.instantiate();
    
    var spawn_position
    var valid_spawn = false
    
    while !valid_spawn:
        spawn_position = Vector2(randf_range(constants.ARENA_SPAWN_MIN_X,constants.ARENA_SPAWN_MAX_X),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y))
        if !$Arena.conflict_with_obstacle(spawn_position):
            valid_spawn=true
    
    mob.get_node('.').set_position (spawn_position);
    mob.add_to_group('fishGroup');	
    add_child(mob, true)

func _process(_delta):
    if SteamClient.STEAM_RUNNING:
        Steam.run_callbacks()
    
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
        if game_mode == 'ARCADE':
            update_time_left_display()
        
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
            if spawn_number < TheDirector.WaveDesign.get('total_spawns', 0):
                spawn_number+=1
                
                var spawn_label = "spawn_" + str(spawn_number)
                
                if TheDirector.WaveDesign.get(spawn_label).get('spawn_pattern_b'):                    
                    spawn_enemy(spawn_label, 'spawn_pattern', true)
                    spawn_enemy(spawn_label, 'spawn_pattern_b', true)
                else:
                    spawn_enemy(spawn_label, 'spawn_pattern', false)
                    
                $EnemySpawnTimer.start(TheDirector.WaveDesign.get('reinforcements_timer'))
            
    if game_status == GAME_OVER:
        if $GameOverTimer.time_left == 0:
            return_to_main_screen();
        
func _input(ev):
    if game_status != INTRO_SEQUENCE and game_status != DEDICATION:
        if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
            DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
        else:
            DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)  
          
    if Input.is_action_just_pressed('start') or Input.is_action_just_pressed('quit'):
        handle_pause_input()
                                      
    if Input.is_action_just_released('shark_fire') or Input.is_action_just_released('shark_fire_mouse') or Input.is_action_just_released('quit'):
        match game_status:
            DEDICATION:
                dedication.queue_free()
                intro = intro_scene.instantiate()
                add_child(intro)
                game_status = INTRO_SEQUENCE
            INTRO_SEQUENCE:
                intro.queue_free()
                main_menu()

func handle_pause_input():
    match game_status:
        GAME_RUNNING,WAVE_START,GETTING_KEY,WAVE_END,UPGRADE_SCREEN,UPGRADE_WAITING_FOR_CHOICE:                    
            # Avoid 'double press' if we have just come back from the pause menu
            if !accept_pause:
                return
            
            game_status_before_pause = game_status
            game_status = GAME_PAUSED
            
            if game_status_before_pause == UPGRADE_WAITING_FOR_CHOICE:
                upgrade_focus_memory_left_button = $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/Button.has_focus()
                upgrade_focus_memory_middle_button = $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/Button.has_focus()
                upgrade_focus_memory_right_button = $HUD/CanvasLayer/UpgradeChoiceContainer/Choice3/Button.has_focus()
                 
            $PauseMenu.get_node('CanvasLayer').visible = true
            $PauseMenu.set_process_input(true)
            $PauseMenu.pause()
            get_tree().paused = true
   
func _on_enemy_update_score(score_to_add,enemy_global_position,death_source,enemy_type,enemy_is_split,grouped_enemy_has_died): 
    if grouped_enemy_has_died:
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
    
    var enemy_details = constants.ENEMY_SETTINGS[enemy_type]
    
    if enemy_details.get('spawns_others', false) && !enemy_is_split:
        spawn_enemy_set_position(enemy_type,enemy_global_position, 'SPAWN_OUTWARDS', Vector2(-1,+1).normalized(), true)
        spawn_enemy_set_position(enemy_type,enemy_global_position, 'SPAWN_OUTWARDS', Vector2(+1,+1).normalized(), true)
        spawn_enemy_set_position(enemy_type,enemy_global_position, 'SPAWN_OUTWARDS', Vector2(+1,-1).normalized(), true)
        spawn_enemy_set_position(enemy_type,enemy_global_position, 'SPAWN_OUTWARDS', Vector2(-1,-1).normalized(), true)
        enemies_left_this_wave+=4
            
    _on_enemy_update_score_display();
    
    if game_mode == 'ARCADE':
        update_time_left_display();

    return score_to_return

func _on_enemy_update_score_display():
    $HUD.get_node('CanvasLayer').get_node('Score').text = "SCORE\n" + str(score);
    
    if score_multiplier > 1:
        $HUD.get_node('CanvasLayer').get_node('Score').text += " x" + str(score_multiplier)
    
    $HUD.get_node('CanvasLayer').get_node('HighScore').text = "HIGH SCORE\n" + str(Storage.Stats.get_value('player','high_score'));

func _reset_score_multiplier():
    score_multiplier=1
    _on_enemy_update_score_display()

func update_time_left_display():
    
        var time_left
        
        match game_status:
            GAME_RUNNING,GETTING_KEY,WAVE_END,UPGRADE_SCREEN,UPGRADE_WAITING_FOR_CHOICE:
                time_left = int(ceil($WaveTimeLeftTimer.time_left))
            _:
                time_left = TheDirector.WaveDesign.get('wave_time')
                 
        $HUD.get_node('CanvasLayer').get_node('EnemiesLeft').text = "TIME\n" + str(time_left)
        
        if time_left == 3 and !$CountdownEffect.is_playing():
            $CountdownEffect.play()
            
        # FOOBAR
        if time_left and time_left <= 3:
            $HUD.get_node("CanvasLayer/Label").text = "[center][font_size=128][pulse freq=1.0 color=#ffffff40 ease=-2.0]" + str(time_left)
            $HUD.get_node("CanvasLayer/Label").visible = true;
            
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
    game_status = game_status_before_pause
    $PauseMenu.get_node('CanvasLayer').visible = false
    
    if game_status == UPGRADE_WAITING_FOR_CHOICE:
        if upgrade_focus_memory_left_button:
            $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/Button.grab_focus()
            upgrade_focus_memory_left_button = false
            
        if upgrade_focus_memory_middle_button:
            $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/Button.grab_focus()
            upgrade_focus_memory_middle_button = false
        
        if upgrade_focus_memory_right_button:
            $HUD/CanvasLayer/UpgradeChoiceContainer/Choice3/Button.grab_focus()
            upgrade_focus_memory_right_button = false

    $PauseMenu.set_process_input(false)
    accept_pause = false
    $AcceptPauseTimer.start()
    get_tree().paused = false
    
func _on_pause_menu_abandon_game_pressed():
    $PauseMenu.get_node('CanvasLayer').visible = false;
    $PauseMenu.set_process_input(false);
    get_tree().paused = false;
    return_to_main_screen();

func _on_main_menu_credits_pressed():
    game_status = CREDITS
    $Credits.prepare_content()
    $MainMenu.get_node("CanvasLayer").visible = false
    $Credits/CanvasLayer/VBoxContainer/ReturnButton.grab_focus()
    $HUD/CanvasLayer/HighScore.visible = false;
    $Credits/CanvasLayer.visible = true
    $Credits.commence_scroll()
    
func _on_main_menu_how_to_play_pressed():
    game_status = HOW_TO_PLAY
    $MainMenu.get_node("CanvasLayer").visible = false
    $HowToPlay/CanvasLayer/VBoxContainer/ReturnButton.grab_focus()
    $HUD/CanvasLayer/HighScore.visible = false;
    $HowToPlay/CanvasLayer.visible = true

func dedication_has_finished():
    dedication.queue_free()
    game_status = INTRO_SEQUENCE
    intro = intro_scene.instantiate()
    add_child(intro)

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
    upgrade_three_index = 0
    
    # Form an array of upgrades that are eligible for inclusion.
    var eligible_upgrades:Array = []
    
    for single_upgrade in $Player.upgrades:
        var single_upgrade_detail = $Player.upgrades.get(single_upgrade)
        if single_upgrade_detail[0] < single_upgrade_detail[1]:
            # This can be included as we have not exceeded max level of the upgrade.
            eligible_upgrades.append(single_upgrade)
    
    while eligible_upgrades.size() < 3:
        eligible_upgrades.append('HEAL ME')
    
    # Now select the two upgrades to present to the player.
    eligible_upgrades.shuffle()
    upgrade_one_index = eligible_upgrades.pop_front()
    upgrade_two_index = eligible_upgrades.pop_front()
    upgrade_three_index = eligible_upgrades.pop_front()
                
    if constants.DEV_FORCE_UPGRADE:
        upgrade_one_index = constants.DEV_FORCE_UPGRADE
        
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/TextureRect.texture = load($Player.upgrades[upgrade_one_index][2])
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/TextureRect.texture = load($Player.upgrades[upgrade_two_index][2])
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice3/TextureRect.texture = load($Player.upgrades[upgrade_three_index][2])

    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/Title.text = upgrade_one_index
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/Title.text = upgrade_two_index
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice3/Title.text = upgrade_three_index
    
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice1/Description.text = $Player.upgrades[upgrade_one_index][3]
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/Description.text = $Player.upgrades[upgrade_two_index][3]
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice3/Description.text = $Player.upgrades[upgrade_three_index][3]
    
    $HUD/CanvasLayer/UpgradeChoiceContainer/Choice2/Button.grab_focus()
    
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

func _on_how_to_play_return_button_pressed():
    game_status = MAIN_MENU
    $MainMenu.get_node("CanvasLayer").visible = true
    $MainMenu/CanvasLayer/MainMenuContainer/HowToPlay.grab_focus()
    $HUD/CanvasLayer/HighScore.visible = true
    $HowToPlay/CanvasLayer.visible = false

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

func _on_steam_overlay_toggled(toggled, _user_activated, _user_id):
    if toggled:
        handle_pause_input()

func _on_steam_input_device_disconnected(input_handle):
    Logging.log_entry("Input device disconnected: " + str(input_handle))
    
func _on_steam_input_device_connected(input_handle):
    Logging.log_entry("Input device connected: " + str(input_handle))
    
func _on_artillery_timer():
    var mob = artillery_scene.instantiate();
    
    var spawn_position
          
    spawn_position = Vector2(randf_range($Player.position.x-200, $Player.position.x+200), randf_range($Player.position.y-200, $Player.position.y+200))
    
    mob.get_node('.').set_position (spawn_position);
    mob.add_to_group('artilleryGroup');	
    add_child(mob, true);
    
    $ArtilleryTimer.start(randf_range(constants.ARTILLERY_MINIMUM_TIME, constants.ARTILLERY_MAXIMUM_TIME))

func _on_accept_pause_timer_timeout():
    accept_pause = true
    
func _on_wave_time_left_timer_timeout():
    if game_mode =='ARCADE' and game_status == GAME_RUNNING:        
        # Make sure we update time to 0
        update_time_left_display() 
        
        # Have a random enemy drop the key in fear.
        var random_enemy_idx = randi_range(0, get_tree().get_nodes_in_group("enemyGroup").size()-1)
        $Key.global_position = get_tree().get_nodes_in_group("enemyGroup")[random_enemy_idx].global_position
        $Key.show();
        $Key/CollisionShape2D.disabled = false;
        $Key/AnimatedSprite2D.play();
        
        wave_end()
        
func _on_steam_stats_ready(_game: int, _result: int, _user: int) -> void:
    Logging.log_entry("Steam stats / achievements now available.")
    
    if constants.DEV_WIPE_ACHIEVEMENTS:
        Logging.log_entry("Wiping achievements...")
        #Steam.clearAchievement('ACH_ARCADE_BEAT_1_WAVE')
        Steam.storeStats()
