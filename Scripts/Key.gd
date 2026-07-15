extends CharacterBody2D

enum { IDLE, FOLLOWING_PLAYER }

var state = IDLE
var holder = null


func _ready():
	state = IDLE


func _physics_process(_delta):
	match state:
		IDLE:
			velocity = Vector2i(0, 0)
		FOLLOWING_PLAYER:
			if is_instance_valid(holder):
				global_position = holder.global_position + Vector2(0, 50)


# Stick the key to the shark that grabbed it and follow it to the exit.
func start_following(new_holder):
	holder = new_holder
	$CollisionShape2D.disabled = true
	state = FOLLOWING_PLAYER


func _on_player_player_found_exit_stop_key_movement():
	state = IDLE
	holder = null
	visible = false
