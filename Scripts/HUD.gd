extends Control

signal upgrade_button_pressed(button_number)

const POWERUP_BAR_SEQUENCE = ["SPEED UP", "FAST SPRAY", "BIG SPRAY", "GRENADE", "MINI SHARK"]

var powerup_index = 0

# Player 2's powerup bar (a runtime clone of player 1's authored container),
# created by add_second_powerup_bar() when a second player is present.
var powerup_container_2 = null


# Called when the node enters the scene tree for the first time.
func _ready():
	powerup_index = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


# Create player 2's powerup bar by cloning player 1's, anchored bottom-right.
# Safe to call more than once.
func add_second_powerup_bar():
	if powerup_container_2 != null:
		return
	powerup_container_2 = $CanvasLayer/PowerUpContainer.duplicate()
	powerup_container_2.name = "PowerUpContainer2"
	# Bottom-right (mirrors player 1's bottom-left).
	powerup_container_2.anchor_left = 1.0
	powerup_container_2.anchor_right = 1.0
	powerup_container_2.offset_left = -500.0
	powerup_container_2.offset_right = -20.0
	powerup_container_2.grow_horizontal = 0
	$CanvasLayer.add_child(powerup_container_2)


func remove_second_powerup_bar():
	if powerup_container_2 != null:
		powerup_container_2.queue_free()
		powerup_container_2 = null


# The powerup container for the given player: player 1 uses the authored one,
# player 2 its clone. Falls back to player 1's container.
func container_for(player):
	if powerup_container_2 != null and player != get_parent().get_primary_player():
		return powerup_container_2
	return $CanvasLayer/PowerUpContainer


func activate_powerup(player, powerup):
	var single_powerup = container_for(player).get_node(powerup)

	single_powerup.get_node("Label/ProgressBar").value = (
		single_powerup.get_node("Label/ProgressBar").max_value
	)
	single_powerup.get_node("Label/ProgressBar").visible = true
	single_powerup.visible = true


func deactivate_powerup(player, powerup):
	var single_powerup = container_for(player).get_node(powerup)

	single_powerup.get_node("Label/ProgressBar").value = (
		single_powerup.get_node("Label/ProgressBar").max_value
	)
	single_powerup.get_node("Label/ProgressBar").visible = false
	single_powerup.visible = false


func show_powerup_bar():
	$CanvasLayer/PowerUpContainer.visible = true
	if powerup_container_2 != null:
		powerup_container_2.visible = true


func hide_powerup_bar():
	$CanvasLayer/PowerUpContainer.visible = false
	if powerup_container_2 != null:
		powerup_container_2.visible = false


func reset_powerup_bar():
	powerup_index = 0

	for container in _all_containers():
		for single_powerup in container.get_children():
			single_powerup.visible = false
			single_powerup.get_node("Label/ProgressBar").max_value = constants.POWERUP_ACTIVE_DURATION


func reset_powerup_bar_text():
	for container in _all_containers():
		for single_powerup in container.get_children():
			single_powerup.get_node("Label").text = single_powerup.name


func reset_powerup_bar_durations(player):
	var duration_percentage = player.upgrades["MORE POWER"][0] * 20
	var duration = int(
		(
			constants.POWERUP_ACTIVE_DURATION
			+ ((duration_percentage / 100.0) * constants.POWERUP_ACTIVE_DURATION)
		)
	)

	for single_powerup in container_for(player).get_children():
		single_powerup.get_node("Label/ProgressBar").max_value = duration


func set_powerup_level(player, powerup, level):
	var text = " " + str(level)

	if level == 0:
		text = ""

	if level == player.max_powerup_levels[powerup]:
		text = " MAX"

	var single_powerup = container_for(player).get_node(powerup)
	single_powerup.get_node("Label").text = powerup + text


func set_all_powerup_levels(player):
	for powerup in POWERUP_BAR_SEQUENCE:
		set_powerup_level(player, powerup, player.current_powerup_levels[powerup])


# Every powerup container currently present (player 1, and player 2 if spawned).
func _all_containers():
	var containers = [$CanvasLayer/PowerUpContainer]
	if powerup_container_2 != null:
		containers.append(powerup_container_2)
	return containers


func _on_upgrade_button_pressed(button_number):
	upgrade_button_pressed.emit(button_number)


func update_upgrade_summary():

	var sidebar_text = ""
	var upgrades = get_parent().get_primary_player().upgrades

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
