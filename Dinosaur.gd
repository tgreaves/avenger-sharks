extends CharacterBody2D

const DinosaurAttackScene = preload("res://DinosaurAttack.tscn");
var state = IDLE;

enum {
	IDLE,
	RAMPAGING
}

func _ready():
	$AnimatedSprite2D.play()
	state=IDLE

func _go_on_a_rampage():
	state=RAMPAGING;
	set_collision_layer_value(6,false);	# No longer be an item.
	set_collision_layer_value(8,true); # Be a DINOSAUR!
	set_collision_mask_value(1,false); # No longer collide with player.
	set_collision_mask_value(5,true); # We do not want to collide with walls.

	$AnimatedSprite2D.play('dinosaur-run');
	$DinosaurAttackTimer.start(0.1); # Insta attack first time.
	$DinosaurSurvivalTimer.start(constants.DINOSAUR_SURVIVAL_TIME);
	$AudioStreamDinosaurGrowl.play();
	
	# Set a random direction.
	velocity = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * constants.DINOSAUR_SPEED;
	
func _physics_process(delta):
	var collision = move_and_collide(velocity * delta);
	
	if velocity.x > 0:
		$AnimatedSprite2D.set_flip_h(false);
			
	if velocity.x < 0:
		$AnimatedSprite2D.set_flip_h(true);

	if collision:
		velocity = velocity.bounce(collision.get_normal());

	if state==RAMPAGING && $DinosaurAttackTimer.time_left == 0:
		# Spiral attack pattern.
		var i = 1;
		while (i <= 16):
			var dinosaur_attack = DinosaurAttackScene.instantiate();
			get_parent().add_child(dinosaur_attack);
			dinosaur_attack.add_to_group('dinosaurAttack');
			var target_direction = Vector2(1,1).normalized();
			target_direction = target_direction.rotated ( deg_to_rad(360/16) * i);
			dinosaur_attack.global_position = position;
			dinosaur_attack.velocity = target_direction * constants.DINOSAUR_ATTACK_SPEED;
			i = i + 1;
		
		$DinosaurAttackTimer.start(constants.DINOSAUR_ATTACK_DELAY);
		$AudioStreamDinosaurAttack.play();
			
	if state==RAMPAGING && $DinosaurSurvivalTimer.time_left == 0:
		queue_free();
