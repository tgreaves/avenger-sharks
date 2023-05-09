extends Control

var PowerUpBarSequence = [  'SPEEDUP',
                            'FAST SPRAY',
                            'BIG SPRAY',
                            'GRENADE',
                            'MINI SHARK']

var PowerUpIndex = 0;

signal upgrade_button_pressed(button_number)

# Called when the node enters the scene tree for the first time.
func _ready():
    PowerUpIndex = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func activate_powerup(powerup):
    match powerup:
        'SPEEDUP':
            $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.value = $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.max_value
            $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.visible = true
            $CanvasLayer/PowerUpContainer/SpeedUpContainer.visible = true
        'FAST SPRAY':
            $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.value = $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.max_value
            $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.visible = true
            $CanvasLayer/PowerUpContainer/FastSprayContainer.visible = true
        'BIG SPRAY':
            $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.value = $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.max_value 
            $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.visible = true
            $CanvasLayer/PowerUpContainer/BigSprayContainer.visible = true
        'GRENADE':
            $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade/ProgressBar.value = $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade/ProgressBar.max_value 
            $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade/ProgressBar.visible = true
            $CanvasLayer/PowerUpContainer/GrenadeContainer.visible = true
        'MINI SHARK':
            $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.value =   $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.max_value
            $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.visible = true
            $CanvasLayer/PowerUpContainer/MiniSharkContainer.visible = true

func deactivate_powerup(powerup):
    match powerup:
        'SPEEDUP':
            $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.value = $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.max_value
            $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.visible = false
            $CanvasLayer/PowerUpContainer/SpeedUpContainer.visible = false
        'FAST SPRAY':
            $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.value = $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.max_value
            $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.visible = false
            $CanvasLayer/PowerUpContainer/FastSprayContainer.visible = false
        'BIG SPRAY':
            $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.value = $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.max_value 
            $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.visible = false
            $CanvasLayer/PowerUpContainer/BigSprayContainer.visible = false
        'GRENADE':
            $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade/ProgressBar.value = $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade/ProgressBar.max_value 
            $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade/ProgressBar.visible = false
            $CanvasLayer/PowerUpContainer/GrenadeContainer.visible = false
        'MINI SHARK':
            $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.value =   $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.max_value
            $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.visible = false    
            $CanvasLayer/PowerUpContainer/MiniSharkContainer.visible = false
       
func get_selected_powerup():
    if PowerUpIndex == 0:
        return 'NIL'
        
    return PowerUpBarSequence[ PowerUpIndex-1 ]

func show_powerup_bar():
    $CanvasLayer/PowerUpContainer.visible = true

func hide_powerup_bar():
    $CanvasLayer/PowerUpContainer.visible = false
 
func reset_powerup_bar():
    PowerUpIndex = 0
    
    $CanvasLayer/PowerUpContainer/SpeedUpContainer.visible = false
    $CanvasLayer/PowerUpContainer/FastSprayContainer.visible = false
    $CanvasLayer/PowerUpContainer/BigSprayContainer.visible = false
    $CanvasLayer/PowerUpContainer/GrenadeContainer.visible = false
    $CanvasLayer/PowerUpContainer/MiniSharkContainer.visible = false
    
    #$CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.visible = false
    #$CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.visible = false
    #$CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.visible = false
    #$CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.visible = false
    
    $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.max_value = constants.POWERUP_ACTIVE_DURATION
    $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.max_value = constants.POWERUP_ACTIVE_DURATION
    $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.max_value = constants.POWERUP_ACTIVE_DURATION
    $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade/ProgressBar.max_value = constants.POWERUP_ACTIVE_DURATION
    $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.max_value = constants.POWERUP_ACTIVE_DURATION

func reset_powerup_bar_text():
    
    $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp.text = "SPEED UP"
    $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray.text = "FAST SPRAY"
    $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray.text = "BIG SPRAY"
    $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade.text = "GRENADE"
    $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark.text = "MINI SHARK"

func reset_powerup_bar_durations():
    var duration_percentage = get_parent().get_node('Player').upgrades['MORE POWER'][0] * 20
    var duration = int(constants.POWERUP_ACTIVE_DURATION + ((duration_percentage / 100.0) * constants.POWERUP_ACTIVE_DURATION))
                            
    $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ProgressBar.max_value = duration
    $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ProgressBar.max_value = duration
    $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ProgressBar.max_value = duration
    $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade/ProgressBar.max_value = duration
    $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ProgressBar.max_value = duration

func set_powerup_level(powerup, level):
    var text = " " + str(level)
    
    if level == 0:
        text=""
    
    if level == get_parent().get_node('Player').max_powerup_levels[powerup]:
        text = " MAX"
    
    match powerup:
        'SPEEDUP':
            $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp.text = "SPEED-UP" + text
        'FAST SPRAY':
            $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray.text = "FAST SPRAY" + text
        'BIG SPRAY':
            $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray.text = "BIG SPRAY" + text
        'GRENADE':
            $CanvasLayer/PowerUpContainer/GrenadeContainer/Grenade.text = "GRENADE" + text
        'MINI SHARK':
            $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark.text = "MINI SHARK" + text
    
func set_all_powerup_levels():
    for powerup in PowerUpBarSequence:
        set_powerup_level(powerup, get_parent().get_node('Player').current_powerup_levels[powerup])
        
func _on_upgrade_button_pressed(button_number):
    emit_signal("upgrade_button_pressed", button_number)
    
func update_upgrade_summary():
#        'MAGNET':           [ 0, 1, 'res://Images/crosshair184.png', 'A powerful magnet which does magnet things.'],
#        'ARMOUR':           [ 0, 3, 'res://Images/crosshair184.png', 'Decrease incoming damage by 10%'],

    var sidebar_text = ""
    var upgrades = get_parent().get_node('Player').upgrades
    
    for single_upgrade in upgrades:
        if upgrades[single_upgrade][0]:
            if upgrades[single_upgrade][1] > 1:
                # Upgrade has multiple levels.
                sidebar_text += single_upgrade + " " + str(upgrades[single_upgrade][0])
            else:
                # Upgrade has one level (i.e. is either on or off)
                sidebar_text += single_upgrade
        
            sidebar_text += "\n"
        
    $CanvasLayer/UpgradeSummary.text = sidebar_text
