# Gameplay

* Difficulty levels (fish themed, e.g Minnow upwards)
* Boss wave
* Pacifist mode
* Chill mode
* Dinosaur mode - Only triggering dinosaurs will kill enemies, but have more of them?

# Power-ups / Progression

* More power-up suggestions
  * Bouncing shots?
  * Exploding shots
  * Piercing shots

* Keep count of fish rescued - use as currency in pre-game shop...
  * Start with more health.
  * Other characters?

# Game environment

* Scenery / Obstacles in room (Tileset has boxes)
* Opens up possibilities of some rooms being special, e.g. just full of fish?
* Every x waves is a special room?

# User Experience

* How to play
* Basic options (e.g. full screen and windowed selection)

# Bugs

* Big spray doesn't work when player close to a wall.

# THINGS FOR 0.3-alpha

* BALANCE AND FIXES
    * Upgrades currently not balanced...
        * Armour + Health basically makes it hard to die!
    * Spawning...
        * Introduce certain enemies at different waves.
        
* UPGRADE SYSTEM
    * Perma power-up: Sets power-up to start a level at Level 1 or more (So have one per power-up)
    * Upgrade that only works for x stages (e.g. confuse enemies)

* SURVIVAL MODE
    * [DONE] Implement game mode selection from main menu.
    * Disable mouse cursor during game (remember to enable again after game finishes) - also pause?
    * [DONE] Player cannot shoot
    * [DONE] Wave ends if all fish collected
    * [DONE] Spawn key at last fish location so game loop does not break
    * [DONE] Necros do not try and eat the fish
    * [DONE] Disable necro / fish collisions in this mode
    * [DONE] HUD: Needs to display FISH instead if ENEMIES
    * [DONE] Number of fish could change with wave progression
    * Disable power-ups in this mode as they don't apply (HUD?)
    * [DONE] Disable fish frenzy bar / ability to enable and use
    * [DONE] Health random spawning on level
    
* ENEMY TYPES
    * Static turret - probably new Scene to support
        * Rotate during physics.
        * After random timer, charge animation + second timer
        * Fire solid laser - persist for third timer
        * Damages player
        * Return to turrent
        * Statuses
            * ROTATING
            * CHARGING
            * FIRING
    * Turret could fire a homing missile instead.

* SPAWN PATTERNS
    * Movement patterns as well (sine wave for example enemies in a group)
    * Option on Circle spawn for all to be the same.
        * Will need to re-work Enemy logic to not all be done in _ready() as is making things awkward.
        * Base on Item and spawn_specific() and spawn_random
    
* PERSISTENT STORAGE
    * Encryption
    
* STEAM
    * Initial store presence.
    * Cloud saving (but of what?)
        * Statistics!
            * Games played
            * Shots fired
            * Chests collected
            * Max wave reached
            * ... etc...
            * Enemies killed
    * Achievements
        * Beat a wave
        * Beat 5 waves
        * Beat 10 waves
    * Leaderboard support (High scores)
    
* JACK'S IDEAS
    * Hammerhead shark
        * Hits one time to lose one life
        * If it loses two more, then it is done but can take three lives one hit.
        


This commit:
    
* Tidy up spawning code.
* Display custom message for special waves.
* Score multiplier system
* TODO: Display score pop-up above enemy when dead
