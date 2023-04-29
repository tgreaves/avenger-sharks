# Changelog

# 0.3-alpha

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
* Game balance: 
    * Enemy types that spawn start simple and grow more complex as waves progress.
    * Chests 2 x likely to be dropped than health potions.
    * Spawn traps less frequently.
* Graphics: 
    * Display obtained upgrades on HUD.
    * Speed up Necromancer death animation.
* Misc: Persistent storage support.
* Misc: Statistics (which use the persistent storage...) now tracked and viewable.
* Misc: ESC key can now exit intro and credits.
* Steam: Initial store assets and listing.
* Bug fixes:
    * Stop game breaking if player dies at the same time as beating a wave.

# 0.2-alpha

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

# 0.1-alpha

First release.
