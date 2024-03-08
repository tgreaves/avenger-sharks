extends CharacterBody2D

const SharkSprayScene = preload("res://Scenes/SharkSpray.tscn")
const GrenadeScene = preload("res://Scenes/Grenade.tscn")
const MiniSharkScene = preload("res://Scenes/MiniShark.tscn")

enum {
    ALIVE,
    FISH_FRENZY,
    HUNTING_KEY,
    HUNTING_EXIT,
    FOUND_EXIT,
    GOING_THROUGH_DOOR,
    MOVING_TO_START_POSITION,
    EXPLODING,
    EXPLODED,
    CHEATING_DEATH
}

@export var speed = constants.PLAYER_SPEED;
@export var player_energy = constants.PLAYER_START_GAME_ENERGY;
@export var shark_status = ALIVE
@export var spray_size = 0.5
@export var current_powerup_levels = {}
@export var max_powerup_levels = {}
@export var upgrades = {}

signal player_died;
signal player_got_fish;
signal player_got_key;
signal player_found_exit_stop_key_movement;
signal player_found_exit;
signal player_low_energy
signal player_no_longer_low_energy
signal player_made_upgrade_choice

var key_global_position
var initial_player_position
var fish_frenzy_enabled = false
var fish_frenzy_colour
var item_magnet_enabled = false
var blink_status = false
var power_pellet_enabled = false
var power_pellet_warning_running = false
var powerup_labels_being_displayed = 0
var fire_delay = constants.PLAYER_FIRE_DELAY
var grenade_delay = constants.PLAYER_GRENADE_DELAY
var astar_pathing_grid

func _ready():
    shark_status = ALIVE;
    
    if initial_player_position:
        global_position = initial_player_position
    else:
        initial_player_position = global_position
        
    # Initiate maximum levels for each power-up
    max_powerup_levels = {
        'SPEED UP':     constants.POWERUP_SPEEDUP_MAX_LEVEL,
        'FAST SPRAY':   constants.POWERUP_FASTSPRAY_MAX_LEVEL,
        'BIG SPRAY':    constants.POWERUP_BIGSPRAY_MAX_LEVEL,
        'GRENADE':      constants.POWERUP_GRENADE_MAX_LEVEL,
        'MINI SHARK':   constants.POWERUP_MINISHARK_MAX_LEVEL
    }
    
    upgrades = {
        # Code          [ Current Level, Max Level, Image path, Description
        # If Max Level is 0 then it is a health-style purchase (Purchase once, instand result, doesn't stick)
        # If Max Level is 1 then it can only ever be purchased once (Binary item)
        'MAGNET':           [ 0, 1, 'res://Images/crosshair184.png', 'A powerful magnet which does magnet things.'],
        'ARMOUR':           [ 0, 3, 'res://Images/crosshair184.png', 'Decrease incoming damage by 10%'],
        'POTION POWER':     [ 0, 3, 'res://Images/crosshair184.png', 'Health potions are 10% more efficient'],
        'FISH AFFINITY':    [ 0, 3, 'res://Images/crosshair184.png', 'Decrease fish needed for FRENZY by 10%'],
        'DOMINANT DINO':    [ 0, 3, 'res://Images/crosshair184.png', 'Increase Mr Dinosaur attack time by 20%'],
        'MORE POWER':       [ 0, 3, 'res://Images/crosshair184.png', 'Increase Power Up duration by 20%'],
        'LOOT LOVER':       [ 0, 3, 'res://Images/crosshair184.png', 'Increase item drop rate by 10%'],
        'CHEAT DEATH':      [ 0, 1, 'res://Images/crosshair184.png', 'Regain 50% health upon death - Once!'],
        'HEAL ME':          [ -1, 0, 'res://Images/crosshair184.png', 'Instantly regain all health']
    }
    
func prepare_for_new_game():
    speed = constants.PLAYER_SPEED
    fire_delay = constants.PLAYER_FIRE_DELAY
    spray_size = 0.5
    fish_frenzy_enabled = false
    power_pellet_enabled = false
    $AnimatedSprite2D.set_modulate(Color(1, 1, 1, 1))
    
    for single_powerup in max_powerup_levels:
        current_powerup_levels[single_powerup] = 0
    
    get_parent().get_node('HUD').reset_powerup_bar()
    get_parent().get_node('HUD').reset_powerup_bar_text()
    get_parent().get_node('HUD').set_all_powerup_levels()
    
    despawn_mini_sharks()
    $PowerUpTickTimer.start()
    
func prepare_for_new_wave():
    blink_status = false
    $AnimatedSprite2DDamaged.visible = false;
    $EnergyProgressBar.visible = true
    
    if get_parent().game_mode == 'ARCADE':
        $FishProgressBar.visible = true
    
    set_fire_rate_delay_timer()
    set_grenade_rate_delay_timer()

func get_input():
    
    if shark_status != ALIVE:
        return;
        
    var input_direction = Input.get_vector("left", "right", "up", "down")
    velocity = input_direction * speed
        
    if $FireRateTimer.time_left == 0 && get_parent().game_mode == 'ARCADE':    
        # Mouse aiming
        if Input.is_action_pressed('shark_fire_mouse'):
            var shark_spray = SharkSprayScene.instantiate()
            get_parent().add_child(shark_spray)
            shark_spray.add_to_group('sharkSprayGroup')
            var target_direction = (get_global_mouse_position() - global_position).normalized()
            shark_spray.global_position = position;
            shark_spray.velocity = velocity + (target_direction * constants.PLAYER_FIRE_SPEED)
            Storage.increase_stat('player','shots_fired',1)
            
            mini_shark_fire(target_direction)
            grenade_fire(target_direction)
            
            $AudioStreamPlayerSpray.play()
            set_fire_rate_delay_timer()
        
        # Controller (Twin stick)
        var shoot_direction = Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down");
        if shoot_direction:
            var shark_spray = SharkSprayScene.instantiate()
            get_parent().add_child(shark_spray)
            shark_spray.add_to_group('sharkSprayGroup')
            shark_spray.global_position = position
            
            var shoot_input = Vector2.ZERO;
            shoot_input.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left");
            shoot_input.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up");
            shoot_direction = shoot_direction.normalized();
            
            shark_spray.velocity = velocity+(shoot_direction * constants.PLAYER_FIRE_SPEED)
            Storage.increase_stat('player','shots_fired',1)
             
            mini_shark_fire(shoot_direction)
            grenade_fire(shoot_direction)
            
            $AudioStreamPlayerSpray.play()
            set_fire_rate_delay_timer()
            
    # Aiming line support (Controller only)
    if get_parent().game_mode == 'ARCADE':
        var shoot_direction = Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")
        
        if shoot_direction:
            var shoot_input = Vector2.ZERO;
            shoot_input.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left");
            shoot_input.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up");
            shoot_direction = shoot_direction.normalized();
                
            $RayCast2D.target_position = shoot_direction*10000
            if $RayCast2D.is_colliding():
                # Need to do this check as rogue traps were causing invalid index position errors.
                if $RayCast2D.get_collider():
                    
                    var line_end_position = $RayCast2D.get_collider().position 
                    
                    # Tilemaps default to (0,0) hit location unless we do something special...
                    if $RayCast2D.get_collider().name == 'Arena':
                        line_end_position = $RayCast2D.get_collision_point()
                    
                    # Remove existing target.
                    remove_aiming_line()
                    
                    $AimingLine.add_point(to_local(line_end_position) )
            
        else:
            # Remove targetting line when stick not being used.
            remove_aiming_line()
            
    if Input.is_action_pressed('fish_frenzy') && fish_frenzy_enabled == true:
        fish_frenzy_enabled = false
        shark_status=FISH_FRENZY
        fish_frenzy_colour = 'BLUE'
        velocity = Vector2(0,0)
        $CollisionShape2D.disabled = true
        $FishProgressBar.visible = true
        $FishFrenzyTimer.start(constants.PLAYER_FISH_FRENZY_DURATION)
        $FishFrenzyFireTimer.start(constants.PLAYER_FISH_FRENZY_FIRE_DELAY)
        
        if Storage.Config.get_value('config','enable_haptics',false):
            Input.start_joy_vibration(0, 0.25, 0.25, constants.PLAYER_FISH_FRENZY_DURATION)
        
func _physics_process(_delta):
    get_input()
    move_and_slide()
            
    if $ProgressBarBlinkTimer.time_left == 0:
        if blink_status == true:
            blink_status = false
        else:
            blink_status = true
        
        if (shark_status != EXPLODING) and (shark_status != EXPLODED):
            if player_energy <= constants.PLAYER_LOW_ENERGY_BLINK:
                $EnergyProgressBar.visible = blink_status
            
            if fish_frenzy_enabled:
                $FishProgressBar.visible = blink_status

        $ProgressBarBlinkTimer.start()
    
    if $PowerUpTickTimer.time_left == 0 && shark_status == ALIVE:
        power_up_tick()
        $PowerUpTickTimer.start()
    
    match shark_status:
        ALIVE:
            if power_pellet_enabled:
                if $PowerPelletTimer.time_left == 0:
                    power_pellet_enabled = false
                    power_pellet_warning_running = false
                    end_shark_attack()
                else:
                    # Start 'Running out' blinking timer
                    if $PowerPelletTimer.time_left < 2 and !power_pellet_warning_running:
                        $PowerPelletWarningTimer.start()
                        power_pellet_warning_running = true
            
                # Alternate normal / red shark colour as timer is running out.
                if power_pellet_warning_running and $PowerPelletWarningTimer.time_left == 0:
                    if $AnimatedSprite2D.get_modulate() == Color(1,1,1,1):
                        $AnimatedSprite2D.set_modulate(Color(1, 0, 0, 1))
                    else:
                        $AnimatedSprite2D.set_modulate(Color(1, 1, 1, 1))
                    
                    $PowerPelletWarningTimer.start()
            
            if velocity.x > 0:
                $AnimatedSprite2D.set_flip_h(true);
            
            if velocity.x < 0:
                $AnimatedSprite2D.set_flip_h(false);
                
            $AnimatedSprite2D.play();
            
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                var collided_with = collision.get_collider();
                   
                if collision.get_collider().name == 'Arena':
                    break
                    
                if collision.get_collider().is_in_group('fishGroup'):
                    collided_with.get_node('.')._death(false);
                    $AudioStreamPlayerGotFish.play();
                    emit_signal('player_got_fish');
                    break
                
                if collision.get_collider().is_in_group('dinosaurGroup'):
                    collided_with.get_node('.')._go_on_a_rampage();
                    break
                
                if collision.get_collider().is_in_group('itemGroup'):
                    if collided_with.get_node('.').source == 'DROPPED':
                        get_parent().dropped_items_on_screen = get_parent().dropped_items_on_screen - 1
                    
                    match collided_with.get_node('.').item_type:
                        "health":
                            var original_energy = player_energy
                            
                            var health_percentage = upgrades['POTION POWER'][0] * 10
                            var health_to_add = int(constants.HEALTH_POTION_BONUS + ((health_percentage / 100.0) * constants.HEALTH_POTION_BONUS))
                            
                            player_energy = player_energy + health_to_add
                            if get_parent().cheat_mode:
                                if player_energy > constants.PLAYER_START_GAME_ENERGY_CHEATING:
                                    player_energy = constants.PLAYER_START_GAME_ENERGY_CHEATING
                            else:
                                if player_energy > constants.PLAYER_START_GAME_ENERGY:
                                    player_energy = constants.PLAYER_START_GAME_ENERGY;
                                    
                            $AudioStreamHealth.play();
                            powerup_label_animation('HEALTH!')
                            _on_main_player_update_energy()
                            
                            if (original_energy <= constants.PLAYER_LOW_ENERGY_BLINK) && (player_energy > constants.PLAYER_LOW_ENERGY_BLINK):
                                emit_signal('player_no_longer_low_energy')
                            
                            collided_with.get_node('.').despawn()
                            
                        "chest":
                            var powerup_options = ['SPEED UP','FAST SPRAY','BIG SPRAY','GRENADE','MINI SHARK']
                            var powerup_selected = powerup_options[randi() % powerup_options.size()]
                            
                            # Uncomment to test.
                            #powerup_selected = 'GRENADE'
                            
                            # Increase powerup level (but not over its maximum allowed)
                            current_powerup_levels[powerup_selected] += 1
                            if current_powerup_levels[powerup_selected] > max_powerup_levels[powerup_selected]:
                                current_powerup_levels[powerup_selected] = max_powerup_levels[powerup_selected]
                        
                            match powerup_selected:
                                'SPEED UP':
                                    speed = constants.PLAYER_SPEED + (constants.PLAYER_SPEED_POWERUP_INCREASE * current_powerup_levels[powerup_selected])
                                'FAST SPRAY':
                                    fire_delay = constants.PLAYER_FIRE_DELAY - (constants.PLAYER_FIRE_DELAY_POWERUP_DECREASE * current_powerup_levels[powerup_selected])
                                'BIG SPRAY':
                                    spray_size = 0.5 + (constants.PLAYER_FIRE_SIZE_POWERUP_INCREASE * current_powerup_levels[powerup_selected])
                                'GRENADE':
                                    grenade_delay = constants.PLAYER_GRENADE_DELAY - (constants.PLAYER_GRENADE_DELAY_POWERUP_DECREASE * current_powerup_levels[powerup_selected])  
                                'MINI SHARK':       
                                    if get_tree().get_nodes_in_group('miniSharkGroup').size() < max_powerup_levels[powerup_selected]:
                                            
                                        var new_mini_shark = MiniSharkScene.instantiate()
                                        add_child(new_mini_shark)
                                        new_mini_shark.add_to_group('miniSharkGroup')
                                    
                                        # Reset circular position of the mini sharks when we spawn a new one, to ensure
                                        # everything stays evenly spaced.
                                        recalculate_mini_shark_spacing()
                                    
                            powerup_label_animation(powerup_selected + "!")
                            get_parent().get_node('HUD').activate_powerup(powerup_selected)
                            get_parent().get_node('HUD').set_powerup_level(powerup_selected, current_powerup_levels[powerup_selected])
                            $AudioStreamPowerUp.play()
                        "power-pellet":
                            $PowerPelletTimer.start(constants.POWER_PELLET_ACTIVE_DURATION)
                            powerup_label_animation('TIME FOR DINNER!')
                            power_pellet_enabled = true
                            power_pellet_warning_running = false
                            get_parent().get_node('AudioStreamPlayerMusic').set_stream_paused(true)
                            get_parent().get_node('SharkAttackMusic').play()
                            
                            # BLOOD THIRSTY
                            $AnimatedSprite2D.set_modulate(Color(1, 0, 0, 1))
                            
                            # Force direction change
                            for single_enemy in get_tree().get_nodes_in_group('enemyGroup'):
                                single_enemy.consider_calling_for_help()
                                single_enemy.reset_state_timer()
                                                  
                    collided_with.get_node('.').despawn()
                
                    break
                
                # Default - Enemy	
                collided_with.get_node('.')._death('PLAYER-BODY');
                _player_hit();
               
        FISH_FRENZY:
            if $FishFrenzyTimer.time_left == 0:
                stop_fish_frenzy()
                
                shark_status = ALIVE               
            else:
                shake(10.0)
                $AnimatedSprite2D.rotation_degrees += 20
                if $AnimatedSprite2D.rotation_degrees >= 360:
                    $AnimatedSprite2D.rotation_degrees = 0
                
                get_parent().fish_collected = ($FishFrenzyTimer.time_left / constants.PLAYER_FISH_FRENZY_DURATION) * constants.FISH_TO_TRIGGER_FISH_FRENZY
                _on_main_player_update_fish()
                
                if $FishFrenzyFireTimer.time_left == 0:
                    $FishFrenzyFireTimer.start(constants.PLAYER_FISH_FRENZY_FIRE_DELAY)
                    var i=0
                    
                    while i <= 32:  
                        var target_direction = Vector2(1,1).normalized()
                        target_direction = target_direction.rotated ( deg_to_rad(360.0/32.0) * i)
                        var shark_spray = SharkSprayScene.instantiate()
                        get_parent().add_child(shark_spray)
                        shark_spray.add_to_group('sharkSprayGroup')
                        shark_spray.global_position = position
                        shark_spray.velocity = target_direction * constants.PLAYER_FIRE_SPEED
                        
                        if fish_frenzy_colour == 'BLUE':
                            fish_frenzy_colour = 'GREEN'
                        else:
                            shark_spray.modulate = Color(0,1,0) 
                            fish_frenzy_colour = 'BLUE'
                            
                        $AudioStreamPlayerSpray.play()
                        i+=1
                                 
        EXPLODING:
            if $PlayerExplosionTimer.time_left == 0:

                # Can the player cheat death?
                if upgrades['CHEAT DEATH'][0]:
                    upgrades['CHEAT DEATH'][0] = 0
                    get_parent().get_node('HUD').update_upgrade_summary()
                    
                    player_energy = 0.5 * constants.PLAYER_START_GAME_ENERGY
                    $EnergyProgressBar.value = player_energy
                    
                    # Play explosion backwards (a bit slower so sound FX fits)
                    $AnimatedSprite2D.animation = 'explosion'
                    $AnimatedSprite2D.speed_scale = -0.5
                    $AnimatedSprite2D.play()
                    $AudioStreamPlayerExplosionReverse.play()
                    
                    shark_status = CHEATING_DEATH
                    $PlayerExplosionTimer.start()
                else:       
                    emit_signal('player_died');
                    shark_status = EXPLODED;
        CHEATING_DEATH:
            if $PlayerExplosionTimer.time_left == 0:
                # Activate player again.
                shark_status = ALIVE
                $CollisionShape2D.set_deferred("disabled", false)
                $AnimatedSprite2D.animation = 'default'
                $AnimatedSprite2D.speed_scale = 1
                $EnergyProgressBar.visible=true
                
                if get_parent().game_mode == 'ARCADE':
                    $FishProgressBar.visible=true    
                
                powerup_label_animation('DEATH CHEATED!')
                
                # Give a 1s grace period before taking damage again.
                $PlayerHitGracePeriodTimer.start(1)      
        HUNTING_KEY:
            if velocity.x > 0:
                $AnimatedSprite2D.set_flip_h(true);
            
            if velocity.x < 0:
                $AnimatedSprite2D.set_flip_h(false);
            
            if $HuntingKeyTimer.time_left == 0:
                position = get_parent().get_node('Key').global_position
            
            # Have we reached the next node on the astar pathing grid?
            var tilemap_coords = get_parent().get_node('Arena').get_tilemap_coords(global_position)
            
            if astar_pathing_grid.size():
                if tilemap_coords == astar_pathing_grid[0]:
                    astar_pathing_grid.pop_front()
                    
                    if astar_pathing_grid.size():
                        var target_direction = (get_parent().get_node('Arena').get_position_from_tilemap(astar_pathing_grid[0]) - global_position).normalized()
                        velocity = target_direction * constants.PLAYER_SPEED_ESCAPING
                
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                
                if collision.get_collider().name == 'Key':  
                    shark_status = HUNTING_EXIT;
                    get_parent().get_node('Arena').get_node('ExitDoor').get_node('CollisionShape2D').disabled = false;
                    emit_signal('player_got_key')
                    
                    var exit_door_global = get_parent().get_node('Arena').get_node('ExitDoor').global_position            
                    astar_pathing_grid = get_parent().get_node('Arena').get_astar_route_from_positions(global_position, exit_door_global)
                  
                    # Start heading towards the first one. 
                    var target_direction = (get_parent().get_node('Arena').get_position_from_tilemap(astar_pathing_grid[0]) - global_position).normalized()
                    velocity = target_direction * constants.PLAYER_SPEED_ESCAPING
                    
                    $HuntingDoorTimer.start()
        HUNTING_EXIT:
            var did_collide = false
            
            # Have we reached the next node on the astar pathing grid?
            var tilemap_coords = get_parent().get_node('Arena').get_tilemap_coords(global_position)
            
            if tilemap_coords == astar_pathing_grid[0]:
                astar_pathing_grid.pop_front()
                
                if astar_pathing_grid.size():
                    var target_direction = (get_parent().get_node('Arena').get_position_from_tilemap(astar_pathing_grid[0]) - global_position).normalized()
                    velocity = target_direction * constants.PLAYER_SPEED_ESCAPING
                        
            if velocity.x > 0:
                $AnimatedSprite2D.set_flip_h(true);
            
            if velocity.x < 0:
                $AnimatedSprite2D.set_flip_h(false);
              
            if $HuntingDoorTimer.time_left == 0:
                position.x = 2632
                position.y = 286
            
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                
                if collision.get_collider().name == 'Arena':
                    did_collide=true
                    velocity = velocity.slide(collision.get_normal())
                
                if collision.get_collider().name == 'ExitDoor':  
                    did_collide=true
                    shark_status = FOUND_EXIT;
                    velocity = Vector2i(0,0)

                    # Open door.
                    get_parent().get_node('Arena').open_top_door()
                    get_parent().get_node('Arena').get_node('ExitDoor').get_node('CollisionShape2D').disabled = true;
                    
                    emit_signal('player_found_exit_stop_key_movement')
                    shark_status=GOING_THROUGH_DOOR
                    
                    #var tween_camera = get_tree().create_tween()   
                    #tween_camera.tween_property($Camera2D, "zoom", Vector2(3.0,3.0), 0.2)
                
                    $DoorOpenTimer.start()   
                    
            if !did_collide:
                var target_direction = (get_parent().get_node('Arena').get_node('ExitDoor').global_position - global_position).normalized();
                velocity = target_direction * constants.PLAYER_SPEED_ESCAPING;
                         
        GOING_THROUGH_DOOR:
                if $DoorOpenTimer.time_left == 0:
                    var target_direction = (get_parent().get_node('Arena').get_node('ExitLocation').global_position - global_position).normalized();
                    velocity = target_direction * constants.PLAYER_SPEED_ESCAPING;            
                     
                    var tween = get_tree().create_tween()
                    tween.tween_property(get_parent(), "modulate", Color(0,0,0,0), 0.35)
                                    
                for i in get_slide_collision_count():
                    var collision = get_slide_collision(i)
                
                    if collision.get_collider().name == 'ExitLocation':  
                        emit_signal('player_found_exit');  
        MOVING_TO_START_POSITION:
                if $DoorCloseTimer.time_left == 0:
                        # Close bottom door.
                            get_parent().get_node('Arena').close_bottom_door()
            
                for i in get_slide_collision_count():
                    var collision = get_slide_collision(i)
                     
                    if collision.get_collider().name == 'PlayerStartLocation':  
                        shark_status = ALIVE
                        get_parent().get_node('Arena').get_node('PlayerStartLocation').get_node('CollisionShape2D').disabled = true;
                                
func _player_hit():
    if shark_status != ALIVE:
        return
    
    if (!power_pellet_enabled) and $PlayerHitGracePeriodTimer.time_left == 0:
    
        $PlayerHitGracePeriodTimer.start();
        $AudioStreamPlayerHit.play();
        
        get_parent()._reset_score_multiplier()

        get_parent().get_node('HUD').flash_screen_red()
        
        if Storage.Config.get_value('config','enable_haptics',false):
            Input.start_joy_vibration(0, 0.5, 0.5, 0.05)
        
        var damage_reduction_percentage = upgrades['ARMOUR'][0] * constants.ARMOUR_DAMAGE_REDUCTION_PERCENTAGE
        var damage_to_perform = constants.PLAYER_HIT_BY_ENEMY_DAMAGE - (( damage_reduction_percentage / 100.0) * constants.PLAYER_HIT_BY_ENEMY_DAMAGE)
 
        player_energy = player_energy - damage_to_perform
        
        if player_energy <= 0:
            player_energy = 0;
            $CollisionShape2D.set_deferred("disabled", true)
            velocity = Vector2(0,0);
            $AnimatedSprite2D.animation = 'explosion';
            $AudioStreamPlayerExplosion.play();
            $EnergyProgressBar.visible=false
            $FishProgressBar.visible=false
            shark_status=EXPLODING;
            $PlayerExplosionTimer.start();
            despawn_mini_sharks()
            remove_aiming_line()
        else:
            $AnimatedSprite2DDamaged.visible = true;
            $AnimatedSprite2DDamaged.play();
        
            $EnergyProgressBar.value = player_energy
            _on_main_player_update_energy()
            
            if player_energy <= constants.PLAYER_LOW_ENERGY_BLINK:
                emit_signal('player_low_energy')
                
func _on_main_player_hunt_key(passed_key_global_position):
    if shark_status == FISH_FRENZY:
        stop_fish_frenzy()
    
    remove_aiming_line()
    
    shark_status = HUNTING_KEY
    key_global_position = passed_key_global_position
    
    astar_pathing_grid = get_parent().get_node('Arena').get_astar_route_from_positions(global_position, key_global_position)
    Logging.log_entry("ROUTE IS: " + str(astar_pathing_grid))
    
    # Start heading towards the first one.
    Logging.log_entry("First one would be: " + str(astar_pathing_grid[0]))
    Logging.log_entry("Actual coords: " + str(get_parent().get_node('Arena').get_position_from_tilemap(astar_pathing_grid[0])))
    
    var target_direction = (get_parent().get_node('Arena').get_position_from_tilemap(astar_pathing_grid[0]) - global_position).normalized()
    velocity = target_direction * constants.PLAYER_SPEED_ESCAPING
    
    # 'Break glass'
    $HuntingKeyTimer.start()

func _on_main_player_move_to_starting_position():
    shark_status = MOVING_TO_START_POSITION
    
    set_process(true);
    set_physics_process(true);
    visible = true
    
    get_parent().get_node('Arena').get_node('PlayerStartLocation').get_node('CollisionShape2D').disabled = false;
    
    var target_direction = (initial_player_position - global_position).normalized();
    velocity = target_direction * constants.PLAYER_SPEED
    
    $DoorCloseTimer.start()

func powerup_label_animation(powerup_name):
    var new_label = $PowerUpLabel.duplicate()
    add_child(new_label)
    
    powerup_labels_being_displayed += 1

    # Initial position bump if there are multiple animations happening.
    if powerup_labels_being_displayed > 1:
        new_label.position.y += -50 * (powerup_labels_being_displayed-1)
    
    new_label.set_modulate(Color(1,1,1,1));
    new_label.text = powerup_name
    new_label.visible = true
    
    # Text should move upwards slightly.
    var target_position = new_label.position
    target_position.y += -50
    
    var tween = get_tree().create_tween()
    tween.set_parallel()
    tween.tween_property(new_label, "modulate", Color(0,0,0,0), 2)
    tween.tween_property(new_label, "position", target_position, 2)
    tween.tween_callback(self.powerup_label_animation_decrease_count).set_delay(1.5)
    tween.tween_callback(new_label.queue_free).set_delay(2)
 
func powerup_label_animation_decrease_count():
    powerup_labels_being_displayed += -1
    
    if powerup_labels_being_displayed < 0:
        powerup_labels_being_displayed = 0
   
func set_fire_rate_delay_timer():
    $FireRateTimer.start(fire_delay)    
        
func set_grenade_rate_delay_timer():
    $GrenadeRateTimer.start(grenade_delay)         
        
func mini_shark_fire(shark_fire_direction):
    for mini_shark in get_tree().get_nodes_in_group("miniSharkGroup"):
        var mini_shark_spray = SharkSprayScene.instantiate()
        get_parent().add_child(mini_shark_spray)
        mini_shark_spray.add_to_group('miniSharkSprayGroup')
        mini_shark_spray.global_position = mini_shark.global_position
        mini_shark_spray.velocity = shark_fire_direction * constants.PLAYER_FIRE_SPEED;
        
func recalculate_mini_shark_spacing():
    var number_of_mini_sharks = get_tree().get_nodes_in_group('miniSharkGroup').size()
    var shark_count = 0;
    for single_shark in get_tree().get_nodes_in_group('miniSharkGroup'):
        single_shark.set_circle_position(shark_count, number_of_mini_sharks)
        shark_count = shark_count + 1

func despawn_mini_sharks():
    for single_shark in get_tree().get_nodes_in_group('miniSharkGroup'):
        single_shark.queue_free()

func grenade_fire(_fire_direction):
    if $GrenadeRateTimer.time_left == 0 and current_powerup_levels['GRENADE']:
        var grenade = GrenadeScene.instantiate()
        get_parent().add_child(grenade)
        grenade.add_to_group('grenadeGroup')
        grenade.global_position = position
        
        var enemy_distance = 10000
        var closest_enemy
       
        if get_tree().get_nodes_in_group('enemyGroup').size():
             # Find nearest enemy that is alive.
        
            for enemy in get_tree().get_nodes_in_group('enemyGroup'):
                if enemy.is_enemy_alive():
                    var distance = position.distance_to(enemy.position)
                    if distance < enemy_distance:
                        enemy_distance=distance
                        closest_enemy=enemy
            
        if enemy_distance != 10000:
            grenade.velocity = position.direction_to(closest_enemy.position) * constants.GRENADE_SPEED
        else:
            grenade.velocity = Vector2(0,0)
    
        $GrenadeRateTimer.start(grenade_delay)
    
func _on_main_player_enable_fish_frenzy():
    powerup_label_animation('FRENZY READY!')
    fish_frenzy_enabled = true

func shake(shake_amount):
    $Camera2D.set_offset(Vector2( 
        randf_range(-1.0, 1.0) * shake_amount,
        randf_range(-1.0, 1.0) * shake_amount
    ))
    
func shake_reset():
    $Camera2D.set_offset(Vector2(0.0,0.0))

func _on_main_player_update_energy():
    $EnergyProgressBar.value = player_energy
    $EnergyProgressBar.visible = true   

func _on_main_player_update_fish():
    $FishProgressBar.value = get_parent().fish_collected
    
func stop_fish_frenzy():
    $AnimatedSprite2D.rotation_degrees = 0
    shake_reset()
    get_parent().fish_collected = 0
    _on_main_player_update_fish()
    $CollisionShape2D.disabled = false

func power_up_tick():
    for powerup in max_powerup_levels:
        if current_powerup_levels[powerup] >= 1:
            
            var single_powerup = get_parent().get_node('HUD/CanvasLayer/PowerUpContainer').get_node(powerup)
            var value = single_powerup.get_node('Label/ProgressBar').value
            if value:
                value -= 1
                single_powerup.get_node('Label/ProgressBar').value = value
                
                if value <= 0:
                    decrease_powerup_level(powerup)
                    
                    match powerup:
                        'SPEED UP':
                            speed = constants.PLAYER_SPEED + (constants.PLAYER_SPEED_POWERUP_INCREASE * current_powerup_levels[powerup])
                        'FAST SPRAY':
                            fire_delay = constants.PLAYER_FIRE_DELAY - (constants.PLAYER_FIRE_DELAY_POWERUP_DECREASE * current_powerup_levels[powerup])  
                        'BIG SPRAY':
                            spray_size = 0.5 + (constants.PLAYER_FIRE_SIZE_POWERUP_INCREASE * current_powerup_levels[powerup])  
                        'GRENADE':
                            grenade_delay = constants.PLAYER_GRENADE_DELAY - (constants.PLAYER_GRENADE_DELAY_POWERUP_DECREASE * current_powerup_levels[powerup])                   
                        'MINI SHARK':
                            for single_shark in get_tree().get_nodes_in_group('miniSharkGroup'):
                                single_shark.queue_free()
                                break
                                    
                            recalculate_mini_shark_spacing()

func decrease_powerup_level(powerup):
    current_powerup_levels[powerup] = current_powerup_levels[powerup] - 1
    if current_powerup_levels[powerup] <= 0:
        current_powerup_levels[powerup] = 0
        get_parent().get_node('HUD').deactivate_powerup(powerup)
    else:
        get_parent().get_node('HUD').activate_powerup(powerup)
    
    get_parent().get_node('HUD').set_powerup_level(powerup, current_powerup_levels[powerup])
    
func _on_hud_upgrade_button_pressed(button_number):

    var selected_upgrade
    
    match button_number:
        1:
            selected_upgrade = get_parent().upgrade_one_index
        2:
            selected_upgrade = get_parent().upgrade_two_index
        3:
            selected_upgrade = get_parent().upgrade_three_index
    
    $AudioStreamPlayerSelectedUpgrade.play()
    
    # Mark upgrade as in use by increasing its level.
    # Ensure level does not exceed the maximum allowed.
    
    if upgrades[selected_upgrade][0] != -1:
        upgrades[selected_upgrade][0] = upgrades[selected_upgrade][0] + 1
        if upgrades[selected_upgrade][0] > upgrades[selected_upgrade][1]:
            upgrades[selected_upgrade][0] = upgrades[selected_upgrade][1]
    
    match selected_upgrade:
        'MAGNET':
            item_magnet_enabled = true
        'ARMOUR':
            pass    # No further action other than marking upgrade as in use needed.
        'FISH AFFINITY':
            var affinity_percentage = upgrades['FISH AFFINITY'][0] * 10
            var fish_needed = int(constants.FISH_TO_TRIGGER_FISH_FRENZY - ((affinity_percentage / 100.0) * constants.FISH_TO_TRIGGER_FISH_FRENZY))
            $FishProgressBar.max_value = fish_needed
        'MORE POWER':
            get_parent().get_node('HUD').reset_powerup_bar_durations()
        'HEAL ME':
            var original_energy = player_energy
            player_energy = constants.PLAYER_START_GAME_ENERGY
            _on_main_player_update_energy()
                            
            if (original_energy <= constants.PLAYER_LOW_ENERGY_BLINK) && (player_energy > constants.PLAYER_LOW_ENERGY_BLINK):
                emit_signal('player_no_longer_low_energy')
            
    
    get_parent().get_node('HUD').update_upgrade_summary()
    
    # Go to next wave.
    emit_signal('player_made_upgrade_choice')

func is_player_alive():
    if shark_status == ALIVE:
        return true
    else:
        return false
        
func remove_aiming_line():
    if $AimingLine.get_point_count() > 1:
        $AimingLine.remove_point(1)
        
func end_shark_attack():
    $AnimatedSprite2D.set_modulate(Color(1, 1, 1, 1))
    get_parent().get_node('SharkAttackMusic').stop()
    get_parent().get_node('AudioStreamPlayerMusic').set_stream_paused(false)
                
    for single_enemy in get_tree().get_nodes_in_group('enemyGroup'):
        single_enemy.reset_state_timer()
        single_enemy.stop_calling_for_help()
    
