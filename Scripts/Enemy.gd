extends CharacterBody2D

const EnemyAttackScene = preload("res://Scenes/EnemyAttack.tscn");
const EnemyTrapScene = preload("res://Scenes/EnemyTrap.tscn");

enum {
    SPAWNING,
    WANDER,
    DYING
}

var state = SPAWNING
var enemy_type
var enemy_speed
var enemy_health
var enemy_score
var attack_timer_min
var attack_timer_max
var attack_type
var trap_timer_min
var trap_timer_max
var stored_modulate;
var hit_to_be_processed;
var ai_mode = ''
var ai_mode_setting = ''
var initial_direction = 0
var enemy_is_split = false
var instant_spawn = false

func _ready():
    pass
    
func spawn_random():
    var mob_types
    
    # Determine spawn list for this wave.
    for local_wave_number in constants.ENEMY_SPAWN_WAVE_CONFIGURATION:
        if get_parent().wave_number >= local_wave_number: 
            mob_types = constants.ENEMY_SPAWN_WAVE_CONFIGURATION[local_wave_number] 

    enemy_type = mob_types[randi() % mob_types.size()]
    spawn_specific(enemy_type)

func spawn_specific(enemy_type_in):
    enemy_type = enemy_type_in
    
    $AnimatedSprite2D.animation = enemy_type + str('-run')
    
    var enemy_settings = constants.ENEMY_SETTINGS[enemy_type_in]
    enemy_speed = enemy_settings[0]
    enemy_health = enemy_settings[1]
    ai_mode_setting = enemy_settings[2]
    enemy_score = enemy_settings[3]
    attack_timer_min = enemy_settings[4]
    attack_timer_max = enemy_settings[5]
    attack_type = enemy_settings[6]
    trap_timer_min = enemy_settings[7]
    trap_timer_max = enemy_settings[8]
    
    # Special settings for necromancer.
    match enemy_type:
        'necromancer':
            $AnimatedSprite2D.offset = Vector2(0,-25)
            $CollisionShape2D.scale = Vector2(1.5, 1.5)
            set_collision_mask_value(7,true)
    
    # Increase enemy speed as waves progress.
    var i=1
    while i <= get_parent().wave_number - 1:
        enemy_speed = enemy_speed + int( (constants.ENEMY_SPEED_WAVE_PERCENTAGE_MULTIPLIER / enemy_speed)*100 )
        i+=1
    
    if !instant_spawn:
        $StateTimer.start();
    
    if ai_mode == "":
        ai_mode = ai_mode_setting
    
    if ai_mode == 'SPAWN_OUTWARDS':
        $SpawnOutwardsTimer.start()
    
    if enemy_is_split:
        scale = constants.ENEMY_SPLIT_SIZE
        enemy_speed = enemy_speed * constants.ENEMY_SPLIT_SPEED_MULTIPLIER
    
    set_modulate(Color(0,0,0,0));
    hit_to_be_processed = false
    $SpawnParticles.emitting = true

func set_ai_mode(ai_mode_in):
    ai_mode = ai_mode_in
    
func set_initial_direction(initial_direction_in):
    initial_direction = initial_direction_in
    
    if initial_direction.x < 0:
        $AnimatedSprite2D.set_flip_h(true)
    
func set_instant_spawn(spawn):
    instant_spawn = spawn
    
func set_enemy_is_split(is_split):
    enemy_is_split = is_split

func _physics_process(delta):
    set_modulate(lerp(get_modulate(), Color(1,1,1,1), 0.02));
    
    match state:
        SPAWNING:
            velocity = Vector2(0,0);
            
            if $FlashHitTimer.time_left == 0 and hit_to_be_processed:
                set_modulate(stored_modulate);
                hit_to_be_processed = false
                
            if $StateTimer.time_left == 0:
                $SpawnParticles.emitting = false
                state = WANDER;
                $AnimatedSprite2D.play();
                               
                set_collision_mask_value(1,true)    # Allow player collisions.
                set_collision_layer_value(3,true)   # Identify as an Enemy

                if attack_timer_min:
                    $AttackTimer.start(randf_range(attack_timer_min, attack_timer_max));
                    
                if trap_timer_min:
                    $TrapTimer.start(randf_range(trap_timer_min, trap_timer_max));

        WANDER:
            if $FlashHitTimer.time_left == 0:
                set_modulate(Color(1,1,1,1));
            
            if $StateTimer.time_left == 0:
                match ai_mode:
                    # Keep running until enemy hits a wall.
                    'DEFERRED_UNTIL_WALL':
                        velocity = initial_direction * (enemy_speed * constants.ENEMY_SPEED_DEFERRED_AI_MULTIPLIER)
                        
                    # (For mini skeletons) - Spawns outwards. Then will switch to CHASE after timer expires.
                    'SPAWN_OUTWARDS':
                        velocity = initial_direction * (enemy_speed * constants.ENEMY_SPEED_DEFERRED_AI_MULTIPLIER)
                        
                        if $SpawnOutwardsTimer.time_left==0:
                            ai_mode='CHASE'
                        
                    # Pursue the player.
                    'CHASE':
                        var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                        velocity = target_direction * enemy_speed;
                        $StateTimer.start(randf_range(constants.ENEMY_CHASE_REORIENT_MINIMUM_SECONDS,
                                                    constants.ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS));
                    
                    # 1. Try and eat fish
                    # 2. Pursue player.                            
                    'FISH':
                        var target_direction;
                        
                        var fish_points = get_tree().get_nodes_in_group("fishGroup");
                        
                        # In Pacifist mode, Necros do not go after fish.
                        if fish_points.size() and get_parent().game_mode == 'ARCADE':
                            var nearest_fish = fish_points[0];
                        
                            for single_fish in fish_points:
                                if single_fish.global_position.distance_to(global_position) < nearest_fish.global_position.distance_to(global_position):
                                        nearest_fish = single_fish
                            
                            target_direction = (nearest_fish.global_position - global_position).normalized();
                            velocity = target_direction * enemy_speed;
                            $StateTimer.start(randf_range(constants.ENEMY_CHASE_REORIENT_MINIMUM_SECONDS,
                                                        constants.ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS));
                        else:
                            # Pacifist mode.
                            $StateTimer.start(randf_range(constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MINIMUM_SECONDS,
                                                    constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MAXIMUM_SECONDS));
                            velocity = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * enemy_speed;
                            
                    'WANDER':        
                            # Wander around a bit randomly.
                            $StateTimer.start(randf_range(constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MINIMUM_SECONDS,
                                                        constants.ENEMY_DEFAULT_CHANGE_DIRECTION_MAXIMUM_SECONDS));
                            velocity = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized() * enemy_speed;
                            
                
                # OVERRIDE AI - Always chase the player when wave population is low.   
                if get_parent().enemies_left_this_wave <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW:
                    var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                    
                    if (get_parent().enemies_left_this_wave <= constants.ENEMY_ALL_CHASE_WHEN_POPULATION_LOW):
                        velocity = target_direction * (enemy_speed * constants.ENEMY_SPEED_POPULATION_LOW_MULTIPLIER)
                    else:
                        velocity = target_direction * enemy_speed;
                    
                    $StateTimer.start(randf_range(constants.ENEMY_CHASE_REORIENT_MINIMUM_SECONDS,
                                                constants.ENEMY_CHASE_REORIENT_MAXIMUM_SECONDS));
                                                                                
        DYING:
            if $FlashHitTimer.time_left == 0:
                set_modulate(Color(1,1,1,1));
                
            if $DeathParticlesTimer.time_left == 0:
                $DeathParticles.emitting = false
                
            if $StateTimer.time_left == 0:
                self.queue_free();
            
    var collision = move_and_collide(velocity * delta);	
    
    if velocity.x > 0:
        $AnimatedSprite2D.set_flip_h(false);
    
    if velocity.x < 0:
        $AnimatedSprite2D.set_flip_h(true);	
            
    if $AttackTimer.time_left == 0 && state == WANDER && attack_timer_min:
        match attack_type:
            'STANDARD':
                var enemy_attack = EnemyAttackScene.instantiate();
                get_parent().add_child(enemy_attack);
                enemy_attack.add_to_group('enemyAttack');
                
                var target_direction = (get_parent().get_node("Player").global_position - global_position).normalized();
                
                # We don't want enemies to always be a perfect shot.
                target_direction = target_direction.rotated( deg_to_rad(randf_range(0,constants.ENEMY_ATTACK_ARC_DEGREES)));
                
                enemy_attack.global_position = position;

                enemy_attack.velocity = target_direction * enemy_attack.enemy_attack_speed;
            
            'SPIRAL':
                # Spiral attack pattern.
                var i = 1;
                while (i <= 16):
                    var enemy_attack = EnemyAttackScene.instantiate()
                    get_parent().add_child(enemy_attack);
                    enemy_attack.add_to_group('enemyAttack')
                    var target_direction = Vector2(1,1).normalized();
                    target_direction = target_direction.rotated ( deg_to_rad(360.0/16.0) * i)
                    enemy_attack.global_position = position;
                    enemy_attack.velocity = target_direction * enemy_attack.enemy_attack_speed
                    i = i + 1;
            
        $AttackTimer.start(randf_range(attack_timer_min, attack_timer_max))
                  
    if $TrapTimer.time_left == 0 && state == WANDER && trap_timer_min:
        var enemy_trap = EnemyTrapScene.instantiate();
        get_parent().add_child(enemy_trap);
        enemy_trap.add_to_group('enemyTrap');
        enemy_trap.global_position = position;
        
        $TrapTimer.start(randf_range(trap_timer_min, trap_timer_max))
        
    if collision:
        if enemy_type == 'necromancer' && collision.get_collider().name.contains('Fish') && get_parent().game_mode == 'ARCADE':
            var collided_with = collision.get_collider()
            collided_with.get_node('.')._death(1)
            $AudioStreamPlayerFishSplat.play()
        else:
            if collision.get_collider().name == 'Player':
                var collided_with = collision.get_collider()
                collided_with._player_hit()
                _death('PLAYER-BODY')
            else:
                # Hit a wall? Ensure AI mode is standard.
                velocity = velocity.bounce(collision.get_normal())
                ai_mode=ai_mode_setting
    
func _death(death_source):
    if state == SPAWNING && !constants.ENEMY_ALLOW_DAMAGE_WHEN_SPAWNING:
        return
    
    if state != DYING:
        enemy_health = enemy_health - 1;
        
        hit_to_be_processed = true
        
        if enemy_health <=0 :
            $CollisionShape2D.set_deferred("disabled", true)
            velocity = Vector2(0,0);
            $AnimatedSprite2D.animation = enemy_type + str('-death');
            $AnimatedSprite2D.play()
            $AudioStreamPlayer.play();
            $StateTimer.start(2);
            $SpawnParticles.emitting = false
            $DeathParticles.emitting = true
            $DeathParticlesTimer.start()
            state = DYING;
            
            var actual_scored = get_parent()._on_enemy_update_score(enemy_score,global_position,death_source,enemy_type,enemy_is_split)
            
            score_label_animation(str(actual_scored))
            
            if get_parent().game_mode == 'ARCADE' && (get_parent().dropped_items_on_screen < constants.ARCADE_MAXIMUM_DROPPED_ITEMS_ON_SCREEN):
                leave_behind_item()
        else:
            stored_modulate = get_modulate()
            set_modulate(Color(10,10,10,10));
            $FlashHitTimer.start()
            
func leave_behind_item():
    var percentage_calc  = (get_parent().get_node('Player').upgrades['LOOT LOVER'][0] * 10.0) / 100.0
    var leave_percentage = constants.ENEMY_LEAVE_BEHIND_ITEM_PERCENTAGE + (percentage_calc * constants.ENEMY_LEAVE_BEHIND_ITEM_PERCENTAGE)
    
    if randi_range(1,100) <= leave_percentage:
        var item = get_parent().item_scene.instantiate()
        get_parent().add_child(item)
        item.spawn_random(true)
        item.set_source('DROPPED')
        item.get_node('.').set_position(position)
        item.add_to_group('itemGroup')
        get_parent().dropped_items_on_screen += 1

func score_label_animation(label_text):
    var new_label = $ScoreLabel.duplicate()
    add_child(new_label)
    
    new_label.set_modulate(Color(1,1,1,1));
    new_label.text = label_text
    new_label.visible = true
    
    # Text should move upwards slightly.
    var target_position = new_label.position
    target_position.y += -50
    
    var tween = get_tree().create_tween()
    tween.set_parallel()
    tween.tween_property(new_label, "modulate", Color(0,0,0,0), 2)
    tween.tween_property(new_label, "position", target_position, 2)
    tween.tween_callback(new_label.queue_free).set_delay(2)
    
func is_enemy_alive():
    if state == WANDER:
        return true
    else:
        return false
