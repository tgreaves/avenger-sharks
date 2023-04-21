extends CharacterBody2D

const SharkSprayScene = preload("res://Scenes/SharkSpray.tscn")
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
    EXPLODED
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

var key_global_position;
var initial_player_position;
var fish_frenzy_enabled = false
var fish_frenzy_colour
var item_magnet_enabled = false
var blink_status = false
var fire_delay = constants.PLAYER_FIRE_DELAY


func _ready():
    shark_status = ALIVE;
    
    if initial_player_position:
        global_position = initial_player_position
    else:
        initial_player_position = global_position
        
    # Initiate maximum levels for each power-up
    max_powerup_levels = {
        'SPEEDUP':      constants.POWERUP_SPEEDUP_MAX_LEVEL,
        'FAST SPRAY':   constants.POWERUP_FASTSPRAY_MAX_LEVEL,
        'BIG SPRAY':    constants.POWERUP_BIGSPRAY_MAX_LEVEL,
        'MINI SHARK':   constants.POWERUP_MINISHARK_MAX_LEVEL
    }
    
    upgrades = {
        # Code          [ Current Level, Max Level, Image path, Description
        # If Max Level is 1 then it can only ever be purchased once (Binary item)
        'MAGNET':           [ 0, 1, 'res://Images/crosshair184.png', 'A powerful magnet which does magnet things.'],
        'ARMOUR':           [ 0, 3, 'res://Images/crosshair184.png', 'Decrease incoming damage by 10%'],
        'POTION POWER':     [ 0, 3, 'res://Images/crosshair184.png', 'Healthy potions are 10% more efficient'],
        'FISH AFFINITY':    [ 0, 3, 'res://Images/crosshair184.png', 'Decrease fish needed for FRENZY by 10%'],
        'DOMINANT DINO':    [ 0, 3, 'res://Images/crosshair184.png', 'Increase Mr Dinosaur attack time by 20%'],
        'MORE POWER':       [ 0, 3, 'res://Images/crosshair184.png', 'Increase Power Up duration by 20%'],
        'LOOT LOVER':       [ 0, 3, 'res://Images/crosshair184.png',' Increase item drop rate by 10%']
    }
    
func prepare_for_new_game():
    speed = constants.PLAYER_SPEED
    fire_delay = constants.PLAYER_FIRE_DELAY
    spray_size = 0.5
    fish_frenzy_enabled = false
    
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
    $FishProgressBar.visible = true
    set_fire_rate_delay_timer()

func get_input():
    
    if shark_status != ALIVE:
        return;
        
    var input_direction = Input.get_vector("left", "right", "up", "down")
    velocity = input_direction * speed
    
    if $FireRateTimer.time_left == 0:
        if input_direction && Input.is_action_pressed('shark_fire'):
            var shark_spray = SharkSprayScene.instantiate();
            get_parent().add_child(shark_spray);
            shark_spray.global_position = position;
            shark_spray.velocity = input_direction * constants.PLAYER_FIRE_SPEED;
            
            mini_shark_fire(input_direction)
            
            $AudioStreamPlayerSpray.play()
            set_fire_rate_delay_timer()
            
        if Input.is_action_pressed('shark_fire_mouse'):
            var shark_spray = SharkSprayScene.instantiate();
            get_parent().add_child(shark_spray);
            var target_direction = (get_global_mouse_position() - global_position).normalized()
            shark_spray.global_position = position;
            shark_spray.velocity = target_direction * constants.PLAYER_FIRE_SPEED
            
            mini_shark_fire(target_direction)
            
            $AudioStreamPlayerSpray.play()
            set_fire_rate_delay_timer()
            
        var shoot_direction = Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down");
            
        if shoot_direction:
            var shark_spray = SharkSprayScene.instantiate();
            get_parent().add_child(shark_spray);
            shark_spray.global_position = position;
            
            var shoot_input = Vector2.ZERO;
            shoot_input.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left");
            shoot_input.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up");
            shoot_direction = shoot_direction.normalized();
            
            shark_spray.velocity = shoot_direction * constants.PLAYER_FIRE_SPEED;
            
            mini_shark_fire(shoot_direction)
            
            $AudioStreamPlayerSpray.play()
            set_fire_rate_delay_timer()
            
    if Input.is_action_pressed('fish_frenzy') && fish_frenzy_enabled == true:
        fish_frenzy_enabled = false
        shark_status=FISH_FRENZY
        fish_frenzy_colour = 'BLUE'
        velocity = Vector2(0,0)
        $CollisionShape2D.disabled = true
        $FishProgressBar.visible = true
        $FishFrenzyTimer.start(constants.PLAYER_FISH_FRENZY_DURATION)
        $FishFrenzyFireTimer.start(constants.PLAYER_FISH_FRENZY_FIRE_DELAY)
        
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
    
    if $PowerUpTickTimer.time_left == 0:
        power_up_tick()
        $PowerUpTickTimer.start()
    
    match shark_status:
        ALIVE:
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
                    
                if collision.get_collider().name.contains('Fish'):
                    collided_with.get_node('.')._death(0);
                    $AudioStreamPlayerGotFish.play();
                    emit_signal('player_got_fish');
                    break
                
                if collision.get_collider().name.contains('Dinosaur'):
                    collided_with.get_node('.')._go_on_a_rampage();
                    break
                
                if collision.get_collider().name.contains('Item'):
                    match collided_with.get_node('.').item_type:
                        "health":
                            var original_energy = player_energy
                            
                            var health_percentage = upgrades['POTION POWER'][0] * 10
                            var health_to_add = int(constants.HEALTH_POTION_BONUS + ((health_percentage / 100.0) * constants.HEALTH_POTION_BONUS))
                            
                            print("Health potion - adding " + str(health_to_add))
                            
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
                            #get_parent().get_node('HUD').chest_collected()
                            #$AudioStreamPlayerGotChest.play()
                            var powerup_options = ['SPEEDUP','FAST SPRAY','BIG SPRAY','MINI SHARK']
                            var powerup_selected = powerup_options[randi() % powerup_options.size()]
                            
                            # Increase powerup level (but not over its maximum allowed)
                            current_powerup_levels[powerup_selected] += 1
                            if current_powerup_levels[powerup_selected] > max_powerup_levels[powerup_selected]:
                                current_powerup_levels[powerup_selected] = max_powerup_levels[powerup_selected]
                        
                            match powerup_selected:
                                'SPEEDUP':
                                    speed = constants.PLAYER_SPEED + (constants.PLAYER_SPEED_POWERUP_INCREASE * current_powerup_levels[powerup_selected])
                                    powerup_label_animation('SPEED UP!')
                                'FAST SPRAY':
                                    fire_delay = constants.PLAYER_FIRE_DELAY - (constants.PLAYER_FIRE_DELAY_POWERUP_DECREASE * current_powerup_levels[powerup_selected])
                                    powerup_label_animation('FAST SPRAY!') 
                                'BIG SPRAY':
                                    spray_size = 0.5 + (constants.PLAYER_FIRE_SIZE_POWERUP_INCREASE * current_powerup_levels[powerup_selected])
                                    powerup_label_animation('BIG SPRAY!')
                                'MINI SHARK':       
                                    if get_tree().get_nodes_in_group('miniSharkGroup').size() < 8:
                                            
                                        var new_mini_shark = MiniSharkScene.instantiate()
                                        add_child(new_mini_shark)
                                        new_mini_shark.add_to_group('miniSharkGroup')
                                    
                                        # Reset circular position of the mini sharks when we spawn a new one, to ensure
                                        # everything stays evenly spaced.
                                        recalculate_mini_shark_spacing()
                                        
                                    powerup_label_animation('MINI SHARK!')
                                    
                            get_parent().get_node('HUD').activate_powerup(powerup_selected)
                            get_parent().get_node('HUD').set_powerup_level(powerup_selected, current_powerup_levels[powerup_selected])
                            $AudioStreamPowerUp.play()
                        
                    collided_with.get_node('.').despawn()
                
                    break
                
                # Default - Enemy	
                collided_with.get_node('.')._death();
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
                        var target_direction = Vector2(1,1).normalized();
                        target_direction = target_direction.rotated ( deg_to_rad(360.0/32.0) * i);
                        var shark_spray = SharkSprayScene.instantiate();
                        get_parent().add_child(shark_spray);
                        shark_spray.global_position = position;
                        shark_spray.velocity = target_direction * constants.PLAYER_FIRE_SPEED;
                        
                        if fish_frenzy_colour == 'BLUE':
                            fish_frenzy_colour = 'GREEN'
                        else:
                            shark_spray.modulate = Color(0,1,0) 
                            fish_frenzy_colour = 'BLUE'
                            
                        $AudioStreamPlayerSpray.play()
                        i+=1
                                 
        EXPLODING:
            if $PlayerExplosionTimer.time_left == 0:
                emit_signal('player_died');
                shark_status = EXPLODED;
        HUNTING_KEY:
            if velocity.x > 0:
                $AnimatedSprite2D.set_flip_h(true);
            
            if velocity.x < 0:
                $AnimatedSprite2D.set_flip_h(false);
              
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                
                if collision.get_collider().name == 'Key':  
                    shark_status = HUNTING_EXIT;
                    var target_direction = (get_parent().get_node('Arena').get_node('ExitDoor').global_position - global_position).normalized();
                    velocity = target_direction * constants.PLAYER_SPEED_ESCAPING;
                    get_parent().get_node('Arena').get_node('ExitDoor').get_node('CollisionShape2D').disabled = false;
                    emit_signal('player_got_key')
        HUNTING_EXIT:
            if velocity.x > 0:
                $AnimatedSprite2D.set_flip_h(true);
            
            if velocity.x < 0:
                $AnimatedSprite2D.set_flip_h(false);
              
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                
                if collision.get_collider().name == 'ExitDoor':  
                    shark_status = FOUND_EXIT;
                    velocity = Vector2i(0,0)
                    
                    # Open door.
                    get_parent().get_node('Arena').set_cell(
                        2,
                        Vector2(31,2),
                        -1,
                        Vector2i(9,7))
                    
                    get_parent().get_node('Arena').set_cell(
                        2,
                        Vector2(32,2),
                        -1,
                        Vector2i(9,7))
                    
                    get_parent().get_node('Arena').get_node('ExitDoor').get_node('CollisionShape2D').disabled = true;
                    
                    emit_signal('player_found_exit_stop_key_movement');
                    shark_status=GOING_THROUGH_DOOR;
                   
                    $DoorOpenTimer.start()            
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
                            get_parent().get_node('Arena').set_cell(
                                2,
                                Vector2(31,33),
                                0,
                                Vector2i(6,6))
                            
                            get_parent().get_node('Arena').set_cell(
                                2,
                                Vector2(32,33),
                                0,
                                Vector2i(7,6))
            
                for i in get_slide_collision_count():
                    var collision = get_slide_collision(i)
                     
                    if collision.get_collider().name == 'PlayerStartLocation':  
                        shark_status = ALIVE
                        get_parent().get_node('Arena').get_node('PlayerStartLocation').get_node('CollisionShape2D').disabled = true;
                                
func _player_hit():
    
    if shark_status != ALIVE:
        return
    
    if $PlayerHitGracePeriodTimer.time_left == 0:
    
        $PlayerHitGracePeriodTimer.start();
        $AudioStreamPlayerHit.play();
        
        var damage_reduction_percentage = upgrades['ARMOUR'][0] * constants.ARMOUR_DAMAGE_REDUCTION_PERCENTAGE
        var damage_to_perform = constants.PLAYER_HIT_BY_ENEMY_DAMAGE - (( damage_reduction_percentage / 100.0) * constants.PLAYER_HIT_BY_ENEMY_DAMAGE)
        
        print ("_player_hit() Reduct percentage = " + str(damage_reduction_percentage))
        print ("_player_hit() Damage to perform = " + str(damage_to_perform))
        
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
    
    shark_status = HUNTING_KEY
    key_global_position = passed_key_global_position;
    var target_direction = (key_global_position - global_position).normalized();
    velocity = target_direction * constants.PLAYER_SPEED_ESCAPING;

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
    tween.tween_callback(new_label.queue_free).set_delay(3)
    
func set_fire_rate_delay_timer():
    $FireRateTimer.start(fire_delay)    
        
func mini_shark_fire(shark_fire_direction):
    for mini_shark in get_tree().get_nodes_in_group("miniSharkGroup"):
        var mini_shark_spray = SharkSprayScene.instantiate()
        get_parent().add_child(mini_shark_spray)
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
            
            match powerup:
                'SPEEDUP':
                    var value = get_parent().get_node('HUD/CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar').value
                    if value:    
                        value -= 1
                        get_parent().get_node('HUD/CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar').value = value
                    
                        if value <= 0:
                            decrease_powerup_level(powerup)
                            speed = constants.PLAYER_SPEED + (constants.PLAYER_SPEED_POWERUP_INCREASE * current_powerup_levels[powerup])
                'FAST SPRAY':
                    var value = get_parent().get_node('HUD/CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar').value
                    
                    if value:
                        value -= 1
                        get_parent().get_node('HUD/CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar').value = value
                        
                        if value <= 0:
                            decrease_powerup_level(powerup)
                            fire_delay = constants.PLAYER_FIRE_DELAY - (constants.PLAYER_FIRE_DELAY_POWERUP_DECREASE * current_powerup_levels[powerup])  
                'BIG SPRAY':
                    var value = get_parent().get_node('HUD/CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar').value
                    
                    if value:
                        value -= 1
                        get_parent().get_node('HUD/CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar').value = value
                        
                        if value <= 0:
                            decrease_powerup_level(powerup)
                            spray_size = 0.5 + (constants.PLAYER_FIRE_SIZE_POWERUP_INCREASE * current_powerup_levels[powerup])            
                'MINI SHARK':
                    var value = get_parent().get_node('HUD/CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar').value
                    if value:
                        
                        value -= 1
                        get_parent().get_node('HUD/CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar').value = value
                        
                        if value <= 0:
                            decrease_powerup_level(powerup)
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
    print("PRESSED STAGE 2: " + str(button_number))
    
    # TODO: Handle the upgrade.
    
    var selected_upgrade
    if button_number == 1:
        selected_upgrade = get_parent().upgrade_one_index
    else:
        selected_upgrade = get_parent().upgrade_two_index

    print("Selected upgrade = " + str(selected_upgrade))
    
    $AudioStreamPlayerSelectedUpgrade.play()
    
    # Mark upgrade as in use by increasing its level.
    # Ensure level does not exceed the maximum allowed.
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
            print("Fish needed now: " + str(fish_needed))
        'MORE POWER':
            get_parent().get_node('HUD').reset_powerup_bar_durations()
    
    get_parent().get_node('HUD').update_upgrade_summary()
    
    # Go to next wave.
    emit_signal('player_made_upgrade_choice')

