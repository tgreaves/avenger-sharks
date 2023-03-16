extends CharacterBody2D

@export var spray_speed = 800

func _ready():
	$AnimatedSprite2D.play();

func _physics_process(delta):
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		print("BULLET HIT: ", collision.get_collider().name)
		
		collision.get_collider().get_node('.')._death();
		self.queue_free()
