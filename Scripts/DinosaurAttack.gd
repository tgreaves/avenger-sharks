extends CharacterBody2D

func _ready():
    $AnimatedSprite2D.play();
        
func _physics_process(_delta):
    move_and_slide()
    
    for i in get_slide_collision_count():
        var collision = get_slide_collision(i)
        
        if collision.get_collider().name == 'Arena':
            self.queue_free()
            break;
            
        if collision.get_collider().name == 'ExitDoor':
            self.queue_free()
            break    
            
        if collision.get_collider().name == 'ExitLocation':
            self.queue_free()
            break      
        
        if collision.get_collider().name == 'PlayerStartLocation':
            break 
            
        collision.get_collider().get_node('.')._death('DINOSAUR');
        $CollisionShape2D.disabled = true;
        self.queue_free()
