extends CharacterBody2D
## Terminator boss enemy that shoots at the player and has various attacks.
##
## The Terminator boss has multiple attacks that it can use against the player.
## These attacks include shooting projectiles, spawning buttons, and creating
## electric forcefields. The boss will randomly choose an attack to use at
## regular intervals.

@onready var _animated_sprite = $AnimatedSprite2D

@export var electro_laser_scene: PackedScene

## Scene for the taser projectile
@export var taser_projectile_scene: PackedScene

## Scene for the button that the boss can spawn
@export var button_scene: PackedScene

## Scene for the electric forcefield
@export var electric_forcefield_scene: PackedScene

## Reference to the health bar for the boss.
@onready var health_bar = $HealthBar

## Maximum health
@export var max_health: int = 150

## Current health
var current_health: float

## Minimum interval between attacks
@export var min_attack_interval: float = 3.0

## Maximum interval between attacks
@export var max_attack_interval: float = 8.0

## The current waypoint the boss is moving to
var current_target: Vector2 = Vector2.ZERO

## Speed of movement
@export var move_speed: float = 150.0

## How close to the target before picking a new one
@export var proximity_threshold: float = 10.0

## Minimum wait time between moves
@export var min_wait_time: float = 0.8

## Maximum wait time between moves
@export var max_wait_time: float = 2.5

## The last played animation
var last_animation: String = "idle_down"

## Tracks if the forcefield is active
var has_forcefield: bool = false

## Timer for attack intervals
var attack_timer: Timer

## Prevents walking animations from overwriting attack animations
var is_attacking: bool = false


## Initialize the boss
func _ready() -> void:
	print("TerminatorBoss was spawned at runtime!")
	current_health = max_health
	health_bar.init_health(current_health)

	attack_spawn_buttons_with_forcefield()
	move_to_next_waypoint()

	# Initialize attack timer
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.connect("timeout", Callable(self, "_choose_and_execute_attack"))
	_start_random_attack_timer()


## Choose a random waypoint within the bounds of the room
## FIX: make this dymanic based on the room size instead of hardcoded
func choose_random_waypoint() -> Vector2:
	var min_x = 24 + 50
	var max_x = 1133 - 50
	var min_y = -800 + 50
	var max_y = -51 - 50

	# Randomly select a new waypoint
	return Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))


## Move the boss to the next waypoint
func move_to_next_waypoint() -> void:
	# Choose a random waypoint and start moving toward it
	current_target = choose_random_waypoint()


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# If we have a target waypoint, move toward it
	if current_target != Vector2.ZERO:
		var direction = (current_target - global_position).normalized()
		velocity = direction * move_speed
		# Determine the animation to play based on movement direction
		if not is_attacking:
			if abs(direction.x) > abs(direction.y):  # Horizontal movement
				if direction.x > 0:
					play_animation("walk_right")  # Moving right
				else:
					play_animation("walk_left")  # Moving left
			else:  # Vertical movement
				if direction.y > 0:
					play_animation("walk_down")  # Moving down
				else:
					play_animation("walk_up")  # Moving up

	# Apply movement
		move_and_slide()

	# Check if we've reached the waypoint
		if global_position.distance_to(current_target) <= proximity_threshold:
			velocity = Vector2.ZERO  # Stop moving
			current_target = Vector2.ZERO  # Clear the target
			play_idle_animation()
			start_wait_timer()  # Start a timer for the next movement
	else:
		velocity = Vector2.ZERO  # No movement when no target
		play_idle_animation()  # Ensure the boss is idle

## Start a timer to wait before moving to the next waypoint
func start_wait_timer():
	# Wait for a random interval, then move to the next waypoint
	var wait_time = randf_range(min_wait_time, max_wait_time)
	await get_tree().create_timer(wait_time).timeout
	move_to_next_waypoint()


## Recursively searches for the Player node starting from the given root node.
## Returns the Player node if found, otherwise returns null.
## @param root: The root node to start the search from.
## @return The Player node if found, otherwise null.
func find_player_node(root: Node) -> Node:
	# Check if the current node is the Player
	if root.name == "Player":
		return root

	# Recursively search through all children
	for child in root.get_children():
		var result = find_player_node(child)
		if result:
			return result

	# If no Player node is found, return null
	return null


func createTaserProj(projectile):
	var taser_proj = get_parent().get_node("TaserProjectiles")
	taser_proj.add_child(projectile)


# --------------------------------------------------
# Attack 1: Single Projectile Towards Player
# --------------------------------------------------
func attack_shoot_at_player():
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	var player = find_player_node(get_tree().get_root())
	if not player:
		print("Player not found!")
		return

	# Spawn the taser projectile
	var projectile = taser_projectile_scene.instantiate()
	createTaserProj(projectile)

	# Set the attacking flag to true
	is_attacking = true

	# Calculate direction to the player and set projectile velocity
	projectile.scale = Vector2(2.25,2.25)
	var direction = (player.global_position - global_position).normalized()
	projectile.global_position = global_position
	projectile.velocity = direction * projectile.speed

	# Play the appropriate animation based on direction
	play_spell_animation(direction)
	# Wait for the attack animation to finish
	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag

func attack_burst_shoot_at_player(burst_count: int = 3, delay: float = 0.1) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	var player = find_player_node(get_tree().get_root())
	if not player:
		print("Player not found!")
		return

	var direction = (player.global_position - global_position).normalized()

	# Set the attacking flag to true
	is_attacking = true

	# Fire `burst_count` projectiles with a delay
	for i in range(burst_count):
		await get_tree().create_timer(delay).timeout

		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		createTaserProj(projectile)

		# Calculate direction to the player and set projectile velocity
		projectile.scale = Vector2(2.25,2.25)
		direction = (player.global_position - global_position).normalized()
		projectile.global_position = global_position
		projectile.velocity = direction * projectile.speed
	play_spell_animation(direction)
	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag


func attack_spread_shoot_at_player(spread_count: int = 5, angle_range: float = PI / 2) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	var player = find_player_node(get_tree().get_root())
	if not player:
		print("Player not found!")
		return

	# Calculate the base direction to the player
	var base_direction = (player.global_position - global_position).normalized()
	var base_angle = base_direction.angle()

	# Set the attacking flag to true
	is_attacking = true

	# Fire `spread_count` projectiles across the angle range
	for i in range(spread_count):
		# Calculate the angle for this projectile
		var angle_offset = lerp(-angle_range / 2, angle_range / 2, float(i) / (spread_count - 1))
		var projectile_angle = base_angle + angle_offset

		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		createTaserProj(projectile)

		# Set its position and velocity
		projectile.scale = Vector2(2.25, 2.25)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(projectile_angle) * projectile.speed

	play_spell_animation(base_direction)
	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag

func attack_circular_shoot(num_projectiles: int = 8) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	# Set the attacking flag to true
	is_attacking = true
	# Fire `num_projectiles` in a circular pattern
	for i in range(num_projectiles):
		# Calculate the angle for this projectile
		var angle = TAU * float(i) / num_projectiles

		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		createTaserProj(projectile)

		# Set its position and velocity
		projectile.scale = Vector2(2.25,2.25)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(angle) * projectile.speed

	play_animation("slash_down")
	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag

var spiral_angle: float = 0.0  # Keeps track of the current angle

func attack_spiral_shoot(num_projectiles: int = 16, spiral_speed: float = 0.1) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	# Set the attacking flag to true
	is_attacking = true

	play_animation("slash_down")
	# Fire projectiles in a rotating spiral
	for i in range(num_projectiles):
		await get_tree().create_timer(spiral_speed).timeout

		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		createTaserProj(projectile)

		# Calculate the angle for this projectile
		spiral_angle += TAU / num_projectiles  # Increment the spiral angle
		var direction = Vector2.RIGHT.rotated(spiral_angle)

		# Set the projectile's position and velocity
		projectile.scale = Vector2(2.25,2.25)
		projectile.speed = 275.0
		projectile.global_position = global_position
		projectile.velocity = direction * projectile.speed


	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag


func attack_horizontal_wall(num_projectiles: int = 10, spacing: float = 200.0) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	# Set the attacking flag to true
	is_attacking = true

	var player = find_player_node(get_tree().get_root())

	if not player:
		print("Player not found!")
		return


	# Determine starting y position (farthest from the player)
	var start_y: float
	var direction: Vector2

	if abs(-800 - player.global_position.y) > abs(-51 - player.global_position.y):
		start_y = -800  # Farthest top
		direction = Vector2(0, 1)  # Move downward
	else:
		start_y = -51  # Farthest bottom
		direction = Vector2(0, -1)  # Move upward

	# Calculate the horizontal center (midpoint) of the range
	var horizontal_center_x = (24 + 1133) / 2.0

	# Calculate the starting position of the wall
	var start_position = Vector2(horizontal_center_x - (num_projectiles - 1) * spacing / 2, start_y)

	# Spawn projectiles in a horizontal line
	for i in range(num_projectiles):
		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		createTaserProj(projectile)

		# Set the projectile's position and velocity
		projectile.lifetime = 10.0
		projectile.scale = Vector2(2, 2)
		projectile.global_position = start_position + Vector2(i * spacing, 0)
		projectile.velocity = direction * projectile.speed

	play_spell_animation(direction)
	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag

func attack_vertical_wall(num_projectiles: int = 10, spacing: float = 150.0) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	# Set the attacking flag to true
	is_attacking = true

	var player = find_player_node(get_tree().get_root())
	if not player:
		print("Player not found!")
		return

	# Determine starting x position (farthest from the player)
	var start_x: float
	var direction: Vector2


	if abs(24 - player.global_position.x) > abs(1133 - player.global_position.x):
		start_x = 24  # Farthest left
		direction = Vector2(1, 0)  # Move right
	else:
		start_x = 1133  # Farthest right
		direction = Vector2(-1, 0)  # Move left

	# Calculate the vertical center (midpoint) of the range
	var vertical_center_y = (-800 + -51) / 2.0

	# Calculate the starting position of the wall
	var start_position = Vector2(start_x, vertical_center_y - (num_projectiles - 1) * spacing / 2)

	# Spawn projectiles in a vertical line
	for i in range(num_projectiles):
		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		createTaserProj(projectile)

		# Set the projectile's position and velocity
		projectile.lifetime = 10.0
		projectile.scale = Vector2(2,2)
		projectile.global_position = start_position + Vector2(0, i * spacing)
		projectile.velocity = direction * projectile.speed

	play_spell_animation(direction)
	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag

func spawn_electro_lasers():
	if not electro_laser_scene:
		print("Electro Laser scene not set!")
		return

	# Set the attacking flag to true
	is_attacking = true

	var electro_laser_node = get_parent().get_node("ElectroLasers")
	# Spawn vertical laser
	print("Spawning vertical laser")
	var vertical_laser = electro_laser_scene.instantiate()
	electro_laser_node.add_child(vertical_laser)  # Add as child of the boss

	# Set the correct global position for the vertical laser
	var random_x = randf_range(24, 1133) #1238
	vertical_laser.global_position = Vector2(random_x, -426)  # Exact global position
	vertical_laser.scale = Vector2(3, 28.6)  # Proper scale
	print("Vertical laser global position: ", vertical_laser.global_position, " scale: ", vertical_laser.scale)

	# Spawn horizontal laser
	print("Spawning horizontal laser")
	var horizontal_laser = electro_laser_scene.instantiate()
	electro_laser_node.add_child(horizontal_laser)  # Add as child of the boss

	# Set the correct global position for the horizontal laser
	var random_y = randf_range(-800, -51)
	horizontal_laser.global_position = Vector2(577, random_y)  # Exact global position
	horizontal_laser.scale = Vector2(3, 41.2)  # Proper scale
	horizontal_laser.rotation = deg_to_rad(90)  # Rotate horizontal laser
	print("Horizontal laser global position: ", horizontal_laser.global_position, " scale: ", horizontal_laser.scale)

	play_animation("slash_down")
	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag

func delete_electro_lasers():
	var electro_laser_node = get_parent().get_node("ElectroLasers")
	for child in electro_laser_node.get_children():
		child.queue_free()

func attack_electro_laser():
	# Spawn the lasers using the existing function
	spawn_electro_lasers()

	# Wait for 10 seconds, then delete the lasers
	await get_tree().create_timer(10.0).timeout
	delete_electro_lasers()

func attack_spawn_buttons_with_forcefield():
	if not button_scene or not electric_forcefield_scene:
		print("Button or Forcefield scene not set!")
		return

	# Spawn the electric forcefield on the boss
	var forcefield = electric_forcefield_scene.instantiate()
	add_child(forcefield)
	forcefield.scale = Vector2(2,2.5)
	forcefield.global_position = Vector2(global_position.x, global_position.y + 20)  # Place forcefield at boss position
	has_forcefield = true
	print("Spawned forcefield at position: ", forcefield.global_position)

	   # Find the parent node to attach the buttons
	var boss_button_node = get_parent().get_node("BossButtons")
	if not boss_button_node:
		print("Failed to find the room node!")
		forcefield.queue_free()  # Remove forcefield if no parent node is found
		has_forcefield = false
		return

	# Spawn the two buttons at valid random positions
	var button_positions = calculate_button_positions()
	if button_positions.size() == 0:
		print("Failed to calculate valid button positions!")
		forcefield.queue_free()  # Remove forcefield if button spawning fails
		has_forcefield = false
		return

	# Set the attacking flag to true
	is_attacking = true

	var buttons = []  # Store the button instances
	for pos in button_positions:
		var button = button_scene.instantiate()
		boss_button_node.add_child(button)
		button.scale = Vector2(1.2, 1.2)
		button.global_position = pos
		buttons.append(button)
		print("Spawned button at position: ", pos)
		print("Button visibility:", button.visible)
		# Create a dictionary to track button states

	var button_states = {}
	for button in buttons:
		button_states[button] = false  # Initially all buttons are unpressed
		button.connect("button_state_changed", Callable(self, "_on_button_state_changed").bind(button, button_states, forcefield))


	play_animation("spell_down")
	await _animated_sprite.animation_finished
	is_attacking = false  # Reset attacking flag

func calculate_button_positions() -> Array:
	var min_x = 24
	var max_x = 1133
	var min_y = -800
	var max_y = -51

	# Generate a random position for the first button
	var pos1 = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))

	# Generate a random offset for the second button, ensuring the distance is 250-300
	var offset = randf_range(250, 300)
	var angle = randf_range(0, TAU)  # Random angle in radians

	# Calculate the second position using the offset and angle
	var pos2 = pos1 + Vector2(cos(angle), sin(angle)) * offset

	# Clamp the second position to keep it within bounds
	pos2.x = clamp(pos2.x, min_x, max_x)
	pos2.y = clamp(pos2.y, min_y, max_y)

	# Return the two positions
	return [pos1, pos2]

# Handle button press events
func _on_button_state_changed(is_pressed: bool, button: Node, button_states: Dictionary, forcefield: Node2D) -> void:
	# Update the specific button's state
	button_states[button] = is_pressed

	# Check if all buttons are pressed
	if all_buttons_pressed(button_states):
		print("All buttons pressed! Removing forcefield.")
		forcefield.queue_free()
		has_forcefield = false
		# Clean up all buttons
		for button_instance in button_states.keys():
			button_instance.queue_free()

# Helper to check if all buttons are pressed
func all_buttons_pressed(button_states: Dictionary) -> bool:
	# Check if all buttons in the dictionary are pressed
	for button in button_states:
		if not button_states[button]:
			return false
	return true


func take_damage(amount: float) -> void:
	if has_forcefield:
		return

	current_health -= amount
	# Check if the boss is dead
	if health_bar:
		health_bar.value = current_health

	if current_health <= 0:
		die()

	if (float(current_health) / float(max_health)) <= 0.5:
		for attack in attacks:
			if attack.unlocked == false:
				attack.unlocked = true

	health_bar.health = current_health

func die() -> void:
	queue_free()  # Remove the boss from the scene

# Helper to play animations and track the last one
func play_animation(animation_name: String) -> void:
	var animated_sprite = $AnimatedSprite2D  # Adjust this path if needed
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
		last_animation = animation_name

# Helper to play the idle animation based on the last animation
func play_idle_animation() -> void:
	if "down" in last_animation:
		play_animation("idle_down")
	elif "up" in last_animation:
		play_animation("idle_up")
	elif "left" in last_animation:
		play_animation("idle_left")
	elif "right" in last_animation:
		play_animation("idle_right")
	else:
		play_animation("idle_down")  # Default idle if no direction found

func play_spell_animation(direction):
	if abs(direction.x) > abs(direction.y):  # Horizontal movement
		if direction.x > 0:
			play_animation("spell_right")  # Moving right
		else:
			play_animation("spell_left")  # Moving left
	else:  # Vertical movement
		if direction.y > 0:
			play_animation("spell_down")  # Moving down
		else:
			play_animation("spell_up")  # Moving up


###
# ATTACK LOGIC
###
var attacks = [
	{
		"name": "attack_shoot_at_player",
		"function": Callable(self, "attack_shoot_at_player"),
		"weight": 3,  # Probability weight
		"unlocked": true  # Initially available
	},
	{
		"name": "attack_burst_shoot_at_player",
		"function": Callable(self, "attack_burst_shoot_at_player"),
		"weight": 2,
		"unlocked": true
	},
	{
		"name": "attack_spread_shoot_at_player",
		"function": Callable(self, "attack_spread_shoot_at_player"),
		"weight": 3,
		"unlocked": true  # Unlock later
	},
	{
		"name": "attack_circular_shoot",
		"function": Callable(self, "attack_circular_shoot"),
		"weight": 2,
		"unlocked": true  # Unlock later
	},
	{
		"name": "attack_spiral_shoot",
		"function": Callable(self, "attack_spiral_shoot"),
		"weight": 5,
		"unlocked": false  # Unlock later
	},
	{
		"name": "attack_horizontal_wall",
		"function": Callable(self, "attack_horizontal_wall"),
		"weight": 4,
		"unlocked": false  # Unlock later
	},
	{
		"name": "attack_vertical_wall",
		"function": Callable(self, "attack_vertical_wall"),
		"weight": 4,
		"unlocked": false  # Unlock later
	},
	{
		"name": "attack_electro_laser",
		"function": Callable(self, "attack_electro_laser"),
		"weight": 12,
		"unlocked": false  # Unlock later
	},
	{
		"name": "attack_spawn_buttons_with_forcefield",
		"function": Callable(self, "attack_spawn_buttons_with_forcefield"),
		"weight": 0.5,
		"unlocked": true  # Unlock later
	}
]


func _start_random_attack_timer():
	# Set the timer with a random interval between min and max
	var wait_time = randf_range(min_attack_interval, max_attack_interval)
	attack_timer.wait_time = wait_time
	attack_timer.start()
	print("Attack timer started, next attack in ", wait_time, " seconds")

@export var quick_succession_chance: float = 0.25  # 30% chance for a quick follow-up attack
@export var quick_succession_delay: float = 0.8  # Delay between the successive attacks

func _choose_and_execute_attack():
	# Filter unlocked attacks
	var available_attacks = []
	for attack in attacks:
		if attack.unlocked:
			available_attacks.append(attack)

	if available_attacks.size() == 0:
		print("No available attacks!")
		_start_random_attack_timer()  # Restart main timer for the next cycle
		return

	# Calculate total weight
	var total_weight = 0
	for attack in available_attacks:
		total_weight += attack.weight

	# Randomly select an attack based on weights
	var random_value = randf() * total_weight
	var cumulative_weight = 0

	for attack in available_attacks:
		cumulative_weight += attack.weight
		if random_value <= cumulative_weight:
			# Check if forcefield is active and the attack is forcefield-related
			if has_forcefield and attack.name == "attack_spawn_buttons_with_forcefield":
				print("Forcefield is active, skipping attack_spawn_buttons_with_forcefield")
				_start_random_attack_timer()  # Restart main timer
				return  # Exit this function cleanly

			# Execute the chosen attack
			attack.function.call()

			# Check for quick succession (but do NOT reset the main timer)
			if randf() < quick_succession_chance:
				print("Quick succession triggered!")
				await _perform_quick_succession_attack(available_attacks)

			break

	# Start the main timer again for the next attack
	_start_random_attack_timer()

func _perform_quick_succession_attack(available_attacks: Array) -> void:
	# Wait for the quick succession delay
	await get_tree().create_timer(quick_succession_delay).timeout

	# Recalculate total weight for available attacks
	var total_weight = 0
	for attack in available_attacks:
		total_weight += attack.weight

	# Randomly select a second attack
	var random_value = randf() * total_weight
	var cumulative_weight = 0

	for attack in available_attacks:
		cumulative_weight += attack.weight
		if random_value <= cumulative_weight:
			# Ensure the second attack isn't the forcefield if already active
			if has_forcefield and attack.name == "attack_spawn_buttons_with_forcefield":
				print("Skipping forcefield attack in quick succession")
				return  # Skip quick succession in this case

			# Execute the second attack
			attack.function.call()
			break
