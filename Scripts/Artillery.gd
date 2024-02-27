extends CharacterBody2D

enum {
    CHASING,
    EXPLODING,
    SAFE
}

var state

func _ready():
    $Sprite2D.set_modulate(Color(0,0,0,0))
    var tween = get_tree().create_tween()
    tween.tween_property($Sprite2D, "modulate", Color(1,0,0,1), constants.ARTILLERY_WARNING_TIME)
    
    $StateTimer.connect('timeout', _on_artillery_timeout)
    $StateTimer.start(constants.ARTILLERY_WARNING_TIME)
    
    $Area2D.connect('body_entered', _on_body_entered)
    
    state = CHASING
    
func _physics_process(_delta):
    match state:
        CHASING:
            # Chase the player.
            var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
          
            # TODO: Adjust speed here.
            position += target_direction * constants.ARTILLERY_CHASE_SPEED
        EXPLODING:
            get_parent().get_node('Player').shake(10)
            
func _on_artillery_timeout():
    match state:
        CHASING:
            state = EXPLODING
            velocity = Vector2(0,0)
            $Sprite2D.visible = false
            $AnimatedSprite2D.visible = true
            $AnimatedSprite2D.play()
            
            $Area2D.set_monitoring(true)
            $ArtillerySound.play()
            
            $StateTimer.start(0.5)
        EXPLODING:
            # After one second, the explosion is 'safe'.
            state = SAFE

            $Area2D.set_monitoring(false)
            get_parent().get_node('Player').shake_reset()
            
            $StateTimer.start(2)
        SAFE:
            queue_free()
            
func _on_body_entered(_body):
    # The masking means it must be the player that is inside us.
    get_parent().get_node('Player')._player_hit()
