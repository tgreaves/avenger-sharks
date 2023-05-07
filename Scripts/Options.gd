extends Control

signal options_return_button_pressed

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func build_options_screen():
    if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
        $CanvasLayer/MainMenuContainer/HBoxContainer/ScreenModeSetting.text = 'FULL SCREEN'
    else:
        $CanvasLayer/MainMenuContainer/HBoxContainer/ScreenModeSetting.text = 'WINDOWED'

func _on_return_button_pressed():
    emit_signal('options_return_button_pressed')

func _on_screen_mode_button_pressed():
    if $CanvasLayer/MainMenuContainer/HBoxContainer/ScreenModeSetting.text == 'FULL SCREEN':
        $CanvasLayer/MainMenuContainer/HBoxContainer/ScreenModeSetting.text = 'WINDOWED'
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        get_window().size = constants.WINDOW_SIZE
        Storage.Config.set_value('config','screen_mode','WINDOWED')
    else:
        $CanvasLayer/MainMenuContainer/HBoxContainer/ScreenModeSetting.text = 'FULL SCREEN'
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        Storage.Config.set_value('config','screen_mode','FULL_SCREEN')

