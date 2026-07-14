class_name PlayerInput
extends RefCounted

# Input abstraction spike for couch co-op (Phase 2 groundwork).
#
# Two modes, matching the two gameplay modes:
#
#   ANY       - 1-player mode. Honours the project's "device":-1 action
#               bindings, so keyboard/mouse AND any controller all drive the
#               one player simultaneously (today's behaviour, unchanged).
#
#   SPECIFIC  - 2-player mode. Only input events from the assigned device_id
#               count. Godot's global Input.is_action_pressed() cannot filter
#               by device, so in this mode we track action state ourselves from
#               per-event device information fed via feed_event().
#
# For SPECIFIC keyboard/mouse, device_id is KEYBOARD_DEVICE (a sentinel), since
# keyboard events report device 0 but we want to distinguish "the keyboard
# player" from "gamepad 0".

enum Mode { ANY, SPECIFIC }

# Keyboard and mouse events report device 0. We use a distinct sentinel so a
# keyboard player is never confused with gamepad 0.
const KEYBOARD_DEVICE := -100

var mode: int = Mode.ANY
var device_id: int = -1

# Actions we care about for movement/aim/abilities.
var _move_actions := ["left", "right", "up", "down"]
var _aim_actions := ["shoot_left", "shoot_right", "shoot_up", "shoot_down"]
# Firing is split across two actions: shark_fire (controller) and
# shark_fire_mouse (left mouse button). Both must be tracked.
var _button_actions := ["shark_fire", "shark_fire_mouse", "fish_frenzy", "secondary_ability"]

# SPECIFIC-mode action strengths, updated from feed_event().
var _strength := {}
var _pressed := {}


func _init(input_mode: int = Mode.ANY, id: int = -1):
	mode = input_mode
	device_id = id
	for a in _move_actions + _aim_actions + _button_actions:
		_strength[a] = 0.0
		_pressed[a] = false


# Does this event belong to this player? Keyboard/mouse events are routed to the
# KEYBOARD_DEVICE player; joypad events to the player whose device_id matches.
func _event_is_mine(event: InputEvent) -> bool:
	var is_keyboard_or_mouse = (
		event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion
	)
	if is_keyboard_or_mouse:
		return device_id == KEYBOARD_DEVICE
	# Joypad event.
	return event.get_device() == device_id


# Call from the owner's _input(event) in SPECIFIC mode.
func feed_event(event: InputEvent) -> void:
	if mode != Mode.SPECIFIC:
		return
	if not _event_is_mine(event):
		return

	for a in _strength.keys():
		if event.is_action(a):
			_strength[a] = event.get_action_strength(a)
			_pressed[a] = event.is_action_pressed(a)


func get_move_vector() -> Vector2:
	if mode == Mode.ANY:
		return Input.get_vector("left", "right", "up", "down")
	var v = Vector2(
		_strength["right"] - _strength["left"], _strength["down"] - _strength["up"]
	)
	return v if v.length() <= 1.0 else v.normalized()


func get_aim_vector() -> Vector2:
	if mode == Mode.ANY:
		return Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")
	var v = Vector2(
		_strength["shoot_right"] - _strength["shoot_left"],
		_strength["shoot_down"] - _strength["shoot_up"]
	)
	return v if v.length() <= 1.0 else v.normalized()


func is_pressed(action: String) -> bool:
	if mode == Mode.ANY:
		return Input.is_action_pressed(action)
	return _pressed.get(action, false)


# Fire is either the controller action or the mouse action.
func is_firing() -> bool:
	return is_pressed("shark_fire") or is_pressed("shark_fire_mouse")
