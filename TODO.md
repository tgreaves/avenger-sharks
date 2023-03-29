# Gameplay

* Necromancers...
  * Check hit boxes as should be 5 hits only... might need to remove collision from SharkSpray on a hit.

* Ability to shoot enemies when spawning in (but not collide)
* Replace power-ups with sprites (NOTE: Tilemap has animations too), and implement more....
  * Speed?
  * Bouncing shots?
  * Exploding shots
  * Piercing shots
  * Mega Shark Mode?!
  * 'Mini Shark' that rotates around the player
* Scenery / Obstacles in room (Tileset has boxes)

* Opens up possibilities of some rooms being special, e.g. just full of fish?
* Every x waves is a special room?

* When only x enemy left, give hint arrows // change their behaviour to hunt for all types.
* Keep count of fish rescued - use as currency in shop between x levels?
* Bonus points for collecting all fish at end of wave?
* Animation of fish being released back into the sea?

# Bugs

* Necromancers sometimes flicker after death / level transitions.
* Big spray doesn't work when player close to a wall.
* Visual: Smoother transition between levels? (Colour mismatch)
** Tween modulate Main to accomplish this.  If it works, we can remove ArenaBlank...

* Best visual colour: 2863f8

# Patch notes

* Design: Experimenting with ocean-themed colour scheme for Tiles.
* Bug fix: Camera was not moving to far right.
* Internal: Converted Main scene parent to Node2D (was: Node) to prepare for fade in/out changes.
