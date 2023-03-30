extends Node2D

@export var fish_scene: PackedScene;

enum {
    ALL_IS_FINE,
    LABEL_GONE,
    NECRO_STOP,
    NECRO_ATTACK,
    SHARK_SPIN,
    NECRO_LEAVE,
    SHARK_CHASE,
    FADE_OUT
}

var state
var shark_rotation = 0
var necro_start_position

# Called when the node enters the scene tree for the first time.
func _ready():
    state = ALL_IS_FINE
    var i = 0;
    while i < 50:
        spawn_fish()
        i+= 1
        
    $Shark/SharkSprite.play()
    $MusicBoxSong.play()
    $StateTimer.start(9.7)
    $IntroLabelTimer.start(5)
    
    necro_start_position = $Necromancer/NecroSprite.global_position
    
    set_modulate(Color(0,0,0,0));
    var tween = get_tree().create_tween()
    tween.tween_property(self, "modulate", Color(1,1,1,1), 2.0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    match state:
        ALL_IS_FINE:
            # Start happy music and set-up title fade.
            if $IntroLabelTimer.time_left == 0:
                var tween = get_tree().create_tween()
                tween.tween_property($IntroLabel, "modulate", Color(1,1,1,0), 2)
                #tween.tween_callback(new_label.queue_free).set_delay(3)
                
                state = LABEL_GONE
                
        LABEL_GONE:
            # Start creepy music, commence necromancer movement onto screen.
            if $StateTimer.time_left == 0:
                $MusicBoxSong.stop()
                $BadThingsSong.play()
                $Necromancer/NecroSprite.play()
                state = NECRO_STOP
                var target_direction = ($Shark.global_position - $Necromancer.global_position).normalized()
                $Necromancer.velocity = target_direction * 75
                
                $StateTimer.start(8)
                
        NECRO_STOP:
            if $StateTimer.time_left == 0:
                $Necromancer.velocity = Vector2(0,0)
                state = NECRO_ATTACK
                $StateTimer.start(1)
            
        NECRO_ATTACK:
            if $StateTimer.time_left == 0:
                # Wait for next sequence in music, then necro attack stage.
                $Necromancer/NecroSprite.animation = 'necromancer-attack'
    
                var i = 0
    
                for fish in get_tree().get_nodes_in_group('fishGroup'):
                    i = i + 1
                    fish.swim_to_necromancer(i)
                
                state = SHARK_SPIN
                $StateTimer.start(12)
        SHARK_SPIN:
            shark_spin()
            
            if $StateTimer.time_left == 0:
                # Fish collection will have completed.
                state = NECRO_LEAVE
                
                $Necromancer/NecroSprite.animation = 'necromancer-run'
                $Necromancer/NecroSprite.flip_h = false
                $SeaWallRight/CollisionShape2D.disabled = true
                $SaveUsLabel.visible = true
                var tween = get_tree().create_tween()
                tween.tween_property($SaveUsLabel, "modulate", Color(1,1,1,0), 3)
                
                $StateTimer.start(8)
        NECRO_LEAVE:
            shark_spin()        # Keep spinning!
            
            var target_direction = (necro_start_position - $Necromancer.global_position).normalized()
            $Necromancer.velocity = target_direction * 75
            
            if $StateTimer.time_left == 0:
                $Shark.rotation_degrees = 0
                state = SHARK_CHASE
                $StateTimer.start(1)
                
        SHARK_CHASE:
            $Shark.swim_to_necromancer()
            if $StateTimer.time_left == 0:
                var tween = get_tree().create_tween()
                tween.set_parallel()
                tween.tween_property(self, "modulate", Color(0,0,0,0), 5.0)
                tween.tween_property($BadThingsSong, "volume_db", -80, 5.0)
                
                $StateTimer.start(4)
                state=FADE_OUT
                
        FADE_OUT:
            if $StateTimer.time_left == 0:
                get_parent().intro_has_finished()
            
                
func spawn_fish():
    var mob = fish_scene.instantiate();
    mob.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X, constants.ARENA_SPAWN_MAX_X / 2),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y / 2)));
    mob.add_to_group('fishGroup');	
    mob.set_intro_mode()
    add_child(mob);
    
func shark_spin():
    shark_rotation = shark_rotation + 5
    if shark_rotation > 350:
        shark_rotation = 0
    $Shark.rotation_degrees = shark_rotation
