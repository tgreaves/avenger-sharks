class_name AiInput
extends PlayerInput

# Computer-controlled input. Extends PlayerInput so a CPU shark plugs into
# Player.get_input() exactly like a device would — the AI only decides move/aim/
# button intent; the Player applies it (firing, powerups, etc.) unchanged.
#
# Slice A: follow the human player. Combat (aim/fire/frenzy) and smarts
# (fish-seeking, dodging) come in later slices.

# How close to the human the CPU tries to stay before it stops advancing, so it
# doesn't shove the human or pile directly on top.
const FOLLOW_DISTANCE := 250.0

var _move := Vector2.ZERO


func _init():
	# AI is neither ANY nor device-SPECIFIC; the base mode is irrelevant because
	# we override the getters. Use SPECIFIC so no global Input.* leaks through.
	super(Mode.SPECIFIC, -1)


func update(owner, _delta) -> void:
	_move = Vector2.ZERO

	var human = _nearest_human(owner)
	if human == null:
		return

	# Move toward the human, easing off within FOLLOW_DISTANCE.
	var to_human = human.global_position - owner.global_position
	if to_human.length() > FOLLOW_DISTANCE:
		_move = to_human.normalized()


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
	return Vector2.ZERO


func is_pressed(_action: String) -> bool:
	return false


func is_just_pressed(_action: String) -> bool:
	return false


func uses_mouse() -> bool:
	return false
