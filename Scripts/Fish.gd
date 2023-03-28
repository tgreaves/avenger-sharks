extends CharacterBody2D

enum {
    ACTIVE,
    DESPAWNING,
    INTRO_WANDER
}

var state = ACTIVE;
var fish_speed;

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
    
    $StateTimer.start(1)
