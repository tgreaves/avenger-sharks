extends CharacterBody2D

@export var speed = 400

signal hit;
@onready var screen_size = get_viewport_rect().size

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	
func _physics_process(delta):
	get_input()
	move_and_slide()
		
	if velocity.x > 0:
		$AnimatedSprite2D.set_flip_h(true);
	
	if velocity.x < 0:
		$AnimatedSprite2D.set_flip_h(false);
		
	$AnimatedSprite2D.play();
	
	print("Count is" + str(get_slide_collision_count()));
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		print("I collided with ", collision.get_collider().name)
		
		var collided_with = collision.get_collider();
		collided_with.queue_free();
	
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
	
	print("x: " + str(position.x) + " y: " + str(position.y))
	
	#move_and_slide()
