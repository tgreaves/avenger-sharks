extends CharacterBody2D

@export var enemy_attack_speed = 500

func _ready():
	$AnimatedSprite2D.play();

func _physics_process(_delta):
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		
		if collision.get_collider().name == 'Arena':
			self.queue_free()
			break;
		
		collision.get_collider().get_node('.')._player_hit();
		
		$CollisionShape2D.disabled = true;
		self.queue_free();
		break;
		
func _death():
		$CollisionShape2D.set_deferred("disabled", true)
		#$AudioStreamPlayer.play();
		#$StateTimer.start(2);
		#$AttackTimer.stop();
		#state = DYING;
	
		#get_parent()._on_enemy_update_score();
		self.queue_free();

