extends CharacterBody2D

# Phase 1 boss: a single large enemy with a big health pool the sharks deplete.
# For now it just drifts slowly and takes damage — attacks/behaviour come in a
# later phase. Built as a buffed, scaled-up reskin of the necromancer sprite.
#
# Damage contract (shared with normal enemies): shark spray / grenade collide
# with this body (enemy collision layer, bit 3) and call death("PLAYER-SHOT",
# owner_player). Each hit reduces boss_health and updates the shared BossHealthBar
# via Main; at 0 the boss dies and emits boss_defeated.

enum { ALIVE, DYING }

const EnemyAttackScene = preload("res://Scenes/EnemyAttack.tscn")

signal boss_damaged(current_health, max_health)
signal boss_defeated(defeat_position, attacker)

var boss_health := 0
var boss_max_health := 0
var state = ALIVE

# Gentle drift so it isn't a static target; real movement comes in Phase 3.
const DRIFT_SPEED := 120.0
var _drift_direction := Vector2.ZERO


func _ready():
	$AnimatedSprite2D.animation = "boss-run"
	$AnimatedSprite2D.play()
	_pick_new_drift()
	$DriftTimer.connect("timeout", _on_drift_timer_timeout)
	$DriftTimer.start(randf_range(1.5, 3.0))

	# Attack cadences: a rotating spiral on one timer, aimed volleys at the
	# nearest shark on another. Both fire only while ALIVE.
	$SpiralTimer.connect("timeout", _on_spiral_timer_timeout)
	$SpiralTimer.start(constants.BOSS_SPIRAL_INTERVAL)
	$AimedTimer.connect("timeout", _on_aimed_timer_timeout)
	$AimedTimer.start(constants.BOSS_AIMED_INTERVAL)


# Called by Main right after instancing to set the health pool for this wave.
func configure(health_in):
	boss_health = health_in
	boss_max_health = health_in

	# Data-driven scale + offset (mirrors ENEMY_SETTINGS sprite_scale /
	# collision_scale / sprite_offset).
	$AnimatedSprite2D.scale = constants.BOSS_SPRITE_SCALE
	# offset is in texture pixels and auto-scales with the node (as the enemy does
	# it), so it is not multiplied by the scale here.
	$AnimatedSprite2D.offset = constants.BOSS_SPRITE_OFFSET
	$CollisionShape2D.scale = constants.BOSS_COLLISION_SCALE
	# Match the enemy's capsule centring offset (Vector2(2, -1) at 1x), scaled.
	$CollisionShape2D.position = Vector2(2, -1) * constants.BOSS_COLLISION_SCALE


func _physics_process(delta):
	if state == DYING:
		if $StateTimer.time_left == 0:
			queue_free()
		return

	# Fade back to normal tint after a hit flash.
	if $FlashHitTimer.time_left == 0:
		set_modulate(Color(1, 1, 1, 1))

	velocity = _drift_direction * DRIFT_SPEED

	if velocity.x > 0:
		$AnimatedSprite2D.set_flip_h(false)
	elif velocity.x < 0:
		$AnimatedSprite2D.set_flip_h(true)

	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider.is_in_group("players"):
			# Ramming a shark hurts it (player_hit has its own grace period, so
			# staying in contact won't drain energy every frame). Keep drifting
			# through rather than bouncing off the player.
			collider.player_hit()
		else:
			# Bounce off walls; keep drifting.
			_drift_direction = _drift_direction.bounce(collision.get_normal())


func _on_drift_timer_timeout():
	_pick_new_drift()
	$DriftTimer.start(randf_range(1.5, 3.0))


func _pick_new_drift():
	_drift_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()


# Spawn one EnemyAttack projectile travelling in a direction (standard enemy
# attack damage / collision — it calls player_hit() on contact itself).
func _fire_projectile(direction):
	var attack = EnemyAttackScene.instantiate()
	get_parent().add_child(attack)
	attack.add_to_group("enemyAttack")
	attack.global_position = global_position
	attack.velocity = direction.normalized() * constants.BOSS_ATTACK_PROJECTILE_SPEED


func _on_spiral_timer_timeout():
	if state == ALIVE:
		var count = constants.BOSS_SPIRAL_PROJECTILE_COUNT
		for i in range(count):
			var direction = Vector2(1, 0).rotated(deg_to_rad(360.0 / count) * i)
			_fire_projectile(direction)
	$SpiralTimer.start(constants.BOSS_SPIRAL_INTERVAL)


func _on_aimed_timer_timeout():
	if state == ALIVE:
		var target = get_parent().get_nearest_player(global_position)
		if target != null:
			var aim = (target.global_position - global_position).normalized()
			var count = constants.BOSS_AIMED_PROJECTILE_COUNT
			var spread = constants.BOSS_AIMED_SPREAD_DEGREES
			# Fan the volley symmetrically around the aim direction.
			for i in range(count):
				var offset = 0.0
				if count > 1:
					offset = -spread / 2.0 + (spread / (count - 1)) * i
				_fire_projectile(aim.rotated(deg_to_rad(offset)))
	$AimedTimer.start(constants.BOSS_AIMED_INTERVAL)


# Same signature as Enemy.death() so shark spray / grenade can hit us uniformly.
func death(death_source, attacker = null):
	if state == DYING:
		return

	boss_health -= 1
	boss_damaged.emit(boss_health, boss_max_health)

	if boss_health <= 0:
		_die(attacker)
	else:
		# Hit flash.
		set_modulate(Color(10, 10, 10, 10))
		$FlashHitTimer.start()


func _die(attacker):
	state = DYING
	velocity = Vector2.ZERO
	$SpiralTimer.stop()
	$AimedTimer.stop()
	# Leave enemyGroup so the wave-end sweep (which calls swim_escape on every
	# member) doesn't touch the boss; it frees itself via StateTimer below.
	remove_from_group("enemyGroup")
	$CollisionShape2D.set_deferred("disabled", true)
	set_modulate(Color(1, 1, 1, 1))
	$AnimatedSprite2D.animation = "boss-death"
	$AnimatedSprite2D.play()
	$AudioStreamPlayer.play()
	$StateTimer.start(2)
	boss_defeated.emit(global_position, attacker)
