extends Control

signal options_return_button_pressed

var first_time_done = false

# Called when the node enters the scene tree for the first time.
func _ready():
    first_time_done = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func build_options_screen():
    if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
        $CanvasLayer/OptionsContainer/ScreenModeContainer/ScreenModeSetting.text = 'FULL SCREEN'
    else:
        $CanvasLayer/OptionsContainer/ScreenModeContainer/ScreenModeSetting.text = 'WINDOWED'

    $CanvasLayer/OptionsContainer/MasterVolumeContainer/MasterVolumeSetting.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index('Master')))
    $CanvasLayer/OptionsContainer/MusicVolumeContainer/MusicVolumeSetting.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index('Music')))
    $CanvasLayer/OptionsContainer/EffectsVolumeContainer/EffectsVolumeSetting.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index('Effects')))

func _on_return_button_pressed():
    emit_signal('options_return_button_pressed')

func _on_screen_mode_button_pressed():
    if $CanvasLayer/OptionsContainer/ScreenModeContainer/ScreenModeSetting.text == 'FULL SCREEN':
        $CanvasLayer/OptionsContainer/ScreenModeContainer/ScreenModeSetting.text = 'WINDOWED'
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        get_window().size = constants.WINDOW_SIZE
        Storage.Config.set_value('config','screen_mode','WINDOWED')
    else:
        $CanvasLayer/OptionsContainer/ScreenModeContainer/ScreenModeSetting.text = 'FULL SCREEN'
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        Storage.Config.set_value('config','screen_mode','FULL_SCREEN')

func _on_master_volume_setting_value_changed(value):
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Master'), linear_to_db(value))
    Storage.Config.set_value('config','master_volume',value)

func _on_music_volume_setting_value_changed(value):
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), linear_to_db(value))
    Storage.Config.set_value('config','music_volume',value)

func _on_effects_volume_setting_value_changed(value):
    if first_time_done == false:
        first_time_done=true
        return
    
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Effects'), linear_to_db(value))
    Storage.Config.set_value('config','effects_volume',value)
    get_parent().get_node('Player/AudioStreamPlayerSpray').play()
