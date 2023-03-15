extends CharacterBody2D

enum {
	IDLE,
	WANDER
}

var state = WANDER;
@onready var screen_size = get_viewport_rect().size

func _ready():
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
			
	move_and_slide();	
	
	if velocity.x > 0:
		$AnimatedSprite2D.set_flip_h(false);
	
	if velocity.x < 0:
		$AnimatedSprite2D.set_flip_h(true);	
			
			
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
