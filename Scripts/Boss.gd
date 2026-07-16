extends CharacterBody2D

# Boss: a single large enemy with a big health pool the sharks deplete. Its
# sprite is a random enemy type and its behaviour profile is themed to that type
# (chosen by TheDirector, applied in configure()).
#
# Damage contract (shared with normal enemies): shark spray / grenade collide
# with this body (enemy collision layer, bit 3) and call death("PLAYER-SHOT",
# owner_player). Each hit reduces boss_health and updates the shared BossHealthBar
# via Main; at 0 the boss dies and emits boss_defeated.

enum { ALIVE, DYING }

const EnemyAttackScene = preload("res://Scenes/EnemyAttack.tscn")
const EnemyScene = preload("res://Scenes/Enemy.tscn")

signal boss_damaged(current_health, max_health)
signal boss_defeated(defeat_position, attacker)

var boss_health := 0
var boss_max_health := 0
var state = ALIVE

var boss_type := "necromancer"
var behaviour := ""
var move_speed := 0.0

# ROAM: random drift direction, re-picked periodically.
var _drift_direction := Vector2.ZERO
# True once the wave is live (begin_fighting). Until then the boss drifts into
# view without chasing or attacking, so players see it spawn before it engages.
var _fighting := false


func _ready():
	_pick_new_drift()
	$DriftTimer.connect("timeout", _on_drift_timer_timeout)
	$DriftTimer.start(randf_range(1.5, 3.0))

	$SpiralTimer.connect("timeout", _on_spiral_timer_timeout)
	$AimedTimer.connect("timeout", _on_aimed_timer_timeout)
	$ArtilleryTimer.connect("timeout", _on_artillery_timer_timeout)


# Called by Main right after instancing: health pool, sprite type, and the
# behaviour profile (all from wave_design).
func configure(health_in, type_in, behaviour_in):
	boss_health = health_in
	boss_max_health = health_in
	boss_type = type_in
	behaviour = behaviour_in

	# Borrow the shared enemy SpriteFrames (all types' run/death anims) from a
	# throwaway Enemy instance so the boss can wear any enemy's sprite.
	var enemy = EnemyScene.instantiate()
	$AnimatedSprite2D.sprite_frames = enemy.get_node("AnimatedSprite2D").sprite_frames
	enemy.free()

	$AnimatedSprite2D.animation = boss_type + "-run"
	$AnimatedSprite2D.play()

	# Per-type scale (native frame sizes differ); collision scales with it, using
	# the necromancer-tuned capsule as the reference proportion.
	var type_scale = constants.BOSS_TYPE_SETTINGS[boss_type]["scale"]
	$AnimatedSprite2D.scale = type_scale
	# The shared capsule fits the necromancer at collision 1.75 / sprite 7; scale
	# the collision to the same ratio for this type's sprite scale.
	var collision_scale = type_scale * (1.75 / 7.0)
	$CollisionShape2D.scale = collision_scale
	$CollisionShape2D.position = Vector2(2, -1) * collision_scale

	# Set movement speed for the profile now (so the boss drifts/roams into view
	# during the swim-in), but hold attacks until begin_fighting().
	match behaviour:
		constants.BOSS_BEHAVIOUR_ROAM_SPIRAL, constants.BOSS_BEHAVIOUR_ARTILLERY:
			move_speed = constants.BOSS_ROAM_SPEED
		constants.BOSS_BEHAVIOUR_CHASE_AIMED:
			move_speed = constants.BOSS_CHASE_SPEED
		constants.BOSS_BEHAVIOUR_BULLETHELL:
			# Hovers slowly rather than truly stationary (run anim has no idle).
			move_speed = constants.BOSS_HOVER_SPEED


# The wave has gone live (players are in position) — start the attack timers for
# the chosen profile. Spawned earlier (during the swim-in) with attacks held so
# the players see the boss materialise before it opens fire.
func begin_fighting():
	_fighting = true
	match behaviour:
		constants.BOSS_BEHAVIOUR_ROAM_SPIRAL:
			$SpiralTimer.start(constants.BOSS_SPIRAL_INTERVAL)
			$AimedTimer.start(constants.BOSS_AIMED_INTERVAL)
		constants.BOSS_BEHAVIOUR_CHASE_AIMED:
			$AimedTimer.start(constants.BOSS_AIMED_INTERVAL)
		constants.BOSS_BEHAVIOUR_BULLETHELL:
			$SpiralTimer.start(constants.BOSS_BULLETHELL_SPIRAL_INTERVAL)
		constants.BOSS_BEHAVIOUR_ARTILLERY:
			$AimedTimer.start(constants.BOSS_AIMED_INTERVAL)
			$ArtilleryTimer.start(
				randf_range(
					constants.BOSS_ARTILLERY_INTERVAL_MIN, constants.BOSS_ARTILLERY_INTERVAL_MAX
				)
			)


func _physics_process(delta):
	if state == DYING:
		if $StateTimer.time_left == 0:
			queue_free()
		return

	# Fade back to normal tint after a hit flash.
	if $FlashHitTimer.time_left == 0:
		set_modulate(Color(1, 1, 1, 1))

	velocity = _movement_velocity()

	if velocity.x > 0:
		$AnimatedSprite2D.set_flip_h(false)
	elif velocity.x < 0:
		$AnimatedSprite2D.set_flip_h(true)

	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider.is_in_group("players"):
			# Ramming a shark hurts it (player_hit has its own grace period, so
			# staying in contact won't drain energy every frame). Keep moving
			# through rather than bouncing off the player.
			collider.player_hit()
		else:
			# Bounce off walls (roaming profiles); keep moving.
			_drift_direction = _drift_direction.bounce(collision.get_normal())


# Per-profile movement direction * speed.
func _movement_velocity():
	if move_speed == 0.0:
		return Vector2.ZERO

	# Chase only once the wave is live; during the swim-in the boss just drifts
	# into view.
	if _fighting and behaviour == constants.BOSS_BEHAVIOUR_CHASE_AIMED:
		var target = get_parent().get_nearest_player(global_position)
		if target != null:
			return (target.global_position - global_position).normalized() * move_speed

	return _drift_direction * move_speed


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
		var interval = constants.BOSS_SPIRAL_INTERVAL
		if behaviour == constants.BOSS_BEHAVIOUR_BULLETHELL:
			count = constants.BOSS_BULLETHELL_PROJECTILE_COUNT
			interval = constants.BOSS_BULLETHELL_SPIRAL_INTERVAL
		for i in range(count):
			var direction = Vector2(1, 0).rotated(deg_to_rad(360.0 / count) * i)
			_fire_projectile(direction)
		$SpiralTimer.start(interval)


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


func _on_artillery_timer_timeout():
	if state == ALIVE:
		# Rain a POLLUTION STRIKE on a random living shark (reuses Main's spawner).
		get_parent().spawn_boss_artillery()
		$ArtilleryTimer.start(
			randf_range(constants.BOSS_ARTILLERY_INTERVAL_MIN, constants.BOSS_ARTILLERY_INTERVAL_MAX)
		)


# --- Enemy-compatible API ---
# The boss lives in "enemyGroup" so projectiles collide with it, but several
# systems iterate that group and call enemy-only methods (grenade auto-aim, the
# CPU's threat/aim scan, power-pellet/wave-end resets). Provide matching stubs
# so the boss participates like any enemy.

func is_enemy_alive() -> bool:
	return state == ALIVE


func is_enemy_targetable() -> bool:
	return state == ALIVE


func reset_state_timer():
	pass


func stop_calling_for_help():
	pass


func swim_escape():
	# The boss doesn't flee at wave end; it's only ever in the group while it's
	# the live target (it leaves the group on defeat). No-op keeps the wave-end
	# sweep safe if it ever iterates a still-living boss.
	pass


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
	$ArtilleryTimer.stop()
	# Leave enemyGroup so the wave-end sweep (which calls swim_escape on every
	# member) doesn't touch the boss; it frees itself via StateTimer below.
	remove_from_group("enemyGroup")
	$CollisionShape2D.set_deferred("disabled", true)
	set_modulate(Color(1, 1, 1, 1))
	$AnimatedSprite2D.animation = boss_type + "-death"
	$AnimatedSprite2D.play()
	$AudioStreamPlayer.play()
	$StateTimer.start(2)
	boss_defeated.emit(global_position, attacker)
