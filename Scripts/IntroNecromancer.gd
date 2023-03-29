extends CharacterBody2D


const SPEED = 100.0
const JUMP_VELOCITY = -400.0

func _physics_process(_delta):
    move_and_slide()
