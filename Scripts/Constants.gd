extends Node

const GAME_VERSION = "1.1.0-beta2"

# Developer settings.
const DEV_DELAY_ON_START = false
const DEV_LOGGING = true
const DEV_ALLOW_CHEATS = false
const DEV_SKIP_INTRO = false
const DEV_START_GAME_IMMEDIATELY = false
const DEV_STEAM_TESTING = false
const DEV_SPAWN_ENEMY_COUNT = 0
const DEV_SPAWN_ONE_ENEMY_TYPE = ''
const DEV_FORCE_UPGRADE = ''
const DEV_WAVE_LASTS_FOREVER = false

# Hardware settings
const WINDOW_TITLE = "Avenger Sharks " + GAME_VERSION
const WINDOW_SIZE = Vector2(1920,1080)

# Game settings
const START_WAVE = 1

const ARENA_SPAWN_MIN_X = 170
const ARENA_SPAWN_MAX_X = 2500 * 2
const ARENA_SPAWN_MIN_Y = 320
const ARENA_SPAWN_MAX_Y = 1250 * 2

const ARENA_OBSTACLE_MINIMUM = 3
const ARENA_OBSTACLE_MAXIMUM = 7
const ARENA_OBSTACLE_SIZE_MINIMUM = 3
const ARENA_OBSTACLE_SIZE_MAXIMUM = 5

const PLAYER_START_GAME_ENERGY = 100
const PLAYER_START_GAME_ENERGY_CHEATING = 99999
const PLAYER_LOW_ENERGY_BLINK = 30

const PLAYER_SPEED = 800
const PLAYER_SPEED_POWERUP_INCREASE = 25
const PLAYER_SPEED_ESCAPING = 1200;

const PLAYER_FIRE_DELAY = 0.15
const PLAYER_FIRE_DELAY_POWERUP_DECREASE = 0.01
const PLAYER_FIRE_SPEED = 1600;
const PLAYER_FIRE_SIZE_POWERUP_INCREASE = 0.25

const PLAYER_GRENADE_DELAY = 0.6
const PLAYER_GRENADE_DELAY_POWERUP_DECREASE = 0.1

const PLAYER_HIT_BY_ENEMY_DAMAGE = 10;

const PLAYER_FISH_FRENZY_DURATION = 1.5
const PLAYER_FISH_FRENZY_FIRE_DELAY = 0.1

const DINOSAUR_SPEED = 800
const DINOSAUR_ATTACK_DELAY = 0.5
const DINOSAUR_ATTACK_SPEED = 800
const DINOSAUR_SURVIVAL_TIME = 5

const ARTILLERY_MINIMUM_WAVE = 1
const ARTILLERY_MINIMUM_TIME = 5
const ARTILLERY_MAXIMUM_TIME = 10
const ARTILLERY_WARNING_TIME = 5
const ARTILLERY_CHASE_SPEED = 3

# Enemy spawning
const ENEMY_SPAWN_WAVE_SPECIAL_MIN_WAVE = 2

const ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION = {
    90:      ['STANDARD', '', ''],
    93:      ['ALL_THE_SAME', 'bee', 'Feel the buzz!'],
    96:      ['ALL_THE_SAME', 'skeleton', 'Rattling bones approach!'],
    100:     ['ALL_THE_SAME', 'snake', 'Boing! Boing! Boing!']
    #100:     ['ALL_THE_SAME', 'necromancer', 'The fish become fearful!'] 
}

const ENEMY_SPAWN_PLACEMENT_CONFIGURATION_WAVE_START = {
    50:     'RANDOM',
    100:    'CIRCLE_SURROUND_PLAYER'
}

const ENEMY_SPAWN_PLACEMENT_CONFIGURATION = {
    50:     'RANDOM',
    80:     'CIRCLE_SURROUND_PLAYER',
    85:     'HARD_TOP', 
    90:     'HARD_BOTTOM',
    95:     'HARD_LEFT',
    100:    'HARD_RIGHT'
}

const ENEMY_MULTIPLIER_AT_WAVE_START = 10
const ENEMY_MULTIPLIER_DURING_WAVE = 15

const ENEMY_REINFORCEMENTS_SPAWN_BASE_SECONDS = 5
const ENEMY_REINFORCEMENTS_SPAWN_BATCH_SIZE = 10
const ENEMY_REINFORCEMENTS_SPAWN_BATCH_MULTIPLIER = 1
const ENEMY_REINFORCEMENTS_SPAWN_MINIMUM_NUMBER = 5
const ENEMY_REINFORCEMENTS_SPAWN_MULTI_PLACEMENT_PERCENTAGE = 50

# Enemy (General)
const ENEMY_SETTINGS = {
    'knight':   {
        'minimum_wave': 1,
        'spawn_chance': 1.0,
        'speed':    450,
        'health':   4,
        'AI':       'CHASE',
        'score':    10,
        'death_sprite_offset':  Vector2(5,0)
    },
    'wizard':   {
        'minimum_wave': 1,
        'spawn_chance': 1.0,
        'speed':    450,
        'health':   1,
        'AI':       'WANDER',
        'score':    10,
        'attack_timer_min': 3,
        'attack_timer_max': 5,
        'attack_type':  'STANDARD',
        'death_sprite_offset':  Vector2(10,0)
    },
    'rogue':   {
        'minimum_wave':  2,
        'spawn_chance': 0.5,
        'speed':    450,
        'health':   1,
        'AI':       'WANDER',
        'score':    10,
        'trap_timer_min': 4,
        'trap_timer_max': 10,
    },
    'necromancer':  {
        'minimum_wave': 8,
        'spawn_chance': 0.1,
        'speed':    100,
        'health':   10,
        'AI':       'FISH',
        'score':    30,
        'attack_timer_min': 5,
        'attack_timer_max': 10,
        'attack_type':  'SPIRAL',
        'sprite_offset':    Vector2(0,-25),
        'collision_scale':  Vector2(1.5,1.5),
        'collision_mask_enable':    7
    },
    'bee':   {
        'minimum_wave': 4,
        'spawn_chance': 0.35,
        'speed':    600,
        'health':   1,
        'AI':       'CHASE',
        'score':    10,
    },
    'skeleton': {
        'minimum_wave': 3,
        'spawn_chance': 0.25,
        'speed':    450,
        'health':   1,
        'AI':       'WANDER',
        'score':    10,
        'spawns_others':    true,
        'split_size':  Vector2(0.75,0.75),
        'death_sprite_offset':  Vector2(0,-5)
    },
    'snake': {
        'minimum_wave': 5,
        'spawn_chance': 0.15,
        'speed':    450,
        'health':   2,
        'AI':       'GROUP',
        'score':    10,
        'grouped_enemy':  true,
        'chase_at_low_population':  false,
        'sprite_scale': Vector2(6,6)
    }
}

const ENEMY_SPEED_WAVE_PERCENTAGE_MULTIPLIER = 10
const ENEMY_SPEED_DEFERRED_AI_MULTIPLIER = 1.5
const ENEMY_SPEED_POPULATION_LOW_MULTIPLIER = 1.5

const ENEMY_ALLOW_DAMAGE_WHEN_SPAWNING = false

const ENEMY_ATTACK_ARC_DEGREES = 20;

const ENEMY_CHASE_REORIENT_MINIMUM_SECONDS = 0.5;
const ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS = 1.0;
const ENEMY_DEFAULT_CHANGE_DIRECTION_MINIMUM_SECONDS = 1;
const ENEMY_DEFAULT_CHANGE_DIRECTION_MAXIMUM_SECONDS = 3;

const ENEMY_ALL_CHASE_WHEN_POPULATION_LOW = 10

const ENEMY_TRAP_HEALTH = 10

const ENEMY_CALL_FOR_HELP_MINIMUM_TIME = 2.0
const ENEMY_CALL_FOR_HELP_MAXIMUM_TIME = 3.0
const ENEMY_CALL_FOR_HELP_PERCENTAGE = 20
const ENEMY_CALL_FOR_HELP_PHRASES = [ "HELP!", "DON'T EAT ME!", "NOOOOO!"]

# Boss waves
const BOSS_WAVE_MULTIPLIER = 1000000

# Fish
const FISH_TO_SPAWN_ARCADE = 20;
const FISH_TO_SPAWN_PACIFIST_BASE = 5
const FISH_TO_SPAWN_PACIFIST_WAVE_MULTIPLIER = 2
const GET_FISH_SCORE = 50;
const FISH_TO_TRIGGER_FISH_FRENZY = 15

# Items
const ARCADE_SPAWNING_ITEMS = ['dinosaur','dinosaur','power-pellet','power-pellet']
#const ARCADE_SPAWNING_ITEMS = ['power-pellet']
const PACIFIST_SPAWNING_ITEMS = ['health']

const ITEM_SPAWN_MINIMUM_SECONDS = 10
const ITEM_SPAWN_MAXIMUM_SECONDS = 15
const ENEMY_LEAVE_BEHIND_ITEM_PERCENTAGE = 15
const ITEM_DESPAWN_TIME = 10
const ARCADE_MAXIMUM_DROPPED_ITEMS_ON_SCREEN = 5

const HEALTH_POTION_BONUS = 20
const GRENADE_SPEED = 400

# Power up levels
const POWERUP_SPEEDUP_MAX_LEVEL = 3
const POWERUP_FASTSPRAY_MAX_LEVEL = 3
const POWERUP_BIGSPRAY_MAX_LEVEL = 3
const POWERUP_GRENADE_MAX_LEVEL = 3
const POWERUP_MINISHARK_MAX_LEVEL = 3

const POWERUP_ACTIVE_DURATION = 10
const POWER_PELLET_ACTIVE_DURATION = 10

# Upgrades
const ARMOUR_DAMAGE_REDUCTION_PERCENTAGE = 10
