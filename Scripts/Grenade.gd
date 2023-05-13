extends CharacterBody2D

enum {
    THROWING,
    EXPLODING
}

var state = 'THROWING'

func _ready():
    state = THROWING
    
    $AnimatedSprite2DExplosion.visible = false
    $CollisionShape2DExplosion.disabled = true
    $AnimatedSprite2D.play()
    
    # Up in the air... and down again...
    # TODO: Bake some of these into constants where appropriate.
    var tween = get_tree().create_tween()
    tween.tween_property(self, "scale", Vector2(10,10), 0.25)
    tween.tween_property(self, "scale", Vector2(10,10), 0.10)
    tween.tween_property(self, "scale", Vector2(2,2), 0.25)

    $GrenadeFuseTimer.start()

func _physics_process(_delta):
    move_and_slide()
    
    match state:
        THROWING:
            if $GrenadeFuseTimer.time_left == 0:
                state=EXPLODING
                velocity=Vector2(0,0)
                set_collision_mask_value(3, true)       # Allow enemy damage.
                $CollisionShape2D.disabled = true
                $CollisionShape2DExplosion.disabled = false
                $AnimatedSprite2D.visible = false
                $AnimatedSprite2DExplosion.visible = true
                $AnimatedSprite2DExplosion.play()
                $AudioStreamPlayerExplosion.play()
                $GrenadeExplosionTimer.start()
        EXPLODING:
            if $GrenadeExplosionTimer.time_left == 0:
                queue_free()
            
            # Has explosion caught an enemy?
            # Note: Once damage has occured, disable.
            
            for i in get_slide_collision_count():
                var collision = get_slide_collision(i)
                
                if collision.get_collider().name == 'Arena':
                    self.queue_free()
                    break;
                    
                if collision.get_collider().name == 'ExitDoor':
                    self.queue_free()
                    break;
                
                collision.get_collider().get_node('.')._death('PLAYER-SHOT');
