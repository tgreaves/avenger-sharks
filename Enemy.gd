extends CharacterBody2D

const EnemyAttackScene = preload("res://EnemyAttack.tscn");
const EnemyTrapScene = preload("res://EnemyTrap.tscn");

enum {
	SPAWNING,
	WANDER,
	DYING
}

var state = SPAWNING;
var enemy_type;

@onready var screen_size = get_viewport_rect().size

func _ready():
	var mob_types = ['knight','wizard','rogue']
	enemy_type = mob_types[randi() % mob_types.size()]
	$AnimatedSprite2D.animation = enemy_type + str('-run')
	$CollisionShape2D.disabled = true;
	
	$StateTimer.start();
	
	set_modulate(Color(0,0,0,0));

func _physics_process(delta):
	set_modulate(lerp(get_modulate(), Color(1,1,1,1), 0.02));
	
	match state:
		SPAWNING:
			velocity = Vector2(0,0);
			
			if $StateTimer.time_left == 0:
				state = WANDER;
				$AnimatedSprite2D.play();
				$CollisionShape2D.disabled = false;
				$AttackTimer.start(randf_range(constants.ENEMY_ATTACK_MINIMUM_SECONDS,constants.ENEMY_ATTACK_MAXIMUM_SECONDS));
				$TrapTimer.start(randf_range(constants.ENEMY_TRAP_MINIMUM_SECONDS,constants.ENEMY_TRAP_MAXIMUM_SECONDS));
				#$StateTimer.start(float(2));			
		WANDER:
			#print("WANDER!!");
			if $StateTimer.time_left == 0:
				state = WANDER;
				
				if enemy_type == 'knight':
					# Knights - chase the player.
					var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
					velocity = target_direction * constants.ENEMY_SPEED;
					$StateTimer.start(randf_range(1,1.5));
				else:
					$StateTimer.start(randf_range(1,5));
					velocity = Vector2(randf_range(-1,1), randf_range(-1,1)) * constants.ENEMY_SPEED;
		DYING:
			if $StateTimer.time_left == 0:
				self.queue_free();
			
	var collision = move_and_collide(velocity * delta);	
	
	if velocity.x > 0:
		$AnimatedSprite2D.set_flip_h(false);
	
	if velocity.x < 0:
		$AnimatedSprite2D.set_flip_h(true);	
			
			
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
	
	if $AttackTimer.time_left == 0 && state == WANDER:
		
		if enemy_type == 'wizard':
			var enemy_attack = EnemyAttackScene.instantiate();
			get_parent().add_child(enemy_attack);
			enemy_attack.add_to_group('enemyAttack');
			
			var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
			
			# We don't want enemies to always be a perfect shot.
			target_direction = target_direction.rotated( deg_to_rad(randf_range(0,constants.ENEMY_ATTACK_ARC_DEGREES)));
			
			enemy_attack.global_position = position;

			enemy_attack.velocity = target_direction * enemy_attack.enemy_attack_speed;
			
			$AttackTimer.start(randf_range(constants.ENEMY_ATTACK_MINIMUM_SECONDS,constants.ENEMY_ATTACK_MAXIMUM_SECONDS));
			
	if $TrapTimer.time_left == 0 && state == WANDER:
		if enemy_type == 'rogue':
			print ("ROGUE ATTACK");
			var enemy_trap = EnemyTrapScene.instantiate();
			get_parent().add_child(enemy_trap);
			enemy_trap.add_to_group('enemyTrap');
			enemy_trap.global_position = position;
			
			$TrapTimer.start(randf_range(constants.ENEMY_TRAP_MINIMUM_SECONDS,constants.ENEMY_TRAP_MAXIMUM_SECONDS));
		
	if collision:
		print ("Enemy collision");
		velocity = velocity.bounce(collision.get_normal());
	
func _death():
	if state != DYING:
		$CollisionShape2D.set_deferred("disabled", true)
		velocity = Vector2(0,0);
		$AnimatedSprite2D.animation = enemy_type + str('-death');
		$AudioStreamPlayer.play();
		$StateTimer.start(2);
		#$AttackTimer.stop();
		state = DYING;
	
		get_parent()._on_enemy_update_score();
