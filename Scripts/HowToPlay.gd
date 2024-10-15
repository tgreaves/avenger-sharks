extends Control

signal how_to_play_return_button_pressed


# Called when the node enters the scene tree for the first time.
func _ready():
	pass  # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_return_button_pressed():
	how_to_play_return_button_pressed.emit()
