# Gameplay

* Difficulty levels (fish themed, e.g Minnow upwards)

* Ability to shoot enemies when spawning in (but not collide)
* More power-up suggestions
  * Speed?
  * Bouncing shots?
  * Exploding shots
  * Piercing shots
  * Mega Shark Mode?!
* Powerups: Change mix - put health on different timer, dropped by enemies?

* Scenery / Obstacles in room (Tileset has boxes)

* Opens up possibilities of some rooms being special, e.g. just full of fish?
* Every x waves is a special room?

* Keep count of fish rescued - use as currency in shop between x levels?
* Bonus points for collecting all fish at end of wave?
* Animation of fish being released back into the sea?

* Boss wave

* How to play
* Basic options (e.g. full screen and windowed selection)


# Bugs

* Necromancer have 5 HP but fewer hits seem to kill them. 
* Necromancers sometimes flicker after death / level transitions.
* Big spray doesn't work when player close to a wall.

* New Powerup system design
* Selection bar....
  * Speed-up
  * Fast Spray
  * Big Spray
  * Mini Shark


* Patch Notes

* Internal: MUSIC_ENABLED constant.



"chest":
                            var powerup_selection = randi_range(1,3)
                            
                            match powerup_selection:
                                1:
                                    big_spray=1;
                                    $BigSprayTimer.start(constants.POWER_UP_ACTIVE_DURATION);
                                    powerup_label_animation('BIG SPRAY!')
                                2:
                                    fast_spray=true
                                    $FastSprayTimer.start(constants.POWER_UP_ACTIVE_DURATION);
                                    powerup_label_animation('FAST SPRAY!')
                                3:
                                    if get_tree().get_nodes_in_group('miniSharkGroup').size() < 8:
                                            
                                        var new_mini_shark = MiniSharkScene.instantiate()
                                        add_child(new_mini_shark)
                                        new_mini_shark.add_to_group('miniSharkGroup')
                                    
                                        # Reset circular position of the mini sharks when we spawn a new one, to ensure
                                        # everything stays evenly spaced.
                                        recalculate_mini_shark_spacing()
                                     
                                    powerup_label_animation('MINI SHARK!')
                                    
                            $AudioStreamPowerUp.play()

