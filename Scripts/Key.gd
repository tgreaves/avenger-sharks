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
            global_position = get_parent().get_node("Player").global_position + Vector2(0,50)


func _on_player_player_got_key():
    $CollisionShape2D.disabled = true
    state = FOLLOWING_PLAYER
    
func _on_player_player_found_exit_stop_key_movement():
   state = IDLE;
   visible = false;
    
