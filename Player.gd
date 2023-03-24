extends CharacterBody2D

const SharkSprayScene = preload("res://SharkSpray.tscn");

enum {
    ALIVE,
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
signal player_died;
signal player_got_fish;
signal player_got_key;
signal player_found_exit_stop_key_movement;
signal player_found_exit;
@onready var screen_size = get_viewport_rect().size

var key_global_position;
var initial_player_position;

func _ready():
    shark_status = ALIVE;
    
    if initial_player_position:
        global_position = initial_player_position
    else:
        initial_player_position = global_position

    $AnimatedSprite2DDamaged.visible = false;
    $FireRateTimer.start(constants.PLAYER_FIRE_DELAY);

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
            $AudioStreamPlayerSpray.play()
            $FireRateTimer.start(constants.PLAYER_FIRE_DELAY);
            
        if Input.is_action_pressed('shark_fire_mouse'):
            var shark_spray = SharkSprayScene.instantiate();
            get_parent().add_child(shark_spray);
            var target_direction = (get_global_mouse_position() - global_position).normalized()
            shark_spray.global_position = position;
            shark_spray.velocity = target_direction * constants.PLAYER_FIRE_SPEED
            $AudioStreamPlayerSpray.play()
            $FireRateTimer.start(constants.PLAYER_FIRE_DELAY);
            
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
            $AudioStreamPlayerSpray.play()
            $FireRateTimer.start(constants.PLAYER_FIRE_DELAY);
    
func _physics_process(_delta):
    get_input()
    move_and_slide()
    
    if $PowerUpTimer.time_left == 0:
        if big_spray:
            big_spray=0;
            
    match shark_status:
        ALIVE:
            if velocity.x > 0:
                $AnimatedSprite2D.set_flip_h(true);
            
            if velocity.x < 0:
                $AnimatedSprite2D.set_flip_h(false);
                
            $AnimatedSprite2D.play();
            
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                print("PLAYER collided with ", collision.get_collider().name + " // " + collision.get_collider().get_class())
                
                var collided_with = collision.get_collider();
                
                if collision.get_collider().name == 'Arena':
                    print("RID: " + str(collision.get_collider_rid()));
                    var rid_coords = collided_with.get_coords_for_body_rid( collision.get_collider_rid());
                    print("Coords: " + str(collided_with.get_coords_for_body_rid( collision.get_collider_rid())));
                    print ("ATLAS Trans: " + str(collided_with.get_cell_atlas_coords(1, rid_coords)));
                    
                    match collided_with.get_cell_atlas_coords(1, rid_coords):
                        Vector2i(9,8):
                            print ("HEATH");
                            player_energy = player_energy + constants.HEALTH_POTION_BONUS;
                            if player_energy > constants.PLAYER_START_GAME_ENERGY:
                                player_energy = constants.PLAYER_START_GAME_ENERGY;
                            $AudioStreamHealth.play();
                            emit_signal('update_energy')
                            
                            collided_with.set_cell(		1, 
                                            collided_with.get_coords_for_body_rid( collision.get_collider_rid()),
                                                       -1);
                            
                        Vector2i(7,9):
                            print ("POWERUP");
                            big_spray=1;
                            $PowerUpTimer.start(constants.POWER_UP_ACTIVE_DURATION);
                            $AudioStreamPowerUp.play()
                    
                            collided_with.set_cell(		1, 
                                                       collided_with.get_coords_for_body_rid( collision.get_collider_rid()),
                                                       -1);
                    
                    break;
                    
                if collision.get_collider().name.contains('Fish'):
                    collided_with.get_node('.')._death(0);
                    $AudioStreamPlayerGotFish.play();
                    emit_signal('player_got_fish');
                    break
                
                if collision.get_collider().name.contains('Dinosaur'):
                    collided_with.get_node('.')._go_on_a_rampage();
                    break
                
                # Default - Enemy	
                collided_with.get_node('.')._death();
                _player_hit();
                
            #position.x = clamp(position.x, 0, screen_size.x)
            #position.y = clamp(position.y, 0, screen_size.y)
        EXPLODING:
            if $PlayerExplosionTimer.time_left == 0:
                emit_signal('player_died');
                print("Death signal");
                shark_status = EXPLODED;
        HUNTING_KEY:
            if velocity.x > 0:
                $AnimatedSprite2D.set_flip_h(true);
            
            if velocity.x < 0:
                $AnimatedSprite2D.set_flip_h(false);
              
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                print("PLAYER collided with ", collision.get_collider().name + " // " + collision.get_collider().get_class())
                
                var collided_with = collision.get_collider();
                
                if collision.get_collider().name == 'Key':  
                    print("KEY FOUND");
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
                #print("PLAYER collided with ", collision.get_collider().name + " // " + collision.get_collider().get_class())
                
                var collided_with = collision.get_collider();
                
                # TODO: Wait for player to explicitly hit ExitDoor as a first step.
                # Then clear door tiles
                # Then head further outside of the room before final signal?
                
                if collision.get_collider().name == 'ExitDoor':  
                    print("EXIT FOUND at " + str(global_position));
                    shark_status = FOUND_EXIT;
                    velocity = Vector2i(0,0)
                   # $AudioStreamPlayerDoorOpen.play()
                    
                    # Open door.
                    get_parent().get_node('Arena').set_cell(
                        1,
                        Vector2(31,2),
                        -1,
                        Vector2i(9,7))
                    
                    get_parent().get_node('Arena').set_cell(
                        1,
                        Vector2(32,2),
                        -1,
                        Vector2i(9,7))
                    
                    get_parent().get_node('Arena').get_node('ExitDoor').get_node('CollisionShape2D').disabled = true;
                    
                    emit_signal('player_found_exit_stop_key_movement');
                    shark_status=GOING_THROUGH_DOOR;
                   
                    $DoorOpenTimer.start()            
        GOING_THROUGH_DOOR:
                print ("Going through door..");
                if $DoorOpenTimer.time_left == 0:
                    print("Timer done!");
                    var target_direction = (get_parent().get_node('Arena').get_node('ExitLocation').global_position - global_position).normalized();
                    velocity = target_direction * constants.PLAYER_SPEED_ESCAPING;            
                     
                for i in get_slide_collision_count():
                    var collision = get_slide_collision(i)
                    print("PLAYER collided with ", collision.get_collider().name + " // " + collision.get_collider().get_class())
                    
                    var collided_with = collision.get_collider();
                
                    if collision.get_collider().name == 'ExitLocation':  
                        emit_signal('player_found_exit');  
        MOVING_TO_START_POSITION:
                if $DoorCloseTimer.time_left == 0:
                        # Close bottom door.
                            get_parent().get_node('Arena').set_cell(
                                1,
                                Vector2(31,33),
                                0,
                                Vector2i(6,6))
                            
                            get_parent().get_node('Arena').set_cell(
                                1,
                                Vector2(32,33),
                                0,
                                Vector2i(7,6))
            
                for i in get_slide_collision_count():
                    var collision = get_slide_collision(i)
                    print("PLAYER collided with ", collision.get_collider().name + " // " + collision.get_collider().get_class())
                    
                    var collided_with = collision.get_collider();
                     
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


func _on_main_player_move_to_starting_position():
    shark_status = MOVING_TO_START_POSITION
    
    set_process(true);
    set_physics_process(true);
    visible = true
    
    get_parent().get_node('Arena').get_node('PlayerStartLocation').get_node('CollisionShape2D').disabled = false;
    
    var target_direction = (initial_player_position - global_position).normalized();
    velocity = target_direction * constants.PLAYER_SPEED
    
    $DoorCloseTimer.start()

