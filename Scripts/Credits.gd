extends Control

# Called when the node enters the scene tree for the first time.
func _ready():
    var file = FileAccess.open("res://CREDITS.txt", FileAccess.READ)
    var content = file.get_as_text()
    
    $CanvasLayer/Label.text = content
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    $CanvasLayer/Label.position.y = $CanvasLayer/Label.position.y - 2
