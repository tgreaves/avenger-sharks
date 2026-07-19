extends Node2D

# One-shot explosion effect: plays the shared "explosion" animation once (the same
# frames as a player's death explosion) and then frees itself. Visual only — no
# sound. The spawner sets position and scale (e.g. a homing seeker's mini-explode).


func _ready():
	$AnimatedSprite2D.animation_finished.connect(queue_free)
	$AnimatedSprite2D.play("explosion")
