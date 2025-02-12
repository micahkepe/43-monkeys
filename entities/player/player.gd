extends CharacterBody2D
## Represents a 2D player character in the game.
##
## The player character is controlled by the player and can move in four
## directions (up, down, left, right). The player's movement is controlled by
## input mappings defined in the project settings for the following actions:
## "ui_right" "ui_left" "ui_up" "ui_down"
##
## @tutorial: https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html

## The AnimatedSprite2D node that displays the player's sprite.
## Controls:
##   W/A/S/D => Move Player
##   X       => Rotate swarm slowly (clockwise)
##   Shift+X => Rotate swarm 90° instantly
##   Space   => Toggle swarm lock/unlock
##   Shift+WASD => Translate swarm center up/down/left/right
##   Shift+I => Increase ellipse height
##   Shift+K => Decrease ellipse height
##   Shift+J => Decrease ellipse width
##   Shift+L => Increase ellipse width
##   I/K/J/L => Shoot up/down/left/right
@onready var _animated_sprite = $AnimatedSprite2D

## The base speed at which the player moves
@export
var speed: float = 300.0

## The multiplier applied to speed when sprinting
@export
var sprint_multiplier: float = 1.5

## The current shoot cooldown
var _current_shoot_cooldown: float

## The time taken between each shot
@export
var shoot_cooldown_duration: float = 0.25

## Bannana boomerang scene
@export
var banana_boomerang_scene: PackedScene

@export
var blindness_overlay_scene: PackedScene


# -----------------------------------------------------------------
# TROOP VARIABLES
# -----------------------------------------------------------------

## The available variants of the monkeys to populate the troop.
@export var monkey_scenes: Array[PackedScene] = []

## [DEBUG] The initial amount of monkeys in the troop.
## The troop will need to be collected by the player and have continuity
# between levels.
@export
var initial_troop_amount: int = 0

## The scale of the troop ellipse along the x-axis
@export
var ellipse_width_scale: float = 100.0

## The scale of the troop ellipse along the y-axis
@export
var ellipse_height_scale: float = 100.0

## Whether swarm is "locked" (Does not move with player on WASD)
var _swarm_locked: bool = false

## SwarmMonkeys root node
@onready var _swarm_monkeys_root: Node2D = $SwarmMonkeys

## Additional offset from the player's position
## (Changed by U, O, H, ;)
var _swarm_center_offset: Vector2 = Vector2.ZERO

## Each entry: { "node": <DefaultMonkey>, "angle": float (0..X) }
var _swarm_monkeys: Array = []

## The center of the swarm/troop ellipse
var _swarm_world_center: Vector2

## The rotation of the swarm ellipse
var _swarm_rotation: float = 0.0

# Store flag to indicate if a full ellipse recalc is needed
var _needs_full_ellipse_recalc: bool = false

## Constant vector for upward world direction.
const WORLD_UP = Vector2(0, -1)

## Constant vector for downward world direction.
const WORLD_RIGHT = Vector2(1, 0)

# Health variables.

## The maximum health of the player character (in half-hearts).
var max_health: float = 6.0  # 6 half-hearts = 3 full hearts

## The current health of the player character (in half-hearts).
var _current_health: float = 6.0

## The time between damage ticks.
var _damage_cooldown: float = 1.0

## The current cooldown for taking damage.
var _current_cooldown: float = 0.0

## The UI container for the player's health display.
@onready var hearts_container = $PlayerUI/HeartsContainer

# Monkey counter for number of monkeys in group, including the main monkey.
@onready var monkey_counter_label: Label = $PlayerUI/MonkeyCounter
signal monkey_count_changed(new_count: int)

# -----------------------------------------------------------------

## Called when the node enters the scene tree for the first time.
## Initializes any setup required for the player character.
func _ready() -> void:
	## Set the player's initial position
	_swarm_world_center = global_position

	# Pre-spawn the entire troop at the start
	for i in range(initial_troop_amount):
		add_monkey_to_swarm()

	# Update positions after adding all monkeys
	_update_swarm_positions()

	if !hearts_container:
		print_debug("Hearts container not found!")
		return

	_current_health = max_health
	update_hearts_display()
	monkey_count_changed.connect(_update_monkey_counter)

	# Initialize the counter
	_update_monkey_counter(_swarm_monkeys.size())
	
	apply_blindness(100.0)


## Called when there is an input event. The input event propagates up through
## the node tree until a node consumes it.
func _input(event):
	if event.is_action_pressed("toggle_full_screen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Update the monkey group number
## @param count: int - The number of monkeys in the group.
func _update_monkey_counter(count: int) -> void:
	if monkey_counter_label:
		monkey_counter_label.text = "%d/43" % (count + 1)

## Called every frame.
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame in seconds.
func _physics_process(_delta: float) -> void:
	## The player's current velocity
	var input_velocity = Vector2.ZERO
	var current_speed = speed

	# Movement input
	if Input.is_action_pressed("ui_right") and (not Input.is_key_pressed(KEY_SHIFT) or len(_swarm_monkeys) == 0):
		input_velocity.x += 1
	if Input.is_action_pressed("ui_left") and (not Input.is_key_pressed(KEY_SHIFT) or len(_swarm_monkeys) == 0):
		input_velocity.x -= 1
	if Input.is_action_pressed("ui_up") and (not Input.is_key_pressed(KEY_SHIFT) or len(_swarm_monkeys) == 0):
		input_velocity.y -= 1
	if Input.is_action_pressed("ui_down") and (not Input.is_key_pressed(KEY_SHIFT) or len(_swarm_monkeys) == 0):
		input_velocity.y += 1

	# Normalize diagonal movement
	if input_velocity != Vector2.ZERO:
		input_velocity = input_velocity.normalized()

	## Set animation based on movement direction
	if input_velocity.y < 0:
		_animated_sprite.play("walk_up")
	elif input_velocity.y > 0:
		_animated_sprite.play("walk_down")
	elif input_velocity.x > 0:
		_animated_sprite.play("walk_right")
	elif input_velocity.x < 0:
		_animated_sprite.play("walk_left")
	else:
		_animated_sprite.stop()

	## Set the velocity and move the character
	velocity = input_velocity * current_speed
	move_and_slide()

	# Decrement the shoot cooldown
	if _current_shoot_cooldown > 0.0:
		_current_shoot_cooldown -= _delta
		if _current_shoot_cooldown < 0.0:
			_current_shoot_cooldown = 0.0

	# Handle banana shooting
	_handle_shooting()

	var swarm_modified = handle_swarm_input(_delta)

	# If swam unlocked, move with WASD as the player moves
	if not _swarm_locked and input_velocity != Vector2.ZERO:
		# Animate the monkeys in the correct direction
		if input_velocity.y < 0:
			_swarm_monkeys_walk_up()
		elif input_velocity.y > 0:
			_swarm_monkeys_walk_down()
		elif input_velocity.x > 0:
			_swarm_monkeys_walk_right()
		elif input_velocity.x < 0:
			_swarm_monkeys_walk_left()
		swarm_modified = true
	# If no movement keys pressed, stop monkey animations
	elif not swarm_modified:
		_swarm_monkeys_stop_walk()

	# If changed rotation/size, do angle recalc
	if _needs_full_ellipse_recalc:
		_update_swarm_positions()

	if _current_cooldown > 0:
		_current_cooldown -= _delta


## Instantiates a new DefaultMonkey and evenly distributes the group across the
## ellipse
## @param existing_monkey: Node2D - The existing monkey to add to the swarm.
## If null, a new monkey will be instantiated.
func add_monkey_to_swarm(existing_monkey: Node2D = null) -> void:
	var new_monkey: Node2D

	if existing_monkey:
		var curr_global_pos = existing_monkey.global_position
		print_debug("first global pos:", curr_global_pos)
		new_monkey = existing_monkey
		print_debug("Adding existing monkey to swarm!")

		# Remove from the old parent safely.
		if new_monkey.get_parent():
			new_monkey.get_parent().remove_child(new_monkey)

		# Add to the swarm root.
		_swarm_monkeys_root.add_child(new_monkey)

		# Reapply the stored global transform to preserve its world position.
		new_monkey.global_position = curr_global_pos
	else:
		if monkey_scenes.is_empty():
			print_debug("No monkey scenes available!")
			return

		var new_monkey_scene = monkey_scenes[randi() % monkey_scenes.size()]
		new_monkey = new_monkey_scene.instantiate()
		new_monkey.scale = Vector2(2.5, 2.5)
		print_debug("Spawning a new monkey for the swarm!")
		_swarm_monkeys_root.add_child(new_monkey)
		# new_monkey will be positioned based on its scene settings.

	new_monkey.scale = Vector2(2.5, 2.5)

	# Determine a new angle for the monkey in the swarm.
	var count = _swarm_monkeys.size()
	var new_angle = 0.0
	if count >= 1:
		new_angle = float(count) / float(count + 1) * TAU

	# Add the monkey along with a transitioning flag so it will walk to its target.
	_swarm_monkeys.append({
		"node": new_monkey,
		"angle": new_angle,
		"transitioning": true  # This flag can be used to control movement speed.
	})

	# Recalculate angles for an even distribution.
	var total = float(_swarm_monkeys.size())
	for i in range(_swarm_monkeys.size()):
		var fraction = float(i) / total
		_swarm_monkeys[i]["angle"] = fraction * TAU

	print_debug("end global pos:", new_monkey.global_position)
	_needs_full_ellipse_recalc = true  # Flag to update positions on the ellipse.
	monkey_count_changed.emit(_swarm_monkeys.size())
	print_debug("Monkey added to swarm! Total monkeys: ", _swarm_monkeys.size())


## Positions each monkey on the ellipse boundary using their angle, plus
## '_swarm_center_offset', plus Player.global_position
func _update_swarm_positions() -> void:
	if not _swarm_locked:
		var center_offset = _swarm_center_offset.rotated(_swarm_rotation)
		_swarm_world_center = global_position + center_offset

	for entry in _swarm_monkeys:
		var angle = entry["angle"]
		var monkey = entry["node"]

		# Calculate target position on the ellipse:
		var x_component = Vector2(1, 0).rotated(_swarm_rotation) * ellipse_width_scale * cos(angle)
		var y_component = Vector2(0, 1).rotated(_swarm_rotation) * ellipse_height_scale * sin(angle)
		var target_position = _swarm_world_center + x_component + y_component

		# Calculate how far the monkey is from its target:
		var to_target = target_position - monkey.global_position
		var _move_direction = to_target.normalized()

		# If the monkey is close enough, stop its movement:
		if to_target.length() < 5.0:
			monkey.velocity = Vector2.ZERO
			# Remove the transitioning flag if present
			if entry.has("transitioning"):
				entry["transitioning"] = false
		else:
			# Use a slower speed if the monkey is transitioning
			var move_speed = speed
			if entry.has("transitioning") and entry["transitioning"]:
				move_speed = speed * 0.75  # Adjust this multiplier as needed

			var direction = to_target.normalized()
			monkey.velocity = direction * move_speed

			# Determine movement direction
			if direction.x > 0 and direction.y < 0:
				if monkey.has_method("walk_up_right"):
					monkey.walk_up_right()
			elif direction.x > 0 and direction.y > 0:
				if monkey.has_method("walk_down_right"):
					monkey.walk_down_right()
			elif direction.x < 0 and direction.y < 0:
				if monkey.has_method("walk_up_left"):
					monkey.walk_up_left()
			elif direction.x < 0 and direction.y > 0:
				if monkey.has_method("walk_down_left"):
					monkey.walk_down_left()
			elif abs(direction.x) > abs(direction.y):
				if direction.x > 0:
					if monkey.has_method("walk_right"):
						monkey.walk_right()
					else:
						if monkey.has_method("walk_left"):
							monkey.walk_left()
			else:
				if direction.y > 0:
					if monkey.has_method("walk_down"):
						monkey.walk_down()
					else:
						if monkey.has_method("walk_up"):
							monkey.walk_up()

		monkey.move_and_slide()


## Translates all monkeys by the same offset for WASD movement or swarm keys
## @param global_dir: Vector2 - The global direction to move the swarm
## @param delta: float - The distance to move the swarm
func _shift_swarm_position(global_dir: Vector2, delta: float) -> void:
	# Convert the global direction to the swarm's local space using the inverse rotation
	var local_dir = global_dir.rotated(-_swarm_rotation)
	var shift_vector = local_dir.normalized() * delta

	# Update the swarm center offset for future calculations
	_swarm_center_offset += shift_vector

	# Update each monkey's position based on the shift
	for entry in _swarm_monkeys:
		var monkey = entry["node"]

		# Move each monkey towards its new global position
		var target_position = monkey.global_position + shift_vector

		# Calculate the difference to the target
		var to_target = target_position - monkey.global_position

		# Add a threshold to avoid unnecessary movement
		if to_target.length() < 5.0:  # Small threshold to avoid jittering
			monkey.velocity = Vector2.ZERO
		else:
			# Move toward the target using velocity
			var direction = to_target.normalized()
			monkey.velocity = direction * 450

		# Apply velocity with move_and_slide for collision handling
		monkey.move_and_slide()


##
# Checks keys for ellipse rotation, resizing, lock toggle, and manual swarm
# translation.
# Returns 'true' if any translation or animation occured on the swarm in this
# frame
##
func handle_swarm_input(_delta: float) -> bool:
	var swarm_moved = false

	# Rotations keys
	if Input.is_action_pressed("rotate_swarm_clockwise"):
		# Rotate the transformation matrix
		var rotation_speed = 1.75 * _delta
		_swarm_rotation += rotation_speed

		# Adjust the center offset to rotate around the player
		_swarm_center_offset = _swarm_center_offset.rotated(rotation_speed)

		_needs_full_ellipse_recalc = true
		swarm_moved = true


	# Handle troop lock
	# If the "toggle_lock" key is pressed, toggle the swarm lock state, NOT HELD
	if Input.is_action_just_pressed("toggle_lock"):
		var was_locked = _swarm_locked
		_swarm_locked = not _swarm_locked

		if was_locked and not _swarm_locked:
			_swarm_center_offset = (_swarm_world_center - global_position).rotated(-_swarm_rotation)

		swarm_moved = true #maybe delete


	# Manual Swarm Translation (Shift + WASD)
	if Input.is_action_pressed("translate_up") and len(_swarm_monkeys) > 0:
		_swarm_monkeys_walk_up()
		_shift_swarm_position(Vector2(0, -1), 200.0 * _delta)
		swarm_moved = true
	if Input.is_action_pressed("translate_down") and len(_swarm_monkeys) > 0:
		_swarm_monkeys_walk_down()
		_shift_swarm_position(Vector2(0, 1), 200.0 * _delta)
		swarm_moved = true
	if Input.is_action_pressed("translate_left") and len(_swarm_monkeys) > 0:
		_swarm_monkeys_walk_left()
		_shift_swarm_position(Vector2(-1, 0), 200.0 * _delta)
		swarm_moved = true
	if Input.is_action_pressed("translate_right") and len(_swarm_monkeys) > 0:
		_swarm_monkeys_walk_right()
		_shift_swarm_position(Vector2(1, 0), 200.0 * _delta)
		swarm_moved = true

	# Ellipse resizing
	if Input.is_action_pressed("inc_height_ellipse"):
		_adjust_ellipse_global(Vector2(0, 1), +200.0 * _delta)  # Stretch along global y-axis
		_needs_full_ellipse_recalc = true
		swarm_moved = true

	if Input.is_action_pressed("dec_height_ellipse"):
		_adjust_ellipse_global(Vector2(0, 1), -200.0 * _delta)  # Shrink along global y-axis
		_needs_full_ellipse_recalc = true
		swarm_moved = true

	if Input.is_action_pressed("inc_width_ellipse"):
		_adjust_ellipse_global(Vector2(1, 0), +200.0 * _delta)  # Stretch along global x-axis
		_needs_full_ellipse_recalc = true
		swarm_moved = true

	if Input.is_action_pressed("dec_width_ellipse"):
		_adjust_ellipse_global(Vector2(1, 0), -200.0 * _delta)  # Shrink along global x-axis
		_needs_full_ellipse_recalc = true
		swarm_moved = true

	if Input.is_action_pressed("reset_swarm"):
		# Step 1: Reset swarm position using _shift_swarm_position
		var reset_vector = global_position - _swarm_world_center
		var direction = reset_vector.normalized()  # Get normalized direction
		# Step 2: Play animations for all monkeys based on the reset direction
		for monkey_entry in _swarm_monkeys:
			var monkey = monkey_entry["node"]
			if direction.angle_to(Vector2(0, 1)) < 0.25:  # Closest to down
				monkey.walk_down()
			elif direction.angle_to(Vector2(1, 0)) < 0.25:  # Closest to right
				monkey.walk_right()
			elif direction.angle_to(Vector2(0, -1)) < 0.25:  # Closest to up
				monkey.walk_up()
			elif direction.angle_to(Vector2(-1, 0)) < 0.25:  # Closest to left
				monkey.walk_left()

		_shift_swarm_position(reset_vector, reset_vector.length())

		# Step 2: Reset ellipse size
		ellipse_width_scale = 100.0  # Default width
		ellipse_height_scale = 100.0  # Default height

		# Step 3: Reset swarm rotation and offset
		_swarm_rotation = 0.0  # Reset rotation
		_swarm_center_offset = Vector2.ZERO  # Reset any offset
		_swarm_world_center = global_position  # Align with the player

		# Step 4: Redistribute monkeys evenly around the ellipse
		var total = float(_swarm_monkeys.size())
		for i in range(_swarm_monkeys.size()):
			var fraction = float(i) / total
			_swarm_monkeys[i]["angle"] = fraction * TAU  # Evenly spaced angles

		# Step 5: Mark for full recalculation of positions
		_needs_full_ellipse_recalc = true
		swarm_moved = true

		print_debug("Swarm reset: Position, size, rotation, and distribution updated.")

	return swarm_moved


## Utility to stop monkey animations if no movement keys pressed
func _swarm_monkeys_stop_walk() -> void:
	for entry in _swarm_monkeys:
		entry["node"].stop_walk()
func _swarm_monkeys_walk_up() -> void:
	for entry in _swarm_monkeys:
		entry["node"].walk_up()
func _swarm_monkeys_walk_down() -> void:
	for entry in _swarm_monkeys:
		entry["node"].walk_down()
func _swarm_monkeys_walk_left() -> void:
	for entry in _swarm_monkeys:
		entry["node"].walk_left()
func _swarm_monkeys_walk_right() -> void:
	for entry in _swarm_monkeys:
		entry["node"].walk_right()


## Handles shooting logic. Shoots in the direction of the pressed key.
func _handle_shooting() -> void:
	# Depending on which button is pressed, pass a direction vector
	# If we are still in the cooldown, do nothing
	if _current_shoot_cooldown > 0.0:
		return
	if Input.is_action_pressed("shoot_up") and not Input.is_key_pressed(KEY_SHIFT):
		print_debug()
		spawn_projectile(Vector2.UP)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_down") and not Input.is_key_pressed(KEY_SHIFT):
		spawn_projectile(Vector2.DOWN)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_left") and not Input.is_key_pressed(KEY_SHIFT):
		spawn_projectile(Vector2.LEFT)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_right") and not Input.is_key_pressed(KEY_SHIFT):
		spawn_projectile(Vector2.RIGHT)
		_current_shoot_cooldown = shoot_cooldown_duration


## Spawns a projectile in the given direction.
## @param shoot_direction: Vector2 - The direction in which to shoot the
## projectile.
func spawn_projectile(shoot_direction: Vector2) -> void:
	if banana_boomerang_scene == null:
		return

	if not banana_boomerang_scene.can_instantiate():
		return

	var projectile = banana_boomerang_scene.instantiate()

	if projectile == null:
		return

	$BananaSound.play()

	var offset_distance = 30.0
	var spawn_offset = shoot_direction.normalized() * offset_distance
	var spawn_global_position = global_position + spawn_offset

	# calculating velocity
	var bullet_speed = 550.0
	var shot_dir = shoot_direction.normalized()
	var main_vel = shot_dir * bullet_speed

	# only add perpindicular portion of players velocity onto shot velocity
	# so if you're walking up while shooting up, it won't slow or speed up the bullet.
	# But if you're walking right while shooting up, the bullet goes diagonal.
	var orth_factor = 0.75

	# shoutout chatgpt for the math
	var parallel = (velocity.dot(shot_dir)) * shot_dir
	var orth_vel = velocity - parallel

	var final_vel = main_vel + (orth_vel * orth_factor)
	projectile.velocity = final_vel
	projectile.scale = Vector2(1.5, 1.5)

	var projectiles_node = find_node_recursive(get_tree().root, "Projectiles")

	if projectiles_node == null:
		print_debug("Projectiles node not found! Pwease add.")

		# Defensively add in the node
		projectiles_node = Node2D.new()
		projectiles_node.name = "Projectiles"
		get_tree().root.add_child(projectiles_node)

	var local_spawn_pos = projectiles_node.to_local(spawn_global_position)
	projectile.position = local_spawn_pos

	projectiles_node.call_deferred("add_child", projectile)

## Recursively searches for the target node starting from the given root node.
## Returns the target node if found, otherwise returns null.
## @param root: The root node to start the search from.
## @param target: The name of the target node to search for.
## @return The target node if found, otherwise null.
func find_node_recursive(root: Node, target: String) -> Node:
	if root.name == target:
		return root

	# Recursively search through all children
	for child in root.get_children():
		var result = find_node_recursive(child, target)
		if result:
			return result

	# If no Player node is found, return null
	return null
## Custom _sign function for float
## @param value: float - The value to determine the _sign of.
func _sign(value: float) -> int:
	if value > 0:
		return 1
	elif value < 0:
		return -1
	return 0


## Adjusts the ellipse width or height based on the global direction and delta.
## @param global_dir: Vector2 - The global direction to adjust the ellipse.
## @param delta: float - The amount to adjust the ellipse width or height.
func _adjust_ellipse_global(global_dir: Vector2, delta: float) -> void:
	# Compute rotated axes based on current rotation
	var local_x_axis = Vector2(1, 0).rotated(_swarm_rotation)  # Rotated x-axis
	var local_y_axis = Vector2(0, 1).rotated(_swarm_rotation)  # Rotated y-axis

	# Project global_dir onto the rotated axes
	var x_contribution = abs(global_dir.dot(local_x_axis))
	var y_contribution = abs(global_dir.dot(local_y_axis))

	# Adjust based on the dominant axis
	if abs(x_contribution) > abs(y_contribution):  # Dominantly affects width
		var width_adjustment = delta * _sign(x_contribution)
		ellipse_width_scale = max(10.0, ellipse_width_scale + width_adjustment)
	else:  # Dominantly affects height
		var height_adjustment = delta * _sign(y_contribution)
		ellipse_height_scale = max(10.0, ellipse_height_scale + height_adjustment)

func update_hearts_display() -> void:
	for i in range(hearts_container.get_child_count()):
		var heart = hearts_container.get_child(i)
		if _current_health > i * 2 + 1:
			heart.play("full")  # Fully filled heart
		elif _current_health == i * 2 + 1:
			heart.play("half")  # Half-filled heart
		else:
			heart.play("empty")  # Empty heart


## If the player's health falls below zero.
func _die() -> void:
	queue_free()
	get_tree().change_scene_to_file("res://menus/DiedMenu/died_menu.tscn")


## Take damage for the player.
func take_damage(amount: float) -> void:
	print_debug("Player taking damage")

	# momentarily recolor the monkey to indicate damage
	_animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
	await get_tree().create_timer(0.5).timeout
	_animated_sprite.modulate = Color(1, 1, 1, 1)

	if _current_cooldown <= 0:
		_current_health = max(0, _current_health - amount)
		_current_cooldown = _damage_cooldown
		update_hearts_display()
		$HurtSound.play()

		if _current_health <= 0:
			_die()

func remove_monkey(monkey: Node) -> void:
	print_debug("===REMOVED MONNKEY===")
	# Find the entry with the matching monkey node and remove it
	for i in range(_swarm_monkeys.size()):
		if _swarm_monkeys[i]["node"] == monkey:
			_swarm_monkeys.remove_at(i)
			break

	# Recalculate swarm positions to redistribute the monkeys
	_needs_full_ellipse_recalc = true
	monkey_count_changed.emit(_swarm_monkeys.size())
	print_debug("Monkey removed. Remaining monkeys:", _swarm_monkeys.size())


func heal(amount: float) -> void:
	# Increase current health but do not exceed max_health.
	_current_health = min(max_health, _current_health + amount)

	# Update the hearts UI display.
	update_hearts_display()

	# Apply a light blue tint to indicate healing.
	_animated_sprite.modulate = Color(0.7, 0.7, 1, 1)  # Light blue tint
	await get_tree().create_timer(0.5).timeout
	_animated_sprite.modulate = Color(1, 1, 1, 1)  # Reset to white

	print_debug("Player healed by ", amount, ". Current health: ", _current_health)
	

func apply_blindness(duration: float) -> void:
	print("APPLYING BLINDNESS")
	# Prevent stacking multiple overlays (optional)
	if get_node_or_null("BlindnessOverlay"):
		print("Overlay already exists!")
		return

	# Preload and instantiate the overlay scene.
	var overlay = blindness_overlay_scene.instantiate()
	overlay.name = "BlindnessOverlay"
	
	# Find your dedicated UI node (adjust the path as needed).
	print(get_tree().get_root().name)
	var ui_node = find_node_recursive(get_tree().get_root(), "UI")
	if ui_node:
		print("ui node")
		ui_node.add_child(overlay)
	else:
		print("fallback")
		# Fallback: add to the scene root.
		get_tree().get_root().add_child(overlay)
	
	# Start the overlay with the given duration.
	overlay.start(duration)
