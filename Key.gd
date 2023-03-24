extends CharacterBody2D

enum {
    IDLE,
    FOLLOWING_PLAYER
}

var state = IDLE;

func _ready():
   state = IDLE;

func _physics_process(_delta):
    match state:
        IDLE:
            velocity = Vector2i(0,0);
        FOLLOWING_PLAYER:
            move_and_slide()
            var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
            velocity = target_direction * (constants.PLAYER_SPEED_ESCAPING);


func _on_player_player_got_key():
    print("Signal OK player got key")
    $CollisionShape2D.disabled = true
    state = FOLLOWING_PLAYER
    
func _on_player_player_found_exit_stop_key_movement():
   state = IDLE;
   visible = false;
    
