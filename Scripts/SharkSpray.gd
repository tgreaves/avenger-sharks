extends CharacterBody2D

func _ready():
    $AnimatedSprite2D.play();
    if get_parent().get_node('Player').spray_size:
        set_global_scale(Vector2(   get_parent().get_node('Player').spray_size,
                                    get_parent().get_node('Player').spray_size))
        
        
func _physics_process(_delta):
    move_and_slide()
    
    for i in get_slide_collision_count():
        var collision = get_slide_collision(i)
        
        if collision.get_collider().name == 'Arena':
            self.queue_free()
            break;
            
        if collision.get_collider().name == 'ExitDoor':
            self.queue_free()
            break;
        
        collision.get_collider().get_node('.')._death('PLAYER-SHOT');
        $CollisionShape2D.disabled = true;
        self.queue_free()
