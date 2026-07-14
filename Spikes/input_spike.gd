extends Control

# Throwaway spike to validate the couch co-op input model. Not wired into the
# game. Run this scene directly (F6 in the editor with it open).
#
# Controls:
#   TAB   - cycle through the three configurations below.
#     0. 1-PLAYER (ANY)          keyboard AND controller both drive P1.
#     1. 2-PLAYER kbd + gamepad  keyboard/mouse -> P1, gamepad 0 -> P2.
#     2. 2-PLAYER two gamepads   gamepad 0 -> P1, gamepad 1 -> P2.
#   In every 2P config, devices must not bleed between P1 and P2.

enum Config { ONE_PLAYER, KBD_AND_PAD, TWO_PADS }

var p1: PlayerInput
var p2: PlayerInput
var config: int = Config.ONE_PLAYER

@onready var label: Label = $Label


func _ready():
	_rebuild_players()


func _rebuild_players():
	match config:
		Config.ONE_PLAYER:
			p1 = PlayerInput.new(PlayerInput.Mode.ANY)
			p2 = null
		Config.KBD_AND_PAD:
			p1 = PlayerInput.new(PlayerInput.Mode.SPECIFIC, PlayerInput.KEYBOARD_DEVICE)
			p2 = PlayerInput.new(PlayerInput.Mode.SPECIFIC, 0)  # gamepad 0
		Config.TWO_PADS:
			p1 = PlayerInput.new(PlayerInput.Mode.SPECIFIC, 0)  # gamepad 0
			p2 = PlayerInput.new(PlayerInput.Mode.SPECIFIC, 1)  # gamepad 1


func _config_name() -> String:
	match config:
		Config.ONE_PLAYER:
			return "1-PLAYER (any device)"
		Config.KBD_AND_PAD:
			return "2-PLAYER (keyboard=P1, gamepad 0=P2)"
		Config.TWO_PADS:
			return "2-PLAYER (gamepad 0=P1, gamepad 1=P2)"
	return "?"


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		config = (config + 1) % Config.keys().size()
		_rebuild_players()
		return

	# Feed events to SPECIFIC-mode players.
	if p1:
		p1.feed_event(event)
	if p2:
		p2.feed_event(event)


func _process(_delta):
	var pads = Input.get_connected_joypads()
	var text = "INPUT SPIKE  [TAB to cycle config]\n"
	text += "Config: %s\n" % _config_name()
	text += "Connected joypads: %s\n\n" % str(pads)

	text += "P1  move=%s aim=%s fire=%s frenzy=%s\n" % [
		_fmt(p1.get_move_vector()),
		_fmt(p1.get_aim_vector()),
		p1.is_firing(),
		p1.is_pressed("fish_frenzy"),
	]

	if p2:
		text += "P2  move=%s aim=%s fire=%s frenzy=%s\n" % [
			_fmt(p2.get_move_vector()),
			_fmt(p2.get_aim_vector()),
			p2.is_firing(),
			p2.is_pressed("fish_frenzy"),
		]
	else:
		text += "P2  (inactive in 1-player mode)\n"

	label.text = text


func _fmt(v: Vector2) -> String:
	return "(%+.2f,%+.2f)" % [v.x, v.y]
