extends Node

@export var WaveDesign = {}

func design_wave(wave_number):
    Logging.log_entry("Designing for Wave " + str(wave_number))
    
    WaveDesign.clear()
    
    # Wave obstacle design.
    WaveDesign['obstacle_number'] = randi_range(constants.ARENA_OBSTACLE_MINIMUM, constants.ARENA_OBSTACLE_MAXIMUM)
    
    # Specialised wave.
    if wave_number >= constants.ENEMY_SPAWN_WAVE_SPECIAL_MIN_WAVE:
        var spawn_choice = randi_range(1,100)
    
        for spawn_key in constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION:
            if spawn_choice <= spawn_key:
                WaveDesign['wave_special_type'] = constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][0]
                WaveDesign['wave_special_data'] = constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][1]
                WaveDesign['spawn_text'] = constants.ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION[spawn_key][2]
                
                Logging.log_entry("Specialist wave: " + str(WaveDesign.get('wave_special_type')))
                
                break
    else:
        WaveDesign['wave_special_type'] = 'STANDARD'
    
    # What enemies are eligible to spawn in this wave?
    var wave_enemies = {}
    var wave_enemy_array_for_logging = []
    for enemy in constants.ENEMY_SETTINGS:
        if wave_number >= constants.ENEMY_SETTINGS[enemy].get('minimum_wave'):
            wave_enemies[enemy] = constants.ENEMY_SETTINGS[enemy]
            wave_enemy_array_for_logging.append(enemy)
        
    Logging.log_entry("Eligible enemies: " + str(wave_enemy_array_for_logging))
    
    WaveDesign['eligible_enemies'] = wave_enemies
    
    # TODO: NEXT - What are the ratios?
    # Build up each set of spawns in a wave.
    # Build incremental list of enemies with spawn chandces
    # Generate random number, use this to pick the enemy to spawn.
    # THEN LATER ON:
    # Add some more complexity (e.g. 'Only allow this many on screen at once') ?
    
    # Reinforcements timer.
    WaveDesign['reinforcements_timer'] = constants.ENEMY_REINFORCEMENTS_SPAWN_BASE_SECONDS
    Logging.log_entry("Reinforcements Cadence: " + str(constants.ENEMY_REINFORCEMENTS_SPAWN_BASE_SECONDS))
    
    Logging.log_entry("Final construction: " + str(WaveDesign))
    
