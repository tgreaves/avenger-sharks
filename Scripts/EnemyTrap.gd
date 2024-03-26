extends CharacterBody2D

enum { ACTIVE, DYING }

var trap_health = 0

var state = ACTIVE


func _ready():
	$AnimatedSprite2DDeath.visible = false
	$AnimatedSprite2D.play()

	trap_health = constants.ENEMY_TRAP_HEALTH


func _physics_process(_delta):
	move_and_slide()

	if $FlashHitTimer.time_left == 0:
		set_modulate(Color(1, 1, 1, 1))

	match state:
		ACTIVE:
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)

				if collision.get_collider().name == "Arena":
					self.queue_free()
					break

				collision.get_collider().get_node(".").player_hit()

				$CollisionShape2D.disabled = true
				self.queue_free()
				break

		DYING:
			if $StateTimer.time_left == 0:
				self.queue_free()


func death(_death_source):
	if state != DYING:
		trap_health = trap_health - 1

		set_modulate(Color(10, 10, 10, 10))
		$FlashHitTimer.start()

		if trap_health <= 0:
			$CollisionShape2D.set_deferred("disabled", true)
			$AudioStreamPlayer.play()
			$AnimatedSprite2D.stop()
			$AnimatedSprite2D.visible = false
			$AnimatedSprite2DDeath.visible = true
			$AnimatedSprite2DDeath.play()
			state = DYING

			$StateTimer.start(0.75)
		else:
			set_modulate(Color(10, 10, 10, 10))
			$FlashHitTimer.start()
