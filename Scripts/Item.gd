extends StaticBody2D

var ITEMS = ["chest"]
@export var item_type = ""

# Called when the node enters the scene tree for the first time.
func _ready():
    pass

func spawn_random():
    item_type = ITEMS[randi() % ITEMS.size()]
    $AnimatedSprite2D.animation = item_type + str('-idle')
    $CollisionShape2D.disabled = false;
    $AnimatedSprite2D.play()

func spawn_specific(item_selection):
    item_type = item_selection
    $AnimatedSprite2D.animation = item_selection + str('-idle')
    $CollisionShape2D.disabled = false;
    $AnimatedSprite2D.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func despawn():
    # TODO: Chest should play a different animation, and then spawn text to match item type.
    queue_free()
