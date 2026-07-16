extends Control


const POWERUP_BAR_SEQUENCE = ["SPEED UP", "FAST SPRAY", "BIG SPRAY", "GRENADE", "MINI SHARK"]

var powerup_index = 0

# Player 2's powerup bar (a runtime clone of player 1's authored container),
# created by add_second_powerup_bar() when a second player is present.
var powerup_container_2 = null


# Called when the node enters the scene tree for the first time.
func _ready():
	powerup_index = 0
	# The upgrade header only shows with the upgrade screen.
	$CanvasLayer/UpgradeHeader.visible = false


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


# --- Upgrade choice screen (manual, per-player) ---
#
# Player 1 uses the authored UpgradeChoiceContainer (a centred vertical column of
# Choice1/2/3). Player 2 (2-player) gets a runtime clone positioned to the right,
# with player 1's column shifted left. Highlight is a manual modulate on the
# chosen Choice; there is no Godot focus or Button hover involved.

const UPGRADE_HIGHLIGHT = Color(1, 1, 0.4, 1)   # Highlighted choice tint.
const UPGRADE_DIM = Color(0.6, 0.6, 0.6, 1)     # Non-highlighted choices.
const UPGRADE_CONFIRMED = Color(0.4, 1, 0.4, 1)  # Locked-in choice.

var upgrade_container_2 = null


func _upgrade_container(player):
	if upgrade_container_2 != null and player != get_parent().get_primary_player():
		return upgrade_container_2
	return $CanvasLayer/UpgradeChoiceContainer


# Show the upgrade screen for the given players, filling each column with that
# player's offered upgrades. Adds/removes a second column to match player count.
func show_upgrade_screen(players):
	var one_column = players.size() < 2

	if one_column:
		_remove_upgrade_column_2()
		# Centre player 1's column.
		var c = $CanvasLayer/UpgradeChoiceContainer
		c.offset_left = -320.0
		c.offset_right = 320.0
	else:
		_add_upgrade_column_2()
		# Player 1 left, player 2 right.
		var c1 = $CanvasLayer/UpgradeChoiceContainer
		c1.offset_left = -700.0
		c1.offset_right = -60.0
		upgrade_container_2.offset_left = 60.0
		upgrade_container_2.offset_right = 700.0

	for player in players:
		_fill_upgrade_column(player)

	$CanvasLayer/UpgradeHeader.visible = true
	$CanvasLayer/UpgradeChoiceContainer.visible = true
	if upgrade_container_2 != null:
		upgrade_container_2.visible = true


func hide_upgrade_screen():
	$CanvasLayer/UpgradeHeader.visible = false
	$CanvasLayer/UpgradeChoiceContainer.visible = false
	if upgrade_container_2 != null:
		upgrade_container_2.visible = false


func _add_upgrade_column_2():
	if upgrade_container_2 != null:
		return
	upgrade_container_2 = $CanvasLayer/UpgradeChoiceContainer.duplicate()
	upgrade_container_2.name = "UpgradeChoiceContainer2"
	$CanvasLayer.add_child(upgrade_container_2)


func _remove_upgrade_column_2():
	if upgrade_container_2 != null:
		upgrade_container_2.queue_free()
		upgrade_container_2 = null


# Fill a player's column from its offered_upgrades and reset its highlight.
func _fill_upgrade_column(player):
	var container = _upgrade_container(player)
	var i = 0
	for code in player.offered_upgrades:
		var choice = container.get_node("Choice" + str(i + 1))
		choice.get_node("TextureRect").texture = load(player.upgrades[code][2])
		choice.get_node("Title").text = code
		choice.get_node("Description").text = player.upgrades[code][3]
		i += 1
	set_upgrade_highlight(player, player.upgrade_cursor)


# Tint the choices so the highlighted one stands out (or all-confirmed green).
func set_upgrade_highlight(player, cursor):
	var container = _upgrade_container(player)
	for i in range(3):
		var choice = container.get_node("Choice" + str(i + 1))
		if player.upgrade_confirmed:
			choice.modulate = UPGRADE_CONFIRMED if i == cursor else UPGRADE_DIM
		else:
			choice.modulate = UPGRADE_HIGHLIGHT if i == cursor else UPGRADE_DIM


# Flash the just-confirmed choice a few times as visual confirmation, then leave
# it on the locked-in (confirmed) tint.
func flash_upgrade_choice(player, cursor):
	var choice = _upgrade_container(player).get_node("Choice" + str(cursor + 1))
	var tween = create_tween()
	for i in range(3):
		tween.tween_property(choice, "modulate", Color(1, 1, 1, 1), 0.08)
		tween.tween_property(choice, "modulate", UPGRADE_CONFIRMED, 0.08)


# Which choice index (0..2) the mouse is currently over in this player's column,
# or -1 if none. Only meaningful for the mouse-owning player.
func upgrade_choice_at_mouse(player):
	var container = _upgrade_container(player)
	for i in range(3):
		var choice = container.get_node("Choice" + str(i + 1))
		if choice.get_global_rect().has_point(choice.get_global_mouse_position()):
			return i
	return -1


# Player 2's upgrade summary (a runtime clone of player 1's authored label,
# anchored on the right), created with the second player.
var upgrade_summary_2 = null


func add_second_upgrade_summary():
	if upgrade_summary_2 != null:
		return
	upgrade_summary_2 = $CanvasLayer/UpgradeSummary.duplicate()
	upgrade_summary_2.name = "UpgradeSummary2"
	# Right side (player 1's summary stays on the left). Pushed below the P2
	# score label (which occupies the right slot in 2-player-human).
	upgrade_summary_2.anchor_left = 1.0
	upgrade_summary_2.anchor_right = 1.0
	upgrade_summary_2.offset_left = -658.0
	upgrade_summary_2.offset_right = -6.0
	upgrade_summary_2.offset_top = 280.0
	upgrade_summary_2.offset_bottom = 720.0
	upgrade_summary_2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$CanvasLayer.add_child(upgrade_summary_2)


func remove_second_upgrade_summary():
	if upgrade_summary_2 != null:
		upgrade_summary_2.queue_free()
		upgrade_summary_2 = null


# Show/hide both players' upgrade summaries together.
# Vertically position player 2's upgrade summary. In 2-player-human the right
# slot holds the P2 score, so the summary sits below it; in 2-player-CPU the slot
# holds HIGH SCORE (shorter), so it aligns with player 1's summary.
func set_second_upgrade_summary_top(offset_top):
	if upgrade_summary_2 == null:
		return
	var height = upgrade_summary_2.offset_bottom - upgrade_summary_2.offset_top
	upgrade_summary_2.offset_top = offset_top
	upgrade_summary_2.offset_bottom = offset_top + height


func set_upgrade_summary_visible(is_visible):
	$CanvasLayer/UpgradeSummary.visible = is_visible
	if upgrade_summary_2 != null:
		upgrade_summary_2.visible = is_visible


func _upgrade_summary_label(player):
	if upgrade_summary_2 != null and player != get_parent().get_primary_player():
		return upgrade_summary_2
	return $CanvasLayer/UpgradeSummary


# Render the given shark's owned upgrades into its own summary label.
func update_upgrade_summary(player):
	var sidebar_text = ""
	var upgrades = player.upgrades

	for single_upgrade in upgrades:
		if upgrades[single_upgrade][0] > 0:
			if upgrades[single_upgrade][1] > 1:
				# Upgrade has multiple levels.
				sidebar_text += single_upgrade + " " + str(upgrades[single_upgrade][0])
			else:
				# Upgrade has one level (i.e. is either on or off)
				sidebar_text += single_upgrade

			sidebar_text += "\n"

	_upgrade_summary_label(player).text = sidebar_text


func flash_screen_red():
	var tween = get_tree().create_tween()
	tween.tween_property($CanvasLayer/DamageRect, "visible", true, 0)
	tween.tween_property($CanvasLayer/DamageRect, "modulate", Color(1, 1, 1, 1), 0.10)
	tween.tween_property($CanvasLayer/DamageRect, "modulate", Color(0, 0, 0, 0), 0.10)
	tween.tween_property($CanvasLayer/DamageRect, "visible", false, 0)


func boss_health_reveal():
	# Reveal animates the bar filling up to the spawned boss's actual
	# (player-count-scaled) health.
	var full = get_parent().boss.boss_max_health
	$CanvasLayer/BossHealthBar.max_value = full
	$CanvasLayer/BossHealthBar.value = 0

	var tween = get_tree().create_tween()
	tween.tween_property($CanvasLayer/BossHealthBar, "value", full, 2.0)

	$CanvasLayer/BossHealthBar.visible = true


# Update the boss health bar as the boss takes damage.
func update_boss_health(current_health, max_health):
	$CanvasLayer/BossHealthBar.max_value = max_health
	$CanvasLayer/BossHealthBar.value = current_health
