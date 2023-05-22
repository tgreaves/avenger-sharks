# Gameplay

* Difficulty levels (fish themed, e.g Minnow upwards)+
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

# User Experience

* How to play

# Bugs

# THINGS FOR 0.5-alpha


* BOSS WAVE
    * Randomly determine boss characteristics.
    * Energy bar (which zoooooms up to max when it first appears on HUD)
    * Klaxon, flashing.

* THE DIRECTOR
    * Controls how the game works.
    * What makes up a wave?
        * What types of enemy are eligible to spawn
            * Define a 'minimum' wave for mob types (where appropriate)
        * Balance of enemies / maximum number allowed on screen at a time
            * Define propensity - e.g. 1.0 = standard weighting, 0.5 = half weighting
        * How many spawn at a time
        * How are enemies batched?
        * Speed between spawns
        * Speed multiplier for enemies(?)
 
* 2ND PLAYER CHARACTER
    * Bob the Fish?
        * Faster move speed.
        * Unlocks with x total collected fish (currency)       

* STATISTICS
    * Ability for user to reset

* ENEMY TYPES
    * An enemy that charges the player
    * An enemy that lays an egg or drops acid or something else bad.
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
        
* POWER UPS
    * Add flame thrower!
    * Cursed power-ups :D

* WAVE PROGRESSION
    * Choice of which level
    * Palette swaps (different areas) - could use shaders here.
    * Dialogues ?!!! (Try not to boil the ocean)
    
* GRAPHICS
    * Shaders for water effects
    * More vibrant shader for enemy death
    
* PERSISTENT STORAGE
    * Implement encryption
    
* STEAM
    * Achievements
        * Beat a wave
        * Beat 5 waves
        * Beat 10 waves
    * Leaderboard support (High scores)
    
* GENERAL DEVELOPMENT
    * CI/CD pipeline
    
* JACK'S IDEAS
    * Hammerhead shark
        * Hits one time to lose one life
        * If it loses two more, then it is done but can take three lives one hit.
        

