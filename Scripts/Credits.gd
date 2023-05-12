extends Control

signal credits_return_button_pressed

enum {
    INACTIVE,
    ACTIVE
}

var scrolling = INACTIVE

# Called when the node enters the scene tree for the first time.
func _ready():
    var content = ""
    var i=0
    
    while (i < 30):
        content += '\n'
        i+=1
        
    var file = FileAccess.open("res://CREDITS.txt", FileAccess.READ)
    content += file.get_as_text()
    
    $CanvasLayer/VBoxContainer/ScrollContainer/Label.text = content

func commence_scroll():
    scrolling = ACTIVE
    $CanvasLayer/VBoxContainer/ScrollContainer.scroll_vertical = 0

func stop_scroll():
    scrolling = INACTIVE
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    
    if scrolling == ACTIVE:
        $CanvasLayer/VBoxContainer/ScrollContainer.scroll_vertical += 2

func _on_return_button_pressed():
    stop_scroll()
    emit_signal('credits_return_button_pressed')
