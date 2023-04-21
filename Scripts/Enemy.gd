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
var stored_modulate;
var hit_to_be_processed;

@onready var screen_size = get_viewport_rect().size

func _ready():
    var mob_types = ['knight','knight', 'wizard','wizard', 'rogue','rogue','necromancer'];
    enemy_type = mob_types[randi() % mob_types.size()]
    $AnimatedSprite2D.animation = enemy_type + str('-run')
    
    if enemy_type == 'necromancer':
        $AnimatedSprite2D.offset = Vector2(0,-25)
        $CollisionShape2D.scale = Vector2(1.5, 1.5)
        enemy_speed = constants.ENEMY_NECROMANCER_SPEED;
        enemy_health = constants.ENEMY_NECROMANCER_HEALTH;
    else:
        enemy_speed = constants.ENEMY_SPEED;
        enemy_health = constants.ENEMY_HEALTH;
        
    var i=1
    while i <= get_parent().wave_number - 1:
        enemy_speed = enemy_speed + int( (constants.ENEMY_SPEED_WAVE_PERCENTAGE_MULTIPLIER / enemy_speed)*100 )
        i+=1
    
    $StateTimer.start();
    
    set_modulate(Color(0,0,0,0));
    hit_to_be_processed = false

func _physics_process(delta):
    set_modulate(lerp(get_modulate(), Color(1,1,1,1), 0.02));
    
    match state:
        SPAWNING:
            velocity = Vector2(0,0);
            
            if $FlashHitTimer.time_left == 0 and hit_to_be_processed:
                set_modulate(stored_modulate);
                #set_modulate(lerp(get_modulate(), Color(1,1,1,1), 0.02));
                hit_to_be_processed = false
                
            if $StateTimer.time_left == 0:
                state = WANDER;
                $AnimatedSprite2D.play();
                               
                set_collision_mask_value(1,true); # Allow player collisions.

                if enemy_type == 'necromancer':
                    $AttackTimer.start(randf_range(constants.ENEMY_NECROMANCER_ATTACK_MINIMUM_SECONDS,constants.ENEMY_NECROMANCER_ATTACK_MAXIMUM_SECONDS));
                else:
                    $AttackTimer.start(randf_range(constants.ENEMY_ATTACK_MINIMUM_SECONDS,constants.ENEMY_ATTACK_MAXIMUM_SECONDS));
                $TrapTimer.start(randf_range(constants.ENEMY_TRAP_MINIMUM_SECONDS,constants.ENEMY_TRAP_MAXIMUM_SECONDS));

        WANDER:
            if $FlashHitTimer.time_left == 0:
                set_modulate(Color(1,1,1,1));
            
            if $StateTimer.time_left == 0:
                state = WANDER;
                
                match enemy_type:
                    "knight":
                        # Knights
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
                            velocity = target_direction * enemy_speed;
                            $StateTimer.start(randf_range(constants.ENEMY_CHASE_REORIENT_MINIMUM_SECONDS,
                                                        constants.ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS));
                        else:
                            #target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                            # If no fish left, go into normal wander.
                            $StateTimer.start(randf_range(constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MINIMUM_SECONDS,
                                                    constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MAXIMUM_SECONDS));
                            velocity = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * enemy_speed;
                            
                    _:
                        # Anything else.
                        $StateTimer.start(randf_range(constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MINIMUM_SECONDS,
                                                    constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MAXIMUM_SECONDS));
                        velocity = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * enemy_speed;
                        
                # OVERRIDE when only a limited number of enemies left
                # Behaviour: Chase player.
                if get_parent().enemies_left_this_wave <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW:
                    var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                    velocity = target_direction * enemy_speed;
                    $StateTimer.start(randf_range(constants.ENEMY_CHASE_REORIENT_MINIMUM_SECONDS,
                                                constants.ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS));
                                                
                                                
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
            if collision.get_collider().name == 'Player':
                var collided_with = collision.get_collider();
                collided_with._player_hit();
                _death()
            else:
                velocity = velocity.bounce(collision.get_normal());
    
func _death():
    if state != DYING:
        enemy_health = enemy_health - 1;
        
        hit_to_be_processed = true
        stored_modulate = get_modulate()
        set_modulate(Color(10,10,10,10));
        $FlashHitTimer.start()
        
        if enemy_health <=0 :
            $CollisionShape2D.set_deferred("disabled", true)
            velocity = Vector2(0,0);
            $AnimatedSprite2D.animation = enemy_type + str('-death');
            $AnimatedSprite2D.play()
            $AudioStreamPlayer.play();
            $StateTimer.start(2);
            state = DYING;
            
            var enemy_killed_score = 0;
            if enemy_type == 'necromancer':
                enemy_killed_score = constants.KILL_ENEMY_NECROMANCER_SCORE;
            else:
                enemy_killed_score = constants.KILL_ENEMY_SCORE;
        
            get_parent()._on_enemy_update_score(enemy_killed_score,global_position)
            
            leave_behind_item()
            
func leave_behind_item():
    var leave_percentage = constants.ENEMY_LEAVE_BEHIND_ITEM_PERCENTAGE + (get_parent().get_node('Player').upgrades['LOOT LOVER'][0] * 10)

    print ("Leave percentage = " + str(leave_percentage))
    
    if randi_range(1,100) < leave_percentage:
        var item = get_parent().item_scene.instantiate()
        get_parent().add_child(item)
        item.spawn_random()
        item.get_node('.').set_position(position)
        item.add_to_group('itemGroup')
