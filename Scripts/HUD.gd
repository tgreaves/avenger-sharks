extends Control

var PowerUpBarSequence = [  'SPEEDUP',
                            'FAST SPRAY',
                            'BIG SPRAY',
                            'MINI SHARK']

var PowerUpIndex = 0;

# Called when the node enters the scene tree for the first time.
func _ready():
    PowerUpIndex = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func chest_collected():

    PowerUpIndex += 1
    
    if PowerUpIndex > PowerUpBarSequence.size():
        PowerUpIndex = 1
    
    match PowerUpIndex:
        1:
            $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ColorRect.visible = true
            $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ColorRect.visible = false
        2:
            $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ColorRect.visible = true
            $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ColorRect.visible = false
        3:
            $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ColorRect.visible = true
            $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ColorRect.visible = false
        4:
            $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ColorRect.visible = true
            $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ColorRect.visible = false
            
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
    
    $CanvasLayer/PowerUpContainer/SpeedUpContainer/SpeedUp/ColorRect.visible = false
    $CanvasLayer/PowerUpContainer/FastSprayContainer/FastSpray/ColorRect.visible = false
    $CanvasLayer/PowerUpContainer/BigSprayContainer/BigSpray/ColorRect.visible = false
    $CanvasLayer/PowerUpContainer/MiniSharkContainer/MiniShark/ColorRect.visible = false

func reset_powerup_bar_text():
    
    $CanvasLayer/PowerUpContainer/SpeedUpContainer/Label.text = ""
    $CanvasLayer/PowerUpContainer/FastSprayContainer/Label.text = ""
    $CanvasLayer/PowerUpContainer/BigSprayContainer/Label.text = ""
    $CanvasLayer/PowerUpContainer/MiniSharkContainer/Label.text = ""

func set_powerup_level(powerup, level):
    
    var text = "LEVEL " + str(level)
    
    if level == get_parent().get_node('Player').max_powerup_levels[powerup]:
        text = "LEVEL MAX"
    
    match powerup:
        'SPEEDUP':
            $CanvasLayer/PowerUpContainer/SpeedUpContainer/Label.text = text
        'FAST SPRAY':
            $CanvasLayer/PowerUpContainer/FastSprayContainer/Label.text = text
        'BIG SPRAY':
            $CanvasLayer/PowerUpContainer/BigSprayContainer/Label.text = text
        'MINI SHARK':
            $CanvasLayer/PowerUpContainer/MiniSharkContainer/Label.text = text
    
