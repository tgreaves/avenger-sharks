extends Node2D

enum {
    FADE_IN,
}

var state

# Called when the node enters the scene tree for the first time.
func _ready():
    state = FADE_IN
    
    $StateTimer.start(5)
    
    $CanvasLayer/DedicationContainer.set_modulate(Color(0,0,0,0))
    var tween = get_tree().create_tween()
    tween.tween_property($CanvasLayer/DedicationContainer, "modulate", Color(1,1,1,1), 1.0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match state:
        FADE_IN:
            if $StateTimer.time_left == 0:
                get_parent().dedication_has_finished()
