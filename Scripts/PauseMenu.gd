extends Control

signal unpause_game_pressed
signal abandon_game_pressed

var accept_pause

# Called when the node enters the scene tree for the first time.
func _ready():
    $AcceptPauseTimer.connect('timeout', _on_accept_pause_timer_timeout)
    
func pause():
    accept_pause = false
    $CanvasLayer/PauseMenuContainer/UnpauseGame.grab_focus()
    $AcceptPauseTimer.start()
        
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func _input(ev):
    if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
        DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
    else:
        DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)

    if !accept_pause:
        return

    if Input.is_action_just_pressed('start') or Input.is_action_just_pressed('quit'):
        Logging.log_entry("Signal")
        emit_signal('unpause_game_pressed')

func _on_unpause_game_pressed():
    emit_signal('unpause_game_pressed')

func _on_abandon_game_pressed():
    emit_signal('abandon_game_pressed')
    
func _on_accept_pause_timer_timeout():
    accept_pause = true
