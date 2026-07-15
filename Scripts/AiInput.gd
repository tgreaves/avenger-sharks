class_name AiInput
extends PlayerInput

# Computer-controlled input. Extends PlayerInput so a CPU shark plugs into
# Player.get_input() exactly like a device would — the AI only decides move/aim/
# button intent; the Player applies it (firing, powerups, etc.) unchanged.
#
# Slice A: follow the human player.
# Slice B: aim + fire at the nearest living enemy; trigger fish frenzy.
# Smarts (fish-seeking, dodging) come in slice C.

# How close to the human the CPU tries to stay before it stops advancing, so it
# doesn't shove the human or pile directly on top.
const FOLLOW_DISTANCE := 250.0
# Only engage enemies within this range (world units).
const ENGAGE_RANGE := 1400.0

var _move := Vector2.ZERO
var _aim := Vector2.ZERO
var _firing := false
var _frenzy := false


func _init():
	# AI is neither ANY nor device-SPECIFIC; the base mode is irrelevant because
	# we override the getters. Use SPECIFIC so no global Input.* leaks through.
	super(Mode.SPECIFIC, -1)


func update(owner, _delta) -> void:
	_move = Vector2.ZERO
	_aim = Vector2.ZERO
	_firing = false
	_frenzy = false

	# Movement: follow the human, easing off within FOLLOW_DISTANCE.
	var human = _nearest_human(owner)
	if human != null:
		var to_human = human.global_position - owner.global_position
		if to_human.length() > FOLLOW_DISTANCE:
			_move = to_human.normalized()

	# Combat: aim at and fire on the nearest living enemy in range.
	var enemy = _nearest_enemy(owner)
	if enemy != null:
		var to_enemy = enemy.global_position - owner.global_position
		if to_enemy.length() <= ENGAGE_RANGE:
			_aim = to_enemy.normalized()
			_firing = true

	# Fish frenzy: use it as soon as it is available.
	if owner.fish_frenzy_enabled:
		_frenzy = true


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


func is_just_pressed(_action: String) -> bool:
	return false


func uses_mouse() -> bool:
	return false
