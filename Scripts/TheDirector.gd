extends Node

@export var wave_design = {}
var spawn_ratios = {}
var running_chance = 0.0


func design_wave(wave_number):
	Logging.log_entry("Designing for Wave " + str(wave_number))

	var left_to_spawn = 0

	wave_design.clear()
	spawn_ratios.clear()
	running_chance = 0.0

	if wave_number % constants.BOSS_WAVE_MULTIPLIER == 0:
		Logging.log_entry("Boss wave qualifier.")
		design_boss_wave(wave_number)
		return

	# Wave timer.
	wave_design["wave_time"] = constants.WAVE_SURVIVAL_TIME_BASE

	if wave_number > 1:
		wave_design["wave_time"] = (
			wave_design["wave_time"] + (constants.WAVE_SURVIVAL_TIME_INCREASE * (wave_number - 1))
		)

	if wave_design["wave_time"] > constants.WAVE_SURVIVAL_TIME_MAXIMUM:
		wave_design["wave_time"] = constants.WAVE_SURVIVAL_TIME_MAXIMUM

	# Wave obstacle design.
	wave_design["obstacle_number"] = randi_range(
		constants.ARENA_OBSTACLE_MINIMUM, constants.ARENA_OBSTACLE_MAXIMUM
	)

	# Specialised wave.
	if wave_number >= constants.ENEMY_SPAWN_WAVE_SPECIAL_MIN_WAVE:
		var spawn_choice = randi_range(1, 100)

		for spawn_key in constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION:
			if spawn_choice <= spawn_key:
				wave_design["wave_special_type"] = (
					constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][0]
				)
				wave_design["wave_special_data"] = (
					constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][1]
				)
				wave_design["spawn_text"] = (
					constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][2]
				)

				Logging.log_entry("Specialist wave: " + str(wave_design.get("wave_special_type")))

				break
	else:
		wave_design["wave_special_type"] = "STANDARD"

	# Artillery
	if wave_number >= constants.ARTILLERY_MINIMUM_WAVE:
		Logging.log_entry("Artillery is possible for this wave.")
		if randi_range(1, 100) <= constants.ARTILLERY_FEATURE_PERCENTAGE:
			Logging.log_entry("Artillery WILL happen.")
			wave_design["artillery"] = true
		else:
			Logging.log_entry("Artillery WILL NOT happen.")

	# How many enemies?
	wave_design["total_enemies"] = (
		(wave_number * constants.ENEMY_MULTIPLIER_AT_WAVE_START)
		+ (wave_number * constants.ENEMY_MULTIPLIER_DURING_WAVE)
	)

	if constants.DEV_SPAWN_ENEMY_COUNT:
		Logging.log_entry("DEV_SPAWN_ENEMY_COUNT override.")
		wave_design["total_enemies"] = constants.DEV_SPAWN_ENEMY_COUNT

	Logging.log_entry("Total enemies this wave: " + str(wave_design["total_enemies"]))
	left_to_spawn = wave_design["total_enemies"] + 5000  # Padding.

	# What enemies are eligible to spawn in this wave?
	var wave_enemies = {}
	var wave_enemy_array_for_logging = []
	for enemy in constants.ENEMY_SETTINGS:
		if wave_number >= constants.ENEMY_SETTINGS[enemy].get("minimum_wave"):
			wave_enemies[enemy] = constants.ENEMY_SETTINGS[enemy]
			wave_enemy_array_for_logging.append(enemy)

	Logging.log_entry("Eligible enemies: " + str(wave_enemy_array_for_logging))

	wave_design["eligible_enemies"] = wave_enemies

	if constants.DEV_SPAWN_ONE_ENEMY_TYPE:
		Logging.log_entry("DEV_SPAWN_ONE_ENEMY_TYPE override.")
		wave_design["eligible_enemies"][constants.DEV_SPAWN_ONE_ENEMY_TYPE] = (
			constants.ENEMY_SETTINGS.get(constants.DEV_SPAWN_ONE_ENEMY_TYPE, false)
		)

	running_chance = 0.0

	for enemy in wave_design["eligible_enemies"]:
		running_chance += wave_design["eligible_enemies"][enemy].get("spawn_chance")
		spawn_ratios[running_chance] = enemy

	Logging.log_entry("Spawn ratios: " + str(spawn_ratios))

	var number_to_spawn_at_start = wave_number * constants.ENEMY_MULTIPLIER_AT_WAVE_START

	if number_to_spawn_at_start > left_to_spawn:
		number_to_spawn_at_start = left_to_spawn

	Logging.log_entry("Number of enemies to spawn at start: " + str(number_to_spawn_at_start))
	wave_design["start_spawn"] = {}
	wave_design["start_spawn"]["spawn_array"] = get_random_enemies(number_to_spawn_at_start)
	wave_design["start_spawn"]["spawn_pattern"] = get_spawn_pattern(
		constants.ENEMY_SPAWN_PLACEMENT_CONFIGURATION_WAVE_START, ""
	)

	# Now subsequent waves.
	left_to_spawn = left_to_spawn - number_to_spawn_at_start
	var spawn_number = 0

	while left_to_spawn:
		spawn_number += 1
		var spawn_key = "spawn_" + str(spawn_number)
		Logging.log_entry("Left to spawn: " + str(left_to_spawn))

		var enemies_to_spawn = (
			constants.ENEMY_REINFORCEMENTS_SPAWN_BATCH_SIZE
			+ (wave_number * constants.ENEMY_REINFORCEMENTS_SPAWN_BATCH_MULTIPLIER)
		)
		if enemies_to_spawn > left_to_spawn:
			enemies_to_spawn = left_to_spawn

		Logging.log_entry("This spawn I want to spawn: " + str(enemies_to_spawn))

		wave_design[spawn_key] = {}

		if randi_range(1, 100) <= constants.ENEMY_REINFORCEMENTS_SPAWN_MULTI_PLACEMENT_PERCENTAGE:
			wave_design[spawn_key]["spawn_array"] = get_random_enemies(enemies_to_spawn)
			wave_design[spawn_key]["spawn_pattern"] = get_spawn_pattern(
				constants.ENEMY_SPAWN_PLACEMENT_CONFIGURATION, ""
			)
			wave_design[spawn_key]["spawn_pattern_b"] = get_spawn_pattern(
				constants.ENEMY_SPAWN_PLACEMENT_CONFIGURATION,
				wave_design[spawn_key]["spawn_pattern"]
			)
		else:
			wave_design[spawn_key]["spawn_array"] = get_random_enemies(enemies_to_spawn)
			wave_design[spawn_key]["spawn_pattern"] = get_spawn_pattern(
				constants.ENEMY_SPAWN_PLACEMENT_CONFIGURATION, ""
			)

		left_to_spawn = left_to_spawn - enemies_to_spawn

		Logging.log_entry(
			"Spawn " + str(spawn_key) + " -- Contents: " + str(wave_design[spawn_key]["spawn_array"])
		)

	wave_design["total_spawns"] = spawn_number

	# Reinforcements timer.
	wave_design["reinforcements_timer"] = constants.ENEMY_REINFORCEMENTS_SPAWN_BASE_SECONDS
	Logging.log_entry(
		"Reinforcements Cadence: " + str(constants.ENEMY_REINFORCEMENTS_SPAWN_BASE_SECONDS)
	)

	Logging.log_entry("Final construction: " + str(wave_design))


func get_random_enemies(number_enemies):
	var spawn_array = []

	if TheDirector.wave_design.get("wave_special_type") == "ALL_THE_SAME":
		for i in range(0, number_enemies):
			spawn_array.append(TheDirector.wave_design.get("wave_special_data"))

		return spawn_array

	for i in range(0, number_enemies):
		# Pick enemies.
		var chosen_enemy
		var spawn_choice = randf_range(0.0, running_chance)
		#Logging.log_entry("Random number: " + str(spawn_choice))

		for individual_ratio in spawn_ratios:
			if spawn_choice <= individual_ratio:
				chosen_enemy = spawn_ratios[individual_ratio]
				break

		#Logging.log_entry("Chosen enemy: " + str(chosen_enemy))
		spawn_array.append(chosen_enemy)

	return spawn_array


func get_spawn_pattern(enemy_spawn_placement_configuration, previous_spawn_pattern):
	var acceptable_choice = false
	var spawn_pattern

	# If we have been passed the previous_spawn_pattern, do not allow the same pattern to be used
	# again.
	while !acceptable_choice:
		var spawn_choice = randi_range(1, 100)

		for spawn_key in enemy_spawn_placement_configuration:
			if spawn_choice <= spawn_key:
				spawn_pattern = enemy_spawn_placement_configuration[spawn_key]
				break

		if spawn_pattern != previous_spawn_pattern:
			acceptable_choice = true

	return spawn_pattern


func design_boss_wave(_wave_number):
	wave_design["boss_wave"] = true
	wave_design["boss_health"] = 1000
	wave_design["spawn_text"] = "ALERT! BOSS DETECTED!"
