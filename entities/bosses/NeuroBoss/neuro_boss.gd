extends CharacterBody2D
## The NeuroBoss is a powerful enemy that can manipulate bananas and control
## monkeys.

# Signals for monkey control - allows decoupling from Player
signal monkey_controlled(monkey)
signal monkey_released(monkey)
signal boss_died

## The health of the boss.
@export var max_health: float = 75.0

## How fast the boss moves in pixels
@export var move_speed: float = 130.0

## How close to target before picking new one
@export var proximity_threshold: float = 50.0

@export_group("Attack Configuration")
@export var min_wait_time: float = 0.5
@export var max_wait_time: float = 1.5
@export var avoid_distance: float = 100.0
@export var melee_damage: int = 2
@export var min_attack_interval: float = 3.0
@export var max_attack_interval: float = 6.0
@export var special_ability_cooldown: float = 12.0
@export var max_caught_bananas: int = 5
@export var caught_items_orbit_radius: float = 80.0
@export var caught_orbit_speed: float = 2.0
@export var mind_control_range: float = 250.0
@export var max_controlled_monkeys: int = 3
@export var mind_control_duration: float = 8.0
@export var melee_attack_chance: float = 0.05
@export var banana_throw_chance: float = 0.1
@export var mind_control_chance: float = 0.2
@export var psychic_push_chance: float = 0.05
@export var shoot_chance: float = 0.2
@export var spiral_burst_chance: float = 0.1
@export var flower_ring_chance: float = 0.1
@export var spiral_vortex_chance: float=  0.1
@export var random_rain_chance: float = 0.1






@export var psychic_push_force: float = 500.0
@export var psychic_push_range: float = 200.0
@export var shoot_range: float = 400.0

# Attack settings for controlled monkeys
@export var controlled_monkey_attack_range: float = 100.0
@export var controlled_monkey_attack_damage: int = 1
@export var controlled_monkey_move_speed: float = 150.0
@export var controlled_monkey_attack_interval: float = 1.0

const STUCK_THRESHOLD: float = 5.0
const SIMPLE_MOVEMENT_DURATION: float = 5.0
const BANANA_THROW_SPEED: float = 550.0 # Speed for thrown bananas

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar = $HealthBar
@onready var banana_detection_area: Area2D = $BananaDetectionArea
@onready var hitbox: Area2D = $Hitbox

@export var wizard_orb_scene: PackedScene

# Visual orbit ring
var orbit_ring: Node2D

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
var monkey_attack_cooldowns: Dictionary = {}
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
	"throw_bananas": true,
	"shoot": true
}

@onready var taser_scene = preload("res://projectiles/BananaBoomerang/banana_boomerang.tscn")

func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	# Create the orbit ring visual
	_create_orbit_ring()

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

	# Ensure animation_finished signal is properly connected - FIX: Don't try to disconnect first
	if !_animated_sprite.animation_finished.is_connected(Callable(self, "_on_animated_sprite_2d_animation_finished")):
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

		# Connect hitbox signals - FIX: Only disconnect if connected
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

# Create the visual orbit ring
func _create_orbit_ring() -> void:
	orbit_ring = Node2D.new()
	orbit_ring.name = "OrbitRing"
	add_child(orbit_ring)

	# Set z_index to be behind the boss but in front of the background
	orbit_ring.z_index = -1

# Draw the orbit ring - needed to make it visible
func _draw() -> void:
	if caught_bananas.size() > 0:
		# Draw orbit circle with a pulsing glow effect
		var alpha = 0.5 + 0.2 * sin(Time.get_ticks_msec() / 200.0)
		var color = Color(1.0, 0.7, 0.2, alpha)  # Golden glow
		draw_circle(Vector2.ZERO, caught_items_orbit_radius, color)

		# Draw a slightly smaller inner circle for a ring effect
		var inner_color = Color(1.0, 0.7, 0.2, alpha * 0.3)  # More transparent
		draw_circle(Vector2.ZERO, caught_items_orbit_radius - 5, inner_color)

		# Draw orbit path
		var orbit_color = Color(1.0, 0.8, 0.3, 0.3)  # Faint golden line
		draw_arc(Vector2.ZERO, caught_items_orbit_radius, 0, TAU, 64, orbit_color, 2.0)

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
		queue_redraw()  # Redraw the orbit ring
	else:
		queue_redraw()  # Still redraw to hide ring when no bananas

	# Update controlled monkeys to make them attack player/troop
	update_controlled_monkeys(delta)

	# CRITICAL FIX: Check controlled monkeys for death (monitoring health)
	check_controlled_monkeys_health()

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

# ADDED FUNCTION: Monitor controlled monkeys health to detect death
func check_controlled_monkeys_health() -> void:
	var monkeys_to_remove = []

	for monkey in controlled_monkeys:
		if not is_instance_valid(monkey):
			monkeys_to_remove.append(monkey)
			continue

		# Special case: if the monkey is an AnimatedSprite2D, it might be a child of the actual monkey
		if monkey is AnimatedSprite2D:
			var parent = monkey.get_parent()
			if is_instance_valid(parent) and parent is CharacterBody2D and "current_health" in parent:
				# Monitor the parent's health instead
				if parent.current_health <= 0:
					monkeys_to_remove.append(monkey)
					print("NeuroBoss: Detected sprite's parent death by health check:", parent.name)
			continue

		# Check if monkey has health data
		if "current_health" in monkey:
			var monkey_health = monkey.current_health  # Renamed to avoid shadowing

			# If health is already at 0, this monkey is dead
			if monkey_health <= 0:
				monkeys_to_remove.append(monkey)
				print("NeuroBoss: Detected monkey death (health=0):", monkey.name)
				continue

			# Store last known health if not already stored
			if not monkey.has_meta("last_known_health"):
				monkey.set_meta("last_known_health", monkey_health)
				continue

			var last_health = monkey.get_meta("last_known_health")

			# If health dropped since last check, record the new health
			if monkey_health < last_health:
				print("NeuroBoss: Monkey", monkey.name, "health dropped from", last_health, "to", monkey_health)
				monkey.set_meta("last_known_health", monkey_health)

				# If health dropped to 0 or below, consider it dead
				if monkey_health <= 0:
					monkeys_to_remove.append(monkey)
					print("NeuroBoss: Detected monkey death by health drop:", monkey.name)

	# Remove any dead monkeys
	for monkey in monkeys_to_remove:
		_on_controlled_monkey_died(monkey)

# Simplified animation playing function
func play_animation(anim_name: String) -> void:
	if is_dead or !is_instance_valid(_animated_sprite):
		return

	# Check if animation exists before trying to play it
	if _animated_sprite.sprite_frames.has_animation(anim_name):
		_animated_sprite.play(anim_name)

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
		print("NeuroBoss: Animation not found: ", anim_name, " - Available animations: ",
			_animated_sprite.sprite_frames.get_animation_names())
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
	#print("NeuroBoss: New waypoint set:", current_target)

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
		print("===ATTACK MELEE")
		print("NeuroBoss: Choosing Melee Attack.")
		perform_melee_attack()
		chosen_attack = true

	# Banana Throw
	cumulative_chance += banana_throw_chance
	if not chosen_attack and phases_active["throw_bananas"] and caught_bananas.size() > 0 and banana_throw_cooldown <= 0 and rand_val <= cumulative_chance:
		print("===ATTACK BANANANA")
		#print("NeuroBoss: Choosing Banana Throw Attack.")
		throw_caught_bananas()
		chosen_attack = true

	# Mind Control
	cumulative_chance += mind_control_chance
	if not chosen_attack and phases_active["mind_control"] and rand_val <= cumulative_chance:
		print("===ATTACK MIND CONTROl")
		#print("NeuroBoss: Choosing Mind Control Attack.")
		perform_mind_control()
		chosen_attack = true

	# Psychic Push
	cumulative_chance += psychic_push_chance
	if not chosen_attack and phases_active["psychic_push"] and distance_to_player < psychic_push_range and rand_val <= cumulative_chance:
		print("===ATTACK PSHYSIC PUSH")
		#print("NeuroBoss: Choosing Psychic Push Attack.")
		perform_psychic_push()
		chosen_attack = true

	# Psychic Push
	cumulative_chance += shoot_chance
	if not chosen_attack and phases_active["shoot"] and distance_to_player < shoot_range and rand_val <= cumulative_chance:
		print("===ATTACK SHOOT")
		#print("NeuroBoss: Choosing Psychic Push Attack.")
		attack_shoot_projectiles_circle()
		chosen_attack = true

	cumulative_chance += spiral_burst_chance
	if not chosen_attack and phases_active["shoot"] and distance_to_player < shoot_range and rand_val <= cumulative_chance:
		print("===ATTACK SHOOT")
		#print("NeuroBoss: Choosing Psychic Push Attack.")
		attack_spiral_burst()
		chosen_attack = true

	cumulative_chance += flower_ring_chance
	if not chosen_attack and phases_active["shoot"] and distance_to_player < shoot_range and rand_val <= cumulative_chance:
		print("===ATTACK SHOOT")
		#print("NeuroBoss: Choosing Psychic Push Attack.")
		attack_flower_ring()
		chosen_attack = true

	cumulative_chance += spiral_vortex_chance
	if not chosen_attack and phases_active["shoot"] and distance_to_player < shoot_range and rand_val <= cumulative_chance:
		print("===ATTACK SHOOT")
		#print("NeuroBoss: Choosing Psychic Push Attack.")
		attack_dual_spiral_vortex()
		chosen_attack = true

	cumulative_chance += random_rain_chance
	if not chosen_attack and phases_active["shoot"] and distance_to_player < shoot_range and rand_val <= cumulative_chance:
		print("===ATTACK SHOOT")
		#print("NeuroBoss: Choosing Psychic Push Attack.")
		attack_random_rain()
		chosen_attack = true

	# Default action if no attack chosen: Move towards player
	if not chosen_attack:
		#print("NeuroBoss: No attack chosen, moving towards player.")
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
		#print("DEBUG: No bananas to throw!")
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

# FIXED: Complete overhaul of banana throw execution
func _execute_banana_throw():
	var projectiles_node = find_or_create_projectiles_node()
	var targets = get_tree().get_nodes_in_group("player")

	# Add troop monkeys as secondary targets if no player found
	if targets.is_empty():
		targets = get_tree().get_nodes_in_group("troop")

	#print("DEBUG: Found targets:", targets.size())
	#print("DEBUG: Current caught bananas:", caught_bananas.size())

	# IMPORTANT FIX: Only create a copy but DON'T clear the original array yet!
	var bananas_to_throw_copy = caught_bananas.duplicate()
	var bananas_to_remove = [] # Track which bananas to remove after successful throws

	#print("DEBUG: Bananas to throw:", bananas_to_throw_copy.size())

	# If we have no bananas or no targets, exit early
	if bananas_to_throw_copy.size() == 0 or targets.size() == 0:
		#print("DEBUG: No bananas or targets available for throw")
		is_attacking = false
		in_special_ability = false
		return

	# FIXED: Determine the throw direction based on the boss's facing
	var throw_direction = Vector2.ZERO

	# Use the last_direction_suffix to determine the throw direction
	if last_direction_suffix == "up":
		throw_direction = Vector2(0, -1)
	elif last_direction_suffix == "down":
		throw_direction = Vector2(0, 1)
	elif last_direction_suffix == "left":
		throw_direction = Vector2(-1, 0)
	elif last_direction_suffix == "right":
		throw_direction = Vector2(1, 0)
	else:
		# Default to the last known direction if suffix not recognized
		throw_direction = last_known_direction

	# Make sure we have a valid throw direction
	if throw_direction == Vector2.ZERO:
		throw_direction = Vector2(0, 1) # Default to throwing down if no direction

	# Now process the bananas for throwing
	for banana in bananas_to_throw_copy:
		if not is_instance_valid(banana):
			continue

		# Get a random target for damage, but use our calculated throw direction
		var target_node = null
		if not targets.is_empty():
			target_node = targets[randi() % targets.size()]

		if not target_node:
			continue # Skip if no targets left

		# Create a new taser projectile that LOOKS like a red banana
		var taser = taser_scene.instantiate()
		taser.global_position = global_position

		# FIXED: Use the boss's facing direction with minimal variation
		var variation = randf_range(-0.1, 0.1) # Reduced variation for more accurate forward throws
		var final_throw_direction = throw_direction.rotated(variation)

		# Set velocity and appearance - make it look like a red banana
		taser.velocity = final_throw_direction * BANANA_THROW_SPEED
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
		taser.set_meta("source_entity", self)

		# Set collision properties for proper hitting
		taser.collision_layer = 1 << 2  # Layer 3 (Projectiles)
		taser.collision_mask = (1 << 3) | (1 << 4)  # Layers 4 (Troop) and 5 (Player)

		# Add the taser to the scene
		projectiles_node.add_child(taser)

		# Track banana for removal instead of immediately freeing it
		bananas_to_remove.append(banana)

		print("NeuroBoss: Threw banana (as taser) at", target_node.name)
		await get_tree().create_timer(0.2).timeout

	# Now safely remove all bananas that were successfully thrown
	for banana in bananas_to_remove:
		if is_instance_valid(banana):
			# Remove from array before freeing to avoid invalid reference
			if caught_bananas.has(banana):
				caught_bananas.erase(banana)
			banana.queue_free()

	#print("DEBUG: Finished throwing all bananas")

	# Reset the catching flag after completion with a delay
	await get_tree().create_timer(0.5).timeout
	debug_can_catch_bananas = true

	# Reset animation lock after throw is complete
	in_special_ability = false
	is_attacking = false

# FIXED: Improved function for controlled monkey behavior
func update_controlled_monkeys(delta: float) -> void:
	var player = find_player_node(get_tree().root)
	if not player or controlled_monkeys.is_empty():
		return

	# Check which monkeys are still valid and remove any that aren't
	var valid_monkeys = []
	for monkey in controlled_monkeys:
		if is_instance_valid(monkey) and monkey.has_meta("controlled_by_boss"):
			valid_monkeys.append(monkey)
		else:
			# Handle removing invalid monkeys
			if monkey_attack_cooldowns.has(monkey):
				monkey_attack_cooldowns.erase(monkey)

	# Update our list if any monkeys are no longer valid
	if valid_monkeys.size() != controlled_monkeys.size():
		controlled_monkeys = valid_monkeys

	for monkey in controlled_monkeys:
		# Initialize attack cooldown for this monkey if needed
		if not monkey_attack_cooldowns.has(monkey):
			monkey_attack_cooldowns[monkey] = 0.0

		# Update cooldown
		if monkey_attack_cooldowns[monkey] > 0:
			monkey_attack_cooldowns[monkey] -= delta

		# Choose a target - either player or a random troop member
		var target = player
		var troop_members = get_tree().get_nodes_in_group("troop")
		if not troop_members.is_empty() and randf() < 0.3:  # 30% chance to target troop instead of player
			target = troop_members[randi() % troop_members.size()]

		if not is_instance_valid(target):
			continue

		# Calculate distance to target
		var distance_to_target = monkey.global_position.distance_to(target.global_position)

		# Direction to target
		var direction = (target.global_position - monkey.global_position).normalized()

		# Handle animation
		_update_monkey_animation(monkey, direction)

		# Move monkey toward target if not in attack range
		if distance_to_target > controlled_monkey_attack_range:
			if "velocity" in monkey:
				monkey.velocity = direction * controlled_monkey_move_speed
				# Apply the velocity (if the monkey has move_and_slide method)
				if monkey.has_method("move_and_slide"):
					monkey.move_and_slide()
		else:
			# Slow down when in attack range
			if "velocity" in monkey:
				monkey.velocity = direction * (controlled_monkey_move_speed * 0.5)
				if monkey.has_method("move_and_slide"):
					monkey.move_and_slide()

			# Attack if cooldown is done
			if monkey_attack_cooldowns[monkey] <= 0:
				_make_monkey_attack(monkey, target, direction)
				monkey_attack_cooldowns[monkey] = controlled_monkey_attack_interval

# FIXED: Helper function to update monkey animation with improved AnimatedSprite2D handling
func _update_monkey_animation(monkey, direction: Vector2) -> void:
	if not is_instance_valid(monkey):
		return

	# Check if monkey has an animate_walk method
	if monkey.has_method("animate_walk"):
		monkey.animate_walk(direction)
		return

	# Check for AnimationTree
	var animation_tree = monkey.get_node_or_null("AnimationTree")
	if is_instance_valid(animation_tree):
		var playback = animation_tree.get("parameters/playback")
		if playback != null:
			# Set blend positions if they exist
			if animation_tree.has("parameters/Walk/BlendSpace2D/blend_position"):
				animation_tree.set("parameters/Walk/BlendSpace2D/blend_position", direction)
			if animation_tree.has("parameters/Idle/BlendSpace2D/blend_position"):
				animation_tree.set("parameters/Idle/BlendSpace2D/blend_position", direction)

			# Travel to appropriate state
			if direction.length() > 0.1:
				playback.travel("Walk")
			else:
				playback.travel("Idle")
		return

	# Check for AnimatedSprite2D
	var sprite = monkey.get_node_or_null("AnimatedSprite2D")
	if is_instance_valid(sprite) && is_instance_valid(sprite.sprite_frames):
		var anim_suffix = "_down"  # Default direction

		# Determine direction suffix
		if abs(direction.x) > abs(direction.y):
			anim_suffix = "_right" if direction.x > 0 else "_left"
		else:
			anim_suffix = "_down" if direction.y > 0 else "_up"

		# Choose animation name
		var anim_name = "walk" + anim_suffix if direction.length() > 0.1 else "idle" + anim_suffix

		# Play animation if it exists
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)

# Helper method for checking safely if a parameter exists in the AnimationTree
func has_parameter(animation_tree, param_path: String) -> bool:
	var parts = param_path.split("/")
	var current = animation_tree

	for part in parts:
		if not current.has(part):
			return false
		current = current.get(part)

	return true

# Helper function to make a monkey attack - FIXED FOR DAMAGE DEALING
func _make_monkey_attack(monkey, target, direction: Vector2) -> void:
	if not is_instance_valid(monkey) or not is_instance_valid(target):
		return

	# Apply damage immediately to ensure it happens
	if target.has_method("take_damage"):
		target.take_damage(controlled_monkey_attack_damage)

	# Try different attack methods for visuals
	if monkey.has_method("attack"):
		monkey.attack(target)
	elif monkey.has_method("perform_attack"):
		monkey.perform_attack()
	elif monkey.has_method("_play_attack_animation"):
		monkey._play_attack_animation(target)
	elif monkey.has_node("AnimationTree"):
		var animation_tree = monkey.get_node("AnimationTree")
		if animation_tree:
			var playback = animation_tree.get("parameters/playback")
			if playback:
				# Set attack direction in blend space if available
				if has_parameter(animation_tree, "parameters/Attack/BlendSpace2D/blend_position"):
					animation_tree.set("parameters/Attack/BlendSpace2D/blend_position", direction)
				playback.travel("Attack")
	else:
		# Visual attack feedback
		if monkey.has_node("AnimatedSprite2D"):
			var sprite = monkey.get_node("AnimatedSprite2D")
			if sprite:
				sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)  # Briefly flash red
				get_tree().create_timer(0.2).timeout.connect(func():
					if is_instance_valid(sprite):
						sprite.modulate = Color(1.0, 0.5, 0.5, 1.0)  # Back to normal red tint
				)

func perform_mind_control():
	is_attacking = true
	in_special_ability = true
	velocity = Vector2.ZERO

	# Ensure we have a valid direction for the animation
	if last_known_direction == Vector2.ZERO:
		last_known_direction = Vector2.DOWN

	# Get the animation name based on our current direction
	var anim_name = get_direction_animation("expand", last_known_direction)
	print("NeuroBoss: Mind Control - Playing animation:", anim_name)

	# Play the animation
	play_animation(anim_name)

	# Schedule mind control effect with a longer delay to ensure animation plays
	get_tree().create_timer(0.5).timeout.connect(Callable(self, "_execute_mind_control"))

# Updated to properly handle animation state and find monkeys
func _execute_mind_control():
	print("NeuroBoss: Executing mind control")

	# Find all potential monkeys to control
	var monkeys_in_range = []
	var troop_nodes = get_tree().get_nodes_in_group("troop")
	print("NeuroBoss: Found", troop_nodes.size(), "total troop members")

	for monkey in troop_nodes:
		if not controlled_monkeys.has(monkey):
			var distance = monkey.global_position.distance_to(global_position)
			if distance <= mind_control_range:
				monkeys_in_range.append(monkey)
				print("NeuroBoss: Found monkey in range at distance", distance)

	if monkeys_in_range.size() > 0:
		monkeys_in_range.sort_custom(Callable(self, "sort_by_distance"))

		var control_count = min(monkeys_in_range.size(), max_controlled_monkeys - controlled_monkeys.size())
		print("NeuroBoss: Found", monkeys_in_range.size(), "potential monkeys, controlling", control_count)

		var took_control = false
		for i in range(control_count):
			if is_instance_valid(monkeys_in_range[i]):
				take_control_of_monkey(monkeys_in_range[i])
				took_control = true

		# Only schedule release if we actually took control of any monkeys
		if took_control:
			print("NeuroBoss: Started mind control - will release in", mind_control_duration, "seconds")
			get_tree().create_timer(mind_control_duration).timeout.connect(Callable(self, "release_all_controlled_monkeys"))
		else:
			print("NeuroBoss: Failed to take control of any monkeys")
	else:
		print("NeuroBoss: No monkeys in range to control")

	# Reset animation state after a small delay to ensure animation completes
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(self) and not is_dead:
			# Only reset if we're still in the special ability state
			if in_special_ability:
				in_special_ability = false
				is_attacking = false
				print("NeuroBoss: Mind control animation complete, resetting animation state")

				# Resume normal animations
				if velocity.length_squared() > 10.0:
					var anim_name = get_direction_animation("walk", velocity.normalized())
					play_animation(anim_name)
				else:
					play_idle_animation()
	)

	_start_special_ability_timer()

# FIXED: Updated to properly detect controlled monkey death
func take_control_of_monkey(monkey_node: Node2D):
	if not is_instance_valid(monkey_node):
		print("NeuroBoss: Cannot take control of invalid monkey")
		return

	# Determine the actual monkey to control (in case we receive an AnimatedSprite2D)
	var monkey = monkey_node
	if monkey_node is AnimatedSprite2D:
		var parent = monkey_node.get_parent()
		if is_instance_valid(parent) and parent is CharacterBody2D:
			monkey = parent
			print("NeuroBoss: Using parent", parent.name, "instead of sprite for control")

	if controlled_monkeys.has(monkey):
		print("NeuroBoss: Monkey already controlled:", monkey.name)
		return

	print("NeuroBoss: Taking control of monkey:", monkey.name)

	# Add to our control list and set metadata
	controlled_monkeys.append(monkey)
	monkey.set_meta("controlled_by_boss", true)

	# Save current health to detect death later
	if "current_health" in monkey:
		monkey.set_meta("last_known_health", monkey.current_health)

	# Make controlled monkeys red
	monkey.modulate = Color(1.0, 0.5, 0.5, 1.0) # Red tint

	# CRITICAL FIX: Configure controlled monkey to be recognized as an enemy
	if not monkey.is_in_group("enemies"):
		monkey.add_to_group("enemies")

	# Remove from player's groups
	if monkey.is_in_group("troop"):
		monkey.remove_from_group("troop")

	# SIGNAL-BASED APPROACH: Emit signal that monkey is being controlled
	monkey_controlled.emit(monkey)

	# Get the monkey's current parent to check if removal is needed
	var current_parent = monkey.get_parent()

	# Reparent to boss - use get_parent() to check if it has a parent first
	if current_parent:
		print("NeuroBoss: Reparenting monkey from", current_parent.name, "to NeuroBoss")
		var global_pos = monkey.global_position
		current_parent.remove_child(monkey)
		add_child(monkey)
		monkey.global_position = global_pos  # Maintain world position
	else:
		print("NeuroBoss: Monkey has no parent, adding directly")
		add_child(monkey)
		# Position relative to boss
		monkey.position = Vector2(randf_range(-50, 50), randf_range(-50, 50))

	# Update collision properties - make sure we can still damage the monkey
	# Set the collision layer to enemy (layer 2)
	if monkey is CollisionObject2D:
		monkey.collision_layer = 1 << 1  # Layer 2 (Enemies)
		monkey.collision_mask = (1 << 0) | (1 << 3) | (1 << 4)  # Layer 1 (World), Layer 4 (Troop), Layer 5 (Player)

	# Set up hitbox to affect player and troop
	var monkey_hitbox = monkey.get_node_or_null("Hitbox")
	if is_instance_valid(monkey_hitbox) and monkey_hitbox is Area2D:
		monkey_hitbox.collision_layer = 1 << 1  # Layer 2 (Enemies)
		monkey_hitbox.collision_mask = (1 << 3) | (1 << 4)  # Layer 4 (Troop) and 5 (Player)

	# Initialize attack cooldown for this monkey
	monkey_attack_cooldowns[monkey] = 0.0

func clean_up_invalid_references() -> void:
	# Clean up controlled monkeys
	var valid_monkeys = []
	for m in controlled_monkeys:
		if is_instance_valid(m):
			valid_monkeys.append(m)
	controlled_monkeys = valid_monkeys

	# Clean up caught bananas
	var valid_bananas = []
	for b in caught_bananas:
		if is_instance_valid(b):
			valid_bananas.append(b)
	caught_bananas = valid_bananas

	# Clean up attack cooldowns dictionary
	var keys_to_remove = []
	for key in monkey_attack_cooldowns.keys():
		if not is_instance_valid(key):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		monkey_attack_cooldowns.erase(key)

# Improved fix for the controlled monkey issue (dying but remaining invincible)
func _on_controlled_monkey_died(monkey_node):
	print("NeuroBoss: Controlled monkey died: ", monkey_node.name if is_instance_valid(monkey_node) else "Invalid monkey")

	# If the monkey isn't valid, clean up all our arrays
	if not is_instance_valid(monkey_node):
		clean_up_invalid_references()
		return

	# Special case for AnimatedSprite2D - we need to handle the parent CharacterBody2D
	var monkey = monkey_node
	if monkey_node is AnimatedSprite2D:
		var parent = monkey_node.get_parent()
		if is_instance_valid(parent) and parent is CharacterBody2D:
			monkey = parent
			print("NeuroBoss: Using parent", parent.name, "instead of sprite for death handling")

	# PLAY DEATH ANIMATION - Critical to fix animation issues
	# First check if we can safely play a death animation
	var played_animation = false
	if is_instance_valid(monkey):
		# Try to play death animation through AnimationTree if available
		var anim_tree = monkey.get_node_or_null("AnimationTree")
		if is_instance_valid(anim_tree):
			var playback = anim_tree.get("parameters/playback")
			if playback and anim_tree.get("parameters/playback").has_method("travel"):
				print("NeuroBoss: Playing 'die' animation via AnimationTree for", monkey.name)
				anim_tree.get("parameters/playback").travel("die")
				played_animation = true

		# If AnimationTree approach didn't work, try AnimatedSprite2D
		if not played_animation:
			var sprite = monkey.get_node_or_null("AnimatedSprite2D")
			if is_instance_valid(sprite) and is_instance_valid(sprite.sprite_frames):
				# Check if 'die' animation exists before playing
				if sprite.sprite_frames.has_animation("die"):
					print("NeuroBoss: Playing 'die' animation via AnimatedSprite2D for", monkey.name)
					sprite.play("die")
					played_animation = true
				else:
					print("NeuroBoss: No 'die' animation found in sprite frames for", monkey.name)
					# List available animations for debugging
					print("NeuroBoss: Available animations:", sprite.sprite_frames.get_animation_names())

	# Continue with cleanup
	if is_instance_valid(monkey):
		# Remove from controlled_monkeys array
		if controlled_monkeys.has(monkey_node):
			controlled_monkeys.erase(monkey_node)
		elif controlled_monkeys.has(monkey):
			controlled_monkeys.erase(monkey)

		# Remove from attack cooldowns
		if monkey_attack_cooldowns.has(monkey_node):
			monkey_attack_cooldowns.erase(monkey_node)
		if monkey_attack_cooldowns.has(monkey):
			monkey_attack_cooldowns.erase(monkey)

		# Clear all collision masks immediately
		if monkey is CollisionObject2D:
			monkey.collision_layer = 0
			monkey.collision_mask = 0

			# Disable all collision shapes
			for child in monkey.get_children():
				if child is CollisionShape2D:
					child.set_deferred("disabled", true)
				elif child is Area2D:
					child.set_deferred("monitoring", false)
					child.set_deferred("monitorable", false)
					for grandchild in child.get_children():
						if grandchild is CollisionShape2D:
							grandchild.set_deferred("disabled", true)

		# Clear any metadata we've set
		if monkey.has_meta("controlled_by_boss"):
			monkey.remove_meta("controlled_by_boss")
		if monkey.has_meta("last_known_health"):
			monkey.remove_meta("last_known_health")

		# Emit signal that the monkey has been released
		monkey_released.emit(monkey)

		# Queue_free after a short delay to allow animation to play
		if monkey.get_parent() == self:
			# Create a timer to delay the queue_free call
			if played_animation:
				print("NeuroBoss: Delaying queue_free to allow death animation to play")
				get_tree().create_timer(1.5).timeout.connect(func():
					if is_instance_valid(monkey):
						monkey.queue_free()
						print("NeuroBoss: Queued free after animation delay:", monkey.name)
				)
			else:
				# If we couldn't play an animation, free immediately
				monkey.queue_free()
				print("NeuroBoss: Queued free immediately (no animation played):", monkey.name)

		print("NeuroBoss: Cleaned up controlled monkey:", monkey.name)

	# Final cleanup of arrays to remove any invalid references
	clean_up_invalid_references()

# Detect death animations in controlled monkeys
func _on_controlled_monkey_animation_finished(anim_name, monkey):
	if anim_name == "die":
		_on_controlled_monkey_died(monkey)

func _on_controlled_monkey_animation_tree_finished(anim_name, monkey):
	if anim_name == "die":
		_on_controlled_monkey_died(monkey)

# FIXED: Release controlled monkeys without extra walking logic
func release_all_controlled_monkeys():
	print("NeuroBoss: Releasing", controlled_monkeys.size(), "controlled monkeys")
	var released_count = 0

	# Make a copy of the array to safely iterate while modifying
	var monkeys_to_release = controlled_monkeys.duplicate()

	for monkey_node in monkeys_to_release:
		if not is_instance_valid(monkey_node):
			continue

		# Get the actual monkey (in case we accidentally stored an AnimatedSprite2D)
		var monkey = monkey_node
		if monkey_node is AnimatedSprite2D:
			var parent = monkey_node.get_parent()
			if is_instance_valid(parent) and parent is CharacterBody2D:
				monkey = parent

		released_count += 1

		# Check if the monkey is dead
		var monkey_is_dead = false  # Renamed to avoid shadowing
		if "current_health" in monkey and monkey.current_health <= 0:
			monkey_is_dead = true

		if monkey_is_dead:
			# For dead monkeys, completely remove them
			if is_instance_valid(monkey):
				# Clear collision properties first
				if monkey is CollisionObject2D:
					monkey.collision_layer = 0
					monkey.collision_mask = 0

				# Disconnect any signals we connected
				_disconnect_monkey_signals(monkey)

				# Free the monkey node completely
				if monkey.get_parent() == self:
					monkey.queue_free()

				# Signal that it's been released (for cleanup in level script)
				emit_signal("monkey_released", monkey)
		else:
			# For living monkeys, restore their properties
			# Reset collision settings properly
			if monkey is CollisionObject2D:
				monkey.collision_layer = 1 << 2  # Layer 3 (Troop)
				monkey.collision_mask = 1 << 0   # Layer 1 (World)

			# Clean up metadata
			monkey.remove_meta("controlled_by_boss")
			if monkey.has_meta("controlled_projectiles_hostile"):
				monkey.remove_meta("controlled_projectiles_hostile")
			if monkey.has_meta("last_known_health"):
				monkey.remove_meta("last_known_health")

			# Remove from Enemy group
			if monkey.is_in_group("enemies"):
				monkey.remove_from_group("enemies")

			# Add back to troop group
			if not monkey.is_in_group("troop"):
				monkey.add_to_group("troop")

			# Reset appearance
			monkey.modulate = Color(1, 1, 1, 1)

			# Disconnect all signals
			_disconnect_monkey_signals(monkey)

			# Fix monkey hitbox collision settings
			var monkey_hitbox = monkey.get_node_or_null("Hitbox")
			if is_instance_valid(monkey_hitbox) and monkey_hitbox is Area2D:
				monkey_hitbox.collision_layer = 1 << 2  # Layer 3 (Troop)
				monkey_hitbox.collision_mask = 1 << 1   # Layer 2 (Enemies)

			# Only remove if it's our child
			if monkey.get_parent() == self:
				# Store monkey data for transition
				var global_pos = monkey.global_position
				remove_child(monkey)

				# Add back to scene root so it can be added to player
				var scene_root = get_tree().current_scene
				if is_instance_valid(scene_root):
					scene_root.add_child(monkey)
					monkey.global_position = global_pos  # Maintain world position

					# Signal the monkey is released
					emit_signal("monkey_released", monkey)
				else:
					print("NeuroBoss: No scene root found, cannot release monkey properly")
			else:
				# Signal monkey released even if not our child
				emit_signal("monkey_released", monkey)

	# Clear all controlled monkey references
	controlled_monkeys.clear()
	monkey_attack_cooldowns.clear()

	print("NeuroBoss: Released", released_count, "monkeys")


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

# FIXED: Complete overhaul of banana orbit system to prevent disappearing
func update_banana_orbit(delta: float):
	# Increment the rotation
	banana_rotation += caught_orbit_speed * delta

	# Make a defensive copy of the array
	var valid_bananas = []

	for i in range(caught_bananas.size()):
		var banana = caught_bananas[i]

		## First validate the banana
		if not is_instance_valid(banana):
			continue

		# Make sure it's tagged as caught to prevent collisions from removing it
		if not banana.has_meta("caught_by_boss"):
			banana.set_meta("caught_by_boss", true)

		valid_bananas.append(banana)

		# Calculate orbit position based on index and rotation
		var angle = banana_rotation + (TAU * i / caught_bananas.size())
		var target_offset = Vector2.RIGHT.rotated(angle) * caught_items_orbit_radius
		var target_position = global_position + target_offset

		# Calculate lerp factor based on distance - slower lerp for far bananas
		var lerp_factor = clamp(banana.global_position.distance_to(target_position) / 100.0, 0.1, 0.3)

		# If the banana is very far, bring it in faster
		if banana.global_position.distance_to(target_position) > 200.0:
			lerp_factor = 0.5

		# Update position
		banana.global_position = banana.global_position.lerp(target_position, lerp_factor)
		banana.rotation = angle + PI / 2 # Point outwards

	# Only update the bananas array if sizes don't match
	if valid_bananas.size() != caught_bananas.size():
		caught_bananas = valid_bananas
		#print("DEBUG: Cleaned up invalid orbiting bananas, now have", caught_bananas.size())

	# Double-check all caught bananas for collision settings
	for banana in caught_bananas:
		if is_instance_valid(banana):
			# Ensure collision is still disabled
			if banana is CollisionObject2D:
				banana.set_deferred("collision_layer", 0)
				banana.set_deferred("collision_mask", 0)


# Handle banana/projectile catching to prevent collisions
func catch_banana(banana):
	if banana == null or not is_instance_valid(banana):
		return

	# Skip if in throw mode
	if not debug_can_catch_bananas:
		#print("DEBUG: Not catching - boss is in throw mode")
		return

	# Skip if already caught
	if banana.has_meta("caught_by_boss"):
		#print("DEBUG: Ignoring already caught banana in catch_banana")
		return

	# Skip boss-thrown bananas
	if banana.has_meta("thrown_by_boss"):
		#print("DEBUG: Ignoring boss-thrown banana in catch_banana")
		return

	# Skip if maximum bananas reached
	if caught_bananas.size() >= max_caught_bananas:
		#print("DEBUG: Maximum bananas reached, cannot catch more")
		return

	#print("NeuroBoss: Catching banana:" + banana.name)
	# Set metadata immediately to prevent double-catching
	banana.set_meta("caught_by_boss", true)
	call_deferred("_process_caught_banana", banana)


func _process_caught_banana(banana):
	if banana == null or not is_instance_valid(banana):
		return

	#print("DEBUG: Processing caught banana:", banana.name)

	var original_position = banana.global_position

	# Add to caught bananas array
	if not caught_bananas.has(banana):
		caught_bananas.append(banana)

	# Reparent to boss
	if banana.get_parent():
		var original_parent = banana.get_parent()
		original_parent.remove_child(banana)
	
	var proj_node = get_tree().root.find_child("Projectiles", true, false)
	proj_node.add_child(banana)

	# Restore position
	banana.global_position = original_position

	# Reset appearance
	banana.modulate = Color(1, 1, 1)


## Helper comparator function between nodes a and b.
## @param a: Node2D the first node
## @param b: Node2D the second node
## @returns bool True if a is closer than b, False otherwise
func sort_by_distance(a: Node2D, b: Node2D) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b): return false
	var dist_a = global_position.distance_squared_to(a.global_position)
	var dist_b = global_position.distance_squared_to(b.global_position)
	return dist_a < dist_b


## Define the behavior for taking damage.
## @param amount: float the amount of damage to incur
func take_damage(amount: float) -> void:
	if is_dead: return
	current_health -= amount
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		_die()
	else:
		modulate = Color(2, 0.5, 0.5) # Flash red
		get_tree().create_timer(0.1).timeout.connect(func(): modulate = Color(1, 1, 1))


## Handle any cleanup, animations, or sounds associated with the NeuroBoss's
## death.
func _die():
	if is_dead: return

	if Engine.get_frames_drawn() % 60 == 0:
		clean_up_invalid_references()

	is_dead = true

	# First play the fall_down animation
	_animated_sprite.play("fall_down")

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
	if $Hitbox:
		$Hitbox.set_deferred("monitoring", false)

	if banana_detection_area: banana_detection_area.monitoring = false

	# Release resources
	release_all_controlled_monkeys()
	for banana in caught_bananas:
		if is_instance_valid(banana): banana.queue_free()
	caught_bananas.clear()

	# Emit death signal before the boss is removed
	emit_signal("boss_died")

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

# Signal handler for animation finished - improved with better logging
func _on_animated_sprite_2d_animation_finished() -> void:
	if !is_instance_valid(_animated_sprite):
		return

	var animation_name = _animated_sprite.animation
	#print("NeuroBoss: Animation finished:", animation_name)

	if animation_name == "fall_down":
		# After fall_down completes, play die animation
		print("NeuroBoss: Fall down animation finished, playing die animation")
		_animated_sprite.play("die")
	elif animation_name.begins_with("die") or animation_name == "die":
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
		# Note: we now defer the resetting of in_special_ability in _execute_mind_control
		# to allow time for the controlled monkeys to be processed

		# Only reset flags here if we're NOT in the middle of mind control
		# which handles its own flag reset
		if in_special_ability and not controlled_monkeys.size() > 0:
			in_special_ability = false

		# Return to movement animation based on current velocity
		if velocity.length_squared() > 10.0:
			var anim_name = get_direction_animation("walk", velocity.normalized())
			play_animation(anim_name)
		else:
			play_idle_animation()


## Handle the hit box entered signal.
## @param area: Area2D the area that entered the hitbox
func _on_hitbox_area_entered(area: Area2D):
	if is_dead: return

	# Only check projectiles
	if not area.is_in_group("projectiles"):
		return

	#print("DEBUG: Hitbox detected area:", area.name)
	#print("DEBUG: Area collision layer:", area.collision_layer)

	# Skip our own thrown bananas
	if area.has_meta("thrown_by_boss"):
		#print("DEBUG: Ignoring boss-thrown banana in hitbox")
		return

	# Skip already caught bananas
	if area.has_meta("caught_by_boss"):
		#print("DEBUG: Ignoring already caught banana in hitbox")
		return

	# Handle friendly (player-thrown) bananas
	if area.has_meta("friendly"):
		# Try to catch if conditions are right
		if (in_special_ability or randf() < 0.4) and debug_can_catch_bananas:
			#print("DEBUG: Attempting to catch banana (Hitbox)")
			catch_banana(area)
		else: # Take damage if not caught
			#print("DEBUG: Taking damage from friendly banana")
			var damage = 1.0 # Default
			if "damage" in area:
				damage = float(area.get("damage"))

			take_damage(damage)
			if area.has_method("queue_free"):
				area.queue_free()
				#print("DEBUG: Destroyed banana after damage")


## Handle the area entered signal.
func _on_banana_detection_area_area_entered(area: Area2D):
	if is_dead: return

	# Only process projectiles
	if not area.is_in_group("projectiles"):
		return

	# Skip already caught bananas
	if area.has_meta("caught_by_boss"):
		print_debug("DEBUG: Ignoring already caught banana")
		return

	# Skip boss-thrown bananas
	if area.has_meta("thrown_by_boss"):
		print_debug("DEBUG: Ignoring boss-thrown banana in detection area")
		return

	# Only catch player/friendly bananas
	if area.has_meta("friendly"):
		# Can only catch if not currently throwing
		if not debug_can_catch_bananas:
			#print("DEBUG: Not catching - boss is in throw mode")
			return

		# Higher chance to catch in detection area
		if in_special_ability or randf() < 0.6:
			#print("DEBUG: Attempting to catch banana (Detection Area)")
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


func _disconnect_monkey_signals(monkey):
	if not is_instance_valid(monkey):
		return

	# Disconnect direct signals from the monkey itself
	if monkey.has_signal("died") and monkey.is_connected("died", Callable(self, "_on_controlled_monkey_died")):
		monkey.disconnect("died", Callable(self, "_on_controlled_monkey_died"))

	# Disconnect from AnimatedSprite2D if it exists
	var sprite = monkey.get_node_or_null("AnimatedSprite2D")
	if is_instance_valid(sprite) and sprite.is_connected("animation_finished", Callable(self, "_on_controlled_monkey_animation_finished")):
		sprite.disconnect("animation_finished", Callable(self, "_on_controlled_monkey_animation_finished"))

	# Disconnect from AnimationTree if it exists
	var anim_tree = monkey.get_node_or_null("AnimationTree")
	if is_instance_valid(anim_tree) and anim_tree.has_signal("animation_finished"):
		if anim_tree.is_connected("animation_finished", Callable(self, "_on_controlled_monkey_animation_tree_finished")):
			anim_tree.disconnect("animation_finished", Callable(self, "_on_controlled_monkey_animation_tree_finished"))


func attack_shoot_projectiles_circle() -> void:
	var projectiles_node = get_parent().get_parent().get_node("Projectiles")

	if not wizard_orb_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var num_projectiles = 12
	var angle_step = (PI * 2) / num_projectiles
	for i in range(num_projectiles):
		var projectile: Node
		projectile = wizard_orb_scene.instantiate()

		projectiles_node.add_child(projectile)
		#projectile.scale = Vector2(2.0,2.0)
		projectile.global_position = global_position
		# Set the projectile velocity so that it moves outward.
		projectile.velocity = Vector2.RIGHT.rotated(i * angle_step) * 300

	await get_tree().create_timer(0.8).timeout
	angle_step = (PI / 12)
	for i in range(24):
		if i % 2 == 0:
			continue

		var projectile = wizard_orb_scene.instantiate()
		var proj_node = get_tree().root.find_child("Projectiles", true, false)
		proj_node.add_child(projectile)
		projectile.scale = Vector2(2.0,2.0)
		projectile.global_position = global_position
		# Set the projectile velocity so that it moves outward.
		projectile.velocity = Vector2.RIGHT.rotated(i * angle_step) * 300

	await _animated_sprite.animation_finished
	is_attacking = false


# 1. Spiral Burst
func attack_spiral_burst() -> void:
	var projectiles_node = get_parent().get_parent().get_node("Projectiles")

	if not wizard_orb_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var steps = 20
	var base_speed = 200
	var angle_increment = TAU / 6.0

	for i in range(steps):
		var projectile = wizard_orb_scene.instantiate()
		projectiles_node.add_child(projectile)
		projectile.scale = Vector2(2.0, 2.0)
		projectile.global_position = global_position

		# Spiral out: angle and speed both ramp up
		var angle = i * angle_increment
		var speed = base_speed + i * 10
		projectile.velocity = Vector2.RIGHT.rotated(angle) * speed

		# small delay between each slice of the spiral
		await get_tree().create_timer(0.05).timeout

	# let them clear a bit before resuming
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

# 2. Flower Ring
func attack_flower_ring() -> void:
	var projectiles_node = get_parent().get_parent().get_node("Projectiles")

	if not wizard_orb_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var rings = [100, 200, 300]  # radii
	for radius in rings:
		var count = 12
		var angle_step = TAU / count
		for i in range(count):
			var projectile = wizard_orb_scene.instantiate()
			projectiles_node.add_child(projectile)
			projectile.scale = Vector2(2.0, 2.0)
			projectile.global_position = global_position

			# start just offset from boss, shoot outward
			var angle = i * angle_step
			projectile.position += Vector2.RIGHT.rotated(angle) * radius * 0.2
			projectile.velocity = Vector2.RIGHT.rotated(angle) * (radius * 0.8)

		# pulse between rings
		await get_tree().create_timer(0.2).timeout

	# cooldown before next action
	await get_tree().create_timer(0.6).timeout
	is_attacking = false


# 3. Dual‑Spiral Vortex
func attack_dual_spiral_vortex() -> void:
	var projectiles_node = get_parent().get_parent().get_node("Projectiles")

	if not wizard_orb_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var total = 24
	for i in range(total):
		# clockwise spiral
		var p1 = wizard_orb_scene.instantiate()
		projectiles_node.add_child(p1)
		p1.scale = Vector2(2.0, 2.0)
		p1.global_position = global_position
		var angle1 = TAU * i / total
		p1.velocity = Vector2.RIGHT.rotated(angle1) * 250

		# counter‑clockwise mirror
		var p2 = wizard_orb_scene.instantiate()
		projectiles_node.add_child(p2)
		p2.scale = Vector2(2.0, 2.0)
		p2.global_position = global_position
		var angle2 = -angle1
		p2.velocity = Vector2.RIGHT.rotated(angle2) * 250

		# slight pacing so it feels like two interleaved streams
		await get_tree().create_timer(0.03).timeout

	await get_tree().create_timer(0.5).timeout
	is_attacking = false


# 4. Random Rain
func attack_random_rain() -> void:
	var projectiles_node = get_parent().get_parent().get_node("Projectiles")

	if not wizard_orb_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var count = 20.0
	var width = 600.0

	for i in range(count):
		var projectile = wizard_orb_scene.instantiate()
		projectiles_node.add_child(projectile)
		projectile.scale = Vector2(2.0, 2.0)

		# spawn somewhere above the boss, within width
		var x_off = randf_range(-width/2, width/2)
		projectile.global_position = global_position + Vector2(x_off, -300)

		# drop straight down at random speed
		projectile.velocity = Vector2(0, randf_range(150, 300))

		await get_tree().create_timer(0.1).timeout

	# give it a moment before the boss can act again
	await get_tree().create_timer(0.5).timeout
	is_attacking = false
