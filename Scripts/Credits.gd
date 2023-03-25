extends Control

# Called when the node enters the scene tree for the first time.
func _ready():
    pass
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    $CanvasLayer/Label.position.y = $CanvasLayer/Label.position.y - 2
