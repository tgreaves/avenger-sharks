extends CharacterBody2D

enum {
	IDLE,
	WANDER,
	DYING
}

var state = WANDER;
var enemy_type;

@onready var screen_size = get_viewport_rect().size

func _ready():
	#var mob_types = $AnimatedSprite2D.get_sprite_frames().get_animation_names()
	var mob_types = ['knight','wizard']
	enemy_type = mob_types[randi() % mob_types.size()]
	$AnimatedSprite2D.animation = enemy_type + str('-run')
	
	$AnimatedSprite2D.play()
	$StateTimer.start();
	velocity = Vector2(randf_range(-64,64), randf_range(-64,64));
	move_and_slide();

func _physics_process(delta):
	#print("Time" + str($StateTimer.time_left));
	match state:
		IDLE:
			velocity = Vector2(0,0);
			
			if $StateTimer.time_left == 0:
				#print("Timer out");
				state = WANDER;
				$StateTimer.start(float(2));			
		WANDER:
			#print("WANDER!!");
			if $StateTimer.time_left == 0:
				state = WANDER;
				$StateTimer.start(float(2));
				velocity = Vector2(randf_range(-64,64), randf_range(-64,64));
		DYING:
			if $StateTimer.time_left == 0:
				self.queue_free();
			
	move_and_slide();	
	
	if velocity.x > 0:
		$AnimatedSprite2D.set_flip_h(false);
	
	if velocity.x < 0:
		$AnimatedSprite2D.set_flip_h(true);	
			
			
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
	
func _death():
	print("Dead.")
	$CollisionShape2D.set_deferred("disabled", true)
	velocity = Vector2(0,0);
	$AnimatedSprite2D.animation = enemy_type + str('-death');
	$StateTimer.start(3);
	state = DYING;
