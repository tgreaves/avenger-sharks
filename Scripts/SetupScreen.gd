extends Control

# Two-player device setup / join screen. Shown before a 2-player (human) game so
# each player can claim a device (keyboard/mouse or a gamepad) via press-to-join.
#
# Flow:
#   - Unclaimed device presses confirm -> takes the next free slot (P1 then P2).
#   - A claimed device presses back -> leaves its slot.
#   - Pressing back with no slots filled -> cancel, return to main menu.
#   - Once both slots are filled, confirm/start begins the game.

signal setup_confirmed(devices)   # [p1_device, p2_device] in slot order.
signal setup_cancelled

# Device id per slot; null = unclaimed. KEYBOARD_DEVICE for keyboard/mouse,
# otherwise the gamepad's device id.
var slots = [null, null]


func _ready():
	set_process_input(false)


# Reset to an empty lobby and start listening. Called by Main when the screen
# is shown.
func open():
	slots = [null, null]
	_refresh()
	set_process_input(true)


func close():
	set_process_input(false)


func _input(event):
	if _is_confirm(event):
		_handle_confirm(_device_of(event))
		get_viewport().set_input_as_handled()
	elif _is_back(event):
		_handle_back(_device_of(event))
		get_viewport().set_input_as_handled()


# A device pressed confirm: claim the next free slot, or start if both are full.
func _handle_confirm(device):
	if device in slots:
		if _both_claimed():
			setup_confirmed.emit([slots[0], slots[1]])
		return

	var free = slots.find(null)
	if free != -1:
		slots[free] = device
		_refresh()
		# Filling the last slot doesn't auto-start; players confirm once more.


# A device pressed back: leave its slot, or cancel if the lobby is empty.
func _handle_back(device):
	var index = slots.find(device)
	if index != -1:
		slots[index] = null
		_refresh()
	elif not _any_claimed():
		setup_cancelled.emit()


func _both_claimed():
	return slots[0] != null and slots[1] != null


func _any_claimed():
	return slots[0] != null or slots[1] != null


# The device id a raw input event came from (KEYBOARD_DEVICE for keyboard/mouse).
func _device_of(event):
	if event is InputEventJoypadButton:
		return event.get_device()
	return PlayerInput.KEYBOARD_DEVICE


func _is_confirm(event):
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ENTER or event.keycode == KEY_SPACE
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _is_back(event):
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE
	return false


# Human-readable label for a claimed device.
func _device_label(device):
	if device == PlayerInput.KEYBOARD_DEVICE:
		return "KEYBOARD + MOUSE"
	var pad_name = Input.get_joy_name(device)
	if pad_name == "":
		return "GAMEPAD " + str(device)
	return pad_name.to_upper()


func _refresh():
	for i in range(2):
		var status = get_node("CanvasLayer/SlotContainer/Player" + str(i + 1) + "/Status")
		if slots[i] == null:
			status.text = "PRESS A BUTTON\nTO JOIN"
		else:
			status.text = _device_label(slots[i])

	var hint = $CanvasLayer/Hint
	if _both_claimed():
		hint.text = "PRESS CONFIRM TO START   /   BACK TO LEAVE"
	else:
		hint.text = "BACK TO CANCEL"
