class_name AiInput
extends PlayerInput

# Computer-controlled input. Extends PlayerInput so a CPU shark plugs into
# Player.get_input() exactly like a device would — the AI only decides move/aim/
# button intent; the Player applies it (firing, powerups, etc.) unchanged.
#
# Slice A: follow the human player.
# Slice B: aim + fire at the nearest living enemy; trigger fish frenzy.
# Slice C: cautious smarts — dodge, keep distance, seek fish.

# How close to the human the CPU tries to stay before it stops advancing, so it
# doesn't shove the human or pile directly on top.
const FOLLOW_DISTANCE := 250.0
# Only engage enemies within this range (world units).
const ENGAGE_RANGE := 1400.0
# Cautious spacing: start backing away when an enemy gets within ENTER, and keep
# backing away until it is beyond EXIT. The gap between them (hysteresis) stops
# the shark twitching between "retreat" and "advance" right at the boundary.
const KEEP_DISTANCE_ENTER := 500.0
const KEEP_DISTANCE_EXIT := 650.0
# Surge-dodge when an enemy gets closer than this.
const DANGER_DISTANCE := 300.0
# Seek fish only opportunistically: within this (short) range, and only when no
# enemy is engaging (see ENGAGE_RANGE). Kept short so the CPU commits to combat
# and doesn't make cross-arena detours for fish (which don't score until the
# phase 5 wave-lifecycle work anyway).
const FISH_SEEK_RANGE := 450.0
# Recompute the navigation path at most every this many physics frames (A* is
# not free; the target rarely moves far between frames).
const PATH_RECOMPUTE_FRAMES := 10

var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _firing := false
var _frenzy := false
var _surge := false
# Sticky retreat state for the hysteresis band above.
var _retreating := false
# Cached navigation path (tilemap cells) and recompute throttle.
var _path := []
var _frames_since_path := PATH_RECOMPUTE_FRAMES


func _init():
	# AI is neither ANY nor device-SPECIFIC; the base mode is irrelevant because
	# we override the getters. Use SPECIFIC so no global Input.* leaks through.
	super(Mode.SPECIFIC, -1)


func update(owner, _delta) -> void:
	_move = Vector2.ZERO
	_aim = Vector2.ZERO
	_firing = false
	_frenzy = false
	_surge = false

	var enemy = _nearest_enemy(owner)
	var enemy_distance = INF
	if enemy != null:
		enemy_distance = owner.global_position.distance_to(enemy.global_position)

	# Combat (independent of movement): aim at and fire on the nearest enemy.
	if enemy != null and enemy_distance <= ENGAGE_RANGE:
		_aim = (enemy.global_position - owner.global_position).normalized()
		_firing = true

	# Fish frenzy: use it as soon as it is available.
	if owner.fish_frenzy_enabled:
		_frenzy = true

	# Movement: cautious priority ladder.
	var away_from_enemy = Vector2.ZERO
	if enemy != null:
		away_from_enemy = (owner.global_position - enemy.global_position).normalized()

	# Update sticky retreat state with hysteresis: enter close, leave far.
	if enemy == null:
		_retreating = false
	elif enemy_distance <= KEEP_DISTANCE_ENTER:
		_retreating = true
	elif enemy_distance > KEEP_DISTANCE_EXIT:
		_retreating = false

	_frames_since_path += 1

	if enemy != null and enemy_distance <= DANGER_DISTANCE:
		# 1. Danger — flee, and surge away if we can. Reactive straight-line move
		# away from an adjacent threat; no pathing (short and immediate).
		_move = away_from_enemy
		if owner.swim_surge_available:
			_surge = true
		_path.clear()
	elif _retreating:
		# 2. Too close — back off while keeping the enemy in front (still firing).
		_move = away_from_enemy
		_path.clear()
	else:
		# 3. No nearby threat — seek a fish if one is close AND no enemy is
		# engaging (so we commit to fights), else follow human. Longer-range
		# goals, so navigate around obstacles via A*.
		var target_pos = null
		var engaging = enemy != null and enemy_distance <= ENGAGE_RANGE
		var fish = null
		if not engaging:
			fish = _nearest_fish(owner)

		if fish != null and owner.global_position.distance_to(fish.global_position) <= FISH_SEEK_RANGE:
			target_pos = fish.global_position
		else:
			var human = _nearest_human(owner)
			if human != null:
				if owner.global_position.distance_to(human.global_position) > FOLLOW_DISTANCE:
					target_pos = human.global_position

		if target_pos != null:
			_move = _direction_via_path(owner, target_pos)
		else:
			_path.clear()


# Direction toward `target_pos`, routed around obstacles using the arena's A*
# grid. The path is cached and only recomputed every PATH_RECOMPUTE_FRAMES to
# keep A* cost down. Falls back to a straight line if no path is found.
func _direction_via_path(owner, target_pos: Vector2) -> Vector2:
	var arena = owner.get_parent().get_node("Arena")

	if _frames_since_path >= PATH_RECOMPUTE_FRAMES:
		_path = arena.get_astar_route_from_positions(owner.global_position, target_pos)
		_frames_since_path = 0

	# Drop the current waypoint once we occupy its tile (same arrival test the
	# enemies use — robust to overshoot at high speed).
	var current_cell = arena.get_tilemap_coords(owner.global_position)
	while _path.size() > 0 and _path[0] == current_cell:
		_path.pop_front()

	if _path.size() > 0:
		var waypoint = arena.get_position_from_tilemap(_path[0])
		return (waypoint - owner.global_position).normalized()

	# No path (or arrived) — head straight at the target.
	return (target_pos - owner.global_position).normalized()


func _nearest_fish(owner):
	var nearest = null
	var nearest_distance = INF
	for f in owner.get_tree().get_nodes_in_group("fishGroup"):
		var d = owner.global_position.distance_to(f.global_position)
		if d < nearest_distance:
			nearest = f
			nearest_distance = d
	return nearest


func _nearest_enemy(owner):
	var nearest = null
	var nearest_distance = INF
	for e in owner.get_tree().get_nodes_in_group("enemyGroup"):
		if not e.is_enemy_alive():
			continue
		var d = owner.global_position.distance_to(e.global_position)
		if d < nearest_distance:
			nearest = e
			nearest_distance = d
	return nearest


# The nearest player that is not this AI's owner (i.e. a human teammate).
func _nearest_human(owner):
	var nearest = null
	var nearest_distance = INF
	for p in owner.get_parent().get_players():
		if p == owner:
			continue
		var d = owner.global_position.distance_to(p.global_position)
		if d < nearest_distance:
			nearest = p
			nearest_distance = d
	return nearest


func get_move_vector() -> Vector2:
	return _move


func get_aim_vector() -> Vector2:
	return _aim


func is_pressed(action: String) -> bool:
	match action:
		"shark_fire":
			return _firing
		"fish_frenzy":
			return _frenzy
	return false


func is_just_pressed(action: String) -> bool:
	# Surge is edge-triggered by the Player, but its own swim_surge_available
	# flag gates re-use, so reporting the intent while in danger is safe.
	if action == "secondary_ability":
		return _surge
	return false


func uses_mouse() -> bool:
	return false
