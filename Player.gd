extends CharacterBody2D

const SharkSprayScene = preload("res://SharkSpray.tscn");

@export var speed = 400

signal enemy_eaten;
@onready var screen_size = get_viewport_rect().size

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	
	if input_direction && Input.is_action_just_pressed('shark_fire'):
		var shark_spray = SharkSprayScene.instantiate();
		get_parent().add_child(shark_spray);
		shark_spray.global_position = position;
		shark_spray.velocity = input_direction * shark_spray.spray_speed;
		$AudioStreamPlayer.play()
		
	if Input.is_action_just_pressed('shark_fire_mouse'):
		var shark_spray = SharkSprayScene.instantiate();
		get_parent().add_child(shark_spray);
		var target_direction = (get_global_mouse_position() - global_position).normalized()
		shark_spray.global_position = position;
		shark_spray.velocity = target_direction * shark_spray.spray_speed;
		$AudioStreamPlayer.play()
	
func _physics_process(delta):
	get_input()
	move_and_slide()
		
	if velocity.x > 0:
		$AnimatedSprite2D.set_flip_h(true);
	
	if velocity.x < 0:
		$AnimatedSprite2D.set_flip_h(false);
		
	$AnimatedSprite2D.play();
	
	#print("Count is" + str(get_slide_collision_count()));
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		print("I collided with ", collision.get_collider().name + " // " + collision.get_collider().get_class())
		
		var collided_with = collision.get_collider();
		
		if collided_with.name.contains('SharkSpray'):
			print("Ignore Spray");
			break;
		
		#collided_with.queue_free();
		
		#emit_signal('enemy_eaten');
		#collided_with.get_node('.')._death();
		
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
	

