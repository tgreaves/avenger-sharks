extends CharacterBody2D

signal player_died
signal player_got_fish(collecting_player)
signal player_got_key(holder)
signal player_found_exit_stop_key_movement
signal player_found_exit
signal player_low_energy
signal player_no_longer_low_energy
signal player_has_stopped_cheating_death

enum {
	ALIVE,
	FISH_FRENZY,
	HUNTING_KEY,
	HUNTING_EXIT,
	FOUND_EXIT,
	GOING_THROUGH_DOOR,
	MOVING_TO_START_POSITION,
	EXPLODING,
	EXPLODED,
	CHEATING_DEATH,
	FOLLOWING_KEY_HOLDER
}

const SharkSprayScene = preload("res://Scenes/SharkSpray.tscn")
const GrenadeScene = preload("res://Scenes/Grenade.tscn")
const MiniSharkScene = preload("res://Scenes/MiniShark.tscn")

@export var speed = constants.PLAYER_SPEED
@export var player_energy = constants.PLAYER_START_GAME_ENERGY
@export var shark_status = ALIVE
@export var spray_size = 0.5
@export var current_powerup_levels = {}
@export var max_powerup_levels = {}
@export var upgrades = {}
# The three upgrade codes offered to this shark on the between-wave screen,
# computed per player from its own eligible upgrades.
var offered_upgrades := []
# Between-wave upgrade selection state (manual cursor, per player).
var upgrade_cursor := 1  # Start on the middle choice.
var upgrade_confirmed := false
# CPU "deliberation": it wiggles the cursor a few times before committing.
var upgrade_ai_moves_left := 0
var upgrade_ai_move_cooldown := 0.0
var upgrade_ai_started := false

# Per-shark score and combo multiplier. In 1-player / 2-player-CPU only player 1
# accrues (CPU and unattributed kills funnel to player 1); in 2-player-human
# each shark keeps its own.
var player_score = 0
var player_score_multiplier = 1
# Fish collected toward this shark's own FISH FRENZY (per-player bar/frenzy).
var fish_collected = 0
# True while this shark is carrying the wave-end key (it opens the exit door).
var has_key = false

var key_global_position
var initial_player_position
var fish_frenzy_enabled = false
var fish_frenzy_colour
var item_magnet_enabled = false
var blink_status = false
var power_pellet_enabled = false
var power_pellet_warning_running = false
var powerup_labels_being_displayed = 0
var fire_delay = constants.PLAYER_FIRE_DELAY
var grenade_delay = constants.PLAYER_GRENADE_DELAY
var astar_pathing_grid
var swim_surge_available: bool = true
var swim_surge_activate: bool = false
var tween_surge: Tween

# Per-player input source. Defaults to ANY (1-player: keyboard + controller both
# drive this player, as in single-player). Reassigned to a device-scoped
# SPECIFIC instance when a second player is present.
var input := PlayerInput.new(PlayerInput.Mode.ANY)
# Haptics target device; set from the assigned controller for player 2.
var haptics_device := 0
# Which arena start marker this player swims to at wave start (player 2 uses a
# second marker so both sharks swim in together).
var start_marker_name := "PlayerStartLocation"
# Persistent identity tint (player 2 is tinted so the two sharks are distinct).
# Applied via the sprites' self_modulate, which multiplies with the transient
# modulate effects (power-pellet red, damage flash) rather than clobbering them.
var player_tint := constants.PLAYER_1_TINT

@onready var arena = get_parent().get_node("Arena")
@onready var hud = get_parent().get_node("HUD")


func _ready():
	shark_status = ALIVE

	# Group membership lets other systems find players without relying on the
	# node being named "Player" (which cannot be unique once there are two).
	if !is_in_group("players"):
		add_to_group("players")

	apply_tint()

	if initial_player_position:
		global_position = initial_player_position
	else:
		initial_player_position = global_position

	# Initiate maximum levels for each power-up
	max_powerup_levels = {
		"SPEED UP": constants.POWERUP_SPEEDUP_MAX_LEVEL,
		"FAST SPRAY": constants.POWERUP_FASTSPRAY_MAX_LEVEL,
		"BIG SPRAY": constants.POWERUP_BIGSPRAY_MAX_LEVEL,
		"SCATTER SPRAY": constants.POWERUP_SCATTERSPRAY_MAX_LEVEL,
		"GRENADE": constants.POWERUP_GRENADE_MAX_LEVEL,
		"MINI SHARK": constants.POWERUP_MINISHARK_MAX_LEVEL
	}

	upgrades = {
		# Code          [ Current Level, Max Level, Image path, Description
		# If Max Level is 0 then it is a health-style purchase (Purchase once, instant result,
		# doesn't stick)
		# If Max Level is 1 then it can only ever be purchased once (Binary item)
		"MAGNET":
		[0, 1, "res://Images/crosshair184.png", "A powerful magnet which does magnet things."],
		"ARMOUR": [0, 3, "res://Images/crosshair184.png", "Decrease incoming damage by 10%"],
		"POTION POWER":
		[0, 3, "res://Images/crosshair184.png", "Health potions are 10% more efficient"],
		"FISH AFFINITY":
		[0, 3, "res://Images/crosshair184.png", "Decrease fish needed for FRENZY by 10%"],
		"DOMINANT DINO":
		[0, 3, "res://Images/crosshair184.png", "Increase Mr Dinosaur attack time by 20%"],
		"MORE POWER": [0, 3, "res://Images/crosshair184.png", "Increase Power Up duration by 20%"],
		"LOOT LOVER": [0, 3, "res://Images/crosshair184.png", "Increase item drop rate by 10%"],
		"CHEAT DEATH":
		[0, 1, "res://Images/crosshair184.png", "Regain 50% health upon death - Once!"],
		"SWIM SURGE":
		[0, 3, "res://Images/crosshair184.png", "Improve swim surge re-use time by 10%"],
		"HEAL ME": [-1, 0, "res://Images/crosshair184.png", "Instantly regain all health"]
	}

func do_ready():
	_ready()


func _input(event):
	# Feeds device-scoped input state in SPECIFIC (2-player) mode. No-op in ANY.
	input.feed_event(event)


func prepare_for_new_game():
	speed = constants.PLAYER_SPEED
	fire_delay = constants.PLAYER_FIRE_DELAY
	spray_size = constants.PLAYER_FIRE_SIZE_BASE
	grenade_delay = constants.PLAYER_GRENADE_DELAY

	if constants.DEV_FISH_FRENZY_AVAILABLE_IMMEDIATELY:
		fish_frenzy_enabled = true
	else:
		fish_frenzy_enabled = false
	
	power_pellet_enabled = false
	swim_surge_available = true
	swim_surge_activate = false
	$AnimatedSprite2D.set_modulate(Color(1, 1, 1, 1))

	for single_powerup in max_powerup_levels:
		current_powerup_levels[single_powerup] = 0

	for single_key in upgrades.keys():
		if single_key == "HEAL ME":
			upgrades[single_key][0] = -1
		else:
			upgrades[single_key][0] = 0

	if constants.DEV_CHEAT_DEATH_AVAILABLE_IMMEDIATELY:
		upgrades['CHEAT DEATH'][0] = 1

	hud.reset_powerup_bar()
	hud.reset_powerup_bar_text()
	hud.set_all_powerup_levels(self)
	hud.update_upgrade_summary(self)


	despawn_mini_sharks()
	$PowerUpTickTimer.start()


func prepare_for_new_wave():
	blink_status = false
	$AnimatedSprite2DDamaged.visible = false
	$EnergyProgressBar.visible = true

	if get_parent().game_mode == "ARCADE":
		$FishProgressBar.visible = true

	set_fire_rate_delay_timer()
	set_grenade_rate_delay_timer()


# Revive a shark that was downed in the previous wave (co-op). Restores it to a
# clean ALIVE state at full energy. Safe to call on a living shark too.
func revive_for_new_wave():
	shark_status = ALIVE
	has_key = false
	player_energy = constants.PLAYER_START_GAME_ENERGY
	$CollisionShape2D.set_deferred("disabled", false)
	$AnimatedSprite2D.animation = "default"
	$AnimatedSprite2D.speed_scale = 1
	$AnimatedSprite2D.set_modulate(Color(1, 1, 1, 1))
	$EnergyProgressBar.value = player_energy
	$EnergyProgressBar.visible = true
	velocity = Vector2(0, 0)


func get_input():
	if shark_status != ALIVE:
		return

	var input_direction = input.get_move_vector()

	if !swim_surge_activate:
		velocity = input_direction * speed

	if $FireRateTimer.time_left == 0 && get_parent().game_mode == "ARCADE":
		# Mouse aiming (only for the player that owns the mouse)
		if input.uses_mouse() and input.is_pressed("shark_fire_mouse"):
			var target_direction = (get_global_mouse_position() - global_position).normalized()
			spawn_shark_spray(target_direction)
			scatter_spray_handler(target_direction)
			mini_shark_fire(target_direction)
			grenade_fire(target_direction)

			Storage.increase_stat("player", "shots_fired", 1)
			play_spray_sound()
			set_fire_rate_delay_timer()

		# Controller (Twin stick)
		var shoot_direction = input.get_aim_vector()
		if shoot_direction:
			shoot_direction = shoot_direction.normalized()

			spawn_shark_spray(shoot_direction)
			scatter_spray_handler(shoot_direction)
			mini_shark_fire(shoot_direction)
			grenade_fire(shoot_direction)

			Storage.increase_stat("player", "shots_fired", 1)
			play_spray_sound()
			set_fire_rate_delay_timer()

	# Aiming line support (Controller only)
	if get_parent().game_mode == "ARCADE":
		var shoot_direction = input.get_aim_vector()

		if shoot_direction:
			shoot_direction = shoot_direction.normalized()

			$RayCast2D.target_position = shoot_direction * 10000
			if $RayCast2D.is_colliding():
				# Need to do this check as rogue traps were causing invalid index position errors.
				if $RayCast2D.get_collider():
					var line_end_position = $RayCast2D.get_collider().position

					# Tilemaps default to (0,0) hit location unless we do something special...
					if $RayCast2D.get_collider() is TileMapLayer:
						line_end_position = $RayCast2D.get_collision_point()

					# Remove existing target.
					remove_aiming_line()

					$AimingLine.add_point(to_local(line_end_position))

		else:
			# Remove targetting line when stick not being used.
			remove_aiming_line()

	if input.is_pressed("fish_frenzy") && fish_frenzy_enabled == true:
		# If we are SWIM SURGING, stop that immediately so we don't fall off the map.
		if swim_surge_activate:
			_on_swim_surge_running_timer_timeout()

		fish_frenzy_enabled = false
		shark_status = FISH_FRENZY
		fish_frenzy_colour = "BLUE"
		velocity = Vector2(0, 0)
		$CollisionShape2D.disabled = true
		$FishProgressBar.visible = true
		$FishFrenzyTimer.start(constants.PLAYER_FISH_FRENZY_DURATION)
		$FishFrenzyFireTimer.start(constants.PLAYER_FISH_FRENZY_FIRE_DELAY)

		if Storage.config.get_value("config", "enable_haptics", false):
			Input.start_joy_vibration(haptics_device, 0.25, 0.25, constants.PLAYER_FISH_FRENZY_DURATION)

	if shark_status == ALIVE and input.is_just_pressed("secondary_ability"):
		# For now, this will trigger SWIM SURGE.

		if swim_surge_available and input_direction:
			swim_surge_activate = true
			swim_surge_available = false

			tween_surge = get_tree().create_tween()
			tween_surge.tween_property(self, "velocity", input_direction * 3000, 0.25)

			$SwimSurgeRunningTimer.start()
			$AudioStreamPlayerSplash.play()
			$SurgeParticles.set_emitting(true)


func _physics_process(_delta):
	input.update(self, _delta)
	get_input()
	move_and_slide()

	if $ProgressBarBlinkTimer.time_left == 0:
		if blink_status == true:
			blink_status = false
		else:
			blink_status = true

		if (shark_status != EXPLODING) and (shark_status != EXPLODED):
			if player_energy <= constants.PLAYER_LOW_ENERGY_BLINK:
				$EnergyProgressBar.visible = blink_status

			if fish_frenzy_enabled:
				$FishProgressBar.visible = blink_status

		$ProgressBarBlinkTimer.start()

	if $PowerUpTickTimer.time_left == 0 && shark_status == ALIVE:
		power_up_tick()
		$PowerUpTickTimer.start()

	match shark_status:
		ALIVE:
			if power_pellet_enabled:
				if $PowerPelletTimer.time_left == 0:
					power_pellet_enabled = false
					power_pellet_warning_running = false
					end_shark_attack()
				else:
					# Start 'Running out' blinking timer
					if $PowerPelletTimer.time_left < 2 and !power_pellet_warning_running:
						$PowerPelletWarningTimer.start()
						power_pellet_warning_running = true

				# Alternate normal / red shark colour as timer is running out.
				if power_pellet_warning_running and $PowerPelletWarningTimer.time_left == 0:
					if $AnimatedSprite2D.get_modulate() == Color(1, 1, 1, 1):
						$AnimatedSprite2D.set_modulate(Color(1, 0, 0, 1))
					else:
						$AnimatedSprite2D.set_modulate(Color(1, 1, 1, 1))

					$PowerPelletWarningTimer.start()

			if velocity.x > 0:
				$AnimatedSprite2D.set_flip_h(true)

			if velocity.x < 0:
				$AnimatedSprite2D.set_flip_h(false)

			$AnimatedSprite2D.play()

			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				var collided_with = collision.get_collider()

				if collision.get_collider() is TileMapLayer:
					break

				if collision.get_collider().is_in_group("fishGroup"):
					# The fish flies to this player's score display.
					collided_with.get_node(".").death(false, self)
					$AudioStreamPlayerGotFish.play()
					player_got_fish.emit(self)
					break

				if collision.get_collider().is_in_group("dinosaurGroup"):
					collided_with.get_node(".").go_on_a_rampage(self)
					break

				if collision.get_collider().is_in_group("itemGroup"):
					if collided_with.get_node(".").source == "DROPPED":
						get_parent().dropped_items_on_screen = (
							get_parent().dropped_items_on_screen - 1
						)

					match collided_with.get_node(".").item_type:
						"health":
							var original_energy = player_energy

							var health_percentage = upgrades["POTION POWER"][0] * 10
							var health_to_add = int(
								(
									constants.HEALTH_POTION_BONUS
									+ ((health_percentage / 100.0) * constants.HEALTH_POTION_BONUS)
								)
							)

							player_energy = player_energy + health_to_add
							if get_parent().cheat_mode:
								if player_energy > constants.PLAYER_START_GAME_ENERGY_CHEATING:
									player_energy = constants.PLAYER_START_GAME_ENERGY_CHEATING
							else:
								if player_energy > constants.PLAYER_START_GAME_ENERGY:
									player_energy = constants.PLAYER_START_GAME_ENERGY

							$AudioStreamHealth.play()
							powerup_label_animation("HEALTH!")
							_on_main_player_update_energy()

							if (
								(original_energy <= constants.PLAYER_LOW_ENERGY_BLINK)
								&& (player_energy > constants.PLAYER_LOW_ENERGY_BLINK)
							):
								player_no_longer_low_energy.emit()

							collided_with.get_node(".").despawn()

						"chest":
							var powerup_options = [
								"SPEED UP", "FAST SPRAY", "BIG SPRAY", "SCATTER SPRAY", "GRENADE", "MINI SHARK"
							]
							var powerup_selected = powerup_options[randi() % powerup_options.size()]

							# Developer testing.
							if constants.DEV_FORCE_POWERUP:
								powerup_selected = constants.DEV_FORCE_POWERUP

							# Increase powerup level (but not over its maximum allowed)
							current_powerup_levels[powerup_selected] += 1
							if (
								current_powerup_levels[powerup_selected]
								> max_powerup_levels[powerup_selected]
							):
								current_powerup_levels[powerup_selected] = max_powerup_levels[powerup_selected]

							# Scalar-stat powerups (SPEED UP / FAST SPRAY / BIG SPRAY /
							# GRENADE) recompute from level via the formula table.
							apply_powerup_level(powerup_selected)

							# MINI SHARK is not a scalar stat: it spawns a shark.
							if powerup_selected == "MINI SHARK":
								if (
									get_tree().get_nodes_in_group("miniSharkGroup").size()
									< max_powerup_levels[powerup_selected]
								):
									var new_mini_shark = MiniSharkScene.instantiate()
									add_child(new_mini_shark)
									new_mini_shark.add_to_group("miniSharkGroup")

									# Reset circular position of the mini sharks when we spawn a new one, to ensure
									# everything stays evenly spaced.
									recalculate_mini_shark_spacing()

							powerup_label_animation(powerup_selected + "!")
							hud.activate_powerup(self, powerup_selected)
							hud.set_powerup_level(
								self, powerup_selected, current_powerup_levels[powerup_selected]
							)
							$AudioStreamPowerUp.play()
						"power-pellet":
							$PowerPelletTimer.start(constants.POWER_PELLET_ACTIVE_DURATION)
							powerup_label_animation("TIME FOR DINNER!")
							power_pellet_enabled = true
							power_pellet_warning_running = false
							get_parent().get_node("AudioStreamPlayerMusic").set_stream_paused(true)
							get_parent().get_node("SharkAttackMusic").play()

							# BLOOD THIRSTY
							$AnimatedSprite2D.set_modulate(Color(1, 0, 0, 1))
							$HungryParticles.set_emitting(true)

							# Force direction change
							for single_enemy in get_tree().get_nodes_in_group("enemyGroup"):
								single_enemy.consider_calling_for_help()
								single_enemy.reset_state_timer()

					collided_with.get_node(".").despawn()

					break

				# Default - Enemy
				collided_with.get_node(".").death("PLAYER-BODY", self)
				player_hit()

		FISH_FRENZY:
			if $FishFrenzyTimer.time_left == 0:
				stop_fish_frenzy()

				shark_status = ALIVE
			else:
				shake(10.0)
				$AnimatedSprite2D.rotation_degrees += 20
				if $AnimatedSprite2D.rotation_degrees >= 360:
					$AnimatedSprite2D.rotation_degrees = 0

				fish_collected = (
					($FishFrenzyTimer.time_left / constants.PLAYER_FISH_FRENZY_DURATION)
					* constants.FISH_TO_TRIGGER_FISH_FRENZY
				)
				_on_main_player_update_fish()

				if $FishFrenzyFireTimer.time_left == 0:
					$FishFrenzyFireTimer.start(constants.PLAYER_FISH_FRENZY_FIRE_DELAY)
					var i = 0

					while i <= 32:
						var target_direction = Vector2(1, 1).normalized()
						target_direction = target_direction.rotated(deg_to_rad(360.0 / 32.0) * i)
						var shark_spray = SharkSprayScene.instantiate()
						shark_spray.owner_player = self
						get_parent().add_child(shark_spray)
						shark_spray.add_to_group("sharkSprayGroup")
						shark_spray.global_position = position
						shark_spray.velocity = target_direction * constants.PLAYER_FIRE_SPEED

						if fish_frenzy_colour == "BLUE":
							fish_frenzy_colour = "GREEN"
						else:
							shark_spray.modulate = Color(0, 1, 0)
							fish_frenzy_colour = "BLUE"

						play_spray_sound()
						i += 1

		EXPLODING:
			if $PlayerExplosionTimer.time_left == 0:
				# Can the player cheat death?
				if upgrades["CHEAT DEATH"][0]:
					upgrades["CHEAT DEATH"][0] = 0
					hud.update_upgrade_summary(self)

					player_energy = 0.75 * constants.PLAYER_START_GAME_ENERGY
					$EnergyProgressBar.value = player_energy

					# Play explosion backwards (a bit slower so sound FX fits)
					$AnimatedSprite2D.animation = "explosion"
					$AnimatedSprite2D.speed_scale = -0.5
					$AnimatedSprite2D.play()
					$AudioStreamPlayerExplosionReverse.play()

					shark_status = CHEATING_DEATH
					$PlayerExplosionTimer.start()
				else:
					player_died.emit()
					shark_status = EXPLODED
		CHEATING_DEATH:
			if $PlayerExplosionTimer.time_left == 0:
				# Activate player again.
				shark_status = ALIVE
				$CollisionShape2D.set_deferred("disabled", false)
				$AnimatedSprite2D.animation = "default"
				$AnimatedSprite2D.speed_scale = 1
				$EnergyProgressBar.visible = true

				if get_parent().game_mode == "ARCADE":
					$FishProgressBar.visible = true

				powerup_label_animation("DEATH CHEATED!")

				# Give a 1s grace period before taking damage again.
				$PlayerHitGracePeriodTimer.start(1)
				
				player_has_stopped_cheating_death.emit()
				
		HUNTING_KEY:
			if velocity.x > 0:
				$AnimatedSprite2D.set_flip_h(true)

			if velocity.x < 0:
				$AnimatedSprite2D.set_flip_h(false)

			if $HuntingKeyTimer.time_left == 0:
				position = get_parent().get_node("Key").global_position

			# Have we reached the next node on the astar pathing grid?
			var tilemap_coords = arena.get_tilemap_coords(global_position)

			if astar_pathing_grid.size():
				if tilemap_coords == astar_pathing_grid[0]:
					astar_pathing_grid.pop_front()

					if astar_pathing_grid.size():
						var target_direction = (
							(
								arena.get_position_from_tilemap(
									astar_pathing_grid[0]
								)
								- global_position
							)
							. normalized()
						)
						velocity = target_direction * constants.PLAYER_SPEED_ESCAPING

			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)

				# Only the first shark to reach the key grabs it. get_parent()
				# tracks the current holder so a second shark can't also grab it.
				if collision.get_collider().name == "Key" and get_parent().key_holder == null:
					shark_status = HUNTING_EXIT
					has_key = true
					get_parent().key_holder = self
					arena.get_node("ExitDoor").get_node("CollisionShape2D").disabled = false
					player_got_key.emit(self)

					var exit_door_global = (
						arena.get_node("ExitDoor").global_position
					)
					astar_pathing_grid = (
						get_parent()
						. get_node("Arena")
						. get_astar_route_from_positions(global_position, exit_door_global)
					)

					# Head towards the first path node; if the route is empty (e.g.
					# already adjacent to the door), aim straight at the door.
					var next_target = exit_door_global
					if astar_pathing_grid.size():
						next_target = arena.get_position_from_tilemap(astar_pathing_grid[0])
					var target_direction = (next_target - global_position).normalized()
					velocity = target_direction * constants.PLAYER_SPEED_ESCAPING

					$HuntingDoorTimer.start()
		FOLLOWING_KEY_HOLDER:
			# Trail the key-holder to the exit (it opens the door, not us).
			if velocity.x > 0:
				$AnimatedSprite2D.set_flip_h(true)
			if velocity.x < 0:
				$AnimatedSprite2D.set_flip_h(false)

			if is_instance_valid(key_holder_to_follow):
				# Once close to the holder, stop and stay put (avoids jittering
				# on top of it when it pauses at the door).
				if global_position.distance_to(key_holder_to_follow.global_position) <= constants.FOLLOW_STOP_DISTANCE:
					velocity = Vector2(0, 0)
				else:
					astar_pathing_grid = arena.get_astar_route_from_positions(
						global_position, key_holder_to_follow.global_position
					)
					astar_pathing_grid.pop_front()

					if astar_pathing_grid.size():
						var target_direction = (
							(
								arena.get_position_from_tilemap(astar_pathing_grid[0])
								- global_position
							)
							. normalized()
						)
						velocity = target_direction * constants.PLAYER_SPEED_ESCAPING
		HUNTING_EXIT:
			# Have we reached the next node on the astar pathing grid?
			var tilemap_coords = arena.get_tilemap_coords(global_position)

			if astar_pathing_grid.size() and tilemap_coords == astar_pathing_grid[0]:
				astar_pathing_grid.pop_front()

				if astar_pathing_grid.size():
					var target_direction = (
						(
							arena.get_position_from_tilemap(
								astar_pathing_grid[0]
							)
							- global_position
						)
						. normalized()
					)
					velocity = target_direction * constants.PLAYER_SPEED_ESCAPING

			if velocity.x > 0:
				$AnimatedSprite2D.set_flip_h(true)

			if velocity.x < 0:
				$AnimatedSprite2D.set_flip_h(false)

			if $HuntingDoorTimer.time_left == 0:
				# Anti-stuck failsafe: teleport to the exit door. (On boss waves the
				# exit door is relocated to the room's top door, so use its position
				# rather than the hard-coded arena-top spot.)
				var exit_door = arena.get_node("ExitDoor")
				position = exit_door.global_position

			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)

				# Only the key-holder can open the exit door.
				if collision.get_collider().name == "ExitDoor" and has_key:
					shark_status = FOUND_EXIT
					velocity = Vector2i(0, 0)

					# Open door.
					arena.open_top_door()
					arena.get_node("ExitDoor").get_node("CollisionShape2D").disabled = true

					player_found_exit_stop_key_movement.emit()
					shark_status = GOING_THROUGH_DOOR

					#var tween_camera = get_tree().create_tween()
					#tween_camera.tween_property($Camera2D, "zoom", Vector2(3.0,3.0), 0.2)

					$DoorOpenTimer.start()

		GOING_THROUGH_DOOR:
			if $DoorOpenTimer.time_left == 0:
				var target_direction = (
					(
						arena.get_node("ExitLocation").global_position
						- global_position
					)
					. normalized()
				)
				velocity = target_direction * constants.PLAYER_SPEED_ESCAPING
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)

				if collision.get_collider().name == "ExitLocation":
					player_found_exit.emit()
		MOVING_TO_START_POSITION:
			if $DoorCloseTimer.time_left == 0:
				# Close bottom door.
				arena.close_bottom_door()
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)

				if collision.get_collider().name == start_marker_name:
					shark_status = ALIVE
					arena.get_node(start_marker_name).get_node("CollisionShape2D").disabled = true


func player_hit():
	if shark_status != ALIVE:
		return

	if (!power_pellet_enabled) and $PlayerHitGracePeriodTimer.time_left == 0:
		$PlayerHitGracePeriodTimer.start()
		$AudioStreamPlayerHit.play()

		get_parent().reset_score_multiplier(self)

		hud.flash_screen_red()

		if Storage.config.get_value("config", "enable_haptics", false):
			Input.start_joy_vibration(haptics_device, 0.5, 0.5, 0.05)

		var damage_reduction_percentage = (
			upgrades["ARMOUR"][0] * constants.ARMOUR_DAMAGE_REDUCTION_PERCENTAGE
		)
		var damage_to_perform = (
			constants.PLAYER_HIT_BY_ENEMY_DAMAGE
			- ((damage_reduction_percentage / 100.0) * constants.PLAYER_HIT_BY_ENEMY_DAMAGE)
		)

		player_energy = player_energy - damage_to_perform

		if player_energy <= 0:
			player_energy = 0
			$CollisionShape2D.set_deferred("disabled", true)
			velocity = Vector2(0, 0)
			$AnimatedSprite2D.animation = "explosion"
			$AudioStreamPlayerExplosion.play()
			$EnergyProgressBar.visible = false
			$FishProgressBar.visible = false
			shark_status = EXPLODING
			$PlayerExplosionTimer.start()
			despawn_mini_sharks()
			remove_aiming_line()
		else:
			$AnimatedSprite2DDamaged.visible = true
			$AnimatedSprite2DDamaged.play()

			$EnergyProgressBar.value = player_energy
			_on_main_player_update_energy()

			if player_energy <= constants.PLAYER_LOW_ENERGY_BLINK:
				player_low_energy.emit()


var key_holder_to_follow


# Called (via Main) when the OTHER shark grabbed the key: trail it to the exit.
func follow_key_holder(holder):
	# Only a shark still hunting the key should switch to following.
	if shark_status != HUNTING_KEY:
		return
	key_holder_to_follow = holder
	shark_status = FOLLOWING_KEY_HOLDER


# The door is open; a following shark now heads through it to the exit too.
func go_through_open_door():
	if shark_status != FOLLOWING_KEY_HOLDER:
		return
	shark_status = GOING_THROUGH_DOOR
	$DoorOpenTimer.start()


func _on_main_player_hunt_key(passed_key_global_position):
	# A downed shark (sitting out the wave) does not join the key hunt.
	if not is_player_alive():
		return

	if shark_status == FISH_FRENZY:
		stop_fish_frenzy()

	remove_aiming_line()

	shark_status = HUNTING_KEY
	key_global_position = passed_key_global_position

	astar_pathing_grid = arena.get_astar_route_from_positions(
		global_position, key_global_position
	)

	var target_direction = (
		(
			arena.get_position_from_tilemap(astar_pathing_grid[0])
			- global_position
		)
		. normalized()
	)
	velocity = target_direction * constants.PLAYER_SPEED_ESCAPING

	# 'Break glass'
	$HuntingKeyTimer.start()


func _on_main_player_move_to_starting_position():
	shark_status = MOVING_TO_START_POSITION

	set_process(true)
	set_physics_process(true)
	visible = true

	var marker = arena.get_node(start_marker_name)
	marker.get_node("CollisionShape2D").disabled = false

	# Swim toward this player's own start marker (which triggers ALIVE on
	# collision). Each player has its own marker so both swim in together.
	var target_direction = (marker.global_position - global_position).normalized()
	velocity = target_direction * constants.PLAYER_SPEED

	$DoorCloseTimer.start()


func powerup_label_animation(powerup_name):
	var new_label = $PowerUpLabel.duplicate()
	add_child(new_label)

	powerup_labels_being_displayed += 1

	# Initial position bump if there are multiple animations happening.
	if powerup_labels_being_displayed > 1:
		new_label.position.y += -50 * (powerup_labels_being_displayed - 1)

	new_label.set_modulate(Color(1, 1, 1, 1))
	new_label.text = powerup_name
	new_label.visible = true

	# Text should move upwards slightly.
	var target_position = new_label.position
	target_position.y += -50

	var tween = get_tree().create_tween()
	tween.set_parallel()
	tween.tween_property(new_label, "modulate", Color(0, 0, 0, 0), 2)
	tween.tween_property(new_label, "position", target_position, 2)
	tween.tween_callback(self.powerup_label_animation_decrease_count).set_delay(1.5)
	tween.tween_callback(new_label.queue_free).set_delay(2)


func powerup_label_animation_decrease_count():
	powerup_labels_being_displayed += -1

	if powerup_labels_being_displayed < 0:
		powerup_labels_being_displayed = 0


# Play this shark's spray sound, but only if Main's throttle allows it (avoids
# two sharks stacking near-simultaneous shots into a muddy doubled sound).
func play_spray_sound():
	# Route through Main's single shared spray voice (avoids two per-shark
	# players layering into a doubled sound when firing at slightly different
	# times).
	get_parent().play_spray_sound()


func set_fire_rate_delay_timer():
	$FireRateTimer.start(fire_delay)


func set_grenade_rate_delay_timer():
	$GrenadeRateTimer.start(grenade_delay)


func mini_shark_fire(shark_fire_direction):
	for mini_shark in get_tree().get_nodes_in_group("miniSharkGroup"):
		var mini_shark_spray = SharkSprayScene.instantiate()
		mini_shark_spray.owner_player = self
		get_parent().add_child(mini_shark_spray)
		mini_shark_spray.add_to_group("miniSharkSprayGroup")
		mini_shark_spray.global_position = mini_shark.global_position
		mini_shark_spray.velocity = shark_fire_direction * constants.PLAYER_FIRE_SPEED


func recalculate_mini_shark_spacing():
	var number_of_mini_sharks = get_tree().get_nodes_in_group("miniSharkGroup").size()
	var shark_count = 0
	for single_shark in get_tree().get_nodes_in_group("miniSharkGroup"):
		single_shark.set_circle_position(shark_count, number_of_mini_sharks)
		shark_count = shark_count + 1


func despawn_mini_sharks():
	for single_shark in get_tree().get_nodes_in_group("miniSharkGroup"):
		single_shark.queue_free()


func grenade_fire(_fire_direction):
	if $GrenadeRateTimer.time_left == 0 and current_powerup_levels["GRENADE"]:
		var grenade = GrenadeScene.instantiate()
		get_parent().add_child(grenade)
		grenade.add_to_group("grenadeGroup")
		grenade.owner_player = self
		grenade.global_position = position

		var enemy_distance = 10000
		var closest_enemy

		if get_tree().get_nodes_in_group("enemyGroup").size():
			# Find nearest enemy that is alive.

			for enemy in get_tree().get_nodes_in_group("enemyGroup"):
				if enemy.is_enemy_alive():
					var distance = position.distance_to(enemy.position)
					if distance < enemy_distance:
						enemy_distance = distance
						closest_enemy = enemy

		if enemy_distance != 10000:
			grenade.velocity = (
				position.direction_to(closest_enemy.position) * constants.GRENADE_SPEED
			)
		else:
			grenade.velocity = Vector2(0, 0)

		$GrenadeRateTimer.start(grenade_delay)

func scatter_spray_handler(target_direction):
	if current_powerup_levels["SCATTER SPRAY"]:
		var required_angle = 90 / (current_powerup_levels["SCATTER SPRAY"]+1)

		match current_powerup_levels["SCATTER SPRAY"]:
			1:
				spawn_shark_spray(target_direction.rotated(deg_to_rad(required_angle)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(-required_angle)))
			2:
				spawn_shark_spray(target_direction.rotated(deg_to_rad(required_angle)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(required_angle*2)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(-required_angle)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(-required_angle*2)))
			3:
				spawn_shark_spray(target_direction.rotated(deg_to_rad(required_angle)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(required_angle*2)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(required_angle*3)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(-required_angle)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(-required_angle*2)))
				spawn_shark_spray(target_direction.rotated(deg_to_rad(-required_angle*3)))

func _on_main_player_enable_fish_frenzy():
	powerup_label_animation("FRENZY READY!")
	fish_frenzy_enabled = true


# Apply this player's identity tint to the shark sprites via self_modulate,
# which multiplies with the transient modulate effects (power-pellet, damage)
# instead of clobbering them.
func apply_tint():
	$AnimatedSprite2D.self_modulate = player_tint
	$AnimatedSprite2DDamaged.self_modulate = player_tint
	$AnimatedSprite2DSurgeReady.self_modulate = player_tint


# Screen shake is owned by the shared co-op camera, so it is felt across both
# players. These delegates keep existing callers (fish frenzy, Artillery) working.
func shake(shake_amount):
	get_parent().get_coop_camera().shake(shake_amount)


func shake_reset():
	get_parent().get_coop_camera().shake_reset()


func _on_main_player_update_energy():
	$EnergyProgressBar.value = player_energy
	$EnergyProgressBar.visible = true


func _on_main_player_update_fish():
	$FishProgressBar.value = fish_collected


func stop_fish_frenzy():
	$AnimatedSprite2D.rotation_degrees = 0
	shake_reset()
	fish_collected = 0
	_on_main_player_update_fish()
	$CollisionShape2D.disabled = false


func power_up_tick():
	for powerup in max_powerup_levels:
		if current_powerup_levels[powerup] >= 1:
			var single_powerup = hud.get_node("CanvasLayer/PowerUpContainer").get_node(
				powerup
			)
			var value = single_powerup.get_node("Label/ProgressBar").value
			if value:
				value -= 1
				single_powerup.get_node("Label/ProgressBar").value = value

				if value <= 0:
					decrease_powerup_level(powerup)

					# Scalar-stat powerups recompute from the (now decreased) level.
					apply_powerup_level(powerup)

					# MINI SHARK is not a scalar stat: it despawns a shark.
					if powerup == "MINI SHARK":
						for single_shark in get_tree().get_nodes_in_group("miniSharkGroup"):
							single_shark.queue_free()
							break

						recalculate_mini_shark_spacing()


# Recompute a powerup's scalar stat from its current level, driven by the
# formula table in Constants. No-op for powerups without a scalar stat
# (SCATTER SPRAY, MINI SHARK), which are handled explicitly at each call site.
func apply_powerup_level(powerup):
	var formula = constants.POWERUP_STAT_FORMULAS.get(powerup)
	if formula == null:
		return

	set(
		formula.property,
		formula.base + (formula.direction * formula.step * current_powerup_levels[powerup])
	)


func decrease_powerup_level(powerup):
	current_powerup_levels[powerup] = current_powerup_levels[powerup] - 1
	if current_powerup_levels[powerup] <= 0:
		current_powerup_levels[powerup] = 0
		hud.deactivate_powerup(self, powerup)
	else:
		hud.activate_powerup(self, powerup)

	hud.set_powerup_level(self, powerup, current_powerup_levels[powerup])


# Pick this shark's three upgrade choices from its own eligible upgrades
# (those not yet at max level), padded with HEAL ME. Stored in offered_upgrades.
func choose_offered_upgrades():
	var eligible: Array = []
	for single_upgrade in upgrades:
		var detail = upgrades.get(single_upgrade)
		if detail[0] < detail[1]:
			eligible.append(single_upgrade)

	while eligible.size() < 3:
		eligible.append("HEAL ME")

	eligible.shuffle()
	offered_upgrades = [eligible.pop_front(), eligible.pop_front(), eligible.pop_front()]

	if constants.DEV_FORCE_UPGRADE:
		offered_upgrades[0] = constants.DEV_FORCE_UPGRADE


func confirm_upgrade_choice():
	# Apply the upgrade this shark's cursor is on, and lock the choice in.
	var selected_upgrade = offered_upgrades[upgrade_cursor]
	upgrade_confirmed = true

	$AudioStreamPlayerSelectedUpgrade.play()

	# Mark upgrade as in use by increasing its level.
	# Ensure level does not exceed the maximum allowed.

	if upgrades[selected_upgrade][0] != -1:
		upgrades[selected_upgrade][0] = upgrades[selected_upgrade][0] + 1
		if upgrades[selected_upgrade][0] > upgrades[selected_upgrade][1]:
			upgrades[selected_upgrade][0] = upgrades[selected_upgrade][1]

	match selected_upgrade:
		"MAGNET":
			item_magnet_enabled = true
		"ARMOUR":
			pass  # No further action other than marking upgrade as in use needed.
		"FISH AFFINITY":
			var affinity_percentage = upgrades["FISH AFFINITY"][0] * 10
			var fish_needed = int(
				(
					constants.FISH_TO_TRIGGER_FISH_FRENZY
					- ((affinity_percentage / 100.0) * constants.FISH_TO_TRIGGER_FISH_FRENZY)
				)
			)
			$FishProgressBar.max_value = fish_needed
		"MORE POWER":
			hud.reset_powerup_bar_durations(self)
		"HEAL ME":
			var original_energy = player_energy
			player_energy = constants.PLAYER_START_GAME_ENERGY
			_on_main_player_update_energy()

			if (
				(original_energy <= constants.PLAYER_LOW_ENERGY_BLINK)
				&& (player_energy > constants.PLAYER_LOW_ENERGY_BLINK)
			):
				player_no_longer_low_energy.emit()

	hud.update_upgrade_summary(self)


func spawn_shark_spray(target_direction):
	var shark_spray = SharkSprayScene.instantiate()
	shark_spray.owner_player = self
	get_parent().add_child(shark_spray)
	shark_spray.add_to_group("sharkSprayGroup")
	shark_spray.global_position = position
	shark_spray.velocity = velocity + (target_direction * constants.PLAYER_FIRE_SPEED)

func is_player_alive():
	if shark_status == ALIVE or shark_status == FISH_FRENZY:
		return true

	return false

func is_player_in_fish_frenzy():
	if shark_status == FISH_FRENZY:
		return true
	
	return false
	
func is_player_cheating_death():
	if shark_status == CHEATING_DEATH:
		return true

	if shark_status == EXPLODING and upgrades["CHEAT DEATH"][0]:
		return true

	return false


# Truly out of the game (dying/dead). Every other state — including the wave-end
# hunt/exit states — counts as still in play, so co-op game-over is only decided
# when all sharks are actually down (not merely "not ALIVE").
func is_player_down():
	return shark_status == EXPLODING or shark_status == EXPLODED

func remove_aiming_line():
	if $AimingLine.get_point_count() > 1:
		$AimingLine.remove_point(1)


func end_shark_attack():
	$AnimatedSprite2D.set_modulate(Color(1, 1, 1, 1))
	$HungryParticles.set_emitting(false)

	# SharkAttackMusic is shared, so only stop it (and resume normal music) once
	# NO shark is still power-pelleted — otherwise one shark's pellet ending would
	# cut the music short for the other. Callers clear their own flag first.
	var any_still_attacking = false
	for player in get_parent().get_players():
		if player.power_pellet_enabled:
			any_still_attacking = true
			break

	if not any_still_attacking:
		get_parent().get_node("SharkAttackMusic").stop()
		get_parent().get_node("AudioStreamPlayerMusic").set_stream_paused(false)

	for single_enemy in get_tree().get_nodes_in_group("enemyGroup"):
		single_enemy.reset_state_timer()
		single_enemy.stop_calling_for_help()


func _on_swim_surge_running_timer_timeout():
	tween_surge.kill()
	swim_surge_activate = false
	$SurgeParticles.set_emitting(false)

	var swim_surge_improvement_percentage = upgrades["SWIM SURGE"][0] * 10
	var swim_surge_recharge_time = (
		constants.SWIM_SURGE_BASE_RECHARGE_TIME
		- ((swim_surge_improvement_percentage / 100.0) * constants.SWIM_SURGE_BASE_RECHARGE_TIME)
	)

	$SwimSurgeReuseTimer.start(swim_surge_recharge_time)


func _on_swim_surge_reuse_timer_timeout():
	swim_surge_available = true
	$AnimatedSprite2DSurgeReady.set_visible(true)
	$AnimatedSprite2DSurgeReady.play()
