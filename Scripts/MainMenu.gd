extends Control

signal start_game_pressed
signal exit_game_pressed
signal credits_pressed
signal cheats_pressed
signal game_mode_pressed
signal statistics_pressed
signal options_pressed
signal how_to_play_pressed


# Called when the node enters the scene tree for the first time.
func _ready():
	$CanvasLayer/MainMenuContainer/StartGame.grab_focus()
	$CanvasLayer/VersionLabel.text = "Version " + constants.GAME_VERSION

	if OS.has_feature("steam"):
		$CanvasLayer/VersionLabel.text += " (Steam)"

	if constants.DEV_STEAM_TESTING:
		$CanvasLayer/VersionLabel.text += " (Steam Dev Test)"

	# Disable Statistics and Exit Game for web version.
	if OS.has_feature("web"):
		$CanvasLayer/MainMenuContainer/Statistics.visible = false
		$CanvasLayer/MainMenuContainer/Options.visible = false
		$CanvasLayer/MainMenuContainer/ExitGame.visible = false

func do_ready():
	_ready()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _input(_ev):
	if Input.is_action_just_pressed("cheat") and constants.DEV_ALLOW_CHEATS:
		$CanvasLayer/MainMenuContainer/TitleLabel.text = "CHEAT SHARKS!\n\nBy Tristan Greaves"
		cheats_pressed.emit()

func _on_start_game_pressed():
	start_game_pressed.emit()

func _on_exit_game_pressed():
	exit_game_pressed.emit()

func _on_credits_pressed():
	credits_pressed.emit()

func _on_game_mode_pressed():
	game_mode_pressed.emit()

func _on_statistics_pressed():
	statistics_pressed.emit()

func _on_options_pressed():
	options_pressed.emit()

func _on_how_to_play_pressed():
	how_to_play_pressed.emit()  
