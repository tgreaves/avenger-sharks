extends CharacterBody2D

enum {
    ACTIVE,
    DESPAWNING,
    INTRO_WANDER,
    INTRO_SWIM_TO_NECROMANCER,
    INTRO_AT_NECROMANCER
}

var state = ACTIVE;
var fish_speed;
var intro_fish_id;

func _ready():
    var animation_options = $AnimatedSprite2D.sprite_frames.get_animation_names().size();
    var rng = RandomNumberGenerator.new()
    var index = rng.randi_range(0, animation_options-1);
    
    var animation_name = $AnimatedSprite2D.sprite_frames.get_animation_names()[index];
    
    $AnimatedSprite2D.play(animation_name)

func _physics_process(delta):
    match state:
        ACTIVE:
            move_and_slide()
            
            var distance = position.distance_to( get_parent().get_node('Player').position )
            
            if get_parent().get_node('Player').item_magnet_enabled:
                if distance < 250:
                    var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                    velocity = target_direction * ( get_parent().get_node("Player").speed + 200 )
            
        DESPAWNING:
            if $StateTimer.time_left == 0:
                queue_free();  
        INTRO_WANDER:
            if velocity.x > 0:
                $AnimatedSprite2D.set_flip_h(false);
    
            if velocity.x < 0:
                $AnimatedSprite2D.set_flip_h(true);	
            
            var collision = move_and_collide(velocity * delta);
            if $StateTimer.time_left == 0:
                $StateTimer.start(randf_range(constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MINIMUM_SECONDS,
                                            constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MAXIMUM_SECONDS));
                velocity = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * fish_speed
                
            if collision:
                 velocity = velocity.bounce(collision.get_normal());
                
        INTRO_SWIM_TO_NECROMANCER:
            # We want to end up in an evenly spaced circle around the necromancer.
            var angle_step_degrees = 360.0 / get_tree().get_nodes_in_group('fishGroup').size()
            var target_angle_degrees = intro_fish_id * angle_step_degrees
            var angle = deg_to_rad(target_angle_degrees)
            var offset = Vector2(sin(angle), cos(angle)) * 200;   # 100 = Radius
            var target_position = get_parent().get_node('Necromancer').get_node('NecroSprite').global_position + offset
            
            # Forcibly stop when 'close enough' to target to prevent jitter.
            if global_position.distance_to(target_position) < 2:
                #state = INTRO_SWIM_TO_NECROMANCER
                return
            
            var target_direction = (target_position - global_position).normalized()
            velocity = target_direction * 200
            
            var _collision = move_and_collide(velocity * delta)
        
        INTRO_AT_NECROMANCER:
            set_collision_mask_value(1,false)
            pass

func _death(blood):
    $CollisionShape2D.set_deferred("disabled", true)
    $AnimatedSprite2D.hide();
    remove_from_group('fishGroup');
    
    if blood:
        $AnimatedSprite2DDamaged.play();
        state = DESPAWNING;
        $StateTimer.start(1)
    else:
        queue_free()
        
func set_intro_mode():
    state = INTRO_WANDER
    fish_speed = randi_range(50,250)
    z_index = 1
    
    $StateTimer.start(0)

func swim_to_necromancer(passed_fish_id):
    state = INTRO_SWIM_TO_NECROMANCER
    intro_fish_id = passed_fish_id
    $CollisionShape2D.disabled = true
    
