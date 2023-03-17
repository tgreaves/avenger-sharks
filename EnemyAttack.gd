extends CharacterBody2D

@export var enemy_attack_speed = 500

func _ready():
	$AnimatedSprite2D.play();

func _physics_process(delta):
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		print("ENEMY ATTACK HIT: ", collision.get_collider().name)
		
		collision.get_collider().get_node('.')._player_hit();
		self.queue_free()
