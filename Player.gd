extends CharacterBody2D

const SharkSprayScene = preload("res://SharkSpray.tscn");


enum {
	ALIVE,
	EXPLODING,
	EXPLODED
}

@export var speed = constants.PLAYER_SPEED;
@export var player_energy = constants.PLAYER_START_GAME_ENERGY;
@export var shark_status = ALIVE
@export var big_spray = 0;

signal update_energy;
signal player_died;
@onready var screen_size = get_viewport_rect().size

func _ready():
	shark_status = ALIVE;

func get_input():
	
	if shark_status != ALIVE:
		return;
	
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
	
func _physics_process(_delta):
	get_input()
	move_and_slide()
	
	if $PowerUpTimer.time_left == 0:
		if big_spray:
			big_spray=0;
			
	
	match shark_status:
		ALIVE:
			if velocity.x > 0:
				$AnimatedSprite2D.set_flip_h(true);
			
			if velocity.x < 0:
				$AnimatedSprite2D.set_flip_h(false);
				
			$AnimatedSprite2D.play();
			
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				print("PLAYER collided with ", collision.get_collider().name + " // " + collision.get_collider().get_class())
				
				var collided_with = collision.get_collider();
				
				if collision.get_collider().name == 'Arena':
					print("RID: " + str(collision.get_collider_rid()));
					var rid_coords = collided_with.get_coords_for_body_rid( collision.get_collider_rid());
					print("Coords: " + str(collided_with.get_coords_for_body_rid( collision.get_collider_rid())));
					print ("ATLAS Trans: " + str(collided_with.get_cell_atlas_coords(1, rid_coords)));
					
					match collided_with.get_cell_atlas_coords(1, rid_coords):
						Vector2i(9,8):
							print ("HEATH");
							player_energy = player_energy + constants.HEALTH_POTION_BONUS;
							if player_energy > constants.PLAYER_START_GAME_ENERGY:
								player_energy = constants.PLAYER_START_GAME_ENERGY;
								emit_signal('update_energy')
						Vector2i(7,9):
							print ("POWERUP");
							big_spray=1;
							$PowerUpTimer.start(constants.POWER_UP_ACTIVE_DURATION);
					
					collided_with.set_cell(		1, 
												collided_with.get_coords_for_body_rid( collision.get_collider_rid()),
												-1);
					
					break;
					
				collided_with.get_node('.')._death();
				_player_hit();
				
			position.x = clamp(position.x, 0, screen_size.x)
			position.y = clamp(position.y, 0, screen_size.y)
		EXPLODING:
			if $PlayerExplosionTimer.time_left == 0:
				emit_signal('player_died');
				print("Death signal");
				shark_status = EXPLODED;

func _player_hit():
	$AudioStreamPlayerHit.play();
	player_energy = player_energy - constants.PLAYER_HIT_BY_ENEMY_DAMAGE;
	emit_signal('update_energy');
	
	if player_energy <= 0:
		$CollisionShape2D.set_deferred("disabled", true)
		velocity = Vector2(0,0);
		$AnimatedSprite2D.animation = 'explosion';
		$AudioStreamPlayerExplosion.play();
		shark_status=EXPLODING;
		$PlayerExplosionTimer.start();
	
	

