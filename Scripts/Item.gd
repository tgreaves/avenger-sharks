extends CharacterBody2D

var ITEMS = ["chest", "chest", "chest", "health"]

@export var item_type = ""

enum { SPAWNING, READY }

var state = SPAWNING
var source = ""


# Called when the node enters the scene tree for the first time.
func _ready():
	state = SPAWNING


func spawn_random(despawn_mode):
	item_type = ITEMS[randi() % ITEMS.size()]
	spawn_specific(item_type, despawn_mode)


func spawn_specific(item_selection, despawn_mode):
	item_type = item_selection

	$AnimatedSprite2D.animation = item_selection + str("-idle")
	$CollisionShape2D.disabled = false
	$AnimatedSprite2D.play()

	if item_selection == "power-pellet":
		$AnimatedSprite2D.scale = Vector2(4, 4)

	if despawn_mode:
		$DespawnTimer.start(constants.ITEM_DESPAWN_TIME)

	state = READY


func set_source(in_source):
	source = in_source


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if (state == READY) && ($DespawnTimer.time_left == 0):
		if source == "DROPPED":
			get_parent().dropped_items_on_screen = get_parent().dropped_items_on_screen - 1
		despawn()


func _physics_process(_delta):
	match state:
		READY:
			move_and_slide()

			var distance = position.distance_to(get_parent().get_node("Player").position)

			if get_parent().get_node("Player").item_magnet_enabled:
				if distance < 250:
					var target_direction = (
						(get_parent().get_node("Player").global_position - global_position)
						. normalized()
					)
					velocity = target_direction * (get_parent().get_node("Player").speed + 3000)


func despawn():
	queue_free()
