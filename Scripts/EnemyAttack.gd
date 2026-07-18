extends CharacterBody2D

@export var enemy_attack_speed = 500

# Degrees per second the velocity rotates in flight. 0 = straight line (default);
# non-zero makes the projectile curve (used by boss spiral attacks).
var curve_rate := 0.0
# Per-second decay applied to curve_rate. A constant curve rate traces a full
# circle (bullets loop back); decaying it toward 0 makes the shot curve at first
# then straighten, so it spirals OUTWARD and flies off to the arena edge.
var curve_decay := 0.0


func _ready():
	$AnimatedSprite2D.play()


func _physics_process(delta):
	if curve_rate != 0.0:
		velocity = velocity.rotated(deg_to_rad(curve_rate) * delta)
		if curve_decay > 0.0:
			curve_rate = move_toward(curve_rate, 0.0, curve_decay * delta)

	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)

		if collision.get_collider() is TileMapLayer:
			self.queue_free()
			break

		if collision.get_collider().name == "ExitDoor":
			self.queue_free()
			break

		# Only damage things that can be hurt (players). Other bodies on the shared
		# collision layer — ExitLocation, start markers, boss-room walls/doors —
		# just stop the projectile.
		var collider = collision.get_collider()
		if collider.has_method("player_hit"):
			collider.player_hit()

		$CollisionShape2D.disabled = true
		self.queue_free()
		break
