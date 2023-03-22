extends CharacterBody2D

@export var spray_speed = 800

func _ready():
	$AnimatedSprite2D.play();
	if get_parent().get_node('Player').big_spray:
		print("Big please")
		set_global_scale(Vector2(1.5,1.5))
		
		
func _physics_process(_delta):
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		
		if collision.get_collider().name == 'Arena':
			self.queue_free()
			break;
			
		collision.get_collider().get_node('.')._death();
		$CollisionShape2D.disabled = true;
		self.queue_free()
