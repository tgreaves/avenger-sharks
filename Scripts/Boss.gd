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
# Charge-attack sub-phases (only meaningful while ALIVE). NONE = not charging.
enum { CHARGE_NONE, CHARGE_TELEGRAPH, CHARGE_CHARGING, CHARGE_RECOVERING }

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
var _enraged := false         # True once health crossed the enrage threshold.
# Tint the sprite rests at between hit flashes — white normally, red once enraged.
var _base_tint := Color(1, 1, 1, 1)
var _base_sprite_scale := Vector2.ONE   # Sprite's configured scale (for the enrage flex).
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

# Charge attack: while a charge runs it takes over movement (telegraph → lunge →
# recover) and the normal cadence timer is suspended until it finishes.
var _charge_phase := CHARGE_NONE
var _charge_anchor := Vector2.ZERO    # Where the telegraph began; returned to after the lunge.
var _charge_velocity := Vector2.ZERO  # Locked lunge velocity (direction captured at launch).
# Boss's normal collision_mask (players + walls). While charging, the player bits
# are masked out so the lunge passes THROUGH sharks (contact damage is applied
# manually) and only a wall stops it; restored when the charge finishes.
var _default_collision_mask := 0


func _ready():
	_default_collision_mask = collision_mask
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
	var type_settings = constants.BOSS_TYPE_SETTINGS[boss_type]
	var type_scale = type_settings["scale"]
	$AnimatedSprite2D.scale = type_scale
	_base_sprite_scale = type_scale
	# Some sprites sit off-centre in their frame; reuse the enemy's own tuned
	# sprite_offset (in texture px, auto-scaled by the node) so the creature lines
	# up with the centred collision capsule — same as the normal enemy does.
	var enemy_settings = constants.ENEMY_SETTINGS[boss_type]
	$AnimatedSprite2D.offset = enemy_settings.get("sprite_offset", Vector2.ZERO)
	# Collision scale: the shared capsule is necromancer-shaped, so by default it
	# scales proportionally (fits at collision 1.75 / sprite 7). Sprites whose body
	# fills its frame differently (e.g. the bee's small body) override collision_scale
	# in BOSS_TYPE_SETTINGS.
	var collision_scale = type_settings.get("collision_scale", type_scale * (1.75 / 7.0))
	$CollisionShape2D.scale = collision_scale
	# Collision offset: shared with the normal enemy via ENEMY_SETTINGS, in
	# sprite-relative texture px (same space as sprite_offset), scaled by the sprite
	# scale so one value fits both. Types without it keep the legacy centred default.
	if enemy_settings.has("collision_offset"):
		$CollisionShape2D.position = enemy_settings["collision_offset"] * type_scale
	else:
		$CollisionShape2D.position = Vector2(2, -1) * collision_scale

	# The boss holds the top of the arena; the behaviour drives the attack pool,
	# and BOSS_MOVEMENT_STYLE decides whether it paces or stays rooted. Pick a
	# random side to first head toward when pacing.
	move_speed = constants.BOSS_PATROL_SPEED
	_patrol_direction = 1 if randi() % 2 == 0 else -1

	# Materialise in (invulnerable) like a normal enemy: start transparent and
	# fade to opaque over the spawn-in, with spawn particles swirling around it;
	# begin_fighting() ends the spawn state.
	set_modulate(Color(1, 1, 1, 0))
	$SpawnParticles.emitting = true


# The wave has gone live (players are in position) — start the attack timers for
# the chosen profile. Spawned earlier (during the swim-in) with attacks held so
# the players see the boss materialise before it opens fire.
func begin_fighting():
	_fighting = true
	# Spawn-in over: now vulnerable and fully opaque; stop the spawn particles.
	state = ALIVE
	set_modulate(Color(1, 1, 1, 1))
	$SpawnParticles.emitting = false
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

	# Settle back to the rest tint after a hit flash (white, or red once enraged).
	if $FlashHitTimer.time_left == 0:
		set_modulate(_base_tint)

	# Hold still until the wave goes live (players see the boss appear first).
	if not _fighting:
		return

	# A charge attack takes over movement while it runs (telegraph → lunge →
	# recover); normal patrol + cadence are suspended until it finishes.
	if _charge_phase != CHARGE_NONE:
		_process_charge(delta)
		return

	# Movement style (tunable while we settle the feel). Rooted: hold station and
	# let the attack patterns carry the fight. Pace: sweep the full width edge to
	# edge, reversing ONLY at the patrol bounds so it commits to a full sweep
	# rather than dithering in the middle.
	if constants.BOSS_MOVEMENT_STYLE == constants.BOSS_MOVEMENT_ROOTED:
		velocity = Vector2.ZERO
	else:
		if global_position.x <= patrol_min_x:
			_patrol_direction = 1
		elif global_position.x >= patrol_max_x:
			_patrol_direction = -1
		velocity = Vector2(_patrol_direction * move_speed, 0)
		$AnimatedSprite2D.set_flip_h(_patrol_direction < 0)

	# move_and_collide so ramming a shark still hurts it. A large boss (snake 14x /
	# bee 16x) can reach a side wall *before* its centre crosses the patrol
	# turn-point, so gating the reversal purely on patrol_min_x/max_x pins it
	# against the wall. Reverse on wall contact too so it can never get stuck.
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider and collider.is_in_group("players"):
			collider.player_hit()
		elif constants.BOSS_MOVEMENT_STYLE != constants.BOSS_MOVEMENT_ROOTED:
			_patrol_direction = -_patrol_direction
			$AnimatedSprite2D.set_flip_h(_patrol_direction < 0)


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
		var attack = _pick_attack()
		# A charge takes over movement for its whole telegraph → lunge → recover
		# run and restarts the cadence timer itself once it finishes, so return
		# early rather than firing a projectile + rescheduling here.
		if attack == constants.BOSS_ATTACK_CHARGE:
			_begin_charge()
			return
		match attack:
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


# --- Charge attack -------------------------------------------------------------
# The boss halts and vibrates (fair-warning tell), then lunges very fast at the
# shark's position captured at the moment the lunge begins (so moving during the
# lunge dodges it), then slides back to its patrol band and resumes.

# Enter the telegraph: stop, remember where to return to, and buzz for a moment.
func _begin_charge():
	_charge_phase = CHARGE_TELEGRAPH
	_charge_anchor = global_position
	velocity = Vector2.ZERO
	$ChargeTimer.start(constants.BOSS_CHARGE_TELEGRAPH_TIME)


# Lock in the target and fire the lunge. Direction is captured ONCE here.
func _launch_charge():
	$AnimatedSprite2D.position = Vector2.ZERO   # stop the telegraph vibration
	var direction = Vector2.DOWN
	var target = get_parent().get_nearest_player(global_position)
	if target:
		direction = (target.global_position - global_position).normalized()
	_charge_velocity = direction * constants.BOSS_CHARGE_SPEED
	_charge_phase = CHARGE_CHARGING
	$AnimatedSprite2D.set_flip_h(direction.x < 0)
	# Mask out the sharks' layer so the lunge passes THROUGH them (only a wall
	# stops it); contact damage is applied manually in _process_charge.
	var player_bits = 0
	for p in get_tree().get_nodes_in_group("players"):
		player_bits |= p.collision_layer
	collision_mask = _default_collision_mask & ~player_bits


# Lunge is over (hit something or ran its distance): pause/slide back to anchor.
func _begin_charge_recover():
	_charge_phase = CHARGE_RECOVERING
	velocity = Vector2.ZERO
	$ChargeTimer.start(constants.BOSS_CHARGE_RECOVER_TIME)


# Charge fully done: restore collision, resume normal patrol + cadence.
func _finish_charge():
	_charge_phase = CHARGE_NONE
	collision_mask = _default_collision_mask
	$AttackTimer.start(attack_interval)


# Radius within which a lunge counts as ramming a shark (boss capsule + a margin
# for the shark's own body, so a fast pass reliably connects).
func _charge_contact_radius() -> float:
	return $CollisionShape2D.shape.radius * $CollisionShape2D.scale.x + 40.0


# Per-frame charge driver (called from _physics_process while a charge runs).
func _process_charge(delta):
	match _charge_phase:
		CHARGE_TELEGRAPH:
			# Vibrate the SPRITE (not the body) so the tell doesn't move the hitbox.
			var amp = constants.BOSS_CHARGE_VIBRATE_AMPLITUDE
			$AnimatedSprite2D.position = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
			if $ChargeTimer.time_left == 0:
				_launch_charge()
		CHARGE_CHARGING:
			# Players are masked out, so move_and_collide only ever stops on a wall.
			# The room is fully walled, so the lunge always ends at a wall.
			var collision = move_and_collide(_charge_velocity * delta)
			# Contact damage to any shark the lunge sweeps over — does NOT stop it
			# (player_hit has its own grace period, so passing over is one hit).
			var reach = _charge_contact_radius()
			for p in get_tree().get_nodes_in_group("players"):
				if p.global_position.distance_to(global_position) <= reach:
					p.player_hit()
			if collision:
				_begin_charge_recover()
		CHARGE_RECOVERING:
			# Slide back to where the telegraph began (its patrol band). The timer
			# caps it so a blocked path can't stall the fight — snap home and resume.
			var to_anchor = _charge_anchor - global_position
			var step = constants.BOSS_CHARGE_RETURN_SPEED * delta
			if to_anchor.length() <= step or $ChargeTimer.time_left == 0:
				global_position = _charge_anchor
				_finish_charge()
			else:
				$AnimatedSprite2D.set_flip_h(to_anchor.x < 0)
				move_and_collide(to_anchor.normalized() * step)


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
# death_source is unused (the boss takes 1 damage from any source), hence the _.
func death(_death_source, attacker = null):
	# Invulnerable while spawning in (and once dying), like normal enemies.
	if state != ALIVE:
		return

	boss_health -= 1
	boss_damaged.emit(boss_health, boss_max_health)

	if boss_health <= 0:
		_die(attacker)
	else:
		# Second-phase escalation: below the health threshold the boss enrages,
		# tightening its cadence for the rest of the fight.
		if not _enraged and boss_health <= boss_max_health * constants.BOSS_ENRAGE_HEALTH_FRACTION:
			_enrage()
		# Hit flash.
		set_modulate(Color(10, 10, 10, 10))
		$FlashHitTimer.start()


func _die(attacker):
	state = DYING
	velocity = Vector2.ZERO
	$AttackTimer.stop()
	$ArtilleryTimer.stop()
	# Cancel any in-progress charge, restore collision, undo the telegraph vibration.
	$ChargeTimer.stop()
	_charge_phase = CHARGE_NONE
	collision_mask = _default_collision_mask
	$AnimatedSprite2D.position = Vector2.ZERO
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


# Enrage: once past the health threshold, tighten the attack cadence for the rest
# of the fight (floored so very late bosses don't fire absurdly fast). Restart the
# cadence timer so the faster rate takes effect immediately.
func _enrage():
	_enraged = true
	attack_interval = max(
		constants.BOSS_ATTACK_INTERVAL_MIN * constants.BOSS_ENRAGE_CADENCE_MULTIPLIER,
		attack_interval * constants.BOSS_ENRAGE_CADENCE_MULTIPLIER
	)
	if state == ALIVE:
		$AttackTimer.start(attack_interval)

	# Visual tell: the boss reddens for the rest of the fight (persists between hit
	# flashes via _base_tint) and gives a quick scale flex at the moment it enrages.
	_base_tint = constants.BOSS_ENRAGE_TINT
	set_modulate(_base_tint)
	var flex = create_tween()
	flex.tween_property($AnimatedSprite2D, "scale", _base_sprite_scale * 1.15, 0.12)
	flex.tween_property($AnimatedSprite2D, "scale", _base_sprite_scale, 0.18)
