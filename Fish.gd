extends CharacterBody2D

enum {
	ACTIVE,
	DESPAWNING
}

var state = ACTIVE;

func _ready():
	#$AnimatedSprite2D.anim
	
	var animation_options = $AnimatedSprite2D.sprite_frames.get_animation_names().size();
	var rng = RandomNumberGenerator.new()
	var index = rng.randi_range(0, animation_options-1);
	
	var animation_name = $AnimatedSprite2D.sprite_frames.get_animation_names()[index];
	
	$AnimatedSprite2D.play(animation_name)

func _physics_process(delta):
	match state:
		ACTIVE:
			move_and_slide()
			
		DESPAWNING:
			if $StateTimer.time_left == 0:
				queue_free();

func _death():
	$CollisionShape2D.set_deferred("disabled", true)
	$AudioStreamPlayer.play();
	$AnimatedSprite2D.hide();
	
	state = 'DESPAWNING';
	$StateTimer.start(2);
