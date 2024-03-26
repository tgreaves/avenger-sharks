# Changelog

# 1.3.0 (xxxx-xx-xx)

* Bug fixes:
    * Player could STILL get stuck hunting for exit.  Fixed.  Properly this time!

# 1.2.0 (2024-03-16)

* Gameplay:
    * Player can now SPEED SURGE (left trigger / SPACE) to help avoid enemies.
    * Upgrades:
        * Player now has a choice of 3 between waves (was: 2)
        * NEW: HEAL ME - Restore all health ahead of the next wave.
        * NEW: SPEED SURGE - Improves SPEED SURGE recharge time.
    * Balance:
        * Knight health lowered to 3 (was: 4)
        * Trap health lowered to 4 (was: 10)
        * CHEAT DEATH now restores 75% of player health on activation (was: 50%)
        * Special waves can only start after Wave 3 (was: 2)
    * Chasing enemies now use proper navigation instead of hoping for the best.  Beware! 
* Misc: 
    * Graphics: 'DINNER TIME' particle effects added.
    * How To Play screen added.
    * Adjusted player movement at wave start to commence at the entrance door.
    * [INTERNAL] Added godot-git-plugin.
* Platform:
    * STEAM ACHIEVEMENTS!
        * Beat 1 / 5 / 10 waves in arcade mode.
        * Rescue 100 / 500 / 1000 fish.
        * [HIDDEN] Fail to clear the first wave.
* Bug fixes:
    * Deadlock could occur on upgrade screen if there weren't enough eligible upgrades. 
    * CHEAT DEATH could persist between games.  Upgrades now more consistently reset.
    * Player could get stuck hunting for key or exit.  Proper navigation implemented to avoid this.
    * Enemies would vanish too early when the wave ended during SHARK ATTACK.
    * Shark spray sound not synced properly with gameplay.
    * Countdown sound would keep playing when returning to main menu.
    * Game ending when in FISH FRENZY would result in player stuck at a weird angle.
    * Player, Mini Shark and Dinosaur projectiles not despawning on game ending.

# 1.1.0 (2024-03-03)

* Gameplay:
    * Waves: These are now TIME based to keep the action fast, fresh and furious.
    * New power-up: A magical star that allows your shark to eat the now very scared enemies!
    * Artillery: Watch out for POLLUTION STRIKES from above!
    * Spawning: Avoid spawn types at beginning of wave that give player too much space.
    * AI: Chasing enemies re-orient more often.
    * Knockback: Some enemies are now knocked back when hit.
* Performance:
    * FPS improved as follows...
        * Switched to the Forward+ renderer (Was: 'Compatibility').
        * Particles now switched to GPU.
        * Replace PointLight2D lighting effects on projectiles with Sprite2D equivalent.
* Sound:
    * New music tracks for menu and gameplay.  Enjoy!
    * Countdown effect towards end of wave.
    * Grenade volume lowered slightly.
* Bug fixes:
    * Diet: At some point, Necromancers stopped wanting to eat fish.  Fixed.
    * UI: Tightened up mouse showing / hiding as appropriate
* Platform:
    * Steam: GodotSteam GDExtension upgraded to 4.6.
* Misc:
    * Haptic feedback added! Vibrates on player hit + shark frenzy.  Turn on in OPTIONS.
        * This will not work on all platforms.
            * Example for MacOS Sonoma - https://github.com/godotengine/godot/issues/88674
    * Improved alignment of death animations.
    * Fish now swim off to freedom once rescued.
    * Pause improvements:
        * ESC can be used to unpause.
        * Can now pause game during WAVE START, WAVE END and UPGRADE SCREEN.
    * Debug menu to keep an eye on performance (toggle modes with F3).
    * Removed some spurious debug print() statements.

# 1.0.0 (2024-02-21)

This is the first public release of Avenger Sharks on Steam.

* Platform:
    * Steam: Bringing up Steam Overlay during game automatically pauses.
* Misc:
    * UI: Disable TAB key (avoids Steam Overlay weird behaviour)
    * UI: Hide mouse pointer when mouse is not being used

# 0.5-alpha (2024-02-21)

* Gameplay:
    * New enemy: Snake / Blob: A multi-segment denizen of the dungeons!
    * Random obstacles can appear within a wave.
    * TheDirector AI implemented for wave / spawn design (much refactoring)
    * Removed 'The fish become fearful!' Necromancer wave type -- added fresh ones!
* Graphics:
    * Lighting and Shadow effects.
    * Red screen flash when player takes damage.
    * Added 'For Jack and Emilia' dedication page at start.
* Platform:
    * Steam: Client is now formally Steam enabled, including Steam Overlay.
    * Steam: Revised store assets to new graphical design.
    * Steam: Hide direct itch.io links on CREDITS (Steam policy requirement)
    * Itch: Revised store assets to new graphical design.
    * Itch: Removed web project due to Godot 4 / Mac browser challenges.
* Bug fixes:
    * Crash: Fixed a crash when there was a combo of targetting laser / trap / collision.
    * Pathing: If player gets stuck on key or exit hunt, teleport them to safety.
    * UI: MORE POWER upgrade would hide all the upgrade bars.
    * UI: Powerup floating text now stacks if player picks up several in a short space of time.
    * Music: Would get stuck at 'low health' speed if game abandoned in that state.
    * Credits: Reset scroll when exiting credits screen.
* Misc:
    * Godot upgrade to 4.2.1.stable.
    * GodotSteam upgrade to GDExtension 4.2.
    * Exclude Store_Assets directory from main Godot project.
    * Exclamation mark from title purged.

# 0.4-alpha (2023-05-12)

In this release, the gameplay has been sped up to make it more frenetic, combined
with the addition of skeletons and GRENADES!  The HUD has been streamlined, and the player has a 
targeting laser when playing with a controller. 

Away from the core game, we now also have an Options screen and Steam Cloud
support.

* Gameplay:
    * Increase player fire rate and re-balance FAST SPRAY
    * Enemies can no longer take damage while they are spawning.
    * Increase enemy spawn numbers.
    * % chance of multiple spawns happening at the same time (Will be different types)
    * Increase knight health to 4 (was: 1)
    * Increase necromancer health to 10 (was: 3)
    * Increase trap health to 10 (was: 5)
* Enemies:
    * Added Skeletons (that split into 4 when vanquished!)
* Power-ups:
    * Added GRENADE power-up (Boom!)
    * Power-ups no longer 'tick' unless the player is actively controlling the shark.
* Controls:
    * Controller: Player now has a targetting laser! 
    * Controller: 'B' button to back out of menus.
* Graphics:
    * Power up bar moved to RHS.  Non-activated power-ups are not shown.
* Sound:
    * Master / Music / Volume audio buses implemented.
* Misc
    * Options screen added.  Persistent storage used.
        * Screen mode (Full screen, windowed)
        * Volume (Master, Music, Effects)
    * Credits screen re-jigged.
    * Pacifist Mode: Hide power-up bar.
    * Windowed Mode: Use 1920x1080 as a default (User can re-size)
* Platform:
    * HTML5: Disable storage, Statistics and Exit Game.
    * Steam: Steam Cloud sync for Statistics (cross-platform)
* Bug fixes
    * Player projectiles would not pass through spawning enemies.
    * Magnet: Make a bit stronger to avoid items chasing the player(!)
    * Controller START button mapped to too many menu items (and so not working).
    * Steam Deck: STATISTICS not consistently working when selected with controller.
    * Steam Deck: CREDITS not consistently working when selected with controller.

# 0.3-alpha (2023-05-03)

This release introduces the upgrade system, a new Pacifist game mode, more interesting wave /
spawning mechanics and much more!

* Upgrade system:
    * Upgrade between waves (choice of two).
        * Magnet item pull.  Changed Items to be CharacterBody2D to support.
        * Armour: Reduces damage (10% per level)
        * Fish Affinity: Reduces number of fish to rescue to enable FISH FRENZY (10% per level)
        * Potion Power: Increases health potion efficiency (10% per level)
        * Dominant Dino: Increase dinosaur rampage time (20% per level)
        * More Power: Increase Power Up duration (20% per level)
        * Loot Lover: Increase item drop rate (10% per level)
        * Cheat death: Respawn upon death with 50% health.
* New game mode: Pacifist
    * Player cannot shoot or Frenzy and has to collect the fish to clear waves.
    * No upgrades.
    * Enemies do not drop power-ups.  Health Potions spawn randomly in the arena.
* New enemy type: Bee! (bzzzzzz)
* Wave / Spawning mechanics:
    * Introduce different enemy types as player progresses.
    * % chance of a special wave ('All bees', 'All Necromancers')
    * Spawning methods during a wave:
        * Random (Default for previous releases)
        * Circle around the player
        * Arena edge and move inwards (Top / Bottom / Left / Right)
    * Enemy AI can be deferred to support custom wave patterns
    * Enemies move FASTER if spawning from an edge to keep the tension up.
    * Final enemy spawn during a wave will appear near player (to save having to hunt)
    * Final enemies will move faster in the wave.
* Gameplay and balance:
    * Score multiplier introduced.  Multiplier lost when the player takes damage.
    * Chests more likely to be dropped than health potions.
    * Spawn traps less frequently.
    * Reduced dropped item % (was: 25%, now 15%)
    * Only 5 dropped items permitted on screen at a time (Avoids scaling abuse)
    * Reduced time between enemies spawning in and becoming dangerous to 1.5s (was: 2s)
    * Reduced Necromancer health and attack rate.
* Graphics:
    * Particles!
        * Enemies spawning.
        * Enemies being defeated.
        * Player and Mr Dinosaur attacks. 
    * Display obtained upgrades on HUD.
    * Pop-up points scored from enemies as they are defeated.
    * Speed up Necromancer death animation.
* Misc: Persistent storage support.
* Misc: Statistics (which use the persistent storage...) now tracked and viewable.
    * Games played
    * Shots fired
    * Enemies defeated
    * Fish rescued
    * Furthest wave reached
* Misc: ESC key can now exit intro and credits.
* Steam: Initial store assets and listing.
* Bug fixes:
    * Stop game breaking if player dies at the same time as beating a wave.
    * Improve arena spawn co-ordinates range to prevent insta-collisions.
    * Fixed shonky calculations for enemy spawn numbers within a wave.

# 0.2-alpha (2023-04-16)

This is primarily a bug fix / 'quality of life' release.

* Gameplay: Make player invulnerable during wave exit.
* Gameplay: Improved necromancer hit box.
* Controls: Support AZERTY keyboards.
* Graphics: Make power-up labels a bit bigger.
* Sound: Play tension music when low energy.
* Sound: Remove slight gap at start of main game music.
* Bug fix: Increase 'WAVE X' timer to avoid fish spawning before player in start position.
* Bug fix: Fix 'flash hit' animation for necromancers on spawn.
* Bug fix: Make 'Enemies Left' behaviour consistent between games.
* Bug fix: Tidy up projectiles getting stuck around exit locations in transitions.

# 0.1-alpha (2023-04-06)

First release.
