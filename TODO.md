# Gameplay

* Necromancers...
  * Check hit boxes as should be 5 hits only... might need to remove collision from SharkSpray on a hit.

* Ability to shoot enemies when spawning in (but not collide)
* Replace power-ups with sprites (NOTE: Tilemap has animations too), and implement more....
  * Speed?
  * Bouncing shots?
  * Rapid fire
* Cheat mode
* Scenery / Obstacles in room (Tileset has boxes)

* Room movement: Show entry into next room?
  * Remove door when going through it, replace upon entry / room set-up
  * Can use reload_scene() or similar here.
* Opens up possibilities of some rooms being special, e.g. just full of fish?
* Every x waves is a special room?

* When only x enemy left, give hint arrows // change their behaviour to hunt for all types.
* Keep count of fish rescued - use as currency in shop between x levels?
* Bonus points for collecting all fish at end of wave?

# Bugs

* Potions can block path to starting point -- need to despawn all items at level set-up.
(Set all layer to 0, should be straigthtforward)
* Necromancers sometimes flicker after death / level transitions.
* Big spray doesn't work when player close to a wall.

# Flow

* Some form of intro
* Menu system, credits etc

# Patch notes

* Bug fix: Health potions work correctly in cheat mode.


