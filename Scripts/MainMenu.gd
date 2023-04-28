extends Control

signal start_game_pressed
signal exit_game_pressed
signal credits_pressed
signal cheats_pressed
signal game_mode_pressed

# Called when the node enters the scene tree for the first time.
func _ready():
    $CanvasLayer/MainMenuContainer/StartGame.grab_focus()
    $CanvasLayer/VersionLabel.text = "Version " + constants.GAME_VERSION
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func _input(_ev):
    if Input.is_action_just_pressed('cheat'):
        $CanvasLayer/MainMenuContainer/TitleLabel.text = "CHEAT SHARKS!\n\nBy Tristan Greaves";
        emit_signal("cheats_pressed")

func _on_start_game_pressed():
    emit_signal('start_game_pressed')

func _on_exit_game_pressed():
    emit_signal('exit_game_pressed')

func _on_credits_pressed():
    emit_signal('credits_pressed')
    
func _on_game_mode_pressed():
    emit_signal('game_mode_pressed')
