class_name PlayerInput
extends RefCounted

# Per-player input abstraction for couch co-op.
#
# Two modes, matching the two gameplay modes:
#
#   ANY       - 1-player mode. Delegates to the global Input.* calls, which
#               honour the project's "device":-1 action bindings, so
#               keyboard/mouse AND any controller all drive the one player
#               simultaneously (the original single-player behaviour).
#
#   SPECIFIC  - 2-player mode. Only input events from the assigned device_id
#               count. Godot's global Input.is_action_pressed() cannot filter
#               by device, so this mode tracks action state itself from
#               per-event device information fed via feed_event() (call it from
#               the owner's _input()).
#
# Keyboard/mouse events report device 0, so a keyboard player uses the
# KEYBOARD_DEVICE sentinel to stay distinct from gamepad 0.
#
# Validated for ANY and keyboard+gamepad SPECIFIC via the input spike.
# Two-gamepad SPECIFIC and SPECIFIC-mode just_pressed edge detection are
# pending a hardware play-test.

enum Mode { ANY, SPECIFIC }

const KEYBOARD_DEVICE := -100

# Every action this wrapper can report on.
const TRACKED_ACTIONS := [
	"left", "right", "up", "down",
	"shoot_left", "shoot_right", "shoot_up", "shoot_down",
	"shark_fire", "shark_fire_mouse", "fish_frenzy", "secondary_ability"
]

var mode: int = Mode.ANY
var device_id: int = -1

# SPECIFIC-mode tracked state.
var _strength := {}
var _pressed := {}
var _just_pressed := {}


func _init(input_mode: int = Mode.ANY, id: int = -1):
	mode = input_mode
	device_id = id
	for a in TRACKED_ACTIONS:
		_strength[a] = 0.0
		_pressed[a] = false
		_just_pressed[a] = false


# Whether this player owns the mouse (used for mouse aiming/firing). In ANY
# mode the single player owns it; in SPECIFIC only the keyboard player does.
func uses_mouse() -> bool:
	return mode == Mode.ANY or device_id == KEYBOARD_DEVICE


func _event_is_mine(event: InputEvent) -> bool:
	var is_keyboard_or_mouse = (
		event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion
	)
	if is_keyboard_or_mouse:
		return device_id == KEYBOARD_DEVICE
	# Joypad event.
	return event.get_device() == device_id


# Call from the owner's _input(event). No-op in ANY mode.
func feed_event(event: InputEvent) -> void:
	if mode != Mode.SPECIFIC:
		return
	if not _event_is_mine(event):
		return

	for a in TRACKED_ACTIONS:
		if event.is_action(a):
			var now_pressed = event.is_action_pressed(a)
			if now_pressed and not _pressed[a]:
				_just_pressed[a] = true
			_strength[a] = event.get_action_strength(a)
			_pressed[a] = now_pressed


func get_move_vector() -> Vector2:
	if mode == Mode.ANY:
		return Input.get_vector("left", "right", "up", "down")
	var v = Vector2(_strength["right"] - _strength["left"], _strength["down"] - _strength["up"])
	return v if v.length() <= 1.0 else v.normalized()


func get_aim_vector() -> Vector2:
	if mode == Mode.ANY:
		return Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")
	var v = Vector2(
		_strength["shoot_right"] - _strength["shoot_left"],
		_strength["shoot_down"] - _strength["shoot_up"]
	)
	return v if v.length() <= 1.0 else v.normalized()


func get_strength(action: String) -> float:
	if mode == Mode.ANY:
		return Input.get_action_strength(action)
	return _strength.get(action, 0.0)


func is_pressed(action: String) -> bool:
	if mode == Mode.ANY:
		return Input.is_action_pressed(action)
	return _pressed.get(action, false)


# Edge-triggered. In SPECIFIC mode the flag is consumed on read, so this must be
# called at most once per frame per action (matching Input.is_action_just_pressed
# usage).
func is_just_pressed(action: String) -> bool:
	if mode == Mode.ANY:
		return Input.is_action_just_pressed(action)
	if _just_pressed.get(action, false):
		_just_pressed[action] = false
		return true
	return false
