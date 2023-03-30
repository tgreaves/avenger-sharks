extends CharacterBody2D

enum {
    IDLE,
    INTRO_SWIM_TO_NECROMANCER
}

var state = IDLE

func _physics_process(delta):
    if state == INTRO_SWIM_TO_NECROMANCER:
        
        move_and_slide()
        
        var target_position = get_parent().get_node('Necromancer').get_node('NecroSprite').global_position
        var target_direction = (target_position - global_position).normalized()
        velocity = target_direction * 200
                
        var _collision = move_and_collide(velocity * delta)

func swim_to_necromancer():
    state = INTRO_SWIM_TO_NECROMANCER
