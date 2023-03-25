extends Control

signal unpause_game_pressed
signal abandon_game_pressed

# Called when the node enters the scene tree for the first time.
func _ready():
    $CanvasLayer/PauseMenuContainer/UnpauseGame.grab_focus()
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

#func input(_ev):
#    if Input.is_action_just_pressed('start') or Input.is_action_just_pressed('quit'):
#        emit_signal('unpause_game_pressed')

func _on_unpause_game_pressed():
    emit_signal('unpause_game_pressed')

func _on_abandon_game_pressed():
    emit_signal('abandon_game_pressed')
