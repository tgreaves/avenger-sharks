extends Control

signal unpause_game_pressed
signal abandon_game_pressed

# Called when the node enters the scene tree for the first time.
func _ready():
    $CanvasLayer/PauseMenuContainer/UnpauseGame.grab_focus()
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func _input(ev):
    if ev is InputEventKey:
        DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
    else:
        DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)

func _on_unpause_game_pressed():
    emit_signal('unpause_game_pressed')

func _on_abandon_game_pressed():
    emit_signal('abandon_game_pressed')
