extends Control

signal statistics_return_button_pressed


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func build_statistics_screen():
	$CanvasLayer/VBoxContainer/ReturnButton.grab_focus()

	$CanvasLayer/VBoxContainer/HBoxContainer/StatisticName.text = ""
	$CanvasLayer/VBoxContainer/HBoxContainer/StatisticValue.text = ""

	add_statistic("Games Played", Storage.Stats.get_value("player", "games_played", 0))
	add_statistic("Furthest Wave Reached", Storage.Stats.get_value("player", "furthest_wave", 0))
	add_statistic("Shots Fired", Storage.Stats.get_value("player", "shots_fired", 0))
	add_statistic("Enemies Defeated", Storage.Stats.get_value("player", "enemies_defeated", 0))
	add_statistic("Fish Rescued", Storage.Stats.get_value("player", "fish_rescued", 0))


func add_statistic(stat_name, stat_value):
	$CanvasLayer/VBoxContainer/HBoxContainer/StatisticName.text += stat_name + "\n"
	$CanvasLayer/VBoxContainer/HBoxContainer/StatisticValue.text += str(stat_value) + "\n"


func _on_return_button_pressed():
	emit_signal("statistics_return_button_pressed")
