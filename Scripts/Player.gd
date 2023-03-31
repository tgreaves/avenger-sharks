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
@export var big_spray = 0;

signal update_energy;
signal update_fish;
signal player_died;
signal player_got_fish;
signal player_got_key;
signal player_found_exit_stop_key_movement;
signal player_found_exit;
@onready var screen_size = get_viewport_rect().size

var key_global_position;
var initial_player_position;
var fast_spray = false
var fish_frenzy_enabled = false
var fish_frenzy_colour

func _ready():
    shark_status = ALIVE;
    
    if initial_player_position:
        global_position = initial_player_position
    else:
        initial_player_position = global_position

    $AnimatedSprite2DDamaged.visible = false;
    set_fire_rate_delay_timer();

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
            get_parent().fish_collected = 0
            emit_signal('update_fish')
            shark_status=FISH_FRENZY
            fish_frenzy_colour = 'BLUE'
            velocity = Vector2(0,0)
            $FishFrenzyTimer.start(constants.PLAYER_FISH_FRENZY_DURATION)
            $FishFrenzyFireTimer.start(constants.PLAYER_FISH_FRENZY_FIRE_DELAY)
    
func _physics_process(_delta):
    get_input()
    move_and_slide()
    
    if $BigSprayTimer.time_left == 0:
        if big_spray:
            big_spray=0;
       
    if $FastSprayTimer.time_left == 0:
        if fast_spray:
            fast_spray=false
         
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
                            player_energy = player_energy + constants.HEALTH_POTION_BONUS;
                            if get_parent().cheat_mode:
                                if player_energy > constants.PLAYER_START_GAME_ENERGY_CHEATING:
                                    player_energy = constants.PLAYER_START_GAME_ENERGY_CHEATING
                            else:
                                if player_energy > constants.PLAYER_START_GAME_ENERGY:
                                    player_energy = constants.PLAYER_START_GAME_ENERGY;
                                    
                            $AudioStreamHealth.play();
                            powerup_label_animation('HEALTH!')
                            emit_signal('update_energy')
                            collided_with.get_node('.').despawn()
                            
                        "chest":
                            var powerup_selection = randi_range(1,3)
                            
                            match powerup_selection:
                                1:
                                    big_spray=1;
                                    $BigSprayTimer.start(constants.POWER_UP_ACTIVE_DURATION);
                                    powerup_label_animation('BIG SPRAY!')
                                2:
                                    fast_spray=true
                                    $FastSprayTimer.start(constants.POWER_UP_ACTIVE_DURATION);
                                    powerup_label_animation('FAST SPRAY!')
                                3:
                                    if get_tree().get_nodes_in_group('miniSharkGroup').size() < 8:
                                            
                                        var new_mini_shark = MiniSharkScene.instantiate()
                                        add_child(new_mini_shark)
                                        new_mini_shark.add_to_group('miniSharkGroup')
                                    
                                        # Reset circular position of the mini sharks when we spawn a new one, to ensure
                                        # everything stays evenly spaced.
                                        recalculate_mini_shark_spacing()
                                     
                                    powerup_label_animation('MINI SHARK!')
                                    
                            $AudioStreamPowerUp.play()
                        
                    collided_with.get_node('.').despawn()
                
                    break
                
                # Default - Enemy	
                collided_with.get_node('.')._death();
                _player_hit();
               
        FISH_FRENZY:
            if $FishFrenzyTimer.time_left == 0:
                rotation_degrees = 0
                shake_reset()
                shark_status = ALIVE               
            else:
                shake(10.0)
                rotation_degrees += 20
                if rotation_degrees >= 360:
                    rotation_degrees = 0
                
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
    if $PlayerHitGracePeriodTimer.time_left == 0:
    
        $PlayerHitGracePeriodTimer.start();
        $AudioStreamPlayerHit.play();
        player_energy = player_energy - constants.PLAYER_HIT_BY_ENEMY_DAMAGE;
        
        if player_energy <= 0:
            player_energy = 0;
            $CollisionShape2D.set_deferred("disabled", true)
            velocity = Vector2(0,0);
            $AnimatedSprite2D.animation = 'explosion';
            $AudioStreamPlayerExplosion.play();
            shark_status=EXPLODING;
            $PlayerExplosionTimer.start();
        else:
            $AnimatedSprite2DDamaged.visible = true;
            $AnimatedSprite2DDamaged.play();
        
        emit_signal('update_energy');

func _on_main_player_hunt_key(passed_key_global_position):
    shark_status = HUNTING_KEY
    key_global_position = passed_key_global_position;
    var target_direction = (key_global_position - global_position).normalized();
    velocity = target_direction * constants.PLAYER_SPEED_ESCAPING;
    rotation_degrees = 0        # In case we are in shark frenzy


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
    
    var tween = get_tree().create_tween()
    tween.set_parallel()
    tween.tween_property(new_label, "modulate", Color(0,0,0,0), 2)
    tween.tween_property(new_label, "position", Vector2(-116,-150), 2)
    tween.tween_callback(new_label.queue_free).set_delay(3)
    
func set_fire_rate_delay_timer():
    if fast_spray:
        $FireRateTimer.start(constants.PLAYER_FIRE_DELAY / 2)
    else:
        $FireRateTimer.start(constants.PLAYER_FIRE_DELAY)
        
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
