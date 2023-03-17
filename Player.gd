extends CharacterBody2D

const SharkSprayScene = preload("res://SharkSpray.tscn");

@export var speed = 400
@export var player_energy = 100

signal update_energy;
@onready var screen_size = get_viewport_rect().size

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed
	
	if input_direction && Input.is_action_just_pressed('shark_fire'):
		var shark_spray = SharkSprayScene.instantiate();
		get_parent().add_child(shark_spray);
		shark_spray.global_position = position;
		shark_spray.velocity = input_direction * shark_spray.spray_speed;
		$AudioStreamPlayerSpray.play()
		
	if Input.is_action_just_pressed('shark_fire_mouse'):
		var shark_spray = SharkSprayScene.instantiate();
		get_parent().add_child(shark_spray);
		var target_direction = (get_global_mouse_position() - global_position).normalized()
		shark_spray.global_position = position;
		shark_spray.velocity = target_direction * shark_spray.spray_speed;
		$AudioStreamPlayerSpray.play()
	
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
		print("PLAYER collided with ", collision.get_collider().name + " // " + collision.get_collider().get_class())
		
		var collided_with = collision.get_collider();
		
		collided_with.get_node('.')._death();
		_player_hit();
		
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)

func _player_hit():
	$AudioStreamPlayerHit.play();
	player_energy = player_energy - 1;
	emit_signal('update_energy');
	
	

