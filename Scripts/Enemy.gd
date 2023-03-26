extends CharacterBody2D

const EnemyAttackScene = preload("res://Scenes/EnemyAttack.tscn");
const EnemyTrapScene = preload("res://Scenes/EnemyTrap.tscn");

enum {
    SPAWNING,
    WANDER,
    DYING
}

var state = SPAWNING;
var enemy_type;
var enemy_speed;
var enemy_health;

@onready var screen_size = get_viewport_rect().size

func _ready():
    var mob_types = ['knight','knight', 'wizard','wizard', 'rogue','rogue','necromancer'];
    enemy_type = mob_types[randi() % mob_types.size()]
    $AnimatedSprite2D.animation = enemy_type + str('-run')
    $CollisionShape2D.disabled = true;
    
    if enemy_type == 'necromancer':
        $AnimatedSprite2D.offset = Vector2(0,-20);
        enemy_speed = constants.ENEMY_NECROMANCER_SPEED;
        enemy_health = constants.ENEMY_NECROMANCER_HEALTH;
    else:
        enemy_speed = constants.ENEMY_SPEED;
        enemy_health = constants.ENEMY_HEALTH;
    
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

                if enemy_type == 'necromancer':
                    $AttackTimer.start(randf_range(constants.ENEMY_NECROMANCER_ATTACK_MINIMUM_SECONDS,constants.ENEMY_NECROMANCER_ATTACK_MAXIMUM_SECONDS));
                else:
                    $AttackTimer.start(randf_range(constants.ENEMY_ATTACK_MINIMUM_SECONDS,constants.ENEMY_ATTACK_MAXIMUM_SECONDS));
                $TrapTimer.start(randf_range(constants.ENEMY_TRAP_MINIMUM_SECONDS,constants.ENEMY_TRAP_MAXIMUM_SECONDS));

        WANDER:
            #print("WANDER!!");
            
            if $FlashHitTimer.time_left == 0:
                set_modulate(Color(1,1,1,1));
            
            if $StateTimer.time_left == 0:
                state = WANDER;
                
                match enemy_type:
                    "knight":
                        # Knights and Necromancers - chase the player.
                        var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                        velocity = target_direction * enemy_speed;
                        $StateTimer.start(randf_range(constants.ENEMY_CHASE_REORIENT_MINIMUM_SECONDS,
                                                    constants.ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS));
                    "necromancer":
                        # Necromancer - Move towards nearest fish if present
                        var target_direction;
                        
                        var fish_points = get_tree().get_nodes_in_group("fishGroup");
                        
                        if fish_points.size():
                            var nearest_fish = fish_points[0];
                        
                            for single_fish in fish_points:
                                if single_fish.global_position.distance_to(global_position) < nearest_fish.global_position.distance_to(global_position):
                                        nearest_fish = single_fish
                            
                            target_direction = (nearest_fish.global_position - global_position).normalized();
                        else:
                            # No fish? Default to heading towards player.
                            target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                        
                        velocity = target_direction * enemy_speed;
                        $StateTimer.start(randf_range(constants.ENEMY_CHASE_REORIENT_MINIMUM_SECONDS,
                                                    constants.ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS));
                    _:
                        # Anything else.
                        $StateTimer.start(randf_range(constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MINIMUM_SECONDS,
                                                    constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MAXIMUM_SECONDS));
                        velocity = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * enemy_speed;
        DYING:
            if $FlashHitTimer.time_left == 0:
                set_modulate(Color(1,1,1,1));
                
            if $StateTimer.time_left == 0:
                self.queue_free();
            
    var collision = move_and_collide(velocity * delta);	
    
    if velocity.x > 0:
        $AnimatedSprite2D.set_flip_h(false);
    
    if velocity.x < 0:
        $AnimatedSprite2D.set_flip_h(true);	
            
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
            
        if enemy_type == 'necromancer':
            # Spiral attack pattern.
            var i = 1;
            while (i <= 16):
                var enemy_attack = EnemyAttackScene.instantiate();
                get_parent().add_child(enemy_attack);
                enemy_attack.add_to_group('enemyAttack');
                var target_direction = Vector2(1,1).normalized();
                target_direction = target_direction.rotated ( deg_to_rad(360.0/16.0) * i);
                enemy_attack.global_position = position;
                enemy_attack.velocity = target_direction * enemy_attack.enemy_attack_speed;
                i = i + 1;
            
            $AttackTimer.start(randf_range(constants.ENEMY_NECROMANCER_ATTACK_MINIMUM_SECONDS,constants.ENEMY_NECROMANCER_ATTACK_MAXIMUM_SECONDS));
                
            
    if $TrapTimer.time_left == 0 && state == WANDER:
        if enemy_type == 'rogue':
            var enemy_trap = EnemyTrapScene.instantiate();
            get_parent().add_child(enemy_trap);
            enemy_trap.add_to_group('enemyTrap');
            enemy_trap.global_position = position;
            
            $TrapTimer.start(randf_range(constants.ENEMY_TRAP_MINIMUM_SECONDS,constants.ENEMY_TRAP_MAXIMUM_SECONDS));
        
    if collision:		
        if enemy_type == 'necromancer' && collision.get_collider().name.contains('Fish'):
            var collided_with = collision.get_collider();
            collided_with.get_node('.')._death(1);
            $AudioStreamPlayerFishSplat.play();
        else:		
            velocity = velocity.bounce(collision.get_normal());
    
func _death():
    if state != DYING:
        enemy_health = enemy_health - 1;
        
        set_modulate(Color(10,10,10,10));
        $FlashHitTimer.start()
        
        if enemy_health <=0 :
            $CollisionShape2D.set_deferred("disabled", true)
            velocity = Vector2(0,0);
            $AnimatedSprite2D.animation = enemy_type + str('-death');
            $AudioStreamPlayer.play();
            $StateTimer.start(2);
            state = DYING;
            
            var enemy_killed_score = 0;
            if enemy_type == 'necromancer':
                enemy_killed_score = constants.KILL_ENEMY_NECROMANCER_SCORE;
            else:
                enemy_killed_score = constants.KILL_ENEMY_SCORE;
        
            get_parent()._on_enemy_update_score(enemy_killed_score,global_position);
        else:
            $AnimatedSprite2D.animation = enemy_type + str('-hit');
            await($AnimatedSprite2D.animation_finished);
            $AnimatedSprite2D.animation = enemy_type + str('-run');
            $AnimatedSprite2D.play();
