extends Node

const PlayerScene = preload("res://Scenes/Player.tscn")

# Offset of player 2's start position relative to player 1.
const PLAYER_2_START_OFFSET = Vector2(300, 0)

signal player_hunt_key
signal player_move_to_starting_position
signal player_enable_fish_frenzy
signal player_update_energy
signal player_update_fish

enum {
	DEDICATION,
	INTRO_SEQUENCE,
	MAIN_MENU,
	SETUP_SCREEN,
	CREDITS,
	STATISTICS,
	OPTIONS,
	HOW_TO_PLAY,
	WAVE_START,
	GAME_RUNNING,
	GAME_PAUSED,
	GETTING_KEY,
	CHEATING_DEATH_AT_WAVE_END,
	WAVE_END,
	UPGRADE_SCREEN,
	UPGRADE_WAITING_FOR_CHOICE,
	PREPARE_FOR_WAVE,
	GAME_OVER
}

@export var dedication_scene: PackedScene
@export var intro_scene: PackedScene
@export var enemy_scene: PackedScene
@export var fish_scene: PackedScene
@export var dinosaur_scene: PackedScene
@export var credits_scene: PackedScene
@export var item_scene: PackedScene
@export var statistics_scene: PackedScene
@export var artillery_scene: PackedScene
@export var game_status = INTRO_SEQUENCE
@export var cheat_mode = false
@export var wave_number = 1
@export var enemies_left_this_wave = 0
@export var enemies_on_screen = 0
@export var fish_left_this_wave = 0
@export var game_mode = "ARCADE"
@export var player_count = 1
@export var player_two_is_cpu = false
@export var dropped_items_on_screen = 0
@export var grouped_enemy_id = 0
@export var SteamEngine = null

var game_status_before_pause

# Score and combo multiplier are now per-shark (Player.player_score /
# player_score_multiplier). See scoring_player_for() / best_score().
var spawn_number = 0

var spawned_items_this_wave = []
var intro
var dedication
var credits
var statistics
var first_game_played = false

var accept_pause = true

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()

	# Capture HIGH SCORE's original (centred) layout so we can restore it exactly
	# on the menu after gameplay right-justifies it.
	_capture_high_score_default()

	$ArtilleryTimer.connect("timeout", _on_artillery_timer)

	# Player 1 also notifies Main on key grab (so player 2 can follow it). This
	# is in addition to the scene-wired Player 1 -> Key connection.
	$Player.player_got_key.connect(_on_player_got_key)

	if Engine.has_singleton("Steam") && (OS.has_feature("steam") or constants.DEV_STEAM_TESTING):
		SteamClient.steam_setup()
		SteamClient.SteamEngine.overlay_toggled.connect(_on_steam_overlay_toggled)
		SteamClient.SteamEngine.input_device_connected.connect(_on_steam_input_device_connected)
		SteamClient.SteamEngine.input_device_disconnected.connect(_on_steam_input_device_disconnected)
		SteamClient.SteamEngine.current_stats_received.connect(_on_steam_stats_ready)

	Storage.load_config()

	# Set screen mode based on config.
	if Storage.config.get_value("config", "screen_mode", "FULL_SCREEN") == "FULL_SCREEN":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().size = constants.WINDOW_SIZE

	get_window().title = constants.WINDOW_TITLE
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)

	# Set volume levels from config.
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(Storage.config.get_value("config", "master_volume", 1.0))
	)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(Storage.config.get_value("config", "music_volume", 1.0))
	)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Effects"),
		linear_to_db(Storage.config.get_value("config", "effects_volume", 1.0))
	)

	$WaveTimeLeftTimer.connect("timeout", _on_wave_time_left_timer_timeout)
	$AcceptPauseTimer.connect("timeout", _on_accept_pause_timer_timeout)

	Storage.load_stats()

	game_status = DEDICATION

	$Arena.visible = false
	$HUD/CanvasLayer.visible = false
	$MainMenu.get_node("CanvasLayer").visible = false
	$SetupScreen.get_node("CanvasLayer").visible = false
	$PauseMenu.get_node("CanvasLayer").visible = false
	$Statistics.get_node("CanvasLayer").visible = false
	$Credits.get_node("CanvasLayer").visible = false
	$HowToPlay.get_node("CanvasLayer").visible = false
	$Options.get_node("CanvasLayer").visible = false
	for player in get_players():
		player.set_process(false)
		player.set_physics_process(false)
		player.visible = false
		player.get_node("CollisionShape2D").disabled = false

	# Ensure we update high score as this may have been located from storage.
	_on_enemy_update_score_display()

	if constants.DEV_DELAY_ON_START:
		await get_tree().create_timer(5.0).timeout

	if constants.DEV_SKIP_INTRO:
		main_menu()
	else:
		dedication = dedication_scene.instantiate()
		add_child(dedication)


# --- Player access ---
# Single source of truth for locating players, so other systems don't depend on
# the "Player" node name. Today there is exactly one player; these helpers keep
# behaviour identical while allowing a second player to be added later.


func get_players():
	return get_tree().get_nodes_in_group("players")


# The shared co-op camera (also used in 1-player).
func get_coop_camera():
	return $CoopCamera


var _last_spray_sound_ms = -100000


# Single shared spray voice, rate-capped. One monophonic AudioStreamPlayer means
# no overlapping copies; the interval stops two sharks retriggering it so fast it
# turns into a stuttery "machine gun".
func play_spray_sound():
	var now = Time.get_ticks_msec()
	if now - _last_spray_sound_ms < constants.SPRAY_SOUND_MIN_INTERVAL * 1000.0:
		return
	_last_spray_sound_ms = now
	$SpraySound.play()


# The shark that should be credited for a kill/pickup. Human-controlled players
# score for themselves; the CPU and unattributed kills (e.g. dinosaur) funnel to
# player 1, so 1-player and 2-player-CPU keep a single score.
func scoring_player_for(attacker):
	if attacker != null and not player_two_is_cpu and attacker in get_players():
		return attacker
	return get_primary_player()


# Highest score across all sharks (matches single-player behaviour).
func best_score():
	var best = 0
	for player in get_players():
		best = max(best, player.player_score)
	return best


# Which high-score stat key applies to the current mode. Solo, two-human co-op,
# and CPU-assisted co-op are each a different challenge, so each keeps its own
# board.
func high_score_key():
	if player_count == 2:
		if player_two_is_cpu:
			return "high_score_2p_cpu"
		return "high_score_2p"
	return "high_score"


# The stored high score for the current mode.
func high_score():
	return Storage.stats.get_value("player", high_score_key(), 0)


# Persist the high score if any shark has beaten it (for the current mode).
func update_high_score():
	if best_score() > high_score():
		Storage.stats.set_value("player", high_score_key(), best_score())


# The canonical player for reading shared/player stats (upgrades, powerups, etc.).
func get_primary_player():
	return get_node("Player")


# The player nearest to a world position — used by enemy/item targeting. With a
# single player this always returns that player.
func get_nearest_player(from_position):
	var players = get_players()

	if players.is_empty():
		return null

	var nearest = players[0]
	var nearest_distance = from_position.distance_to(nearest.global_position)

	for player in players:
		var distance = from_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance

	return nearest


# Player 2 (the scene-instanced $Player is always player 1). Held so we can
# despawn it when returning to a single-player menu.
var player_two = null
# Device id assigned to each human player slot ([P1, P2]) for 2-player SPECIFIC
# input. Defaults to the historical hard-coded pairing (P1 keyboard/mouse,
# P2 gamepad 0); the setup screen overwrites these before a 2P-human game.
var player_devices = [PlayerInput.KEYBOARD_DEVICE, 0]
# The shark currently carrying the wave-end key (null until one grabs it), so a
# second shark can't also pick it up.
var key_holder = null
# Wave-end exit tracking: how many sharks must reach the exit, and how many have.
var players_to_exit = 0
var players_exited = 0
# Delay after the last upgrade confirmation so the confirm flash can play out.
var upgrade_advance_delay = 0.0


# Ensure the number of live player nodes matches player_count. Player 1 is the
# scene-instanced $Player; player 2 is spawned/despawned here.
func sync_player_instances():
	if player_count == 2 and player_two == null:
		player_two = PlayerScene.instantiate()
		# Player 2 swims in to its own start marker so both sharks enter together.
		player_two.start_marker_name = "PlayerStartLocation2"
		# Display + wave-start swim-in signals are wired for player 2. Key/exit
		# hunting and upgrades stay single-player (player 1 only) until later
		# Phase 5 slices.
		player_update_energy.connect(player_two._on_main_player_update_energy)
		player_update_fish.connect(player_two._on_main_player_update_fish)
		player_enable_fish_frenzy.connect(player_two._on_main_player_enable_fish_frenzy)
		player_move_to_starting_position.connect(
			player_two._on_main_player_move_to_starting_position
		)
		# Phase 5 slice 1: player 2 can die. Game over is gated on all players
		# being dead (see _on_player_player_died).
		player_two.player_died.connect(_on_player_player_died)
		# Phase 5 slice 2a: player 2's fish score for player 2.
		player_two.player_got_fish.connect(_on_player_player_got_fish)
		# Phase 5 slice 3a: player 2 joins the wave-end key hunt / exit.
		player_hunt_key.connect(player_two._on_main_player_hunt_key)
		player_two.player_got_key.connect(_on_player_got_key)
		player_two.player_found_exit.connect(_on_player_player_found_exit)
		player_two.player_found_exit_stop_key_movement.connect(
			$Key._on_player_player_found_exit_stop_key_movement
		)
		add_child(player_two)
		# Player 2 gets its own powerup bar (bottom-right) and upgrade summary.
		$HUD.add_second_powerup_bar()
		$HUD.add_second_upgrade_summary()
	elif player_count == 1 and player_two != null:
		despawn_player_two()

	assign_player_devices()


# Assign each player's input source and haptics device based on player_count.
#   1-player: player 1 uses ANY (keyboard/mouse AND controller both drive it).
#   2-player: each human slot uses the device chosen on the setup screen
#             (player_devices). CPU player 2 is driven by AiInput.
# Haptics only fire on gamepads: a keyboard slot maps to device 0 (harmless, no
# rumble), otherwise the slot's own gamepad id.
func assign_player_devices():
	var player_one = get_primary_player()

	if player_count == 2:
		var p1_device = player_devices[0]
		player_one.input = PlayerInput.new(PlayerInput.Mode.SPECIFIC, p1_device)
		player_one.haptics_device = _haptics_device_for(p1_device)

		if player_two != null:
			if player_two_is_cpu:
				player_two.input = AiInput.new()
				player_two.haptics_device = 0
			else:
				var p2_device = player_devices[1]
				player_two.input = PlayerInput.new(PlayerInput.Mode.SPECIFIC, p2_device)
				player_two.haptics_device = _haptics_device_for(p2_device)
			player_two.player_tint = constants.PLAYER_2_TINT
			player_two.apply_tint()
	else:
		player_one.input = PlayerInput.new(PlayerInput.Mode.ANY)
		player_one.haptics_device = 0


# Gamepad id to use for haptics for a given input device. Keyboard has no rumble,
# so it maps to device 0 (harmless if nothing is plugged in there).
func _haptics_device_for(device_id):
	if device_id == PlayerInput.KEYBOARD_DEVICE:
		return 0
	return device_id


func despawn_player_two():
	if player_two != null:
		player_two.queue_free()
		player_two = null
	$HUD.remove_second_powerup_bar()
	$HUD.remove_second_upgrade_summary()


func main_menu():
	game_status = MAIN_MENU
	for player in get_players():
		player.player_score = 0
		player.player_score_multiplier = 1
		player.fish_collected = 0
	fish_left_this_wave = 0
	wave_number = constants.START_WAVE - 1
	enemies_on_screen = 0

	$SharkAttackMusic.stop()
	$AudioStreamPlayerMusic.stop()

	if !$MenuMusic.is_playing():
		$MenuMusic.play()

	# Ensure music speed is always at normal.
	_on_player_player_no_longer_low_energy()

	# Hand camera control back to the menu/intro scenes.
	get_coop_camera().deactivate()

	for player in get_players():
		player.set_process(false)
		player.set_physics_process(false)
		player.visible = false
		player.get_node("CollisionShape2D").disabled = false
	$Player.do_ready()

	$UnderwaterFar.visible = true
	$UnderwaterNear.visible = true
	$Arena.visible = false
	$PauseMenu.get_node("CanvasLayer").visible = false
	$PauseMenu.set_process_input(false)

	$MainMenu.get_node("CanvasLayer").visible = true
	$HUD/CanvasLayer/HighScore.visible = true
	# Re-centre HIGH SCORE on the menu (gameplay right-justifies it).
	center_high_score()
	$MainMenu.set_process_input(true)
	$MainMenu.do_ready()

	update_player_count_label()

	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

	$HUD/CanvasLayer.visible = true
	$HUD/CanvasLayer/UpgradeChoiceContainer.visible = false
	$HUD.set_upgrade_summary_visible(false)
	$HUD/CanvasLayer/BossHealthBar.visible = false
	$HUD.get_node("CanvasLayer/Score").visible = false
	$HUD.get_node("CanvasLayer/Label").visible = true
	$HUD.get_node("CanvasLayer/Label").text = ""
	$HUD.get_node("CanvasLayer/EnemiesLeft").visible = false

	$HUD.hide_powerup_bar()

	if constants.DEV_START_GAME_IMMEDIATELY && !first_game_played:
		start_game()


func start_game():
	first_game_played = true

	Storage.increase_stat("player", "games_played", 1)

	# Create/destroy player 2 to match the selected player count.
	sync_player_instances()

	# Position the score HUD for the current mode.
	apply_score_hud_layout()

	for player in get_players():
		if cheat_mode == true:
			player.player_energy = constants.PLAYER_START_GAME_ENERGY_CHEATING
		else:
			player.player_energy = constants.PLAYER_START_GAME_ENERGY

		player.get_node("EnergyProgressBar").max_value = player.player_energy
		player.get_node("FishProgressBar").max_value = constants.FISH_TO_TRIGGER_FISH_FRENZY
		player.prepare_for_new_game()

	#$HUD/CanvasLayer/UpgradeSummary.text = ""
	$HUD.set_upgrade_summary_visible(true)

	if $MenuMusic.is_playing():
		$MenuMusic.stop()
		$AudioStreamPlayerMusic.play()

	enemies_left_this_wave = 0
	grouped_enemy_id = 0

	if game_mode == "ARCADE":
		update_time_left_display()
	else:
		update_fish_left_display()
		for player in get_players():
			player.get_node("FishProgressBar").visible = false

	prepare_for_wave()


func prepare_for_wave():
	wave_number += 1

	if $WaveEndMusic.is_playing():
		$WaveEndMusic.stop()

	if !$AudioStreamPlayerMusic.is_playing():
		$AudioStreamPlayerMusic.play()

	TheDirector.design_wave(wave_number)

	$Arena.close_top_door()
	$Arena.open_bottom_door()

	$HUD.get_node("CanvasLayer/Score").visible = true
	$HUD.get_node("CanvasLayer/Label").visible = false
	$HUD.get_node("CanvasLayer/EnemiesLeft").visible = true

	if game_mode == "ARCADE":
		$HUD.show_powerup_bar()

	$UnderwaterFar.visible = false
	$UnderwaterNear.visible = false
	$MainMenu.get_node("CanvasLayer").visible = false
	$MainMenu.set_process_input(false)
	$Arena.visible = true

	$Arena.reset_arena_floor(player_count)

	for i in range(1, TheDirector.wave_design.get("obstacle_number", 0)):
		$Arena.add_obstacle()

	# Fish spawning
	if game_mode == "ARCADE":
		fish_left_this_wave = constants.FISH_TO_SPAWN_ARCADE
	else:
		fish_left_this_wave = (
			constants.FISH_TO_SPAWN_PACIFIST_BASE
			+ ((wave_number - 1) * constants.FISH_TO_SPAWN_PACIFIST_WAVE_MULTIPLIER)
		)

	var player_index = 0
	for player in get_players():
		player.set_process(true)
		player.set_physics_process(true)
		# Revive any shark downed in the previous wave (no-op for living sharks).
		player.revive_for_new_wave()
		player.prepare_for_new_wave()
		player.visible = true
		#player.position = Vector2(2650, 2500)
		# y=2521 is one tile above the bottom wall band (row 33): spawning both
		# sharks clear of it keeps them at the same height (player 2's column has
		# a wall at the spawn row that would otherwise bump it up ~1 tile).
		player.position = Vector2(2650, 2521) + (PLAYER_2_START_OFFSET * player_index)
		player.get_node("AnimatedSprite2D").animation = "default"
		player.get_node("AnimatedSprite2D").play()
		player_index += 1

	# Take over camera control for gameplay.
	get_coop_camera().activate()
	get_coop_camera().global_position = $Player.position

	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

	if constants.CAMERA_ZOOM_EFFECTS and wave_number == 1:
		# Drive the shared camera's zoom directly for the intro; suspend its
		# follow/zoom logic for the duration so it doesn't fight the tween.
		var coop_camera = get_coop_camera()
		coop_camera.manual_control = true
		coop_camera.global_position = $Player.position
		coop_camera.set_zoom(Vector2(4.0, 4.0))
		var tween_camera = get_tree().create_tween()
		tween_camera.tween_property(coop_camera, "zoom", Vector2(1.0, 1.0), 2.5).set_trans(
			tween_camera.EASE_OUT
		)
		tween_camera.tween_callback(func(): coop_camera.manual_control = false)

	player_move_to_starting_position.emit()

	_on_enemy_update_score_display()

	if game_mode == "ARCADE":
		update_time_left_display()
	else:
		update_fish_left_display()

	player_update_energy.emit()
	player_update_fish.emit()

	$Key/CollisionShape2D.disabled = true

	wave_intro()


func wave_intro():
	game_status = WAVE_START

	var wave_text

	if wave_number == 1:
		match game_mode:
			"ARCADE":
				wave_text = (
					"SURVIVE "
					+ str(TheDirector.wave_design.get("wave_time"))
					+ " SECONDS FOR NEXT WAVE!"
				)
			"PACIFIST":
				wave_text = "COLLECT ALL FISH FOR NEXT WAVE!"
	else:
		wave_text = (
			"[center]WAVE "
			+ str(wave_number)
			+ "\n\nSURVIVE "
			+ str(TheDirector.wave_design.get("wave_time"))
			+ " SECONDS!"
		)

	var spawn_text = TheDirector.wave_design.get("spawn_text", "")

	$HUD.get_node("CanvasLayer/Label").text = wave_text

	if spawn_text:
		$HUD.get_node("CanvasLayer/Label").text += "\n\n" + spawn_text

	# Restore opacity in case the label was left faded by the wave-end fade.
	$HUD.get_node("CanvasLayer/Label").modulate = Color(1, 1, 1, 1)
	$HUD.get_node("CanvasLayer/Label").visible = true
	$WaveIntroTimer.start()


func start_wave():
	game_status = GAME_RUNNING
	var i = 0

	if $SharkAttackMusic.is_playing():
		$SharkAttackMusic.stop()

	if wave_number > Storage.stats.get_value("player", "furthest_wave", 0):
		Storage.increase_stat("player", "furthest_wave", 1)

	$HUD.get_node("CanvasLayer/Score").visible = true
	$HUD.get_node("CanvasLayer/Label").visible = false
	$HUD.get_node("CanvasLayer/EnemiesLeft").visible = true

	dropped_items_on_screen = 0

	$WaveTimeLeftTimer.start(TheDirector.wave_design.get("wave_time"))
	$ItemSpawnTimer.start(
		randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS, constants.ITEM_SPAWN_MAXIMUM_SECONDS)
	)
	$EnemySpawnTimer.start(TheDirector.wave_design.get("reinforcements_timer", 0))

	spawn_number = 0
	enemies_left_this_wave = TheDirector.wave_design.get("total_enemies")

	if TheDirector.wave_design.get("boss_wave", false):
		$HUD.boss_health_reveal()
	else:
		spawn_enemy("start_spawn", "spawn_pattern", false)

	i = 0

	while i < fish_left_this_wave:
		spawn_fish()
		i = i + 1

	if game_mode == "PACIFIST":
		update_fish_left_display()

	# Artillery
	if TheDirector.wave_design.get("artillery", false):
		$ArtilleryTimer.start(
			randf_range(constants.ARTILLERY_MINIMUM_TIME, constants.ARTILLERY_MAXIMUM_TIME)
		)


func wave_end():

	# Wait for any cheat-death payoff (on any shark) to finish first.
	if any_player_cheating_death():
		Logging.log_entry("Setting game_status to CHEATING_DEATH_AT_WAVE_END")
		$HUD.get_node("CanvasLayer/Label").visible = false

		game_status = CHEATING_DEATH_AT_WAVE_END
		return

	# Don't let the wave end if every player beat it by dying.
	if get_living_players().is_empty():
		return

	game_status = GETTING_KEY
	key_holder = null  # No one holds the key yet this wave-end.
	# Every living shark must reach the exit before the wave completes.
	players_to_exit = get_living_players().size()
	players_exited = 0

	# End power-pellet / fish-frenzy states on every living shark.
	for player in get_living_players():
		if player.power_pellet_enabled:
			player.power_pellet_enabled = false
			player.power_pellet_warning_running = false
			player.end_shark_attack()

		if player.is_player_in_fish_frenzy():
			player.stop_fish_frenzy()

	for enemy in get_tree().get_nodes_in_group("enemyGroup"):
		enemy.swim_escape()

	$HUD.get_node("CanvasLayer/Label").text = "WAVE COMPLETE!"
	$HUD.get_node("CanvasLayer/Label").visible = true

	if constants.PLAY_WAVE_END_MUSIC:
		$AudioStreamPlayerMusic.stop()
		$WaveEndMusic.play()

	for enemy_trap in get_tree().get_nodes_in_group("enemyTrap"):
		enemy_trap.queue_free()

	despawn_all_items()
	$ArtilleryTimer.stop()

	player_hunt_key.emit($Key.global_position)

	for fish in get_tree().get_nodes_in_group("fishGroup"):
		fish.queue_free()

	for dinosaur in get_tree().get_nodes_in_group("dinosaurGroup"):
		dinosaur.queue_free()

	for artillery in get_tree().get_nodes_in_group("artilleryGroup"):
		artillery.queue_free()

	# Pop Steam achievement if appropriate.
	if SteamClient.steam_running:
		if game_mode == "ARCADE":
			match wave_number:
				1:
					SteamClient.SteamEngine.setAchievement("ACH_ARCADE_BEAT_1_WAVE")
					SteamClient.SteamEngine.storeStats()
				5:
					SteamClient.SteamEngine.setAchievement("ACH_ARCADE_BEAT_5_WAVES")
				10:
					SteamClient.SteamEngine.setAchievement("ACH_ARCADE_BEAT_10_WAVES")


func wave_end_cleanup():
	for player in get_players():
		player.visible = false
		player.set_process(false)
		player.set_physics_process(false)
	$Key.visible = false

	for enemy_attack in get_tree().get_nodes_in_group("enemyAttack"):
		enemy_attack.queue_free()

	for dinosaur_attack in get_tree().get_nodes_in_group("dinosaurAttack"):
		dinosaur_attack.queue_free()

	if game_mode == "ARCADE":
		game_status = UPGRADE_SCREEN
	else:
		game_status = PREPARE_FOR_WAVE

	$WaveEndTimer.start()


func game_over():
	game_status = GAME_OVER
	$HUD.get_node("CanvasLayer/Label").visible = true
	$HUD.get_node("CanvasLayer/Label").text = "[center]GAME OVER"
	$AudioStreamPlayerMusic.pitch_scale = 1.0

	if SteamClient.steam_running:
		if wave_number == 1:
			SteamClient.SteamEngine.setAchievement("ACH_ARCADE_NAME_IS_BRUCE")

		# Done at end of game to play nicely with Steam rate limiting.
		var fish_hold = Storage.stats.get_value("player", "fish_rescued", 0)

		# To catch players that hit achievements BEFORE they were introduced, check all of them.
		if fish_hold >= 100:
			SteamClient.SteamEngine.setAchievement("ACH_RESCUE_100_FISH")

		if fish_hold >= 500:
			SteamClient.SteamEngine.setAchievement("ACH_RESCUE_500_FISH")

		if fish_hold >= 1000:
			SteamClient.SteamEngine.setAchievement("ACH_RESCUE_1000_FISH")

		SteamClient.SteamEngine.storeStats()

	$AudioStreamPlayerMusic.stop()
	$MenuMusic.play()

	$GameOverTimer.start()


func return_to_main_screen():
	for shark_spray in get_tree().get_nodes_in_group("sharkSprayGroup"):
		shark_spray.queue_free()

	for mini_shark_spray in get_tree().get_nodes_in_group("miniSharkSprayGroup"):
		mini_shark_spray.queue_free()

	for enemy in get_tree().get_nodes_in_group("enemyGroup"):
		enemy.queue_free()

	for enemy_attack in get_tree().get_nodes_in_group("enemyAttack"):
		enemy_attack.queue_free()

	for enemy_trap in get_tree().get_nodes_in_group("enemyTrap"):
		enemy_trap.queue_free()

	for fish in get_tree().get_nodes_in_group("fishGroup"):
		fish.queue_free()

	for dinosaur in get_tree().get_nodes_in_group("dinosaurGroup"):
		dinosaur.queue_free()

	for dinosaur_attack in get_tree().get_nodes_in_group("dinosaurAttack"):
		dinosaur_attack.queue_free()

	for artillery in get_tree().get_nodes_in_group("artilleryGroup"):
		artillery.queue_free()

	$ArtilleryTimer.stop()
	$Key.hide()
	despawn_all_items()
	for player in get_players():
		player.stop_fish_frenzy()
		player.get_node("HungryParticles").set_emitting(false)
	$CountdownEffect.stop()

	Storage.save_stats()

	# Remove player 2 (if any); it is re-created from player_count on next game.
	despawn_player_two()

	main_menu()


func spawn_item():
	var items
	var spawn_position
	var valid_spawn = false

	while !valid_spawn:
		spawn_position = Vector2(
			randf_range(constants.ARENA_SPAWN_MIN_X, constants.ARENA_SPAWN_MAX_X),
			randf_range(constants.ARENA_SPAWN_MIN_Y, constants.ARENA_SPAWN_MAX_Y)
		)
		if !$Arena.conflict_with_obstacle(spawn_position):
			valid_spawn = true

	if game_mode == "ARCADE":
		items = constants.ARCADE_SPAWNING_ITEMS
	else:
		items = constants.PACIFIST_SPAWNING_ITEMS

	var spawned_item = items[randi() % items.size()]

	if spawned_item == "dinosaur":
		var dinosaur = dinosaur_scene.instantiate()
		dinosaur.get_node(".").set_position(spawn_position)
		dinosaur.add_to_group("dinosaurGroup")
		add_child(dinosaur)
	else:
		var item = item_scene.instantiate()
		item.spawn_specific(spawned_item, false)
		item.get_node(".").set_position(spawn_position)
		item.add_to_group("itemGroup")
		add_child(item)

		# If a power pellet, due to their blinking nature, reset all pellet animations to be in sync.
		if spawned_item == "power-pellet":
			for single_item in get_tree().get_nodes_in_group("itemGroup"):
				if single_item.item_type == "power_pellet":
					single_item.get_node("AnimatedSprite2D").stop()
					single_item.get_node("AnimatedSprite2D").start()

	$ItemSpawnTimer.start(
		randf_range(constants.ITEM_SPAWN_MINIMUM_SECONDS, constants.ITEM_SPAWN_MAXIMUM_SECONDS)
	)


func despawn_all_items():
	for item in get_tree().get_nodes_in_group("itemGroup"):
		item.queue_free()


func spawn_enemy(spawn_to_use, spawn_pattern_to_use, half_spawn_boolean):
	var spawn_pattern = TheDirector.wave_design.get(spawn_to_use).get(spawn_pattern_to_use)
	var spawn_array = TheDirector.wave_design.get(spawn_to_use).get("spawn_array")
	var number_to_spawn = spawn_array.size()

	if half_spawn_boolean:
		@warning_ignore("integer_division")
		var spawn_a = int(number_to_spawn / 2)
		var spawn_b = number_to_spawn - spawn_a

		if spawn_pattern_to_use == "spawn_pattern":
			spawn_array = spawn_array.slice(0, spawn_a)
		else:
			spawn_array = spawn_array.slice(spawn_a, spawn_a + spawn_b)

		number_to_spawn = spawn_array.size()

	# If this is the final spawn this wave, AND it is considered a 'low population' spawn, surround
	# the player.
	# Why? Stops the end of the wave being boring with the player having to wait to find
	# the enemies.
	if (
		(enemies_on_screen + number_to_spawn <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW)
		&& (enemies_left_this_wave <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW)
	):
		spawn_pattern = "CIRCLE_SURROUND_PLAYER"

	# Uncomment this to force a spawn pattern for testing.
	#spawn_pattern='RANDOM'

	match spawn_pattern:
		"RANDOM":
			var i = 0
			while i < number_to_spawn:
				spawn_enemy_random_position(spawn_array[i])
				i += 1
		"CIRCLE_SURROUND_PLAYER":
			var i = 0
			while i < number_to_spawn:
				var angle_degrees = (360 / number_to_spawn) * (i + 1)
				var angle_rad = deg_to_rad(angle_degrees)
				var offset = Vector2(sin(angle_rad), cos(angle_rad)) * 600
				var enemy_position = $Player.position + offset

				spawn_enemy_set_position(
					spawn_array[i], enemy_position, "", Vector2(0, 0).normalized(), false
				)
				i += 1
		"HARD_TOP":
			var i = 0
			var y_pos = constants.ARENA_SPAWN_MIN_Y
			var x_step = (
				(constants.ARENA_SPAWN_MAX_X - constants.ARENA_SPAWN_MIN_X) / number_to_spawn
			)
			while i < number_to_spawn:
				spawn_enemy_set_position(
					spawn_array[i],
					Vector2(constants.ARENA_SPAWN_MIN_X + (i * x_step), y_pos),
					"DEFERRED_UNTIL_WALL",
					Vector2(0, 1).normalized(),
					false
				)
				i += 1
		"HARD_BOTTOM":
			var i = 0
			var y_pos = constants.ARENA_SPAWN_MAX_Y
			var x_step = (
				(constants.ARENA_SPAWN_MAX_X - constants.ARENA_SPAWN_MIN_X) / number_to_spawn
			)
			while i < number_to_spawn:
				spawn_enemy_set_position(
					spawn_array[i],
					Vector2(constants.ARENA_SPAWN_MIN_X + (i * x_step), y_pos),
					"DEFERRED_UNTIL_WALL",
					Vector2(0, -1).normalized(),
					false
				)
				i += 1
		"HARD_LEFT":
			var i = 0
			var x_pos = constants.ARENA_SPAWN_MIN_X
			var y_step = (
				(constants.ARENA_SPAWN_MAX_Y - constants.ARENA_SPAWN_MIN_Y) / number_to_spawn
			)
			while i < number_to_spawn:
				spawn_enemy_set_position(
					spawn_array[i],
					Vector2(x_pos, constants.ARENA_SPAWN_MIN_Y + (i * y_step)),
					"DEFERRED_UNTIL_WALL",
					Vector2(1, 0).normalized(),
					false
				)
				i += 1
		"HARD_RIGHT":
			var i = 0
			var x_pos = constants.ARENA_SPAWN_MAX_X
			var y_step = (
				(constants.ARENA_SPAWN_MAX_Y - constants.ARENA_SPAWN_MIN_Y) / number_to_spawn
			)
			while i < number_to_spawn:
				spawn_enemy_set_position(
					spawn_array[i],
					Vector2(x_pos, constants.ARENA_SPAWN_MIN_Y + (i * y_step)),
					"DEFERRED_UNTIL_WALL",
					Vector2(-1, 0).normalized(),
					false
				)
				i += 1

	return spawn_pattern


func spawn_enemy_random_position(enemy_type):
	var mob = enemy_scene.instantiate()

	var spawn_position
	var valid_spawn = false

	while !valid_spawn:
		spawn_position = Vector2(
			randf_range(constants.ARENA_SPAWN_MIN_X, constants.ARENA_SPAWN_MAX_X),
			randf_range(constants.ARENA_SPAWN_MIN_Y, constants.ARENA_SPAWN_MAX_Y)
		)
		if !$Arena.conflict_with_obstacle(spawn_position):
			valid_spawn = true

	mob.get_node(".").set_position(spawn_position)
	mob.add_to_group("enemyGroup")
	add_child(mob, true)

	mob.spawn_specific(enemy_type)

	enemies_on_screen += 1


func spawn_enemy_set_position(
	enemy_type, enemy_position, ai_mode, initial_direction, instant_spawn
):
	enemy_position.x = clamp(
		enemy_position.x, constants.ARENA_SPAWN_MIN_X, constants.ARENA_SPAWN_MAX_X
	)
	enemy_position.y = clamp(
		enemy_position.y, constants.ARENA_SPAWN_MIN_Y, constants.ARENA_SPAWN_MAX_Y
	)

	var valid_spawn = false

	while !valid_spawn:
		if !$Arena.conflict_with_obstacle(enemy_position):
			valid_spawn = true

		# Fuzz enemy_position
		enemy_position = enemy_position + Vector2(50, 50)

	var mob = enemy_scene.instantiate()
	mob.get_node(".").set_position(enemy_position)
	mob.set_ai_mode(ai_mode)

	if initial_direction:
		mob.set_initial_direction(initial_direction)

	mob.add_to_group("enemyGroup")
	add_child(mob, true)

	if instant_spawn:
		mob.set_instant_spawn(true)
		mob.set_enemy_is_split(true)
		mob.spawn_specific(enemy_type)
	else:
		mob.spawn_specific(enemy_type)

	enemies_on_screen += 1


func spawn_fish():
	var mob = fish_scene.instantiate()

	var spawn_position
	var valid_spawn = false

	while !valid_spawn:
		spawn_position = Vector2(
			randf_range(constants.ARENA_SPAWN_MIN_X, constants.ARENA_SPAWN_MAX_X),
			randf_range(constants.ARENA_SPAWN_MIN_Y, constants.ARENA_SPAWN_MAX_Y)
		)
		if !$Arena.conflict_with_obstacle(spawn_position):
			valid_spawn = true

	mob.get_node(".").set_position(spawn_position)
	mob.add_to_group("fishGroup")
	add_child(mob, true)


func _process(_delta):
	if SteamClient.steam_running:
		SteamClient.SteamEngine.run_callbacks()

	if game_status == WAVE_START:
		if $WaveIntroTimer.time_left == 0:
			start_wave()

	if game_status == UPGRADE_SCREEN:
		if $WaveEndTimer.time_left == 0:
			upgrade_screen()

	if game_status == UPGRADE_WAITING_FOR_CHOICE:
		process_upgrade_choice(_delta)

	if game_status == PREPARE_FOR_WAVE:
		if $WaveEndTimer.time_left == 0:
			prepare_for_wave()

	if game_status == GAME_RUNNING:
		if game_mode == "ARCADE":
			update_time_left_display()

		if fish_left_this_wave == 0 && game_mode == "PACIFIST":
			# Spawn the key on a living player.
			var living = get_living_players()
			if living.size():
				$Key.global_position = living[0].global_position
			$Key.show()
			$Key/CollisionShape2D.disabled = false
			$Key/AnimatedSprite2D.play()

			wave_end()

		if $ItemSpawnTimer.time_left == 0:
			spawn_item()

		if $EnemySpawnTimer.time_left == 0:
			if spawn_number < TheDirector.wave_design.get("total_spawns", 0):
				spawn_number += 1

				var spawn_label = "spawn_" + str(spawn_number)

				if TheDirector.wave_design.get(spawn_label).get("spawn_pattern_b"):
					spawn_enemy(spawn_label, "spawn_pattern", true)
					spawn_enemy(spawn_label, "spawn_pattern_b", true)
				else:
					spawn_enemy(spawn_label, "spawn_pattern", false)

				$EnemySpawnTimer.start(TheDirector.wave_design.get("reinforcements_timer"))

	if game_status == GAME_OVER:
		if $GameOverTimer.time_left == 0:
			return_to_main_screen()


func _input(ev):
	if game_status != INTRO_SEQUENCE and game_status != DEDICATION:
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)

	if Input.is_action_just_pressed("start") or Input.is_action_just_pressed("quit"):
		handle_pause_input()

	if (
		Input.is_action_just_released("shark_fire")
		or Input.is_action_just_released("shark_fire_mouse")
		or Input.is_action_just_released("quit")
	):
		match game_status:
			DEDICATION:
				dedication.queue_free()
				intro = intro_scene.instantiate()
				add_child(intro)
				game_status = INTRO_SEQUENCE
			INTRO_SEQUENCE:
				intro.queue_free()
				main_menu()


func handle_pause_input():
	match game_status:
		GAME_RUNNING, WAVE_START, GETTING_KEY, WAVE_END, UPGRADE_SCREEN, UPGRADE_WAITING_FOR_CHOICE:
			# Avoid 'double press' if we have just come back from the pause menu
			if !accept_pause:
				return

			game_status_before_pause = game_status
			game_status = GAME_PAUSED

			# (Upgrade-screen selection is manual per-player state that simply
			# persists across pause — no Godot focus to stash/restore.)

			$PauseMenu.get_node("CanvasLayer").visible = true
			$PauseMenu.set_process_input(true)
			$PauseMenu.pause()
			get_tree().paused = true


func on_enemy_update_score(
	score_to_add,
	enemy_global_position,
	death_source,
	enemy_type,
	enemy_is_split,
	grouped_enemy_has_died,
	attacker = null
):
	if grouped_enemy_has_died:
		enemies_left_this_wave = enemies_left_this_wave - 1
		enemies_on_screen = enemies_on_screen - 1

	var scorer = scoring_player_for(attacker)
	var score_to_return = score_to_add * scorer.player_score_multiplier
	scorer.player_score += score_to_return

	# Don't increase multiplier for dinosaur kills
	if death_source == "PLAYER-SHOT":
		scorer.player_score_multiplier += 1

	update_high_score()

	Storage.increase_stat("player", "enemies_defeated", 1)

	var enemy_details = constants.ENEMY_SETTINGS[enemy_type]

	if enemy_details.get("spawns_others", false) && !enemy_is_split:
		spawn_enemy_set_position(
			enemy_type, enemy_global_position, "SPAWN_OUTWARDS", Vector2(-1, +1).normalized(), true
		)
		spawn_enemy_set_position(
			enemy_type, enemy_global_position, "SPAWN_OUTWARDS", Vector2(+1, +1).normalized(), true
		)
		spawn_enemy_set_position(
			enemy_type, enemy_global_position, "SPAWN_OUTWARDS", Vector2(+1, -1).normalized(), true
		)
		spawn_enemy_set_position(
			enemy_type, enemy_global_position, "SPAWN_OUTWARDS", Vector2(-1, -1).normalized(), true
		)
		enemies_left_this_wave += 4

	_on_enemy_update_score_display()

	if game_mode == "ARCADE":
		update_time_left_display()

	return score_to_return


func _on_enemy_update_score_display():
	var player_one = get_primary_player()
	var show_second = _two_human_players()

	if show_second:
		# In 2-player-human the labels are P1 / P2 to make ownership clear.
		$HUD.get_node("CanvasLayer/Score").text = _score_text("P1", player_one)
		$HUD.get_node("CanvasLayer/Score2").text = _score_text("P2", player_two)
	else:
		$HUD.get_node("CanvasLayer/Score").text = _score_text("SCORE", player_one)

	$HUD.get_node("CanvasLayer/Score2").visible = show_second

	$HUD.get_node("CanvasLayer/HighScore").text = "HIGH SCORE\n" + str(high_score())


func _two_human_players():
	return player_count == 2 and not player_two_is_cpu and player_two != null


# HUD label a collected fish should fly to for the given player. Player 1 always
# uses the left "Score". Player 2 uses "Score2" when it is shown (2-player-human)
# or "HighScore" (top-right) in 2-player-CPU, where Score2 is hidden.
func fish_score_target_for(player):
	if player == get_primary_player():
		return "Score"
	if _two_human_players():
		return "Score2"
	return "HighScore"


# Position the score HUD. TIME sits in the centre in every mode (consistent).
#   1-player / CPU: SCORE left, TIME centre, HIGH SCORE right; P2 hidden.
#   2-player-human: P1 left, TIME centre, P2 right; HIGH SCORE hidden.
func apply_score_hud_layout():
	var score = $HUD.get_node("CanvasLayer/Score")
	var score2 = $HUD.get_node("CanvasLayer/Score2")
	var enemies_left = $HUD.get_node("CanvasLayer/EnemiesLeft")
	var high_score = $HUD.get_node("CanvasLayer/HighScore")

	# TIME to the centre in all modes.
	enemies_left.anchor_left = 0.5
	enemies_left.anchor_right = 0.5
	enemies_left.offset_left = -226.0
	enemies_left.offset_right = 226.0
	enemies_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Right slot: P2 score in 2-player-human, otherwise HIGH SCORE.
	if _two_human_players():
		high_score.visible = false

		score2.offset_top = score.offset_top
		score2.offset_bottom = score.offset_bottom
		score2.anchor_left = 1.0
		score2.anchor_right = 1.0
		score2.offset_left = -636.0
		score2.offset_right = -20.0
		score2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		high_score.visible = true
		high_score.anchor_left = 1.0
		high_score.anchor_right = 1.0
		high_score.offset_left = -656.0
		high_score.offset_right = -20.0
		high_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


var _high_score_default := {}


# Snapshot HIGH SCORE's authored layout so it can be restored verbatim.
func _capture_high_score_default():
	var hs = $HUD.get_node("CanvasLayer/HighScore")
	_high_score_default = {
		"anchor_left": hs.anchor_left,
		"anchor_right": hs.anchor_right,
		"offset_left": hs.offset_left,
		"offset_right": hs.offset_right,
		"grow_horizontal": hs.grow_horizontal,
		"horizontal_alignment": hs.horizontal_alignment,
	}


# Restore HIGH SCORE to its authored (centred) layout — used on the menu, since
# gameplay right-justifies it via apply_score_hud_layout.
func center_high_score():
	var hs = $HUD.get_node("CanvasLayer/HighScore")
	hs.anchor_left = _high_score_default["anchor_left"]
	hs.anchor_right = _high_score_default["anchor_right"]
	hs.offset_left = _high_score_default["offset_left"]
	hs.offset_right = _high_score_default["offset_right"]
	hs.grow_horizontal = _high_score_default["grow_horizontal"]
	hs.horizontal_alignment = _high_score_default["horizontal_alignment"]


func _score_text(label, player):
	var text = label + "\n" + str(player.player_score)
	if player.player_score_multiplier > 1:
		text += " x" + str(player.player_score_multiplier)
	return text


func reset_score_multiplier(player = null):
	# Reset the given shark's combo (the one that got hit); defaults to player 1.
	if player == null:
		player = get_primary_player()
	player.player_score_multiplier = 1
	_on_enemy_update_score_display()


func update_time_left_display():
	var time_left

	match game_status:
		GAME_RUNNING, CHEATING_DEATH_AT_WAVE_END, GETTING_KEY, WAVE_END, UPGRADE_SCREEN, UPGRADE_WAITING_FOR_CHOICE:
			time_left = int(ceil($WaveTimeLeftTimer.time_left))
		_:
			time_left = TheDirector.wave_design.get("wave_time")

	$HUD.get_node("CanvasLayer").get_node("EnemiesLeft").text = "TIME\n" + str(time_left)

	if time_left == 3 and !$CountdownEffect.is_playing():
		$CountdownEffect.play()

	if time_left and time_left <= 3:
		$HUD.get_node("CanvasLayer/Label").text = (
			"[center][font_size=128][pulse freq=1.0 color=#ffffff40 ease=-2.0]" + str(time_left)
		)
		$HUD.get_node("CanvasLayer/Label").visible = true


func update_enemies_left_display():
	$HUD.get_node("CanvasLayer").get_node("EnemiesLeft").text = (
		"ENEMIES\n" + str(enemies_left_this_wave)
	)


func update_fish_left_display():
	$HUD.get_node("CanvasLayer").get_node("EnemiesLeft").text = "FISH\n" + str(fish_left_this_wave)


# True when every player is down (used to gate co-op game over).
func are_all_players_dead():
	# "Down" means actually dying/dead. A shark in a wave-end hunt/exit state is
	# still in the game, so it must not count toward game-over (fixes a false
	# game-over when one shark died just as the wave was ending).
	for player in get_players():
		if not player.is_player_down():
			return false
	return true


# Living players (ALIVE or FISH_FRENZY) — used to drive co-op wave-end.
func get_living_players():
	var living = []
	for player in get_players():
		if player.is_player_alive():
			living.append(player)
	return living


# Is any player currently cheating death? (Wave-end waits for this to resolve.)
func any_player_cheating_death():
	for player in get_players():
		if player.is_player_cheating_death():
			return true
	return false


func _on_player_player_died():
	# In co-op a single death does not end the game — the downed shark sits out
	# and respawns next wave. Game over only when all players are down.
	if are_all_players_dead():
		game_over()
	else:
		# Hide the downed shark(s) for the rest of the wave; they respawn at wave
		# start via revive_for_new_wave().
		for player in get_players():
			if player.is_player_down():
				player.set_physics_process(false)
				player.visible = false


# When one shark grabs the wave-end key: the key sticks to that shark, and the
# other living sharks follow it to the exit (only the holder opens the door).
func _on_player_got_key(holder):
	$Key.start_following(holder)
	# Iterate all players (not get_living_players): a shark hunting the key is in
	# HUNTING_KEY, which is_player_alive() does not count. follow_key_holder()
	# itself guards that only a still-hunting shark switches to following.
	for player in get_players():
		if player != holder:
			player.follow_key_holder(holder)


func _on_player_player_got_fish(collecting_player):
	# Score and fish-frenzy progress credit the shark that collected the fish.
	collecting_player.player_score += constants.GET_FISH_SCORE
	update_high_score()

	Storage.increase_stat("player", "fish_rescued", 1)

	collecting_player.fish_collected += 1
	fish_left_this_wave -= 1  # Shared wave goal (PACIFIST); not per-player.
	_on_enemy_update_score_display()
	collecting_player._on_main_player_update_fish()

	if game_mode == "PACIFIST":
		update_fish_left_display()
	else:
		# This shark fills its own bar and triggers its own frenzy.
		if collecting_player.fish_collected == collecting_player.get_node("FishProgressBar").max_value:
			collecting_player._on_main_player_enable_fish_frenzy()

func _on_player_player_found_exit():
	players_exited += 1

	# The key-holder exits first; only then do the following sharks head through
	# the door, so nobody barges ahead of the shark carrying the key.
	if players_exited < players_to_exit:
		for player in get_players():
			player.go_through_open_door()
		return

	# Fade the screen once the last shark is through, then end the wave. The HUD
	# is on its own CanvasLayer (not a child of Main), so the "WAVE COMPLETE!"
	# banner won't ride this fade — fade it out explicitly, in step.
	var tween = get_tree().create_tween()
	tween.set_parallel()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 0.35)
	tween.tween_property($HUD/CanvasLayer/Label, "modulate", Color(1, 1, 1, 0), 0.35)
	tween.set_parallel(false)
	tween.tween_callback(wave_end_cleanup)


func _on_main_menu_start_game_pressed():
	# Two human players first pick their devices on the setup screen. Single
	# player and 2-player-CPU (no second human device to claim) start directly.
	if player_count == 2 and not player_two_is_cpu:
		show_setup_screen()
	else:
		start_game()


# Show the two-player device setup / join screen.
func show_setup_screen():
	game_status = SETUP_SCREEN
	$MainMenu.get_node("CanvasLayer").visible = false
	$MainMenu.set_process_input(false)
	$SetupScreen.get_node("CanvasLayer").visible = true
	$SetupScreen.open()


# Setup screen: both devices claimed and confirmed. Store the chosen devices and
# start the game.
func _on_setup_screen_setup_confirmed(devices):
	player_devices = devices
	$SetupScreen.close()
	$SetupScreen.get_node("CanvasLayer").visible = false
	start_game()


# Setup screen cancelled: return to the main menu.
func _on_setup_screen_setup_cancelled():
	$SetupScreen.close()
	$SetupScreen.get_node("CanvasLayer").visible = false
	game_status = MAIN_MENU
	$MainMenu.get_node("CanvasLayer").visible = true
	$MainMenu.set_process_input(true)
	$MainMenu/CanvasLayer/MainMenuContainer/StartGame.grab_focus()


func _on_main_menu_exit_game_pressed():
	get_tree().quit()


func _on_pause_menu_unpause_game_pressed():
	game_status = game_status_before_pause
	$PauseMenu.get_node("CanvasLayer").visible = false

	# (No upgrade-screen focus to restore — selection is manual per-player state
	# that persisted across the pause.)

	$PauseMenu.set_process_input(false)
	accept_pause = false
	$AcceptPauseTimer.start()
	get_tree().paused = false


func _on_pause_menu_abandon_game_pressed():
	$PauseMenu.get_node("CanvasLayer").visible = false
	$PauseMenu.set_process_input(false)
	get_tree().paused = false
	return_to_main_screen()


func _on_main_menu_credits_pressed():
	game_status = CREDITS
	$Credits.prepare_content()
	$MainMenu.get_node("CanvasLayer").visible = false
	$Credits/CanvasLayer/VBoxContainer/ReturnButton.grab_focus()
	$HUD/CanvasLayer/HighScore.visible = false
	$Credits/CanvasLayer.visible = true
	$Credits.commence_scroll()


func _on_main_menu_how_to_play_pressed():
	game_status = HOW_TO_PLAY
	$MainMenu.get_node("CanvasLayer").visible = false
	$HowToPlay/CanvasLayer/VBoxContainer/ReturnButton.grab_focus()
	$HUD/CanvasLayer/HighScore.visible = false
	$HowToPlay/CanvasLayer.visible = true


func dedication_has_finished():
	dedication.queue_free()
	game_status = INTRO_SEQUENCE
	intro = intro_scene.instantiate()
	add_child(intro)


func intro_has_finished():
	intro.queue_free()
	main_menu()


func _on_main_menu_cheats_pressed():
	cheat_mode = true


func _on_player_player_low_energy():
	$AudioStreamPlayerMusic.pitch_scale = 1.2


func _on_player_player_no_longer_low_energy():
	$AudioStreamPlayerMusic.pitch_scale = 1.0


func upgrade_screen():
	# The "WAVE COMPLETE!" banner has already faded out with the exit fade; hide
	# it. Its opacity is restored in wave_intro() before the next message shows.
	$HUD.get_node("CanvasLayer/Label").visible = false

	# Each shark picks its own three offered upgrades and starts un-confirmed.
	for player in get_players():
		player.choose_offered_upgrades()
		player.upgrade_cursor = 1
		player.upgrade_confirmed = false
		player.upgrade_ai_started = false

	upgrade_advance_delay = constants.UPGRADE_CONFIRM_FLASH_TIME

	$HUD.show_upgrade_screen(get_players())

	game_status = UPGRADE_WAITING_FOR_CHOICE


# Per-frame upgrade navigation while UPGRADE_WAITING_FOR_CHOICE. Each player
# drives its own column via its input (up/down, mouse hover for the mouse owner)
# and confirms with fire / mouse click. Wave proceeds once all have confirmed.
func process_upgrade_choice(delta):
	for player in get_players():
		if player.upgrade_confirmed:
			continue

		if player.input is AiInput:
			process_cpu_upgrade_choice(player, delta)
			continue

		var moved = false

		# Keyboard/controller: up/down move the cursor (edge-triggered).
		if player.input.is_just_pressed("up"):
			player.upgrade_cursor = max(0, player.upgrade_cursor - 1)
			moved = true
		elif player.input.is_just_pressed("down"):
			player.upgrade_cursor = min(2, player.upgrade_cursor + 1)
			moved = true

		# Mouse (owner only): hovering a choice highlights it.
		if player.input.uses_mouse():
			var hovered = $HUD.upgrade_choice_at_mouse(player)
			if hovered != -1 and hovered != player.upgrade_cursor:
				player.upgrade_cursor = hovered
				moved = true

		if moved:
			$HUD.set_upgrade_highlight(player, player.upgrade_cursor)

		# Confirm: fire button, or a mouse click for the mouse owner.
		var confirm = player.input.is_just_pressed("shark_fire")
		if player.input.uses_mouse() and player.input.is_just_pressed("shark_fire_mouse"):
			# A click only confirms if it is over one of this player's choices.
			var clicked = $HUD.upgrade_choice_at_mouse(player)
			if clicked != -1:
				player.upgrade_cursor = clicked
				confirm = true

		if confirm:
			commit_upgrade(player)

	# All players locked in? Wait out the confirm flash, then advance.
	if all_players_confirmed_upgrade():
		upgrade_advance_delay -= delta
		if upgrade_advance_delay <= 0.0:
			$HUD.hide_upgrade_screen()
			game_status = PREPARE_FOR_WAVE


# Apply a player's highlighted choice and play the confirmation flash.
func commit_upgrade(player):
	player.confirm_upgrade_choice()
	$HUD.flash_upgrade_choice(player, player.upgrade_cursor)


# CPU "pretends to decide": wiggles the cursor a few times, then commits.
func process_cpu_upgrade_choice(player, delta):
	if not player.upgrade_ai_started:
		player.upgrade_ai_started = true
		player.upgrade_ai_moves_left = randi_range(3, 6)
		player.upgrade_ai_move_cooldown = constants.UPGRADE_CPU_MOVE_INTERVAL

	player.upgrade_ai_move_cooldown -= delta
	if player.upgrade_ai_move_cooldown > 0.0:
		return
	player.upgrade_ai_move_cooldown = constants.UPGRADE_CPU_MOVE_INTERVAL

	if player.upgrade_ai_moves_left > 0:
		# Wiggle to a different choice.
		var next = player.upgrade_cursor
		while next == player.upgrade_cursor:
			next = randi() % 3
		player.upgrade_cursor = next
		player.upgrade_ai_moves_left -= 1
		$HUD.set_upgrade_highlight(player, player.upgrade_cursor)
	else:
		commit_upgrade(player)


func all_players_confirmed_upgrade():
	for player in get_players():
		if not player.upgrade_confirmed:
			return false
	return true




func _on_main_menu_game_mode_pressed():
	if game_mode == "ARCADE":
		game_mode = "PACIFIST"
	else:
		game_mode = "ARCADE"

	$MainMenu/CanvasLayer/MainMenuContainer/GameMode.text = "MODE: " + str(game_mode)


func _on_main_menu_player_count_pressed():
	# Cycle: 1 player -> 2 players -> 2 players (CPU) -> 1 player.
	if player_count == 1:
		player_count = 2
		player_two_is_cpu = false
	elif player_count == 2 and not player_two_is_cpu:
		player_two_is_cpu = true
	else:
		player_count = 1
		player_two_is_cpu = false

	update_player_count_label()


func update_player_count_label():
	var label = "PLAYERS: " + str(player_count)
	if player_count == 2 and player_two_is_cpu:
		label += " (CPU)"
	$MainMenu/CanvasLayer/MainMenuContainer/PlayerCount.text = label

	# The menu HIGH SCORE reflects the currently-selected mode's board.
	$HUD.get_node("CanvasLayer/HighScore").text = "HIGH SCORE\n" + str(high_score())


func _on_main_menu_statistics_pressed():
	game_status = STATISTICS
	$MainMenu.get_node("CanvasLayer").visible = false
	$HUD/CanvasLayer/HighScore.visible = false
	$Statistics.build_statistics_screen()
	$Statistics/CanvasLayer.visible = true


func _on_statistics_statistics_return_button_pressed():
	game_status = MAIN_MENU
	$MainMenu.get_node("CanvasLayer").visible = true
	$MainMenu/CanvasLayer/MainMenuContainer/Statistics.grab_focus()
	$HUD/CanvasLayer/HighScore.visible = true
	$Statistics/CanvasLayer.visible = false


func _on_credits_credits_return_button_pressed():
	game_status = MAIN_MENU
	$MainMenu.get_node("CanvasLayer").visible = true
	$MainMenu/CanvasLayer/MainMenuContainer/Credits.grab_focus()
	$HUD/CanvasLayer/HighScore.visible = true
	$Credits/CanvasLayer.visible = false


func _on_how_to_play_return_button_pressed():
	game_status = MAIN_MENU
	$MainMenu.get_node("CanvasLayer").visible = true
	$MainMenu/CanvasLayer/MainMenuContainer/HowToPlay.grab_focus()
	$HUD/CanvasLayer/HighScore.visible = true
	$HowToPlay/CanvasLayer.visible = false


func _on_main_menu_options_pressed():
	game_status = OPTIONS
	$MainMenu.get_node("CanvasLayer").visible = false
	$HUD/CanvasLayer/HighScore.visible = false
	$Options.build_options_screen()
	$Options/CanvasLayer.visible = true


func _on_options_options_return_button_pressed():
	Storage.save_config()

	game_status = MAIN_MENU
	$MainMenu.get_node("CanvasLayer").visible = true
	$MainMenu/CanvasLayer/MainMenuContainer/Options.grab_focus()
	$HUD/CanvasLayer/HighScore.visible = true
	$Options/CanvasLayer.visible = false


func _on_steam_overlay_toggled(toggled, _user_activated, _user_id):
	if toggled:
		handle_pause_input()


func _on_steam_input_device_disconnected(input_handle):
	Logging.log_entry("Input device disconnected: " + str(input_handle))


func _on_steam_input_device_connected(input_handle):
	Logging.log_entry("Input device connected: " + str(input_handle))


func _on_artillery_timer():
	var mob = artillery_scene.instantiate()

	var spawn_position

	spawn_position = Vector2(
		randf_range($Player.position.x - 200, $Player.position.x + 200),
		randf_range($Player.position.y - 200, $Player.position.y + 200)
	)

	mob.get_node(".").set_position(spawn_position)
	mob.add_to_group("artilleryGroup")
	add_child(mob, true)

	$ArtilleryTimer.start(
		randf_range(constants.ARTILLERY_MINIMUM_TIME, constants.ARTILLERY_MAXIMUM_TIME)
	)


func _on_accept_pause_timer_timeout():
	accept_pause = true


func _on_wave_time_left_timer_timeout():
	if game_mode == "ARCADE" and game_status == GAME_RUNNING:
		# Make sure we update time to 0
		update_time_left_display()

		# Have a random enemy drop the key in fear.
		# If there are no enemies left, drop it on a living player instead.
		var enemies = get_tree().get_nodes_in_group("enemyGroup")
		if enemies.size():
			var random_enemy_idx = randi_range(0, enemies.size() - 1)
			$Key.global_position = enemies[random_enemy_idx].global_position
		else:
			var living = get_living_players()
			if living.size():
				$Key.global_position = living[0].global_position
		$Key.show()
		$Key/CollisionShape2D.disabled = false
		$Key/AnimatedSprite2D.play()

		Logging.log_entry('Invoking wave_end()')
		wave_end()


func _on_steam_stats_ready(_game: int, _result: int, _user: int) -> void:
	Logging.log_entry("Steam stats / achievements now available.")

	if constants.DEV_WIPE_ACHIEVEMENTS:
		Logging.log_entry("Wiping achievements...")
		#SteamClient.SteamEngine.clearAchievement('ACH_ARCADE_BEAT_1_WAVE')
		SteamClient.SteamEngine.storeStats()


# Player signal that CHEAT DEATH payoff has finished running.
# If we are in CHEATING_DEATH_AT_WAVE_END, we can now get on with it!
func _on_player_player_has_stopped_cheating_death() -> void:
	if game_status == CHEATING_DEATH_AT_WAVE_END:
		wave_end()
		
