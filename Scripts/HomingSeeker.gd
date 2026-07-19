extends CharacterBody2D

# A homing "seeker" boss projectile: a colourful missile that curves toward the
# nearest shark at a CAPPED turn rate (so juking dodges it). ANY death triggers its
# mini-explosion — timing out, ramming a shark, hitting a wall, or being shot down —
# playing the explosion animation and bursting into a small ring of shots. Two
# things set it apart from the round fireball (EnemyAttack):
#   * Distinct missile sprite, rotated to face travel, so players read it at a glance.
#   * SHOOTABLE — it rides the enemy collision layer (bit 3) and exposes death(), so
#     a shark's spray destroys it (but it still bursts, so shoot it from a distance).
# Lives in the "enemyAttack" group so the existing wave-end / game-end sweeps free it
# (those queue_free it directly, bypassing the explosion — no burst at wave end).

const EnemyAttackScene = preload("res://Scenes/EnemyAttack.tscn")
const ExplosionScene = preload("res://Scenes/Explosion.tscn")

# The missile art points UP (-Y); offset its rotation so it faces its velocity.
const SPRITE_ANGLE_OFFSET = PI / 2

var _life_remaining := 0.0
var _exploded := false   # Guard so a death can only fire the mini-explosion once.


func _ready():
	_life_remaining = constants.BOSS_SEEKER_LIFESPAN


func _physics_process(delta):
	# Home: steer velocity toward the nearest shark, but only by up to
	# BOSS_SEEKER_TURN_RATE per second so a sharp juke can shake it.
	var target = get_parent().get_nearest_player(global_position)
	if target != null:
		var desired = (target.global_position - global_position).angle()
		var current = velocity.angle()
		var max_step = deg_to_rad(constants.BOSS_SEEKER_TURN_RATE) * delta
		var new_angle = current + clamp(wrapf(desired - current, -PI, PI), -max_step, max_step)
		velocity = Vector2.RIGHT.rotated(new_angle) * constants.BOSS_SEEKER_SPEED

	# Point the missile where it's going.
	$Sprite2D.rotation = velocity.angle() + SPRITE_ANGLE_OFFSET

	# Lifespan: on timeout, pop into a small ring burst and despawn.
	_life_remaining -= delta
	if _life_remaining <= 0.0:
		_mini_explode()
		return

	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		# Damage a shark we rammed (other bodies — walls, doors, markers — just stop
		# us). Either way, any contact destroys the seeker with its mini-explosion.
		if collider.has_method("player_hit"):
			collider.player_hit()
		_mini_explode()
		return


# Any death (timeout, ramming a shark, a wall, or being shot) plays the explosion
# animation and bursts into a small ring of ordinary (non-homing) projectiles.
# Guarded so it only fires once.
func _mini_explode():
	if _exploded:
		return
	_exploded = true
	$CollisionShape2D.set_deferred("disabled", true)

	# Visual: the shared player-death explosion animation, sized down for the missile.
	var boom = ExplosionScene.instantiate()
	get_parent().add_child(boom)
	boom.global_position = global_position
	boom.scale = Vector2.ONE * constants.BOSS_SEEKER_EXPLOSION_SCALE

	var count = constants.BOSS_SEEKER_EXPLODE_COUNT
	for i in range(count):
		var attack = EnemyAttackScene.instantiate()
		get_parent().add_child(attack)
		attack.add_to_group("enemyAttack")
		attack.global_position = global_position
		attack.velocity = (
			Vector2.RIGHT.rotated(deg_to_rad((360.0 / count) * i))
			* constants.BOSS_SEEKER_EXPLODE_SPEED
		)
	queue_free()


# Shootable: a shark's spray calls this (same signature as Enemy.death). Destroying
# it still bursts — so it's best shot from a distance.
func death(_death_source, _attacker = null):
	_mini_explode()
