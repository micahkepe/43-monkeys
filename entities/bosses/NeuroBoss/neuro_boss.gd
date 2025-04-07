extends CharacterBody2D
## The NeuroBoss is a powerful enemy that can manipulate bananas and control monkeys.

@export var max_health: float = 75.0
@export var move_speed: float = 130.0
@export var proximity_threshold: float = 50.0 # How close to target before picking new one
@export var min_wait_time: float = 0.5
@export var max_wait_time: float = 2.0
@export var avoid_distance: float = 100.0
@export var melee_damage: int = 2
@export var min_attack_interval: float = 3.0
@export var max_attack_interval: float = 6.0
@export var special_ability_cooldown: float = 12.0
@export var max_caught_bananas: int = 5
@export var banana_orbit_radius: float = 80.0
@export var banana_orbit_speed: float = 2.0
@export var mind_control_range: float = 250.0
@export var max_controlled_monkeys: int = 3
@export var mind_control_duration: float = 8.0
@export var melee_attack_chance: float = 0.3
@export var banana_throw_chance: float = 0.4
@export var mind_control_chance: float = 0.2
@export var psychic_push_chance: float = 0.1
@export var psychic_push_force: float = 500.0
@export var psychic_push_range: float = 200.0

const STUCK_THRESHOLD: float = 5.0
const SIMPLE_MOVEMENT_DURATION: float = 5.0
const BANANA_THROW_SPEED: float = 550.0 # Speed for thrown bananas

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar = $HealthBar
@onready var banana_detection_area: Area2D = $BananaDetectionArea
@onready var hitbox: Area2D = $Hitbox

# Timers - declare them first, will create in _ready
var attack_timer: Timer
var special_ability_timer: Timer
var navigation_timer: Timer
var debug_timer: Timer

var current_health: float
var current_target: Vector2 = Vector2.ZERO
var last_known_direction: Vector2 = Vector2.DOWN # Default direction
var is_attacking: bool = false
var in_special_ability: bool = false
var is_dead: bool = false
var caught_bananas: Array = []
var controlled_monkeys: Array = []
var banana_rotation: float = 0.0
var banana_throw_cooldown: float = 0.0
var last_direction_suffix: String = "down" # Used to track the direction suffix for animations

# Debug variables
var debug_can_catch_bananas: bool = true
var last_position_check_time: float = 0.0 # Time tracking for position checks

# Stuck detection
var stuck_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var simple_movement_mode: bool = false
var simple_movement_timer: float = 0.0

# Active phases (can be modified based on health)
var phases_active = {
	"catch_bananas": true,
	"mind_control": true,
	"melee_attack": true,
	"psychic_push": true,
	"throw_bananas": true
}

@onready var taser_scene = preload("res://projectiles/BananaBoomerang/banana_boomerang.tscn")

func _ready() -> void:
	print("NeuroBoss: Initializing...")
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	# Make sure we have a valid AnimatedSprite2D reference
	if !_animated_sprite:
		_animated_sprite = $AnimatedSprite2D
		if !_animated_sprite:
			printerr("NeuroBoss: Could not find AnimatedSprite2D node!")
			return
			
	# Print all available animations for debugging
	if _animated_sprite && _animated_sprite.sprite_frames:
		var animations = _animated_sprite.sprite_frames.get_animation_names()
		print("NeuroBoss: Available animations: ", animations)
	else:
		printerr("NeuroBoss: No sprite_frames found on AnimatedSprite2D!")
		return
	
	# Ensure animation_finished signal is properly connected
	if _animated_sprite.animation_finished.is_connected(Callable(self, "_on_animated_sprite_2d_animation_finished")):
		_animated_sprite.animation_finished.disconnect(Callable(self, "_on_animated_sprite_2d_animation_finished"))
	
	# Connect the signal
	_animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	print("NeuroBoss: Connected animation_finished signal from AnimatedSprite2D.")

	# Set initial animation
	play_animation("idle_down")
	print("NeuroBoss: Set initial animation to idle_down")

	# --- Collision Setup --- 
	collision_layer = 1 << 1 # Layer 2 
	collision_mask = 1 << 0  # Layer 1  

	# Hitbox Area setup
	if hitbox: 
		hitbox.collision_layer = 1 << 1 # Layer 2 
		hitbox.collision_mask = (1 << 2) | (1 << 3) | (1 << 4) # Layers 3, 4, 5 
		
		# Connect hitbox signals 
		if hitbox.body_entered.is_connected(Callable(self, "_on_hitbox_body_entered")): 
			hitbox.body_entered.disconnect(Callable(self, "_on_hitbox_body_entered")) 
		if hitbox.body_exited.is_connected(Callable(self, "_on_hitbox_body_exited")): 
			hitbox.body_exited.disconnect(Callable(self, "_on_hitbox_body_exited")) 
		if hitbox.area_entered.is_connected(Callable(self, "_on_hitbox_area_entered")): 
			hitbox.area_entered.disconnect(Callable(self, "_on_hitbox_area_entered")) 
			 
		hitbox.body_entered.connect(_on_hitbox_body_entered) 
		hitbox.body_exited.connect(_on_hitbox_body_exited) 
		hitbox.area_entered.connect(_on_hitbox_area_entered) 
	else: 
		printerr("NeuroBoss: Hitbox node not found!")  

	# Banana Detection Area setup
	if banana_detection_area: 
		banana_detection_area.collision_layer = 1 << 7 # Layer 8 
		banana_detection_area.collision_mask = 1 << 2  # Layer 3 (ProjectileProj) 
		
		# Connect banana detection area signal 
		if banana_detection_area.area_entered.is_connected(Callable(self, "_on_banana_detection_area_area_entered")): 
			banana_detection_area.area_entered.disconnect(Callable(self, "_on_banana_detection_area_area_entered")) 
		
		banana_detection_area.area_entered.connect(_on_banana_detection_area_area_entered) 
	else: 
		printerr("NeuroBoss: BananaDetectionArea node not found!") 

	# Create and configure timer nodes
	_setup_timers()

	# Initial state
	last_position = global_position
	
	# Move after initialization
	move_to_next_waypoint()

	print("NeuroBoss: Initialization complete.")

# Setup timers properly
func _setup_timers() -> void:
	# Attack Timer
	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	attack_timer.autostart = false
	add_child(attack_timer)
	attack_timer.timeout.connect(_choose_and_execute_attack)
	
	# Special Ability Timer
	special_ability_timer = Timer.new()
	special_ability_timer.name = "SpecialAbilityTimer"
	special_ability_timer.one_shot = true
	special_ability_timer.autostart = false
	add_child(special_ability_timer)
	special_ability_timer.timeout.connect(_execute_special_ability)
	
	# Navigation Timer
	navigation_timer = Timer.new()
	navigation_timer.name = "NavigationTimer"
	navigation_timer.one_shot = true
	navigation_timer.autostart = false
	add_child(navigation_timer)
	navigation_timer.timeout.connect(move_to_next_waypoint)
	
	# Debug Timer
	debug_timer = Timer.new()
	debug_timer.name = "DebugTimer"
	debug_timer.wait_time = 3.0
	debug_timer.one_shot = false
	debug_timer.autostart = true
	add_child(debug_timer)
	debug_timer.timeout.connect(_on_debug_timer_timeout)
	
	# Start timers after a short delay to ensure they're properly added to the tree
	call_deferred("_start_initial_timers")

# Start timers after being added to the tree
func _start_initial_timers() -> void:
	if is_instance_valid(attack_timer) and attack_timer.is_inside_tree():
		_start_random_attack_timer()
	
	if is_instance_valid(special_ability_timer) and special_ability_timer.is_inside_tree():
		_start_special_ability_timer()
	
	if is_instance_valid(debug_timer) and debug_timer.is_inside_tree() and not debug_timer.is_stopped():
		debug_timer.start()

# Debug timer periodic function to report status and fix issues
func _on_debug_timer_timeout():
	# Log current state
	print("DEBUG: Status - Bananas:", caught_bananas.size(), 
		"Can catch:", debug_can_catch_bananas,
		"Cooldown:", banana_throw_cooldown)
	
	# Animation debugging
	if is_instance_valid(_animated_sprite):
		print("DEBUG: Current animation:", _animated_sprite.animation, 
			"| Playing:", _animated_sprite.is_playing(),
			"| Frame:", _animated_sprite.frame,
			"| is_attacking:", is_attacking,
			"| in_special_ability:", in_special_ability)
		
		# Check if the animation should be playing but isn't
		if !_animated_sprite.is_playing() and !is_dead:
			print("DEBUG: Animation not playing! Attempting to restart...")
			# Try to restart the current animation or switch to idle
			if _animated_sprite.animation != "":
				_animated_sprite.play()
			else:
				play_idle_animation()
	else:
		print("DEBUG: _animated_sprite is not valid!")
		  
	# Validate and fix bananas if needed
	validate_caught_bananas()

# Validate and fix caught bananas
func validate_caught_bananas():
	var valid_bananas = []
	var needs_cleanup = false
	
	for banana in caught_bananas:
		if is_instance_valid(banana) and banana.has_meta("caught_by_boss"):
			valid_bananas.append(banana)
		else:
			needs_cleanup = true
	
	if needs_cleanup:
		caught_bananas = valid_bananas
		print("DEBUG: Cleaned up invalid orbiting bananas, now have", caught_bananas.size())
	
	# If we think we're in throw mode but it's been too long, reset flag
	if not debug_can_catch_bananas and banana_throw_cooldown <= 0:
		debug_can_catch_bananas = true
		print("DEBUG: Force reset catch flag - was stuck")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Update cooldowns
	if banana_throw_cooldown > 0:
		banana_throw_cooldown -= delta
		if banana_throw_cooldown <= 0:
			print("DEBUG: Banana throw cooldown reset, can throw again")
			debug_can_catch_bananas = true  # Reset the flag to allow catching again

	# Update orbiting bananas if any
	if caught_bananas.size() > 0:
		update_banana_orbit(delta)

	# Stuck detection
	var should_be_moving = current_target != Vector2.ZERO
	var is_moving = velocity.length_squared() > 10.0
	
	if (should_be_moving && !is_moving) || (is_moving && !should_be_moving):
		stuck_timer += delta
		if stuck_timer > STUCK_THRESHOLD:
			print("NeuroBoss: Detected stuck! Force resetting.")
			stuck_timer = 0.0
			
			# Reset state
			is_attacking = false
			in_special_ability = false
			
			# Force new target
			move_to_next_waypoint()
	else:
		stuck_timer = 0.0

	# Movement logic if not in special state
	if not is_attacking and not in_special_ability:
		handle_movement(delta)

	# Always apply movement
	move_and_slide()
	
	# Update last_position after movement
	last_position = global_position

# Simplified animation playing function
func play_animation(anim_name: String) -> void:
	if is_dead or !is_instance_valid(_animated_sprite):
		return
	
	# Check if animation exists before trying to play it
	if _animated_sprite.sprite_frames.has_animation(anim_name):
		_animated_sprite.play(anim_name)
		print("NeuroBoss: Playing animation: ", anim_name)
		
		# Update direction tracking based on animation name
		if anim_name.ends_with("_up"):
			last_direction_suffix = "up"
		elif anim_name.ends_with("_down"):
			last_direction_suffix = "down"
		elif anim_name.ends_with("_left"):
			last_direction_suffix = "left"
		elif anim_name.ends_with("_right"):
			last_direction_suffix = "right"
	else:
		# Fallback to a default animation
		print("NeuroBoss: Animation not found: ", anim_name)
		if _animated_sprite.sprite_frames.has_animation("idle_" + last_direction_suffix):
			_animated_sprite.play("idle_" + last_direction_suffix)
		elif _animated_sprite.sprite_frames.has_animation("idle_down"):
			_animated_sprite.play("idle_down")

# Get animation name based on movement direction
func get_direction_animation(base_name: String, direction: Vector2) -> String:
	# Make sure direction is normalized
	if direction.length() > 0:
		direction = direction.normalized()
	else:
		# Default to current direction if no direction
		return base_name + "_" + last_direction_suffix

	# Compare absolute values to determine dominant direction
	if abs(direction.x) > abs(direction.y):
		# Horizontal movement
		if direction.x > 0:
			return base_name + "_right"
		else:
			return base_name + "_left"
	else:
		# Vertical movement
		if direction.y > 0:
			return base_name + "_down"
		else:
			return base_name + "_up"

# Play idle animation based on last direction
func play_idle_animation() -> void:
	if is_dead or is_attacking or in_special_ability:
		return
	play_animation("idle_" + last_direction_suffix)

func handle_movement(delta: float) -> void:
	if current_target == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta * 5)
		if !is_attacking && !in_special_ability:
			play_idle_animation()
		return

	var direction_to_target = (current_target - global_position).normalized()
	
	# Simple Obstacle Avoidance
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direction_to_target * avoid_distance, 1)
	var result = space_state.intersect_ray(query)

	var final_direction = direction_to_target
	if result and global_position.distance_to(result.position) < avoid_distance:
		final_direction = direction_to_target.slide(result.normal).normalized()

	# Set velocity and update last known direction
	velocity = final_direction * move_speed
	
	# Only update the last known direction if it's significant
	if final_direction.length() > 0.1:
		last_known_direction = final_direction
	
	# Update animation based on movement direction
	if !is_attacking && !in_special_ability:
		if velocity.length() > 10.0:
			var anim_name = get_direction_animation("walk", final_direction)
			play_animation(anim_name)
		else:
			play_idle_animation()

	# Check if reached target
	if global_position.distance_to(current_target) <= proximity_threshold:
		current_target = Vector2.ZERO
		velocity = Vector2.ZERO
		if !is_attacking && !in_special_ability:
			play_idle_animation()
		start_navigation_timer()

func move_to_next_waypoint() -> void:
	# Reset state flags
	is_attacking = false
	in_special_ability = false
	
	# Reset animation
	play_idle_animation()
	
	# Choose new waypoint
	current_target = choose_next_waypoint()
	print("NeuroBoss: New waypoint set:", current_target)

func choose_next_waypoint() -> Vector2:
	var player = find_player_node(get_tree().root)
	var target_pos = global_position # Default to current pos

	# Prioritize moving towards the player
	if player:
		var player_pos = player.global_position
		var dist_to_player = global_position.distance_to(player_pos)

		if dist_to_player > proximity_threshold * 3: # If far away, move closer
			target_pos = player_pos + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			print("NeuroBoss: Targeting player area (far).")
		elif dist_to_player < proximity_threshold * 1.5: # If too close, back away
			var direction_away = (global_position - player_pos).normalized()
			target_pos = global_position + direction_away * randf_range(100, 200)
			print("NeuroBoss: Targeting point away from player (close).")
		else: # Mid-range, choose a flanking or random nearby point
			var random_offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
			target_pos = global_position + random_offset
			print("NeuroBoss: Targeting random nearby point.")
	else: # No player, choose random point
		var random_offset = Vector2(randf_range(-300, 300), randf_range(-300, 300))
		target_pos = global_position + random_offset
		print("NeuroBoss: Targeting random distant point.")

	return target_pos

func start_navigation_timer() -> void:
	if is_instance_valid(navigation_timer) and navigation_timer.is_inside_tree():
		navigation_timer.wait_time = randf_range(min_wait_time, max_wait_time)
		navigation_timer.start()
		print("NeuroBoss: Waiting", navigation_timer.wait_time, "s before next move.")

func _start_random_attack_timer():
	if is_instance_valid(attack_timer) and attack_timer.is_inside_tree() and attack_timer.is_stopped():
		attack_timer.wait_time = randf_range(min_attack_interval, max_attack_interval)
		attack_timer.start()
		print("NeuroBoss: Next attack check in", attack_timer.wait_time, "s")

func _choose_and_execute_attack():
	if is_dead or is_attacking or in_special_ability:
		print("NeuroBoss: Cannot attack - busy or dead.")
		_start_random_attack_timer()
		return

	var player = find_player_node(get_tree().root)
	if not player:
		print("NeuroBoss: No player found, skipping attack.")
		_start_random_attack_timer()
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var chosen_attack = false

	# Debug - print throw conditions
	print("DEBUG: Throw conditions - caught_bananas:", caught_bananas.size(), 
		  "cooldown:", banana_throw_cooldown, 
		  "can_catch:", debug_can_catch_bananas)

	# Weighted random choice
	var rand_val = randf()
	var cumulative_chance = 0.0

	# Melee attack
	cumulative_chance += melee_attack_chance
	if phases_active["melee_attack"] and distance_to_player < proximity_threshold * 1.8 and rand_val <= cumulative_chance:
		print("NeuroBoss: Choosing Melee Attack.")
		perform_melee_attack()
		chosen_attack = true

	# Banana Throw
	cumulative_chance += banana_throw_chance
	if not chosen_attack and phases_active["throw_bananas"] and caught_bananas.size() > 0 and banana_throw_cooldown <= 0 and rand_val <= cumulative_chance:
		print("NeuroBoss: Choosing Banana Throw Attack.")
		throw_caught_bananas()
		chosen_attack = true

	# Mind Control
	cumulative_chance += mind_control_chance
	if not chosen_attack and phases_active["mind_control"] and rand_val <= cumulative_chance:
		print("NeuroBoss: Choosing Mind Control Attack.")
		perform_mind_control()
		chosen_attack = true

	# Psychic Push
	cumulative_chance += psychic_push_chance
	if not chosen_attack and phases_active["psychic_push"] and distance_to_player < psychic_push_range and rand_val <= cumulative_chance:
		print("NeuroBoss: Choosing Psychic Push Attack.")
		perform_psychic_push()
		chosen_attack = true

	# Default action if no attack chosen: Move towards player
	if not chosen_attack:
		print("NeuroBoss: No attack chosen, moving towards player.")
		current_target = player.global_position

	_start_random_attack_timer()

func perform_melee_attack():
	var player = find_player_node(get_tree().root)
	if not player: return

	is_attacking = true
	velocity = Vector2.ZERO
	
	# Determine direction to target for animation
	var target_dir = (player.global_position - global_position).normalized()
	last_known_direction = target_dir
	
	# Play slash animation based on direction
	var anim_name = get_direction_animation("slash", target_dir)
	play_animation(anim_name)
	
	# Schedule damage application
	get_tree().create_timer(0.3).timeout.connect(Callable(self, "_apply_melee_damage"))

func _apply_melee_damage():
	var targets = []
	var player = find_player_node(get_tree().root)
	
	# Add player if in range
	if player and global_position.distance_to(player.global_position) < proximity_threshold * 2.0:
		targets.append(player)
	
	# Add any troop members in range
	var troop_members = get_tree().get_nodes_in_group("troop")
	for troop in troop_members:
		if global_position.distance_to(troop.global_position) < proximity_threshold * 2.0:
			targets.append(troop)
	
	# Apply damage
	for target in targets:
		if target.has_method("take_damage"):
			print("NeuroBoss: Applying melee damage to", target.name)
			target.take_damage(melee_damage)

func throw_caught_bananas():
	if caught_bananas.is_empty():
		print("DEBUG: No bananas to throw!")
		return

	is_attacking = true
	in_special_ability = true
	velocity = Vector2.ZERO
	debug_can_catch_bananas = false # Stop catching during throw animation
	banana_throw_cooldown = 2.0 # Prevent immediate re-throw

	var player = find_player_node(get_tree().root)
	var target_dir = Vector2.ZERO
	if player:
		target_dir = (player.global_position - global_position).normalized()
	else:
		target_dir = last_known_direction
	
	# Play expand animation
	var anim_name = get_direction_animation("expand", target_dir)
	play_animation(anim_name)
	
	# Schedule banana throw
	get_tree().create_timer(0.3).timeout.connect(Callable(self, "_execute_banana_throw"))

func _execute_banana_throw():
	var projectiles_node = find_or_create_projectiles_node()
	var targets = get_tree().get_nodes_in_group("player")
	
	# Add troop monkeys as secondary targets if no player found
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("troop")

	print("DEBUG: Found targets:", targets.size())
	print("DEBUG: Current caught bananas:", caught_bananas.size())

	var bananas_to_throw_copy = caught_bananas.duplicate() # Work on a copy
	caught_bananas.clear() # Clear original immediately
	
	print("DEBUG: Bananas to throw:", bananas_to_throw_copy.size())

	for banana in bananas_to_throw_copy:
		if not is_instance_valid(banana):
			continue

		var target_node = null
		if not targets.is_empty():
			target_node = targets[randi() % targets.size()]
		
		if not target_node:
			continue # Skip if no targets left
		
		# Create a new taser projectile that LOOKS like a red banana
		var taser = taser_scene.instantiate()
		taser.global_position = global_position
		
		# Calculate direction to target
		var direction_to_target = (target_node.global_position - taser.global_position).normalized()
		
		# Set velocity and appearance - make it look like a red banana
		taser.velocity = direction_to_target * BANANA_THROW_SPEED
		taser.modulate = Color(1, 0.5, 0.5) # Red tint to indicate it's from boss
		
		# Keep the visual appearance of the banana
		if banana.get_node_or_null("AnimatedSprite2D") and taser.get_node_or_null("AnimatedSprite2D"):
			var banana_sprite = banana.get_node("AnimatedSprite2D")
			var taser_sprite = taser.get_node("AnimatedSprite2D")
			taser_sprite.sprite_frames = banana_sprite.sprite_frames
			taser_sprite.animation = banana_sprite.animation
		
		# Set metadata
		taser.set_meta("thrown_by_boss", true)
		taser.set_meta("friendly", false) # Not friendly to player
		taser.set_meta("owner", self)
		
		# Set collision properties for proper hitting
		taser.collision_layer = 1 << 2  # Layer 3 (Projectiles)
		taser.collision_mask = (1 << 3) | (1 << 4)  # Layers 4 (Troop) and 5 (Player)
		
		# Add the taser to the scene
		projectiles_node.add_child(taser)
		
		# Free the original banana
		if is_instance_valid(banana):
			banana.queue_free()

		print("NeuroBoss: Threw banana (as taser) at", target_node.name)
		await get_tree().create_timer(0.2).timeout
	
	# Reset the catching flag after completion with a delay
	await get_tree().create_timer(0.5).timeout
	debug_can_catch_bananas = true
	
	print("DEBUG: Finished throwing all bananas")
	
	# Reset animation lock after throw is complete
	in_special_ability = false
	is_attacking = false

func perform_mind_control():
	is_attacking = true
	in_special_ability = true
	velocity = Vector2.ZERO

	var anim_name = get_direction_animation("expand", last_known_direction)
	play_animation(anim_name)
	
	# Schedule mind control effect
	get_tree().create_timer(0.5).timeout.connect(Callable(self, "_execute_mind_control"))

func _execute_mind_control():
	var monkeys_in_range = []
	var troop_nodes = get_tree().get_nodes_in_group("troop")
	for monkey in troop_nodes:
		if not controlled_monkeys.has(monkey):
			if monkey.global_position.distance_to(global_position) <= mind_control_range:
				monkeys_in_range.append(monkey)

	if monkeys_in_range.size() > 0:
		monkeys_in_range.sort_custom(Callable(self, "sort_by_distance"))

		var control_count = min(monkeys_in_range.size(), max_controlled_monkeys - controlled_monkeys.size())
		print("NeuroBoss: Found", monkeys_in_range.size(), "potential monkeys, controlling up to", control_count)

		for i in range(control_count):
			take_control_of_monkey(monkeys_in_range[i])

		# Mind control duration
		if control_count > 0:
			get_tree().create_timer(mind_control_duration).timeout.connect(Callable(self, "release_all_controlled_monkeys"))

	# Reset animation lock
	in_special_ability = false
	is_attacking = false
	
	_start_special_ability_timer()

func perform_psychic_push():
	is_attacking = true
	velocity = Vector2.ZERO

	var anim_name = get_direction_animation("slash", last_known_direction)
	play_animation(anim_name)
	
	# Schedule psychic push effect
	get_tree().create_timer(0.2).timeout.connect(Callable(self, "_execute_psychic_push"))

func _execute_psychic_push():
	var bodies_to_push = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("troop")
	var pushed_count = 0
	for body in bodies_to_push:
		if body != self:
			if body.global_position.distance_to(global_position) <= psychic_push_range:
				var push_dir = (body.global_position - global_position).normalized()
				if body.has_method("apply_central_impulse"):
					body.apply_central_impulse(push_dir * psychic_push_force)
					pushed_count += 1
				elif "velocity" in body:
					body.velocity += push_dir * psychic_push_force * 0.5
					pushed_count += 1

	print("NeuroBoss: Pushed", pushed_count, "targets.")
	
	# Reset attack state
	is_attacking = false

func _start_special_ability_timer():
	if is_instance_valid(special_ability_timer) and special_ability_timer.is_inside_tree() and special_ability_timer.is_stopped():
		special_ability_timer.wait_time = special_ability_cooldown
		special_ability_timer.start()
		print("NeuroBoss: Next special ability check in", special_ability_timer.wait_time, "s")

func _execute_special_ability():
	if is_dead or is_attacking or in_special_ability:
		print("NeuroBoss: Cannot use special - busy or dead.")
		_start_special_ability_timer()
		return

	if randf() < 0.5 and phases_active["catch_bananas"]:
		perform_banana_catching_special()
	elif phases_active["mind_control"]:
		perform_mind_control()
	else:
		print("NeuroBoss: No special ability available/chosen.")
		_start_special_ability_timer()
		return

func perform_banana_catching_special():
	print("NeuroBoss: Activating Enhanced Banana Catching.")
	in_special_ability = true
	velocity = Vector2.ZERO

	var anim_name = get_direction_animation("expand", last_known_direction)
	play_animation(anim_name)

	# Temporarily boost detection area
	var original_scale = banana_detection_area.scale
	banana_detection_area.scale = original_scale * 2.0
	banana_detection_area.monitoring = true
	
	# Duration and reset
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(banana_detection_area):
			banana_detection_area.scale = original_scale
			banana_detection_area.monitoring = true
		
		print("NeuroBoss: Enhanced Banana Catching finished.")
		_start_special_ability_timer()
		
		# Reset flags
		in_special_ability = false
	)

func update_banana_orbit(delta: float):
	banana_rotation += banana_orbit_speed * delta

	var valid_bananas = []
	
	for i in range(caught_bananas.size()):
		var banana = caught_bananas[i]
		if is_instance_valid(banana):
			valid_bananas.append(banana)
			
			# Calculate orbit position
			var angle = banana_rotation + (TAU * i / caught_bananas.size())
			var target_offset = Vector2.RIGHT.rotated(angle) * banana_orbit_radius
			var target_position = global_position + target_offset

			var lerp_factor = clamp(banana.global_position.distance_to(target_position) / 100.0, 0.1, 0.3)
			banana.global_position = banana.global_position.lerp(target_position, lerp_factor)
			banana.rotation = angle + PI / 2 # Point outwards
			
			# Disable collisions
			if banana.collision_layer != 0 or banana.collision_mask != 0:
				banana.set_deferred("collision_layer", 0)
				banana.set_deferred("collision_mask", 0)
				
			# Disable Area2D
			var area = banana.get_node_or_null("Area2D")
			if area:
				area.set_deferred("monitoring", false)
				area.set_deferred("monitorable", false)
	
	# Replace with valid bananas
	if valid_bananas.size() != caught_bananas.size():
		caught_bananas = valid_bananas
		print("DEBUG: Cleaned up invalid orbiting bananas, now have", caught_bananas.size())

func catch_banana(banana):
	if banana == null or not is_instance_valid(banana):
		return
	
	# Skip if in throw mode
	if not debug_can_catch_bananas:
		print("DEBUG: Not catching banana - in throw mode")
		return
		
	# Skip if already caught
	if banana.has_meta("caught_by_boss"):
		print("DEBUG: Ignoring already caught banana in catch_banana")
		return
		
	# Skip boss-thrown bananas
	if banana.has_meta("thrown_by_boss"):
		print("DEBUG: Ignoring boss-thrown banana in catch_banana")
		return
	
	print("NeuroBoss: Catching banana:" + banana.name)
	banana.set_meta("caught_by_boss", true)
	call_deferred("_process_caught_banana", banana)

func _process_caught_banana(banana):
	if banana == null or not is_instance_valid(banana):
		return
	
	print("DEBUG: Processing caught banana:", banana.name)
	
	# Limit maximum caught bananas
	if caught_bananas.size() >= max_caught_bananas:
		print("DEBUG: Maximum caught bananas reached, removing oldest")
		if caught_bananas.size() > 0:
			var oldest = caught_bananas.pop_front()
			if is_instance_valid(oldest):
				oldest.queue_free()
	
	var original_position = banana.global_position
	
	# Add to caught bananas array
	if not caught_bananas.has(banana):
		caught_bananas.append(banana)
	
	# Disable collisions
	banana.set_deferred("collision_layer", 0)
	banana.set_deferred("collision_mask", 0)
	
	var banana_collision = banana.get_node_or_null("CollisionShape2D")
	if banana_collision:
		banana_collision.set_deferred("disabled", true)
	
	var banana_area = banana.get_node_or_null("Area2D")
	if banana_area:
		banana_area.set_deferred("monitoring", false)
		banana_area.set_deferred("monitorable", false)
		
		var area_collision = banana_area.get_node_or_null("CollisionShape2D")
		if area_collision:
			area_collision.set_deferred("disabled", true)
	
	# Reparent to boss
	if banana.get_parent():
		var original_parent = banana.get_parent()
		original_parent.remove_child(banana)
	
	add_child(banana)
	
	# Restore position
	banana.global_position = original_position
	
	# Reset appearance
	banana.modulate = Color(1, 1, 1)
	
	print("DEBUG: Banana successfully caught and processed")

func take_control_of_monkey(monkey: Node2D):
	if not is_instance_valid(monkey): return
	if controlled_monkeys.has(monkey): return

	print("NeuroBoss: Taking control of monkey:", monkey.name)
	controlled_monkeys.append(monkey)
	monkey.set_meta("controlled_by_boss", true)
	monkey.modulate = Color(1.0, 0.5, 0.5) # Red tint

	# Remove from player troop if possible
	var player = find_player_node(get_tree().root)
	if player and player.has_method("remove_monkey"):
		player.remove_monkey(monkey)

	# Reparent to boss
	if monkey.get_parent():
		monkey.get_parent().remove_child(monkey)
	add_child(monkey)

	# Add AI
	if monkey.has_method("set_ai_state"):
		monkey.set_ai_state("attack_player")
	else:
		var target_pos = player.global_position if player else global_position + Vector2.LEFT * 100
		if "target_position" in monkey: monkey.target_position = target_pos

func release_all_controlled_monkeys():
	print("NeuroBoss: Releasing", controlled_monkeys.size(), "monkeys.")
	var player = find_player_node(get_tree().root)
	var scene_root = get_tree().current_scene

	for monkey in controlled_monkeys:
		if is_instance_valid(monkey):
			monkey.remove_meta("controlled_by_boss")
			monkey.modulate = Color(1, 1, 1) # Reset color

			if monkey.get_parent() == self:
				remove_child(monkey)

			# Add back to scene root
			if scene_root:
				scene_root.add_child(monkey)

			# Try add back to player troop
			if player and player.has_method("add_monkey_to_swarm"):
				player.add_monkey_to_swarm(monkey)
			elif player:
				monkey.global_position = player.global_position + Vector2(randf_range(-50,50), randf_range(-50,50))

			# Reset monkey AI
			if monkey.has_method("set_ai_state"):
				monkey.set_ai_state("follow_player")

	controlled_monkeys.clear()

func sort_by_distance(a: Node2D, b: Node2D) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b): return false
	var dist_a = global_position.distance_squared_to(a.global_position)
	var dist_b = global_position.distance_squared_to(b.global_position)
	return dist_a < dist_b

func take_damage(amount: float):
	if is_dead: return

	current_health -= amount
	print("NeuroBoss: Took %.1f damage. Health: %.1f / %.1f" % [amount, current_health, max_health])

	if health_bar:
		health_bar.value = current_health

	if current_health <= 0:
		_die()
	else:
		modulate = Color(2, 0.5, 0.5) # Flash red
		get_tree().create_timer(0.1).timeout.connect(func(): modulate = Color(1, 1, 1))

func _die():
	if is_dead: return
	print("NeuroBoss: Dying...")
	is_dead = true

	# Stop everything
	set_physics_process(false)
	velocity = Vector2.ZERO
	if is_instance_valid(attack_timer): attack_timer.stop()
	if is_instance_valid(special_ability_timer): special_ability_timer.stop()
	if is_instance_valid(navigation_timer): navigation_timer.stop()
	if is_instance_valid(debug_timer): debug_timer.stop()

	if health_bar: health_bar.hide()
	collision_layer = 0
	collision_mask = 0
	if hitbox: hitbox.monitoring = false
	if banana_detection_area: banana_detection_area.monitoring = false

	# Release resources
	release_all_controlled_monkeys()
	for banana in caught_bananas:
		if is_instance_valid(banana): banana.queue_free()
	caught_bananas.clear()

	# Play death animation
	if _animated_sprite.sprite_frames.has_animation("die"):
		play_animation("die")
	elif _animated_sprite.sprite_frames.has_animation("die_" + last_direction_suffix):
		play_animation("die_" + last_direction_suffix)
	else:
		queue_free() # If no death animation, just free

func find_player_node(root: Node) -> Node:
	# Use get_nodes_in_group for efficiency
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0]

	# Fallback search
	if root.name == "Player" or root.is_in_group("player"): return root
	for child in root.get_children():
		var result = find_player_node(child)
		if result: return result
	return null

func find_or_create_projectiles_node() -> Node:
	var proj_node = get_tree().root.find_child("Projectiles", true, false)
	if not proj_node:
		print("NeuroBoss: Projectiles node not found, creating one.")
		proj_node = Node2D.new()
		proj_node.name = "Projectiles"
		get_tree().root.add_child(proj_node)
	return proj_node

# Signal handler for animation finished - simplified like PotionBoss
func _on_animated_sprite_2d_animation_finished() -> void:
	if !is_instance_valid(_animated_sprite):
		return
		
	var animation_name = _animated_sprite.animation
	print("NeuroBoss: Animation finished:", animation_name)
	
	if animation_name.begins_with("die") or animation_name == "die":
		print("NeuroBoss: Die animation finished, queueing free")
		queue_free()
	elif animation_name.begins_with("slash"):
		print("NeuroBoss: Slash animation finished, resetting attack state")
		is_attacking = false
		# Return to movement animation based on current velocity
		if velocity.length_squared() > 10.0:
			var anim_name = get_direction_animation("walk", velocity.normalized())
			play_animation(anim_name)
		else:
			play_idle_animation()
	elif animation_name.begins_with("expand") or animation_name.begins_with("cast"):
		print("NeuroBoss: Special animation finished, resetting special state")
		in_special_ability = false
		# Return to movement animation based on current velocity
		if velocity.length_squared() > 10.0:
			var anim_name = get_direction_animation("walk", velocity.normalized())
			play_animation(anim_name)
		else:
			play_idle_animation()

func _on_hitbox_area_entered(area: Area2D):
	if is_dead: return

	# Only check projectiles
	if not area.is_in_group("projectiles"):
		return
		
	print("DEBUG: Hitbox detected area:", area.name)
	print("DEBUG: Area collision layer:", area.collision_layer)
	
	# Skip our own thrown bananas
	if area.get_meta("thrown_by_boss", false):
		print("DEBUG: Ignoring boss-thrown banana in hitbox")
		return
	
	# Skip already caught bananas
	if area.get_meta("caught_by_boss", false):
		print("DEBUG: Ignoring already caught banana in hitbox")
		return
		
	# Handle friendly (player-thrown) bananas
	if area.get_meta("friendly", false):
		# Try to catch if conditions are right
		if (in_special_ability or randf() < 0.4) and debug_can_catch_bananas:
			print("DEBUG: Attempting to catch banana (Hitbox)")
			catch_banana(area)
		else: # Take damage if not caught
			print("DEBUG: Taking damage from friendly banana")
			var damage = 1.0 # Default
			if "damage" in area:
				damage = float(area.get("damage"))
			
			take_damage(damage)
			if area.has_method("queue_free"): 
				area.queue_free()
				print("DEBUG: Destroyed banana after damage")

func _on_banana_detection_area_area_entered(area: Area2D):
	if is_dead: return

	# Only process projectiles
	if not area.is_in_group("projectiles"):
		return
		
	print("DEBUG: BananaDetectionArea detected area:", area.name)
	print("DEBUG: Area collision layer:", area.collision_layer)
	
	# Skip already caught bananas
	if area.get_meta("caught_by_boss", false):
		print("DEBUG: Ignoring already caught banana")
		return
		
	# Skip boss-thrown bananas
	if area.get_meta("thrown_by_boss", false):
		print("DEBUG: Ignoring boss-thrown banana in detection area")
		return
		
	# Only catch player/friendly bananas
	if area.get_meta("friendly", false):
		# Can only catch if not currently throwing
		if not debug_can_catch_bananas:
			print("DEBUG: Not catching - boss is in throw mode")
			return
			
		# Higher chance to catch in detection area
		if in_special_ability or randf() < 0.6:
			print("DEBUG: Attempting to catch banana (Detection Area)")
			catch_banana(area)
	else:
		print("DEBUG: Skipping non-friendly projectile:", area.name)

func _on_hitbox_body_entered(body: Node2D):
	if is_dead or is_attacking or in_special_ability: return
	
	# Trigger melee if player/troop gets close
	if body.is_in_group("player") or body.is_in_group("troop"):
		print("NeuroBoss: Player/Troop entered hitbox:", body.name)
		perform_melee_attack()

func _on_hitbox_body_exited(body: Node2D):
	print("NeuroBoss: Body exited hitbox:", body.name)
	
	# Only care about player or troop members exiting
	if body.is_in_group("player") or body.is_in_group("troop"):
		# If we're currently in a slash animation
		if is_attacking and _animated_sprite.animation.begins_with("slash"):
			# Schedule a check to ensure the attack state resets
			get_tree().create_timer(0.5).timeout.connect(func():
				# Only reset if we're still in attacking state after timeout
				if is_attacking:
					print("NeuroBoss: Forcing attack state reset after body exit")
					is_attacking = false
					
					# Return to appropriate animation
					if velocity.length_squared() > 10.0:
						var anim_name = get_direction_animation("walk", velocity.normalized())
						play_animation(anim_name)
					else:
						play_idle_animation()
			)
