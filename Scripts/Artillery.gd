extends CharacterBody2D

enum { CHASING, EXPLODING, SAFE }

var state
var shaken_player  # Player whose camera we shook, so we reset the same one.


func _ready():
	$Sprite2D.set_modulate(Color(0, 0, 0, 0))
	var tween = get_tree().create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(1, 0, 0, 1), constants.ARTILLERY_WARNING_TIME)

	$ChargingTimer.connect("timeout", _on_charging_timer_timeout)
	$FlashingTimer.connect("timeout", _on_flashing_timer_timeout)
	$ChargingTimer.start(constants.ARTILLERY_WARNING_TIME)
	$FlashingTimer.start(constants.ARTILLERY_WARNING_TIME - 1.0)

	$Area2D.connect("body_entered", _on_body_entered)

	state = CHASING


func _physics_process(_delta):
	match state:
		CHASING:
			# Chase the nearest player.
			var target_direction = (
				(get_parent().get_nearest_player(global_position).global_position - global_position).normalized()
			)
			position += target_direction * constants.ARTILLERY_CHASE_SPEED
		EXPLODING:
			shaken_player = get_parent().get_nearest_player(global_position)
			shaken_player.shake(10)


func _on_charging_timer_timeout():
	match state:
		CHASING:
			state = EXPLODING
			velocity = Vector2(0, 0)
			$Sprite2D.visible = false
			$FlashingTimer.stop()
			$AnimatedSprite2D.visible = true
			$AnimatedSprite2D.play()

			$Area2D.set_monitoring(true)
			$ArtillerySound.play()

			$ChargingTimer.start(0.5)
		EXPLODING:
			# After one second, the explosion is 'safe'.
			state = SAFE

			$Area2D.set_monitoring(false)
			if shaken_player:
				shaken_player.shake_reset()

			$ChargingTimer.start(2)
		SAFE:
			queue_free()


func _on_flashing_timer_timeout():
	if $Sprite2D.is_visible():
		$Sprite2D.set_visible(false)
	else:
		$Sprite2D.set_visible(true)

	$FlashingTimer.start(0.1)


func _on_body_entered(body):
	# The masking means it must be a player that is inside us.
	body.player_hit()
