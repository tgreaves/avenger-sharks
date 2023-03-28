extends Node2D

@export var fish_scene: PackedScene;

enum {
    ALL_IS_FINE,
    LABEL_GONE,
    BAD_TIMES
}

var state

# Called when the node enters the scene tree for the first time.
func _ready():
    state = ALL_IS_FINE
    var i = 0;
    while i < 50:
        spawn_fish()
        i+= 1
        
    $SharkSprite.play()
    $MusicBoxSong.play()
    $StateTimer.start(9.5)
    $IntroLabelTimer.start(5)
    
    #$IntroLabel.set_modulate(Color(1,1,1,1));

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    match state:
        ALL_IS_FINE:
            if $IntroLabelTimer.time_left == 0:
                var tween = get_tree().create_tween()
                tween.tween_property($IntroLabel, "modulate", Color(1,1,1,0), 2)
                #tween.tween_callback(new_label.queue_free).set_delay(3)
                
                state = LABEL_GONE
                
        LABEL_GONE:
            if $StateTimer.time_left == 0:
                $MusicBoxSong.stop()
                $BadThingsSong.play()
                state = BAD_TIMES
                
                
                

func spawn_fish():
    var mob = fish_scene.instantiate();
    mob.get_node('.').set_position (Vector2(randf_range(constants.ARENA_SPAWN_MIN_X, constants.ARENA_SPAWN_MAX_X / 2),randf_range(constants.ARENA_SPAWN_MIN_Y,constants.ARENA_SPAWN_MAX_Y / 2)));
    mob.add_to_group('fishGroup');	
    mob.set_intro_mode()
    add_child(mob);
