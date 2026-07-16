extends Node

const GAME_VERSION = "1.4.0-alpha"

# Developer settings.
const DEV_DELAY_ON_START = false
const DEV_LOGGING = false
const DEV_LOG_WAVE_DESIGN = false
const DEV_ALLOW_CHEATS = false
const DEV_SKIP_INTRO = true
const DEV_START_GAME_IMMEDIATELY = false
const DEV_STEAM_TESTING = false
const DEV_SPAWN_ENEMY_COUNT = 0
const DEV_SPAWN_ONE_ENEMY_TYPE = ""
const DEV_FISH_FRENZY_AVAILABLE_IMMEDIATELY = false
const DEV_CHEAT_DEATH_AVAILABLE_IMMEDIATELY = false 
const DEV_FORCE_UPGRADE = ""   	# ""
const DEV_FORCE_POWERUP = ""	# ""
const DEV_WAVE_LASTS_FOREVER = false
const DEV_WIPE_ACHIEVEMENTS = false
const DEV_FORCE_BOSS_WAVE = false   # Force every wave to be a boss wave for testing.

# Hardware settings
const WINDOW_TITLE = "Avenger Sharks " + GAME_VERSION
const WINDOW_SIZE = Vector2(1920, 1080)
const CAMERA_ZOOM_EFFECTS = false

# Shared co-op camera (also used in 1-player, where it simply follows the one
# shark at the default zoom). Tune by feel after playtest.
const CAMERA_DEFAULT_ZOOM = 1.0             # Zoom when players are together / single player.
const CAMERA_MIN_ZOOM = 0.5                 # Most zoomed-out allowed (readability cap).
const CAMERA_PLAYER_MARGIN = 700.0          # World-units of padding around players' bounding box.
const CAMERA_POSITION_LERP = 5.0            # Higher = snappier follow.
const CAMERA_ZOOM_LERP = 4.0                # Higher = snappier zoom.

# Player identity tints (applied via the shark sprites' self_modulate, so they
# compose with the transient modulate effects for power-pellet / damage).
# Player 1 is untinted (natural colour); player 2 gets a distinct cast.
const PLAYER_1_TINT = Color(1, 1, 1, 1)
# Orange cast. Red pushed above 1.0 and green kept high for the orange hue, with
# blue crushed. Amplifying (rather than capping red at 1.0 and darkening the
# others, which goes muddy brown) keeps it a clean, bright orange.
const PLAYER_2_TINT = Color(1.7, 0.85, 0.2, 1)

# Game settings
const PLAY_WAVE_END_MUSIC = false

const START_WAVE = 1
const WAVE_SURVIVAL_TIME_BASE = 5 # 30
const WAVE_SURVIVAL_TIME_INCREASE = 5
const WAVE_SURVIVAL_TIME_MAXIMUM = 60

const ARENA_SPAWN_MIN_X = 170
const ARENA_SPAWN_MAX_X = 2500 * 2
const ARENA_SPAWN_MIN_Y = 320
const ARENA_SPAWN_MAX_Y = 1250 * 2

const ARENA_OBSTACLE_MINIMUM = 5
const ARENA_OBSTACLE_MAXIMUM = 10
const ARENA_OBSTACLE_SIZE_MINIMUM = 3
const ARENA_OBSTACLE_SIZE_MAXIMUM = 5

const PLAYER_START_GAME_ENERGY = 100
const PLAYER_START_GAME_ENERGY_CHEATING = 99999
const PLAYER_LOW_ENERGY_BLINK = 30

const PLAYER_SPEED = 800
const PLAYER_SPEED_POWERUP_INCREASE = 25
const PLAYER_SPEED_ESCAPING = 1200
# How close the following shark gets to the key-holder before it stops (co-op
# wave-end), so it doesn't jitter on top of the holder at the door.
const FOLLOW_STOP_DISTANCE = 250.0

const PLAYER_FIRE_DELAY = 0.15
const PLAYER_FIRE_DELAY_POWERUP_DECREASE = 0.01
# Minimum gap between (re)triggers of the shared spray voice. Two sharks firing
# independently would otherwise restart the one voice up to twice as often,
# chopping the clip into a stuttery "machine gun". ~0.1s keeps it close to a
# single player's cadence while still allowing FAST SPRAY to feel rapid.
const SPRAY_SOUND_MIN_INTERVAL = 0.1
const PLAYER_FIRE_SPEED = 1600
const PLAYER_FIRE_SIZE_BASE = 0.5
const PLAYER_FIRE_SIZE_POWERUP_INCREASE = 0.25

const PLAYER_GRENADE_DELAY = 0.6
const PLAYER_GRENADE_DELAY_POWERUP_DECREASE = 0.1

# Between-wave upgrade screen.
const UPGRADE_CPU_MOVE_INTERVAL = 0.28   # Gap between CPU "deliberation" cursor moves.
const UPGRADE_CONFIRM_FLASH_TIME = 0.5   # Hold on the confirm flash before advancing.

# Powerups whose effect is a scalar stat recomputed from level:
#   stat = base + (direction * step * level)
# Powerups with non-scalar effects (SCATTER SPRAY, MINI SHARK) are handled
# explicitly in Player.gd and deliberately omitted here.
const POWERUP_STAT_FORMULAS = {
	"SPEED UP":
	{
		"property": "speed",
		"base": PLAYER_SPEED,
		"step": PLAYER_SPEED_POWERUP_INCREASE,
		"direction": 1
	},
	"FAST SPRAY":
	{
		"property": "fire_delay",
		"base": PLAYER_FIRE_DELAY,
		"step": PLAYER_FIRE_DELAY_POWERUP_DECREASE,
		"direction": -1
	},
	"BIG SPRAY":
	{
		"property": "spray_size",
		"base": PLAYER_FIRE_SIZE_BASE,
		"step": PLAYER_FIRE_SIZE_POWERUP_INCREASE,
		"direction": 1
	},
	"GRENADE":
	{
		"property": "grenade_delay",
		"base": PLAYER_GRENADE_DELAY,
		"step": PLAYER_GRENADE_DELAY_POWERUP_DECREASE,
		"direction": -1
	}
}

const PLAYER_HIT_BY_ENEMY_DAMAGE = 10

const PLAYER_FISH_FRENZY_DURATION = 1.5
const PLAYER_FISH_FRENZY_FIRE_DELAY = 0.1

const DINOSAUR_SPEED = 800
const DINOSAUR_ATTACK_DELAY = 0.5
const DINOSAUR_ATTACK_SPEED = 800
const DINOSAUR_SURVIVAL_TIME = 5

const ARTILLERY_MINIMUM_WAVE = 3
const ARTILLERY_FEATURE_PERCENTAGE = 50
const ARTILLERY_MINIMUM_TIME = 5
const ARTILLERY_MAXIMUM_TIME = 10
const ARTILLERY_WARNING_TIME = 4
const ARTILLERY_CHASE_SPEED = 5

# Enemy spawning
const ENEMY_SPAWN_WAVE_SPECIAL_MIN_WAVE = 3

const ENEMY_SPAWN_WAVE_SPECIAL_CONFIGURATION = {
	90: ["STANDARD", "", ""],
	93: ["ALL_THE_SAME", "bee", "Feel the buzz!"],
	96: ["ALL_THE_SAME", "skeleton", "Rattling bones approach!"],
	100: ["ALL_THE_SAME", "snake", "Boing! Boing! Boing!"]
	#100:     ['ALL_THE_SAME', 'necromancer', 'The fish become fearful!']
}

const ENEMY_SPAWN_PLACEMENT_CONFIGURATION_WAVE_START = {50: "RANDOM", 100: "CIRCLE_SURROUND_PLAYER"}

const ENEMY_SPAWN_PLACEMENT_CONFIGURATION = {
	50: "RANDOM",
	80: "CIRCLE_SURROUND_PLAYER",
	85: "HARD_TOP",
	90: "HARD_BOTTOM",
	95: "HARD_LEFT",
	100: "HARD_RIGHT"
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
	"knight":
	{
		"minimum_wave": 1,
		"spawn_chance": 1.0,
		"speed": 450,
		"health": 3,
		"AI": "CHASE",
		"score": 10,
		"can_be_knocked_back": true,
		"death_sprite_offset": Vector2(5, 0)
	},
	"wizard":
	{
		"minimum_wave": 1,
		"spawn_chance": 1.0,
		"speed": 450,
		"health": 1,
		"AI": "WANDER",
		"score": 10,
		"attack_timer_min": 3,
		"attack_timer_max": 5,
		"attack_type": "STANDARD",
		"death_sprite_offset": Vector2(10, 0)
	},
	"rogue":
	{
		"minimum_wave": 2,
		"spawn_chance": 0.5,
		"speed": 450,
		"health": 1,
		"AI": "WANDER",
		"score": 10,
		"trap_timer_min": 4,
		"trap_timer_max": 10,
	},
	"necromancer":
	{
		"minimum_wave": 8,
		"spawn_chance": 0.1,
		"speed": 100,
		"health": 10,
		"AI": "FISH",
		"score": 30,
		"attack_timer_min": 5,
		"attack_timer_max": 10,
		"attack_type": "SPIRAL",
		"can_be_knocked_back": true,
		"sprite_offset": Vector2(0, -25),
		"collision_scale": Vector2(1.5, 1.5),
		"collision_mask_enable": 7
	},
	"bee":
	{
		"minimum_wave": 4,
		"spawn_chance": 0.35,
		"speed": 600,
		"health": 1,
		"AI": "CHASE",
		"score": 10,
	},
	"skeleton":
	{
		"minimum_wave": 3,
		"spawn_chance": 0.25,
		"speed": 450,
		"health": 1,
		"AI": "WANDER",
		"score": 10,
		"spawns_others": true,
		"split_size": Vector2(0.75, 0.75),
		"death_sprite_offset": Vector2(0, -5)
	},
	"snake":
	{
		"minimum_wave": 5,
		"spawn_chance": 0.15,
		"speed": 450,
		"health": 2,
		"AI": "GROUP",
		"score": 10,
		"grouped_enemy": true,
		"chase_at_low_population": false,
		"sprite_scale": Vector2(6, 6)
	}
}

const ENEMY_SPEED_WAVE_PERCENTAGE_MULTIPLIER = 10
const ENEMY_SPEED_DEFERRED_AI_MULTIPLIER = 1.5
const ENEMY_SPEED_POPULATION_LOW_MULTIPLIER = 1.5

const ENEMY_ALLOW_DAMAGE_WHEN_SPAWNING = false

const ENEMY_ATTACK_ARC_DEGREES = 20

const ENEMY_CHASE_REORIENT_MINIMUM_SECONDS = 0.1
const ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS = 0.1

const ENEMY_DEFAULT_CHANGE_DIRECTION_MINIMUM_SECONDS = 1
const ENEMY_DEFAULT_CHANGE_DIRECTION_MAXIMUM_SECONDS = 3

const ENEMY_ALL_CHASE_WHEN_POPULATION_LOW = 10

const ENEMY_TRAP_HEALTH = 4

const ENEMY_CALL_FOR_HELP_MINIMUM_TIME = 2.0
const ENEMY_CALL_FOR_HELP_MAXIMUM_TIME = 3.0
const ENEMY_CALL_FOR_HELP_PERCENTAGE = 20
const ENEMY_CALL_FOR_HELP_PHRASES = ["HELP!", "DON'T EAT ME!", "NOOOOO!"]

const ENEMY_KNOCKBACK_TIMER = 0.3
const ENEMY_KNOCKBACK_VELOCITY_CLAMP = Vector2(200, 200)

# Boss waves
const BOSS_WAVE_MULTIPLIER = 1000000
# Base boss health (number of shots to defeat). Tuned in Phase 5.
const BOSS_BASE_HEALTH = 60
# Boss is tougher in 2-player since two sharks out-damage one.
const BOSS_HEALTH_2P_MULTIPLIER = 1.75
# Where the boss spawns — upper-middle arena, clear of the bottom entrance the
# sharks swim in through.
const BOSS_SPAWN_POSITION = Vector2(2650, 900)
# Boss visual + collision scale (mirrors ENEMY_SETTINGS sprite_scale /
# collision_scale). Applied in Boss.configure() so it stays data-driven.
# The shared capsule (radius 59 / height 132) is tuned to fit the creature at a
# sprite scale of 4 (that's how the enemies use it: sprite 4x, collision 1x). At
# the boss's sprite scale of 7 the creature is drawn 7/4 = 1.75x larger, so the
# collision scale matches at 1.75x to stay proportional.
const BOSS_SPRITE_SCALE = Vector2(7, 7)
const BOSS_COLLISION_SCALE = Vector2(1.75, 1.75)
# The necromancer creature sits low in its frame, so (like the necromancer enemy,
# which uses sprite_offset (0,-25)) the sprite is lifted to sit over the centred
# capsule. Applied in Boss.configure() and scaled with the sprite.
const BOSS_SPRITE_OFFSET = Vector2(0, -25)
# Score awarded for defeating a boss (tuned in Phase 5).
const BOSS_DEFEAT_SCORE_BONUS = 1000
# Boss attacks (Phase 3). The boss roams and threatens via projectiles: a
# rotating spiral on a cadence, with aimed volleys at the nearest shark between
# spirals. Reuses the standard EnemyAttack projectile (standard damage).
const BOSS_SPIRAL_INTERVAL = 3.0         # Seconds between spiral bursts.
const BOSS_SPIRAL_PROJECTILE_COUNT = 20  # Shots per spiral ring.
const BOSS_AIMED_INTERVAL = 1.2          # Seconds between aimed volleys.
const BOSS_AIMED_PROJECTILE_COUNT = 3    # Shots per aimed volley (small spread).
const BOSS_AIMED_SPREAD_DEGREES = 12.0   # Spread of an aimed volley.
const BOSS_ATTACK_PROJECTILE_SPEED = 700 # Boss projectile speed.

# Movement speeds per behaviour profile.
const BOSS_ROAM_SPEED = 120.0            # Aimless drift (ROAM_SPIRAL).
const BOSS_CHASE_SPEED = 260.0           # Pursuit of nearest shark (CHASE_AIMED).
# The "stationary" bullet-hell profile still hovers slowly: the enemy sprites
# only have a run animation (no idle), so a truly motionless boss looks like it
# is running on the spot / into a wall. A slow drift keeps it looking alive.
const BOSS_HOVER_SPEED = 45.0

# Stationary bullet-hell fires a denser, faster spiral (it doesn't move).
const BOSS_BULLETHELL_SPIRAL_INTERVAL = 1.6
const BOSS_BULLETHELL_PROJECTILE_COUNT = 28

# Artillery-rain profile: seconds between POLLUTION-STRIKE drops.
const BOSS_ARTILLERY_INTERVAL_MIN = 1.2
const BOSS_ARTILLERY_INTERVAL_MAX = 2.2

# Boss behaviour profiles (Phase 3.5). The Director picks one, themed to the
# chosen sprite (see BOSS_TYPE_BEHAVIOUR).
const BOSS_BEHAVIOUR_ROAM_SPIRAL = "ROAM_SPIRAL"
const BOSS_BEHAVIOUR_CHASE_AIMED = "CHASE_AIMED"
const BOSS_BEHAVIOUR_BULLETHELL = "STATIONARY_BULLETHELL"
const BOSS_BEHAVIOUR_ARTILLERY = "ARTILLERY_RAIN"

# The boss can be any enemy sprite (Phase 3.5). Each type has a native frame
# size, so per-type base scale keeps them all reading as a big boss (the small
# 32px-tall knight/wizard/rogue/skeleton need more; the necromancer least). The
# behaviour is themed to the type.
const BOSS_TYPE_SETTINGS = {
	"knight": {"scale": Vector2(12, 12), "behaviour": BOSS_BEHAVIOUR_CHASE_AIMED},
	"wizard": {"scale": Vector2(12, 12), "behaviour": BOSS_BEHAVIOUR_ROAM_SPIRAL},
	"rogue": {"scale": Vector2(12, 12), "behaviour": BOSS_BEHAVIOUR_CHASE_AIMED},
	"necromancer": {"scale": Vector2(7, 7), "behaviour": BOSS_BEHAVIOUR_ARTILLERY},
	# The bee boss is a giant queen: bigger, and its adds are themed as a bee swarm.
	"bee": {"scale": Vector2(16, 16), "behaviour": BOSS_BEHAVIOUR_CHASE_AIMED, "adds_type": "bee"},
	"skeleton": {"scale": Vector2(12, 12), "behaviour": BOSS_BEHAVIOUR_BULLETHELL},
	"snake": {"scale": Vector2(14, 14), "behaviour": BOSS_BEHAVIOUR_BULLETHELL}
}

# Procedural adds (Phase 4). The Director rolls an intensity per boss wave,
# weighted toward none/light. When enabled, adds trickle in capped batches on a
# timer alongside the boss and do NOT gate wave completion (only boss HP does).
const BOSS_ADDS_INTENSITY_WEIGHTS = {"none": 55, "light": 30, "heavy": 15}
const BOSS_ADDS_SETTINGS = {
	"light": {"cap": 4, "batch": 2, "interval": 6.0},
	"heavy": {"cap": 8, "batch": 3, "interval": 4.0}
}

# Fish
const FISH_TO_SPAWN_ARCADE = 20
const FISH_TO_SPAWN_PACIFIST_BASE = 5
const FISH_TO_SPAWN_PACIFIST_WAVE_MULTIPLIER = 2
const GET_FISH_SCORE = 50
const FISH_TO_TRIGGER_FISH_FRENZY = 15

# Items
const ARCADE_SPAWNING_ITEMS = ["dinosaur", "dinosaur", "dinosaur", "power-pellet"]
const PACIFIST_SPAWNING_ITEMS = ["health"]

const ITEM_SPAWN_MINIMUM_SECONDS = 10    
const ITEM_SPAWN_MAXIMUM_SECONDS = 15
const ENEMY_LEAVE_BEHIND_ITEM_PERCENTAGE = 15   # 15
const ITEM_DESPAWN_TIME = 10
const ARCADE_MAXIMUM_DROPPED_ITEMS_ON_SCREEN = 5

const HEALTH_POTION_BONUS = 20
const GRENADE_SPEED = 400

# Power up levels
const POWERUP_SPEEDUP_MAX_LEVEL = 3
const POWERUP_FASTSPRAY_MAX_LEVEL = 3
const POWERUP_BIGSPRAY_MAX_LEVEL = 3
const POWERUP_SCATTERSPRAY_MAX_LEVEL = 3
const POWERUP_GRENADE_MAX_LEVEL = 3
const POWERUP_MINISHARK_MAX_LEVEL = 3

const POWERUP_ACTIVE_DURATION = 10
const POWER_PELLET_ACTIVE_DURATION = 10

# Upgrades
const ARMOUR_DAMAGE_REDUCTION_PERCENTAGE = 10
const SWIM_SURGE_BASE_RECHARGE_TIME = 4.0
