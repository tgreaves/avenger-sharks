extends CharacterBody2D

# The player that fired this spray, for score attribution. Set by the spawner.
var owner_player = null


func _ready():
	$AnimatedSprite2D.play()
	# Size from the shark that fired this spray (its own BIG SPRAY level), not a
	# shared "primary" player. owner_player is set by the spawner before add_child,
	# so it is available here; fall back to the primary player if unset.
	var player = owner_player if owner_player != null else get_parent().get_primary_player()
	if player.spray_size:
		set_global_scale(
			Vector2(
				player.spray_size,
				player.spray_size
			)
		)


func _physics_process(_delta):
	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)

		if collision.get_collider() is TileMapLayer:
			self.queue_free()
			break

		if collision.get_collider().name == "ExitDoor":
			self.queue_free()
			break

		if collision.get_collider().name.contains("Artillery"):
			self.queue_free()
			break

		# Only damage things that can take damage (enemies / boss). Other bodies on
		# the shared collision layer — ExitLocation, start markers, boss-room exit
		# door — just stop the spray.
		var collider = collision.get_collider()
		if collider.has_method("death"):
			collider.death("PLAYER-SHOT", owner_player)
		$CollisionShape2D.disabled = true
		self.queue_free()
