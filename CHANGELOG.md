# Changelog

# 1.4.0 (2026-xx-xx)

* Gameplay:
	* BOSS WAVES! Every fifth wave (from wave 5) is a showdown with a giant boss.
		* The fight takes place in a sealed, single-screen room: swim in from the bottom, the door closes behind you, and it's you versus the boss.
		* The boss is a random giant enemy with its own fun title (e.g. MR. RATTLEBONES, THE QUEEN BEE) and a themed attack style. It materialises with a spawn-in effect, and its name is announced as it swims in ("<NAME> IS HERE!").
		* Varied bullet-hell attacks: rotating spirals, curving spirals, shotgun blasts and walls-with-a-gap to dodge through.
		* CHARGE attack: some bosses rear back with a vibrating tell, then lunge across the whole room at where you were standing — move to dodge it. The lunge barrels straight through you (contact still hurts) and only stops when it slams a wall.
		* HOMING SEEKERS: bosses can launch colourful homing missiles that curve after you and burst in a small explosion when they die — juke to shake them, or shoot them down (from a safe distance, as they still go off).
		* Bosses now ENRAGE at 25% health — turning red with an angry flex and firing noticeably faster for the rest of the fight. The whole fight also opens at a brisker pace.
		* Some boss fights also send in 'add' enemies to keep you busy. These now erupt from the boss and are flung out toward the sharks, and always match the boss's own kind — a giant bee sends a bee swarm, a skeleton lord sends skeletons.
		* Defeat the boss for a big score bonus and a full heal; later bosses are tougher.
		* Because beating a boss fully heals both sharks, the HEAL ME upgrade is no longer offered on the upgrade screen right after a boss wave (it would be wasted).
	* LOCAL TWO-PLAYER CO-OP! A second shark can join on a gamepad, or be computer-controlled.
		* Shared zoom-to-fit camera that keeps both sharks in view.
		* Each player has their own energy, FISH FRENZY, power-ups, score and upgrades.
		* Both players choose their between-wave upgrade at the same time.
		* A downed player sits out the rest of the wave and returns next wave; game over only when both are down.
		* Optional CPU-controlled second player.
		* Two-player device setup screen: each player presses a button to claim their controller (or keyboard + mouse) before the game starts.
		* Separate high scores for each mode: 1 player, 2 players, and 2 players (CPU).
		* Co-op fairness pass: each shark's own BIG SPRAY and DOMINANT DINO upgrades now apply to that shark, artillery strikes and circling enemies target either player, and the low-energy / feeding-frenzy music reacts to both sharks.
	* Enemies now spawn while the sharks are still swimming into position, so the action starts without a pause; the opening wave's surrounding enemies now form up around where the sharks come to rest.
* Bug fixes:
	* PACIFIST mode: fish counter failed to update at wave start due to a misspelt game mode check.
	* GRENADE fire rate no longer carries over from a previous game; grenade delay is now reset at the start of each new game.
	* Fixed a crash at wave end if the survival timer expired with no enemies on screen.
	* OPTIONS: fixed the oversized ENABLE HAPTICS button (a stray line break made its row taller than the others).
	* Fixed a crash when a boss projectile struck the boss room's exit marker.
	* Boss waves: the larger bosses (bee, snake) could get stuck against a side wall while pacing instead of turning around. They now reverse on wall contact.
	* Boss waves: aligned the boss collision shapes (bee and necromancer) to their bodies so shots register on the creature rather than the empty water around it.
		* A shark caught mid-SWIM SURGE (dash) when a wave ended could get stuck in the dash and fail to hunt the key; the dash is now cleared cleanly at wave end.
		* Fixed controls becoming unresponsive for a whole wave if an enemy that spawned during the swim-in blocked or deflected a shark from reaching its start position (most easily hit on special waves like FEEL THE BUZZ that spawn enemies around the sharks).
		* Two-player boss waves: the second shark could get stuck on the swim-in and never enter the boss room; both sharks now start inside the room.
		* Two-player waves: the two sharks now spawn symmetrically about the centre (previously player 1 sat on the centre and player 2 was offset to the right) — most noticeable in the boss room, where the camera is locked.
		* Two-player HUD: player 2's upgrade list is now aligned with player 1's (same top and height) instead of sitting lower with a gap below the score.
* Platform:
	* Godot upgrade to 4.7.stable.
	* Steam: GodotSteam GDExtension upgraded to 4.20.
* Misc:
	* [INTERNAL] Arena migrated from the deprecated TileMap node to TileMapLayer nodes.
	* [INTERNAL] Cleared GDScript analyzer warnings (unused/shadowing locals and parameters).

# 1.3.0 (2024-10-15)

* Gameplay:
	* New power up: SCATTER SPRAY
* Bug fixes:
	* Player could STILL get stuck hunting for exit.  Fixed.  Properly this time!
	* FISH FRENZY activated when wave ends would trap the player in the wave forever.
	* CHEAT DEATH activated when wave ends would trap the player in the wave forever.
	* Haptic feedback now works on MacOS (Fixed in Godot 4.3)
* Platform:
	* Godot upgrade to 4.3.stable.
	* Steam: GodotSteam GDExtension upgraded to 4.11-gde (Stated as supporting Godot 4.3)
	* Web: Support reinstated following Godot 4.3 fixing threads / MacOS browser issues.
* Misc:
	* [INTERNAL] Code refactoring with GDScript Toolkit.
	* [INTERNAL] godot-git-plugin upgraded to v3.1.1.

Thanks to chopsteak for their bug reporting via Steam Community!

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
