# Gameplay

* Necromancers...
  * Check hit boxes as should be 5 hits only... might need to remove collision from SharkSpray on a hit.

* Ability to shoot enemies when spawning in (but not collide)
* Replace power-ups with sprites (NOTE: Tilemap has animations too), and implement more....
  * Speed?
  * Bouncing shots?
  * Rapid fire
  * Exploding shots
* Scenery / Obstacles in room (Tileset has boxes)

* Opens up possibilities of some rooms being special, e.g. just full of fish?
* Every x waves is a special room?

* When only x enemy left, give hint arrows // change their behaviour to hunt for all types.
* Keep count of fish rescued - use as currency in shop between x levels?
* Bonus points for collecting all fish at end of wave?
* Animation of fish being released back into the sea?

* Replace health numerical representation with a health bar? // Progress bar 

# Bugs

* Necromancers sometimes flicker after death / level transitions.
* Big spray doesn't work when player close to a wall.
* Items not correctly despawning on game end.

# Flow

* Some form of intro
* Menu system, credits etc

# Patch notes

* Interface: Initial menu system (Main and Pause).
* Interface: Energy now represented as a ProgressBar.
* Interface: Added version number.
* Bug fix: Fixed crash due to SharkSpray conflict with ExitLocation.
* Bug fix: Potions could block level exit route.  They now despawn on wave end.
* Bug fix: Stop items spawning out of bounds.


