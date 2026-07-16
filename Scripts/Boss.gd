extends CharacterBody2D

# Boss: a single large enemy with a big health pool the sharks deplete. Its
# sprite is a random enemy type and its behaviour profile is themed to that type
# (chosen by TheDirector, applied in configure()).
#
# Damage contract (shared with normal enemies): shark spray / grenade collide
# with this body (enemy collision layer, bit 3) and call death("PLAYER-SHOT",
# owner_player). Each hit reduces boss_health and updates the shared BossHealthBar
# via Main; at 0 the boss dies and emits boss_defeated.

enum { SPAWNING, ALIVE, DYING }

const EnemyAttackScene = preload("res://Scenes/EnemyAttack.tscn")
const EnemyScene = preload("res://Scenes/Enemy.tscn")

signal boss_damaged(current_health, max_health)
signal boss_defeated(defeat_position, attacker)

var boss_health := 0
var boss_max_health := 0
# Starts SPAWNING: invulnerable and materialising (like normal enemies) so the
# player can't chip its health before the fight begins. begin_fighting() sets it
# ALIVE.
var state = SPAWNING

var boss_type := "necromancer"
var behaviour := ""
var move_speed := 0.0
var boss_number := 1          # 1st boss, 2nd boss... drives attack cadence.
var attack_interval := 0.0    # Seconds between attacks (from boss_number).
var _spiral_angle := 0.0      # Accumulates so rotating-spiral gaps sweep.

# Horizontal patrol direction (+1 right, -1 left); flips at the box edges and
# is re-rolled periodically so movement isn't perfectly predictable.
var _patrol_direction := 1
# Patrol X bounds, set by Main from the confined boss box.
var patrol_min_x := 0.0
var patrol_max_x := 5000.0
# True once the wave is live (begin_fighting). Until then the boss holds still
# (attacks held) so players see it materialise before it engages.
var _fighting := false


func _ready():
	$DriftTimer.connect("timeout", _on_drift_timer_timeout)
	$DriftTimer.start(randf_range(2.0, 4.0))

	$AttackTimer.connect("timeout", _on_attack_timer_timeout)
	$ArtilleryTimer.connect("timeout", _on_artillery_timer_timeout)


# Called by Main right after instancing: health pool, sprite type, the behaviour
# profile, and which boss encounter this is (for cadence scaling).
func configure(health_in, type_in, behaviour_in, boss_number_in := 1):
	boss_health = health_in
	boss_max_health = health_in
	boss_type = type_in
	behaviour = behaviour_in
	boss_number = boss_number_in

	# Later bosses fire faster (interval shrinks per encounter, floored).
	attack_interval = max(
		constants.BOSS_ATTACK_INTERVAL_MIN,
		constants.BOSS_ATTACK_INTERVAL_BASE
		- (boss_number - 1) * constants.BOSS_ATTACK_INTERVAL_STEP
	)

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

	# Every profile patrols the top of the arena horizontally; the behaviour only
	# drives the attack pool now. Start heading in a random direction.
	move_speed = constants.BOSS_PATROL_SPEED
	_patrol_direction = 1 if randi() % 2 == 0 else -1

	# Materialise in (invulnerable) like a normal enemy: start transparent and
	# fade to opaque over the spawn-in; begin_fighting() ends the spawn state.
	set_modulate(Color(1, 1, 1, 0))


# The wave has gone live (players are in position) — start the attack timers for
# the chosen profile. Spawned earlier (during the swim-in) with attacks held so
# the players see the boss materialise before it opens fire.
func begin_fighting():
	_fighting = true
	# Spawn-in over: now vulnerable and fully opaque.
	state = ALIVE
	set_modulate(Color(1, 1, 1, 1))
	# Single cadence timer drives the weighted attack pool for every profile.
	$AttackTimer.start(attack_interval)
	# The artillery profile additionally rains POLLUTION strikes.
	if behaviour == constants.BOSS_BEHAVIOUR_ARTILLERY:
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

	# Spawning-in: hold still and fade toward opaque (invulnerable). Stays in this
	# state until begin_fighting() flips it to ALIVE when the wave goes live.
	if state == SPAWNING:
		set_modulate(lerp(get_modulate(), Color(1, 1, 1, 1), 0.04))
		return

	# Fade back to normal tint after a hit flash.
	if $FlashHitTimer.time_left == 0:
		set_modulate(Color(1, 1, 1, 1))

	# Hold still until the wave goes live (players see the boss appear first).
	if not _fighting:
		return

	# Patrol horizontally along the top; reverse at the box edges.
	if global_position.x <= patrol_min_x:
		_patrol_direction = 1
	elif global_position.x >= patrol_max_x:
		_patrol_direction = -1

	velocity = Vector2(_patrol_direction * move_speed, 0)
	$AnimatedSprite2D.set_flip_h(_patrol_direction < 0)

	# move_and_collide so ramming a shark still hurts it; the boss stays in its
	# horizontal band so walls aren't a concern.
	var collision = move_and_collide(velocity * delta)
	if collision and collision.get_collider().is_in_group("players"):
		collision.get_collider().player_hit()


func _on_drift_timer_timeout():
	# Occasionally flip patrol direction so it isn't perfectly predictable.
	if randi() % 2 == 0:
		_patrol_direction = -_patrol_direction
	$DriftTimer.start(randf_range(2.0, 4.0))


# Spawn one EnemyAttack projectile travelling in a direction (standard enemy
# attack damage / collision — it calls player_hit() on contact itself).
# curve_rate (deg/sec) makes it curve in flight; 0 = straight.
func _fire_projectile(direction, curve_rate := 0.0, curve_decay := 0.0):
	var attack = EnemyAttackScene.instantiate()
	get_parent().add_child(attack)
	attack.add_to_group("enemyAttack")
	attack.global_position = global_position
	attack.velocity = direction.normalized() * constants.BOSS_ATTACK_PROJECTILE_SPEED
	attack.curve_rate = curve_rate
	attack.curve_decay = curve_decay


# Cadence tick: pick a weighted attack from this profile's pool and fire it.
func _on_attack_timer_timeout():
	if state == ALIVE:
		match _pick_attack():
			constants.BOSS_ATTACK_ROTATING_SPIRAL:
				_attack_rotating_spiral()
			constants.BOSS_ATTACK_TWIN_SPIRAL:
				_attack_twin_spiral()
			constants.BOSS_ATTACK_SHOTGUN:
				_attack_shotgun()
			constants.BOSS_ATTACK_WALL:
				_attack_wall()
			constants.BOSS_ATTACK_CURVING_SPIRAL:
				_attack_curving_spiral()
	$AttackTimer.start(attack_interval)


# Weighted random pick from this behaviour's attack pool.
func _pick_attack():
	var pool = constants.BOSS_ATTACK_POOLS[behaviour]
	var total = 0
	for weight in pool.values():
		total += weight
	var roll = randi_range(1, total)
	var running = 0
	for attack in pool:
		running += pool[attack]
		if roll <= running:
			return attack
	return pool.keys()[0]


# A full ring whose start angle advances each burst, so the gaps sweep around.
func _attack_rotating_spiral():
	var count = constants.BOSS_SPIRAL_PROJECTILE_COUNT
	_spiral_angle += constants.BOSS_SPIRAL_ROTATION_STEP
	for i in range(count):
		var direction = Vector2(1, 0).rotated(
			deg_to_rad(_spiral_angle + (360.0 / count) * i)
		)
		_fire_projectile(direction)


# Two rings rotating in opposite directions for hard-to-read interference.
func _attack_twin_spiral():
	var count = constants.BOSS_TWIN_SPIRAL_COUNT
	_spiral_angle += constants.BOSS_SPIRAL_ROTATION_STEP
	for i in range(count):
		var base = (360.0 / count) * i
		_fire_projectile(Vector2(1, 0).rotated(deg_to_rad(_spiral_angle + base)))
		_fire_projectile(Vector2(1, 0).rotated(deg_to_rad(-_spiral_angle - base)))


# A wide, dense fan aimed at the nearest shark.
func _attack_shotgun():
	var target = get_parent().get_nearest_player(global_position)
	if target == null:
		return
	var aim = (target.global_position - global_position).normalized()
	var count = constants.BOSS_SHOTGUN_PROJECTILE_COUNT
	var spread = constants.BOSS_SHOTGUN_SPREAD_DEGREES
	for i in range(count):
		var offset = 0.0
		if count > 1:
			offset = -spread / 2.0 + (spread / (count - 1)) * i
		_fire_projectile(aim.rotated(deg_to_rad(offset)))


# A broad line of shots with one gap to slip through.
func _attack_wall():
	var count = constants.BOSS_WALL_PROJECTILE_COUNT
	var target = get_parent().get_nearest_player(global_position)
	var base_dir = Vector2(0, 1)
	if target != null:
		base_dir = (target.global_position - global_position).normalized()
	var gap_start = randi_range(0, count - constants.BOSS_WALL_GAP_WIDTH)
	var spread = 160.0
	for i in range(count):
		if i >= gap_start and i < gap_start + constants.BOSS_WALL_GAP_WIDTH:
			continue  # The gap.
		var offset = -spread / 2.0 + (spread / (count - 1)) * i
		_fire_projectile(base_dir.rotated(deg_to_rad(offset)))


# Curving spiral: several arms emit shots over time, and each shot curves in
# flight (its velocity rotates), so the bullets trace visible spiral arms across
# the arena rather than radiating in straight lines.
func _attack_curving_spiral():
	var arms = constants.BOSS_CURVING_SPIRAL_ARMS
	var shots = constants.BOSS_CURVING_SPIRAL_SHOTS
	var curve = constants.BOSS_CURVING_SPIRAL_CURVE_RATE
	# Randomise curve direction per burst for variety.
	if randi() % 2 == 0:
		curve = -curve
	# Advance the base angle so successive bursts start from a new heading.
	_spiral_angle += constants.BOSS_SPIRAL_ROTATION_STEP
	for s in range(shots):
		if state != ALIVE:
			return
		# Each emit step, fire one shot per arm from the (advancing) base angle.
		var step_angle = _spiral_angle + s * 24.0
		for a in range(arms):
			var arm_angle = step_angle + (360.0 / arms) * a
			_fire_projectile(
				Vector2(1, 0).rotated(deg_to_rad(arm_angle)),
				curve,
				constants.BOSS_CURVING_SPIRAL_CURVE_DECAY
			)
		await get_tree().create_timer(constants.BOSS_CURVING_SPIRAL_EMIT_GAP).timeout


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
	# Targetable while spawning too (aim tracks it as it materialises), matching
	# normal enemies — it just can't take damage until ALIVE.
	return state == SPAWNING or state == ALIVE


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
	# Invulnerable while spawning in (and once dying), like normal enemies.
	if state != ALIVE:
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
	$AttackTimer.stop()
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
