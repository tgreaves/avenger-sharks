extends Control

signal upgrade_button_pressed(button_number)

const POWERUP_BAR_SEQUENCE = ["SPEED UP", "FAST SPRAY", "BIG SPRAY", "GRENADE", "MINI SHARK"]

var powerup_index = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	powerup_index = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func activate_powerup(powerup):
	var single_powerup = $CanvasLayer/PowerUpContainer.get_node(powerup)

	single_powerup.get_node("Label/ProgressBar").value = (
		single_powerup.get_node("Label/ProgressBar").max_value
	)
	single_powerup.get_node("Label/ProgressBar").visible = true
	single_powerup.visible = true


func deactivate_powerup(powerup):
	var single_powerup = $CanvasLayer/PowerUpContainer.get_node(powerup)

	single_powerup.get_node("Label/ProgressBar").value = (
		single_powerup.get_node("Label/ProgressBar").max_value
	)
	single_powerup.get_node("Label/ProgressBar").visible = false
	single_powerup.visible = false


func show_powerup_bar():
	$CanvasLayer/PowerUpContainer.visible = true


func hide_powerup_bar():
	$CanvasLayer/PowerUpContainer.visible = false


func reset_powerup_bar():
	powerup_index = 0

	for single_powerup in $CanvasLayer/PowerUpContainer.get_children():
		single_powerup.visible = false
		single_powerup.get_node("Label/ProgressBar").max_value = constants.POWERUP_ACTIVE_DURATION


func reset_powerup_bar_text():
	for single_powerup in $CanvasLayer/PowerUpContainer.get_children():
		single_powerup.get_node("Label").text = single_powerup.name


func reset_powerup_bar_durations():
	var duration_percentage = get_parent().get_node("Player").upgrades["MORE POWER"][0] * 20
	var duration = int(
		(
			constants.POWERUP_ACTIVE_DURATION
			+ ((duration_percentage / 100.0) * constants.POWERUP_ACTIVE_DURATION)
		)
	)

	for single_powerup in $CanvasLayer/PowerUpContainer.get_children():
		single_powerup.get_node("Label/ProgressBar").max_value = duration


func set_powerup_level(powerup, level):
	var text = " " + str(level)

	if level == 0:
		text = ""

	if level == get_parent().get_node("Player").max_powerup_levels[powerup]:
		text = " MAX"

	var single_powerup = $CanvasLayer/PowerUpContainer.get_node(powerup)
	single_powerup.get_node("Label").text = powerup + text


func set_all_powerup_levels():
	for powerup in POWERUP_BAR_SEQUENCE:
		set_powerup_level(powerup, get_parent().get_node("Player").current_powerup_levels[powerup])


func _on_upgrade_button_pressed(button_number):
	upgrade_button_pressed.emit(button_number)


func update_upgrade_summary():

	var sidebar_text = ""
	var upgrades = get_parent().get_node("Player").upgrades

	for single_upgrade in upgrades:
		if upgrades[single_upgrade][0] > 0:
			if upgrades[single_upgrade][1] > 1:
				# Upgrade has multiple levels.
				sidebar_text += single_upgrade + " " + str(upgrades[single_upgrade][0])
			else:
				# Upgrade has one level (i.e. is either on or off)
				sidebar_text += single_upgrade

			sidebar_text += "\n"

	$CanvasLayer/UpgradeSummary.text = sidebar_text


func flash_screen_red():
	var tween = get_tree().create_tween()
	tween.tween_property($CanvasLayer/DamageRect, "visible", true, 0)
	tween.tween_property($CanvasLayer/DamageRect, "modulate", Color(1, 1, 1, 1), 0.10)
	tween.tween_property($CanvasLayer/DamageRect, "modulate", Color(0, 0, 0, 0), 0.10)
	tween.tween_property($CanvasLayer/DamageRect, "visible", false, 0)


func boss_health_reveal():
	$CanvasLayer/BossHealthBar.max_value = TheDirector.wave_design.get("boss_health")
	$CanvasLayer/BossHealthBar.value = 0

	var tween = get_tree().create_tween()
	tween.tween_property(
		$CanvasLayer/BossHealthBar, "value", TheDirector.wave_design.get("boss_health"), 2.0
	)

	$CanvasLayer/BossHealthBar.visible = true
