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

const STUCK_THRESHOLD: float = 3.0
const SIMPLE_MOVEMENT_DURATION: float = 5.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var health_bar = $HealthBar
@onready var banana_detection_area: Area2D = $BananaDetectionArea
@onready var hitbox: Area2D = $Hitbox # Need reference to modify masks if needed

# Timers
@onready var attack_timer: Timer = Timer.new()
@onready var special_ability_timer: Timer = Timer.new()
@onready var navigation_timer: Timer = Timer.new() # Timer for changing waypoints

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

func _ready() -> void:
	print("NeuroBoss: Initializing...")
	current_health = max_health
	if health_bar:
		health_bar.init_health(current_health)

	# AnimationTree setup
	if animation_tree:
		animation_tree.active = true
		# Ensure AnimationPlayer exists and is correctly pathed
		if not has_node("AnimationPlayer"):
			var anim_player = AnimationPlayer.new()
			anim_player.name = "AnimationPlayer"
			add_child(anim_player)
		animation_tree.anim_player = NodePath("AnimationPlayer")
		var anim_player_node = get_node_or_null(animation_tree.anim_player)
		if anim_player_node and anim_player_node is AnimationPlayer:
			if not anim_player_node.is_connected("animation_finished", Callable(self, "_on_animation_player_finished")):
				anim_player_node.connect("animation_finished", Callable(self, "_on_animation_player_finished"))
				print("NeuroBoss: Connected animation_finished signal from AnimationPlayer.")
		else:
			printerr("NeuroBoss: AnimationPlayer not found or invalid at path: ", animation_tree.anim_player)


	# --- Collision Setup ---
	# Body: Layer 2 (Enemy), Masks Layer 1 (World)
	collision_layer = 1 << 1 # Layer 2
	collision_mask = 1 << 0  # Layer 1

	# Hitbox Area: Layer 4 (EnemyHitbox), Masks Layers 3 (PlayerProj), 5 (Player), 6 (Troop)
	if hitbox:
		hitbox.collision_layer = 1 << 3 # Layer 4
		hitbox.collision_mask = (1 << 2) | (1 << 4) | (1 << 5) # Layers 3, 5, 6
		
		# Connect hitbox signals
		if not hitbox.body_entered.is_connected(Callable(self, "_on_hitbox_body_entered")):
			hitbox.body_entered.connect(Callable(self, "_on_hitbox_body_entered"))
		if not hitbox.body_exited.is_connected(Callable(self, "_on_hitbox_body_exited")):
			hitbox.body_exited.connect(Callable(self, "_on_hitbox_body_exited"))
		if not hitbox.area_entered.is_connected(Callable(self, "_on_hitbox_area_entered")):
			hitbox.area_entered.connect(Callable(self, "_on_hitbox_area_entered"))
	else:
		printerr("NeuroBoss: Hitbox node not found!")

	# Banana Detection Area: Layer 8 (SpecialDetect), Masks Layer 3 (PlayerProj)
	if banana_detection_area:
		banana_detection_area.collision_layer = 1 << 7 # Layer 8
		banana_detection_area.collision_mask = 1 << 2  # Layer 3
		
		# Connect banana detection area signal
		if not banana_detection_area.area_entered.is_connected(Callable(self, "_on_banana_detection_area_area_entered")):
			banana_detection_area.area_entered.connect(Callable(self, "_on_banana_detection_area_area_entered"))
	else:
		printerr("NeuroBoss: BananaDetectionArea node not found!")
	# -----------------------
	
	# Connect AnimatedSprite signal
	if animated_sprite and not animated_sprite.animation_finished.is_connected(Callable(self, "_on_animated_sprite_2d_animation_finished")):
		animated_sprite.animation_finished.connect(Callable(self, "_on_animated_sprite_2d_animation_finished"))
		print("NeuroBoss: Connected animation_finished signal from AnimatedSprite2D.")

	# Setup Timers
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_choose_and_execute_attack"))

	special_ability_timer.name = "SpecialAbilityTimer"
	special_ability_timer.one_shot = true
	add_child(special_ability_timer)
	special_ability_timer.connect("timeout", Callable(self, "_execute_special_ability"))

	navigation_timer.name = "NavigationTimer"
	navigation_timer.one_shot = true
	add_child(navigation_timer)
	navigation_timer.connect("timeout", Callable(self, "move_to_next_waypoint"))

	# Ensure AnimationTree is configured
	if animation_tree:
		animation_tree.active = true
		
		# Connect AnimationTree signal if possible
		if not animation_tree.animation_finished.is_connected(Callable(self, "_on_animation_tree_animation_finished")):
			animation_tree.animation_finished.connect(Callable(self, "_on_animation_tree_animation_finished"))
			print("NeuroBoss: Connected animation_finished signal from AnimationTree.")
			
		# Connect animation finished signal from the AnimationTree's AnimationPlayer
		if animation_tree.anim_player:
			var anim_player_node = get_node(animation_tree.anim_player)
			if anim_player_node:
				if not anim_player_node.is_connected("animation_finished", Callable(self, "_on_animation_player_finished")):
					anim_player_node.connect("animation_finished", Callable(self, "_on_animation_player_finished"))
					print("NeuroBoss: Connected animation_finished signal from AnimationPlayer.")
			else:
				printerr("NeuroBoss: AnimationPlayer node path in AnimationTree is invalid!")
	else:
		printerr("NeuroBoss: AnimationTree node not found or not configured!")
		set_physics_process(false) # Cannot function without AnimationTree
		return

	# Initial state
	last_position = global_position
	_start_random_attack_timer()
	_start_special_ability_timer()
	move_to_next_waypoint() # Start moving

	print("NeuroBoss: Initialization complete.")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Update cooldowns
	if banana_throw_cooldown > 0:
		banana_throw_cooldown -= delta

	# Update orbiting bananas if any
	if caught_bananas.size() > 0:
		update_banana_orbit(delta)

	# Movement and AI logic if not performing an action
	if not is_attacking and not in_special_ability:
		# Stuck detection
		if last_position.distance_squared_to(global_position) < (1.0 * delta): # Check if moved significantly
			stuck_timer += delta
			if stuck_timer > STUCK_THRESHOLD and not simple_movement_mode:
				print("NeuroBoss: Detected stuck! Switching to simple movement.")
				simple_movement_mode = true
				simple_movement_timer = 0.0
				move_to_next_waypoint() # Get a new target immediately
		else:
			stuck_timer = 0.0
			last_position = global_position
			if simple_movement_mode: # Reset if we got unstuck
				simple_movement_timer += delta
				if simple_movement_timer > SIMPLE_MOVEMENT_DURATION:
					print("NeuroBoss: Exiting simple movement mode.")
					simple_movement_mode = false

		# Perform movement based on mode
		if simple_movement_mode:
			handle_simple_movement(delta)
		else:
			handle_movement(delta)

		# Update animation based on velocity
		update_animation_state()

	# Always apply movement
	move_and_slide()

func handle_movement(_delta: float):
	if current_target == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * _delta * 5) # Slow down
		return

	var direction_to_target = (current_target - global_position).normalized()
	# Using desired_velocity to avoid the unused variable warning
	var _desired_velocity = direction_to_target * move_speed

	# Simple Obstacle Avoidance (Check only World Layer 1)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direction_to_target * avoid_distance, 1) # Mask 1
	var result = space_state.intersect_ray(query)

	var final_direction = direction_to_target
	if result and global_position.distance_to(result.position) < avoid_distance:
		# Try to slide along the obstacle
		final_direction = direction_to_target.slide(result.normal).normalized()
		print("NeuroBoss: Avoiding obstacle, adjusted direction.")

	velocity = velocity.lerp(final_direction * move_speed, 0.1) # Smooth velocity change

	# Check if reached target
	if global_position.distance_to(current_target) <= proximity_threshold:
		print("NeuroBoss: Reached waypoint.")
		current_target = Vector2.ZERO
		velocity = Vector2.ZERO
		start_navigation_timer() # Wait before choosing next point

func handle_simple_movement(_delta: float):
	if current_target == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * _delta * 5)
		return

	var direction_to_target = (current_target - global_position).normalized()
	velocity = velocity.lerp(direction_to_target * move_speed, 0.1)

	if global_position.distance_to(current_target) <= proximity_threshold * 1.5: # Larger threshold for simple mode
		print("NeuroBoss: Reached simple mode target.")
		current_target = Vector2.ZERO
		start_navigation_timer()

func move_to_next_waypoint() -> void:
	# Ensure the navigation timer isn't running to prevent rapid changes
	if not navigation_timer.is_stopped():
		navigation_timer.stop()

	current_target = choose_next_waypoint()
	print("NeuroBoss: New waypoint set:", current_target)

func choose_next_waypoint() -> Vector2:
	var player = find_player_node(get_tree().get_root())
	var target_pos = global_position # Default to current pos

	# Prioritize moving towards the player unless too close or performing an ability
	if player and not in_special_ability:
		var player_pos = player.global_position
		var dist_to_player = global_position.distance_to(player_pos)

		if dist_to_player > proximity_threshold * 3: # If far away, move closer
			target_pos = player_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50)) # Point near player
			print("NeuroBoss: Targeting player area (far).")
		elif dist_to_player < proximity_threshold * 1.5: # If too close, back away
			var direction_away = (global_position - player_pos).normalized()
			target_pos = global_position + direction_away * randf_range(100, 200)
			print("NeuroBoss: Targeting point away from player (close).")
		else: # Mid-range, choose a flanking or random nearby point
			var random_offset = Vector2(randf_range(-200, 200), randf_range(-200, 200))
			target_pos = global_position + random_offset
			print("NeuroBoss: Targeting random nearby point.")
	else: # No player or busy, choose random point
		var random_offset = Vector2(randf_range(-300, 300), randf_range(-300, 300))
		target_pos = global_position + random_offset
		print("NeuroBoss: Targeting random distant point.")

	# Basic bounds check (adjust these values based on your level)
	# target_pos.x = clamp(target_pos.x, LEVEL_MIN_X, LEVEL_MAX_X)
	# target_pos.y = clamp(target_pos.y, LEVEL_MIN_Y, LEVEL_MAX_Y)

	return target_pos

func start_navigation_timer() -> void:
	if navigation_timer.is_stopped():
		navigation_timer.wait_time = randf_range(min_wait_time, max_wait_time)
		navigation_timer.start()
		print("NeuroBoss: Waiting", navigation_timer.wait_time, "s before next move.")

func update_animation_state() -> void:
	if is_dead or is_attacking or in_special_ability:
		return # Don't change animation during actions or death

	var current_velocity = velocity
	var is_moving = current_velocity.length_squared() > 10.0 # Check if moving significantly

	animation_tree.set("parameters/conditions/is_moving", is_moving)

	if is_moving:
		last_known_direction = current_velocity.normalized()
		animation_tree.set("parameters/Idle/blend_position", last_known_direction)
		animation_tree.set("parameters/Walk/blend_position", last_known_direction)
		animation_tree.set("parameters/AttackMelee/blend_position", last_known_direction)
		animation_tree.set("parameters/AttackThrow/blend_position", last_known_direction)
		animation_tree.set("parameters/AttackPunch/blend_position", last_known_direction)
		animation_tree.set("parameters/SpecialExpand/blend_position", last_known_direction)

func play_animation_state(state_name: String, target_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead: return

	print("NeuroBoss: Attempting to play state:", state_name)
	# Set blend position based on target or last known direction
	var blend_pos = target_direction if target_direction != Vector2.ZERO else last_known_direction
	# Ensure blend_pos is normalized if it's not zero
	if blend_pos.length_squared() > 0.001:
		blend_pos = blend_pos.normalized()
	else: # If zero, use last known direction
		blend_pos = last_known_direction

	# Update blend positions for relevant states
	animation_tree.set("parameters/Idle/blend_position", blend_pos)
	animation_tree.set("parameters/Walk/blend_position", blend_pos)
	animation_tree.set("parameters/AttackMelee/blend_position", blend_pos)
	animation_tree.set("parameters/AttackThrow/blend_position", blend_pos)
	animation_tree.set("parameters/AttackPunch/blend_position", blend_pos)
	animation_tree.set("parameters/SpecialExpand/blend_position", blend_pos)

	# Trigger the state transition (assuming state machine named "playback")
	# You might need specific condition parameters like "do_melee", "do_throw" etc.
	# Example using conditions:
	animation_tree.set("parameters/conditions/do_melee", state_name == "AttackMelee")
	animation_tree.set("parameters/conditions/do_throw", state_name == "AttackThrow")
	animation_tree.set("parameters/conditions/do_punch", state_name == "AttackPunch")
	animation_tree.set("parameters/conditions/do_expand", state_name == "SpecialExpand")
	animation_tree.set("parameters/conditions/is_dead", state_name == "Die")

	# Or using travel directly if your setup allows:
	# animation_tree.travel(state_name) # Less common for complex trees

	last_known_direction = blend_pos # Update last direction based on action

# Called when an animation FINISHES in the AnimationPlayer node managed by AnimationTree
func _on_animation_player_finished(anim_name: StringName):
	print("NeuroBoss: AnimationPlayer finished:", anim_name)

	# Reset action flags when attack/special animations end
	# Check based on the animation name itself, as the state might linger
	if str(anim_name).begins_with("slash_") or str(anim_name).begins_with("attack_") or str(anim_name).begins_with("punch_"):
		if is_attacking:
			print("NeuroBoss: Attack animation complete, resetting state.")
			is_attacking = false
			# Reset trigger conditions in AnimationTree
			animation_tree.set("parameters/conditions/do_melee", false)
			animation_tree.set("parameters/conditions/do_throw", false)
			animation_tree.set("parameters/conditions/do_punch", false)
			move_to_next_waypoint() # Allow movement again

	elif str(anim_name).begins_with("expand_"):
		if in_special_ability:
			print("NeuroBoss: Special ability animation complete, resetting state.")
			in_special_ability = false
			animation_tree.set("parameters/conditions/do_expand", false)
			move_to_next_waypoint() # Allow movement again

	elif str(anim_name) == "die":
		print("NeuroBoss: Death animation complete. Removing node.")
		queue_free()

	# Update overall animation state after action completes
	update_animation_state()

func _start_random_attack_timer():
	if attack_timer.is_stopped():
		attack_timer.wait_time = randf_range(min_attack_interval, max_attack_interval)
		attack_timer.start()
		print("NeuroBoss: Next attack check in", attack_timer.wait_time, "s")

func _choose_and_execute_attack():
	if is_dead or is_attacking or in_special_ability:
		print("NeuroBoss: Cannot attack - busy or dead.")
		_start_random_attack_timer()
		return

	var player = find_player_node(get_tree().get_root())
	if not player:
		print("NeuroBoss: No player found, skipping attack.")
		_start_random_attack_timer()
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var chosen_attack = false

	# Weighted random choice
	var rand_val = randf()
	var cumulative_chance = 0.0

	# Melee
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
		perform_mind_control() # Mind control is a special ability but can be triggered here too
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
	var player = find_player_node(get_tree().get_root())
	if not player: return

	is_attacking = true
	velocity = Vector2.ZERO # Stop moving to attack

	var target_dir = (player.global_position - global_position).normalized()
	play_animation_state("AttackMelee", target_dir)

	# Apply damage slightly after animation starts
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(player) and global_position.distance_to(player.global_position) < proximity_threshold * 2.0:
		if player.has_method("take_damage"):
			print("NeuroBoss: Applying melee damage.")
			player.take_damage(melee_damage)

	# State reset happens in _on_animation_player_finished

func throw_caught_bananas():
	if caught_bananas.is_empty(): return

	is_attacking = true
	velocity = Vector2.ZERO
	banana_throw_cooldown = 2.0 # Prevent immediate re-throw

	var player = find_player_node(get_tree().get_root())
	var target_dir = (player.global_position - global_position).normalized() if player else last_known_direction
	play_animation_state("AttackThrow", target_dir)

	# Throw logic needs to happen asynchronously during the animation
	_async_throw_bananas()

func _async_throw_bananas():
	await get_tree().create_timer(0.1).timeout # Small delay before first throw

	var projectiles_node = find_or_create_projectiles_node()
	var targets = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("troop")

	var bananas_to_throw_copy = caught_bananas.duplicate() # Work on a copy
	caught_bananas.clear() # Clear original immediately

	for banana in bananas_to_throw_copy:
		if not is_instance_valid(banana): continue

		var target_node = targets[randi() % targets.size()] if not targets.is_empty() else null
		if not target_node: break # Stop if no targets left

		# Reparent and configure banana
		if banana.get_parent() == self:
			remove_child(banana)
		projectiles_node.add_child(banana)

		banana.global_position = global_position # Start from boss pos
		banana.remove_meta("caught_by_boss")
		banana.collision_layer = 1 << 6 # Enemy Projectile Layer (e.g., 7)
		banana.collision_mask = (1 << 4) | (1 << 5) # Player & Troop Layers (e.g., 5 & 6)
		banana.set_meta("friendly", false) # Mark as enemy projectile
		banana.modulate = Color(1, 1, 1)

		var direction_to_target = (target_node.global_position - global_position).normalized()
		if banana.has_method("set_velocity"): # Assuming projectile script has this
			banana.set_velocity(direction_to_target * 400.0) # Set velocity
		elif "velocity" in banana:
			banana.velocity = direction_to_target * 400.0

		print("NeuroBoss: Threw banana at", target_node.name)
		await get_tree().create_timer(0.2).timeout # Delay between throws

	# State reset happens in _on_animation_player_finished

func perform_psychic_push():
	is_attacking = true
	velocity = Vector2.ZERO

	var player = find_player_node(get_tree().get_root())
	var target_dir = (player.global_position - global_position).normalized() if player else last_known_direction
	play_animation_state("AttackPunch", target_dir)

	await get_tree().create_timer(0.2).timeout # Delay before push effect

	var bodies_to_push = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("troop")
	var pushed_count = 0
	for body in bodies_to_push:
		if is_instance_valid(body) and body != self:
			if body.global_position.distance_to(global_position) <= psychic_push_range:
				var push_dir = (body.global_position - global_position).normalized()
				if body.has_method("apply_central_impulse"):
					body.apply_central_impulse(push_dir * psychic_push_force)
					pushed_count += 1
				elif "velocity" in body: # Fallback for non-rigid bodies
					body.velocity += push_dir * psychic_push_force * 0.5 # Adjust multiplier
					pushed_count += 1

	print("NeuroBoss: Pushed", pushed_count, "targets.")
	# State reset happens in _on_animation_player_finished

func _start_special_ability_timer():
	if special_ability_timer.is_stopped():
		special_ability_timer.wait_time = special_ability_cooldown
		special_ability_timer.start()
		print("NeuroBoss: Next special ability check in", special_ability_timer.wait_time, "s")

func _execute_special_ability():
	if is_dead or is_attacking or in_special_ability:
		print("NeuroBoss: Cannot use special - busy or dead.")
		_start_special_ability_timer()
		return

	# Choose ability (Example: 50/50 chance between catch and mind control)
	if randf() < 0.5 and phases_active["catch_bananas"]:
		perform_banana_catching_special()
	elif phases_active["mind_control"]:
		perform_mind_control()
	else: # Fallback if choices are disabled
		print("NeuroBoss: No special ability available/chosen.")
		_start_special_ability_timer() # Restart timer even if nothing happened
		return

	# Timer is restarted when the ability finishes in _on_animation_player_finished

func perform_banana_catching_special():
	print("NeuroBoss: Activating Enhanced Banana Catching.")
	in_special_ability = true
	velocity = Vector2.ZERO

	# Use expand animation
	play_animation_state("SpecialExpand", last_known_direction)

	# Temporarily boost detection area
	var original_scale = banana_detection_area.scale
	banana_detection_area.scale = original_scale * 2.0
	banana_detection_area.monitoring = true # Ensure it's active

	# Ability duration
	await get_tree().create_timer(4.0).timeout

	# Restore detection area (check if still valid)
	if is_instance_valid(banana_detection_area):
		banana_detection_area.scale = original_scale
		banana_detection_area.monitoring = false # Deactivate after use? Or keep monitoring?

	print("NeuroBoss: Enhanced Banana Catching finished.")
	# State reset happens in _on_animation_player_finished (when expand anim ends)
	_start_special_ability_timer() # Restart cooldown timer

func perform_mind_control():
	print("NeuroBoss: Activating Mind Control.")
	in_special_ability = true
	velocity = Vector2.ZERO

	play_animation_state("SpecialExpand", last_known_direction) # Reuse expand anim

	await get_tree().create_timer(0.5).timeout # Delay before effect

	var monkeys_in_range = []
	var troop_nodes = get_tree().get_nodes_in_group("troop")
	for monkey in troop_nodes:
		if is_instance_valid(monkey) and not controlled_monkeys.has(monkey):
			if monkey.global_position.distance_to(global_position) <= mind_control_range:
				monkeys_in_range.append(monkey)

	monkeys_in_range.sort_custom(Callable(self, "sort_by_distance")) # Control closest first

	var control_count = min(monkeys_in_range.size(), max_controlled_monkeys - controlled_monkeys.size())
	print("NeuroBoss: Found", monkeys_in_range.size(), "potential monkeys, controlling up to", control_count)

	for i in range(control_count):
		take_control_of_monkey(monkeys_in_range[i])

	# Duration timer for control
	if control_count > 0:
		await get_tree().create_timer(mind_control_duration).timeout
		release_all_controlled_monkeys()

	# State reset happens in _on_animation_player_finished
	_start_special_ability_timer() # Restart cooldown timer

func update_banana_orbit(delta: float):
	banana_rotation += banana_orbit_speed * delta

	var valid_bananas = []
	var needs_cleanup = false
	for banana in caught_bananas:
		if is_instance_valid(banana):
			valid_bananas.append(banana)
		else:
			needs_cleanup = true

	if needs_cleanup:
		caught_bananas = valid_bananas
		print("NeuroBoss: Cleaned up invalid orbiting bananas.")

	for i in range(caught_bananas.size()):
		var banana = caught_bananas[i]
		var angle = banana_rotation + (TAU * i / caught_bananas.size())
		var target_offset = Vector2.RIGHT.rotated(angle) * banana_orbit_radius
		var target_position = global_position + target_offset

		# Make banana smoothly follow orbit position
		banana.global_position = banana.global_position.lerp(target_position, 0.2)
		banana.rotation = angle + PI / 2 # Point outwards

func catch_banana(banana: Node2D):
	if not is_instance_valid(banana): return
	if caught_bananas.size() >= max_caught_bananas: return
	if caught_bananas.has(banana): return

	print("NeuroBoss: Catching banana:", banana.name)
	caught_bananas.append(banana)

	if banana.has_method("set_velocity"): 
		banana.set_velocity(Vector2.ZERO)
	elif "velocity" in banana: 
		banana.velocity = Vector2.ZERO

	if banana.get_parent():
		banana.get_parent().remove_child(banana)
	add_child(banana) # May need call_deferred if issues persist

	banana.set_meta("caught_by_boss", true)
	banana.set_deferred("collision_layer", 0)
	banana.set_deferred("collision_mask", 0)
	banana.modulate = Color(1.0, 0.7, 0.7) # Visual indicator

func take_control_of_monkey(monkey: Node2D):
	if not is_instance_valid(monkey): return
	if controlled_monkeys.has(monkey): return

	print("NeuroBoss: Taking control of monkey:", monkey.name)
	controlled_monkeys.append(monkey)
	monkey.set_meta("controlled_by_boss", true)
	monkey.modulate = Color(1.0, 0.5, 0.5) # Red tint

	# Remove from player troop if possible
	var player = find_player_node(get_tree().get_root())
	if player and player.has_method("remove_monkey"):
		player.remove_monkey(monkey)

	# Reparent to boss (or a dedicated node under boss)
	if monkey.get_parent():
		monkey.get_parent().remove_child(monkey)
	add_child(monkey)

	# TODO: Add AI for controlled monkey to attack player/troop
	if monkey.has_method("set_ai_state"):
		monkey.set_ai_state("attack_player")
	else: # Simple fallback: move towards player
		var target_pos = player.global_position if player else global_position + Vector2.LEFT * 100
		if "target_position" in monkey: monkey.target_position = target_pos

func release_all_controlled_monkeys():
	print("NeuroBoss: Releasing", controlled_monkeys.size(), "monkeys.")
	var player = find_player_node(get_tree().get_root())
	var scene_root = get_tree().current_scene

	for monkey in controlled_monkeys:
		if is_instance_valid(monkey):
			monkey.remove_meta("controlled_by_boss")
			monkey.modulate = Color(1, 1, 1) # Reset color

			if monkey.get_parent() == self:
				remove_child(monkey)

			# Add back to scene root initially
			if scene_root:
				scene_root.add_child(monkey)

			# Try adding back to player troop
			if player and player.has_method("add_monkey_to_swarm"):
				player.add_monkey_to_swarm(monkey) # Let player handle positioning
			else: # Place near player if troop add fails
				if player:
					monkey.global_position = player.global_position + Vector2(randf_range(-50,50), randf_range(-50,50))

			# TODO: Reset monkey AI state
			if monkey.has_method("set_ai_state"):
				monkey.set_ai_state("follow_player") # Or default state

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

	# TODO: Add health thresholds to change phases_active if desired
	# Example threshold changes:
	# if current_health < max_health * 0.75 and phases_active["mind_control"] == false:
	#     phases_active["mind_control"] = true
	#     print("NeuroBoss: Activating mind control phase!")

	if current_health <= 0:
		_die()
	else:
		# Damage flash
		modulate = Color(2, 0.5, 0.5) # Flash white/red
		await get_tree().create_timer(0.1).timeout
		modulate = Color(1, 1, 1) # Reset modulate

func _die():
	if is_dead: return
	print("NeuroBoss: Dying...")
	is_dead = true

	# Stop everything
	set_physics_process(false)
	velocity = Vector2.ZERO
	attack_timer.stop()
	special_ability_timer.stop()
	navigation_timer.stop()

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

	# Play death animation via AnimationTree
	play_animation_state("Die")
	# queue_free() happens in _on_animation_player_finished("die")

func find_player_node(root: Node) -> Node:
	# Optimized: Use get_nodes_in_group if player is in a group
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0]

	# Fallback recursive search (less efficient)
	if root.name == "Player" or root.is_in_group("player"): return root
	for child in root.get_children():
		var result = find_player_node(child)
		if result: return result
	return null

func find_or_create_projectiles_node() -> Node:
	var proj_node = get_tree().get_root().find_child("Projectiles", true, false) # Recursive, ignore owner
	if not proj_node:
		print("NeuroBoss: Projectiles node not found, creating one.")
		proj_node = Node2D.new()
		proj_node.name = "Projectiles"
		get_tree().get_root().add_child(proj_node)
	return proj_node

# Signal handlers

func _on_animated_sprite_2d_animation_finished() -> void:
	print("NeuroBoss: AnimatedSprite2D animation finished:", animated_sprite.animation)
	
	if animated_sprite.animation == "die":
		queue_free()
	elif animated_sprite.animation.begins_with("slash_") or animated_sprite.animation.begins_with("attack_"):
		if is_attacking:
			is_attacking = false
			update_animation_state()

func _on_hitbox_area_entered(area: Area2D):
	if is_dead: return

	# Catch friendly projectiles (bananas)
	if area.is_in_group("projectiles") and area.get_meta("friendly", true) and not area.get_meta("caught_by_boss", false):
		# Catch only during special or randomly
		if in_special_ability or randf() < 0.4: # 40% chance to catch normally
			print("NeuroBoss: Attempting to catch banana (Hitbox).")
			catch_banana(area)
		else: # Take damage if not caught
			var damage = 1.0 # Start with the default value
			if "damage" in area: # Check if the property 'damage' exists on the area node
				var potential_damage = area.get("damage") # Get the actual value
				# Optional but recommended: Check if the retrieved value is actually a number
				if typeof(potential_damage) == TYPE_FLOAT or typeof(potential_damage) == TYPE_INT:
					damage = float(potential_damage) # Use the actual value if it's a number

			print("NeuroBoss: Taking damage from friendly projectile:", damage)
			take_damage(damage)
			if area.has_method("queue_free"): area.queue_free()

func _on_banana_detection_area_area_entered(area: Area2D):
	if is_dead: return

	# Catch friendly projectiles (bananas) - Higher chance during special
	if area.is_in_group("projectiles") and area.get_meta("friendly", true) and not area.get_meta("caught_by_boss", false):
		if in_special_ability or randf() < 0.6: # Higher catch chance in detection zone
			print("NeuroBoss: Attempting to catch banana (Detection Area).")
			catch_banana(area)

func _on_hitbox_body_entered(body: Node2D):
	if is_dead or is_attacking or in_special_ability: return

	# Trigger melee if player/troop gets too close
	if body.is_in_group("player") or body.is_in_group("troop"):
		print("NeuroBoss: Player/Troop entered hitbox:", body.name)
		if randf() < 0.75: # High chance to melee when body enters
			perform_melee_attack()

func _on_hitbox_body_exited(body: Node2D) -> void:
	print("NeuroBoss: Body exited hitbox:", body.name)
	# You can add any special logic when objects leave the hitbox
	# For example, you might want to stop tracking certain targets

func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	print("NeuroBoss: AnimationTree finished animation:", anim_name)
	
	# This method complements _on_animation_player_finished
	# It's useful when animation signals come directly from the AnimationTree
	# rather than from the AnimationPlayer
	
	# Some AnimationTree setups may trigger this signal instead of the AnimationPlayer one
