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
            $CanvasLayer/PowerUpContainer/SpeedUp/ColorRect.visible = true
            $CanvasLayer/PowerUpContainer/MiniShark/ColorRect.visible = false
        2:
            $CanvasLayer/PowerUpContainer/FastSpray/ColorRect.visible = true
            $CanvasLayer/PowerUpContainer/SpeedUp/ColorRect.visible = false
        3:
            $CanvasLayer/PowerUpContainer/BigSpray/ColorRect.visible = true
            $CanvasLayer/PowerUpContainer/FastSpray/ColorRect.visible = false
        4:
            $CanvasLayer/PowerUpContainer/MiniShark/ColorRect.visible = true
            $CanvasLayer/PowerUpContainer/BigSpray/ColorRect.visible = false
            
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
    
    $CanvasLayer/PowerUpContainer/SpeedUp/ColorRect.visible = false
    $CanvasLayer/PowerUpContainer/FastSpray/ColorRect.visible = false
    $CanvasLayer/PowerUpContainer/BigSpray/ColorRect.visible = false
    $CanvasLayer/PowerUpContainer/MiniShark/ColorRect.visible = false

