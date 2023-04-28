extends CharacterBody2D

var ITEMS = ['chest','chest','health']

@export var item_type = ""

enum {
    SPAWNING,
    READY
}

var state = SPAWNING

# Called when the node enters the scene tree for the first time.
func _ready():
    state=SPAWNING

func spawn_random():
    item_type = ITEMS[randi() % ITEMS.size()]
    spawn_specific(item_type)
    
func spawn_specific(item_selection):
    item_type = item_selection
    
    $AnimatedSprite2D.animation = item_selection + str('-idle')
    $CollisionShape2D.disabled = false;
    $AnimatedSprite2D.play()
    
    $DespawnTimer.start(constants.ITEM_DESPAWN_TIME)
    state=READY

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if (state==READY) && ($DespawnTimer.time_left == 0):
        despawn()
        
func _physics_process(_delta):
    match state:
        READY:
            move_and_slide()
            
            var distance = position.distance_to( get_parent().get_node('Player').position )
            
            if get_parent().get_node('Player').item_magnet_enabled:
                if distance < 250:
                    var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                    velocity = target_direction * ( get_parent().get_node("Player").speed + 750 )

func despawn():
    # TODO: Chest should play a different animation, and then spawn text to match item type.
    queue_free()
