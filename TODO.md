# Gameplay

* Difficulty levels (fish themed, e.g Minnow upwards)+
* Chill mode

# Power-ups / Progression

* More power-up suggestions
  * Bouncing shots?
  * Exploding shots
  * Piercing shots
  * Add flame thrower!
  * Cursed power-ups :D

* Keep count of fish rescued - use as currency in pre-game shop...
  * Start with more health.
  * Other characters?

# User Experience

* How to play

# Bugs

Bugs with power ups you want to avoid or your run will be ruined.

Fish Affinity power up bug: If you have a full pink bar and Frenzy is ready and
you save it for the next level and choose the Fish Affinity power up, you can no
longer use your Frenzy move.

How to avoid: As long as your pink meter is not full feel free to choose the Fish
Affinity power up, if your pink meter is full and Frenzy is ready, DO NOT choose
Fish Affinity. Simply pick another option and your meter will be fine.

Cheat Death bug: If you have Cheat Death and you die as the level is getting
ready to end (screen will have a countdown of 3, 2, 1), you will revive but be
unable to collect the key. This keeps you permanently stuck on that level until 
you either quit or die.

If you manage to survive long enough with this bug, all enemies will cease to
spawn and you will be soft locked with quitting the game to be your only option.

How to avoid: If you have Cheat Death DO NOT DIE while the 3, 2, 1 countdown is
on screen to end the level.

I have performed these enough times to feel it is worth posting here to help
others avoid these situations to the best of their abilities. I have lost too
many runs due to these bugs.

Not sure if these will ever get patched but here is hoping one day maybe. Until
then use the above to help avoid these.

Using Frenzy during the 3, 2, 1 countdown to next stage will make the countdown
stop on 1 and not let you advance to the next stage.

How to avoid: Don't use Frenzy move when the stage is about to complete and
change to the next one.

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
		
