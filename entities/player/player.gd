class_name Player extends CharacterBody2D
## Represents a 2D pllayer character in the game.
##
## The player character is contrjolled by the player and can move in four
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

## The animated sprite for the player.
@onready var _animated_sprite = $AnimatedSprite2D

## The troop debug ellipse.
@onready var _troop_ellipse: Node2D = $TroopEllipse

@export_group("Player Variables")

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

## The player's default projectile to throw.
@export
var default_projectile_scene: PackedScene

@export
var blindness_overlay_scene: PackedScene

## The maximum health of the player character (in half-hearts).
@export var max_health: float = 6.0  # 6 half-hearts = 3 full hearts

## The current health of the player character (in half-hearts).
var _current_health: float = 6.0

## The time between damage ticks.
var _damage_cooldown: float = 1.0

## The current cool down for taking damage.
var _current_cooldown: float = 0.0



# -----------------------------------------------------------------
# TROOP VARIABLES
# -----------------------------------------------------------------

@export_group("Troop Variables")

## The available variants of the monkeys to populate the troop.
@export var monkey_scenes: Array[PackedScene] = []

## [DEBUG] The initial amount of monkeys in the troop.
## The troop will need to be collected by the player and have continuity
# between levels.
@export
var initial_troop_amount: int = 0

## The scale of the troop ellipse along the x-axis
@export
var ellipse_width_scale: float = 175.0

## The scale of the troop ellipse along the y-axis
@export
var ellipse_height_scale: float = 175.0

## Whether swarm is "locked" (Does not move with player on WASD)
var _troop_locked: bool = false

## The root node to append the troop monkeys.
@onready var _swarm_monkeys_root: Node2D = $SwarmMonkeys

## The UI display for whether the troop is currently locked.
@onready var _troop_lock_ui: TextureButton = $PlayerUI/TroopLock

## Additional offset from the player's position
## (Changed by U, O, H, ;)
var _swarm_center_offset: Vector2 = Vector2.ZERO

## Each entry: { "node": <DefaultMonkey>, "angle": float (0..X) }
var _swarm_monkeys: Array[Dictionary] = []

## The center of the swarm/troop ellipse
var _swarm_world_center: Vector2

## The rotation of the swarm ellipse
var _swarm_rotation: float = 0.0

# Store flag to indicate if a full ellipse recalculation is needed.
var _needs_full_ellipse_recalc: bool = false

## Constant vector for upward world direction.
const WORLD_UP = Vector2(0, -1)

## Constant vector for downward world direction.
const WORLD_RIGHT = Vector2(1, 0)

var _current_rotation_speed_in_radians_per_sec: float = 0.0

## Getter method for player health.
var health: float:
	get:
		return _current_health
	set(value):
		_current_health = clamp(value, 0, max_health)
		update_hearts_display()

## Getter method for the troop count.
func get_troop_count() -> int:
	print("Troop size:", _swarm_monkeys.size())
	return _swarm_monkeys.size()

# Add this method to get troop monkeys (for health reset)
func get_troop() -> Array:
	return _swarm_monkeys.map(func(entry): return entry["node"])

## The UI container for the player's health display.
@onready var hearts_container = $PlayerUI/HeartsContainer

## Monkey counter for number of monkeys in group, including the main monkey.
@onready var monkey_counter_label: Label = $PlayerUI/MonkeyCounter

## Reference to the AnimationTree
@onready var animation_tree  = $AnimationTree

# ------------------------------------------------
# SIGNALS
# ------------------------------------------------

## Emitted when the count of the troop is altered.
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

	# Ensure UI is shown
	if $PlayerUI:
		$PlayerUI.show()


## Update the monkey group number
## @param count: int - The number of monkeys in the group.
func _update_monkey_counter(count: int) -> void:
	if monkey_counter_label:
		monkey_counter_label.text = "%d/43" % (count + 1)

## Called every frame.
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame in seconds.
func _physics_process(_delta: float) -> void:
	var old_rotation = _swarm_rotation

	## The player's current velocity
	var input_velocity = Vector2.ZERO
	var current_speed = speed

	# Conditionally display the troop ellipse.
	# TODO: only call this on ellipse resizing, not in all shift cases.
	if Input.is_key_pressed(KEY_SHIFT) and _swarm_monkeys.size() > 0:
		_troop_ellipse.show()
	else:
		_troop_ellipse.hide()

	# Player movement input (no SHIFT)
	if not Input.is_key_pressed(KEY_SHIFT):
		if Input.is_action_pressed("ui_right"):
			input_velocity.x += 1
		if Input.is_action_pressed("ui_left"):
			input_velocity.x -= 1
		if Input.is_action_pressed("ui_up"):
			input_velocity.y -= 1
		if Input.is_action_pressed("ui_down"):
			input_velocity.y += 1

	# Normalize diagonal movement
	if input_velocity != Vector2.ZERO:
		input_velocity = input_velocity.normalized()

	## Set animation based on movement direction
	if input_velocity == Vector2.ZERO:
		animation_tree.get("parameters/playback").travel("Idle")
	else:
		animation_tree.get("parameters/playback").travel("Walk")
		animation_tree.set("parameters/Walk/BlendSpace2D/blend_position", input_velocity)
		animation_tree.set("parameters/Idle/BlendSpace2D/blend_position", input_velocity)

	## Set the velocity and move the character
	velocity = input_velocity * current_speed
	move_and_slide()
	if not _troop_locked and len(_swarm_monkeys) > 0:
		for entry in _swarm_monkeys:
			entry["node"].animate_walk(input_velocity)


	# Decrement the shoot cool down
	if _current_shoot_cooldown > 0.0:
		_current_shoot_cooldown -= _delta
		if _current_shoot_cooldown < 0.0:
			_current_shoot_cooldown = 0.0

	# Handle banana shooting
	_handle_shooting()

	var swarm_modified = handle_swarm_input(_delta)

	var rotation_delta = _swarm_rotation - old_rotation
	# 4) Convert that to "radians per second"
	_current_rotation_speed_in_radians_per_sec = rotation_delta / _delta


	# If swam unlocked, move with WASD as the player moves
	if not _troop_locked and input_velocity != Vector2.ZERO:
		swarm_modified = true

	# If changed rotation/size, do angle recalculation.
	if _needs_full_ellipse_recalc or swarm_modified:
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
		print_debug("Spawning a new monkey for the swarm!")
		_swarm_monkeys_root.add_child(new_monkey)
		# new_monkey will be positioned based on its scene settings.


	# Show the monkey's health bar now that it's part of the troop
	if "health_bar" in new_monkey and new_monkey.health_bar:
		new_monkey.health_bar.show()

	# Update is_caged flag to false now that the monkey is in the troop
	if "is_caged" in new_monkey:
		new_monkey.is_caged = false

	# Determine a new angle for the monkey in the swarm.
	var count = _swarm_monkeys.size()
	var new_angle = 0.0
	if count >= 1:
		new_angle = float(count) / float(count + 1) * TAU

	# Add the monkey along with a transitioning flag so it will walk to its target.
	_swarm_monkeys.append({
		"node": new_monkey,
		"angle": new_angle,
		"transitioning": true
		# Removed health and max_health from here - they should be properties of the monkey instance itself
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
func _update_swarm_positions() -> void:
	if not _troop_locked:
		var center_offset = _swarm_center_offset.rotated(_swarm_rotation)
		_swarm_world_center = global_position + center_offset

	for entry in _swarm_monkeys:
		var angle = entry["angle"]
		var monkey = entry["node"]

		# Compute target position on the ellipse.
		var x_component = Vector2(1, 0).rotated(_swarm_rotation) * ellipse_width_scale * cos(angle)
		var y_component = Vector2(0, 1).rotated(_swarm_rotation) * ellipse_height_scale * sin(angle)
		var target_position = _swarm_world_center + x_component + y_component

		if _troop_locked:
			monkey.velocity = Vector2.ZERO
			var to_target = target_position - monkey.global_position
			if to_target.length() > 5.0:
				monkey.velocity = to_target.normalized() * speed
			else:
				monkey.velocity = Vector2.ZERO
			monkey.move_and_slide()
		else:
			var to_target = target_position - monkey.global_position
			if to_target.length() < 5.0:
				monkey.velocity = Vector2.ZERO

				var base_speed = speed
				# How fast the ellipse is spinning this frame:
				var angular_velocity = abs(_current_rotation_speed_in_radians_per_sec)

				# Approximate radius:
				var radius = (ellipse_width_scale + ellipse_height_scale) * 0.5

				# The extra speed needed to keep up with rotation:
				var rotation_chase_speed = angular_velocity * radius

				# Final speed = base speed + chase speed, capped at max of 1k:
				var final_speed = min(base_speed + rotation_chase_speed, 1000.0)
				#var final_speed = base_speed + rotation_chase_speed
				var factor = to_target.length() / 5.0
				if factor < 0.01:
					factor = 0
				monkey.velocity = to_target.normalized() * final_speed * factor




				if entry.has("transitioning"):
					entry["transitioning"] = false
			else:
				var base_speed = speed
				if entry.has("transitioning") and entry["transitioning"]:
					# maybe slower or faster if you want
					base_speed *= 0.75

				# How fast the ellipse is spinning this frame:
				var angular_velocity = abs(_current_rotation_speed_in_radians_per_sec)

				# Approximate radius:
				var radius = (ellipse_width_scale + ellipse_height_scale) * 0.5

				# The extra speed needed to keep up with rotation:
				var rotation_chase_speed = angular_velocity * radius

				# Final speed = base speed + chase speed, capped at max of 1k:
				var final_speed = min(base_speed + rotation_chase_speed, 1000.0)
				#var final_speed = base_speed + rotation_chase_speed

				monkey.velocity = to_target.normalized() * final_speed
			monkey.move_and_slide()

	_troop_ellipse.ellipse_width_scale = ellipse_width_scale
	_troop_ellipse.ellipse_height_scale = ellipse_height_scale
	_troop_ellipse.swarm_rotation = _swarm_rotation
	_troop_ellipse.global_position = _swarm_center_offset.rotated(_swarm_rotation) + global_position
	_troop_ellipse.queue_redraw()


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
		if to_target.length() < 5.0:  # Small threshold to avoid "jitter"
			monkey.velocity = Vector2.ZERO
		else:
			# Move toward the target using velocity
			var direction = to_target.normalized()
			monkey.velocity = direction * 450

		# Apply velocity with move_and_slide for collision handling
		monkey.move_and_slide()


## Checks keys for ellipse rotation, resizing, lock toggle, and manual swarm
## translation. Returns 'true' if any translation or animation occurred on the
## swarm in this frame
func handle_swarm_input(_delta: float) -> bool:
	var swarm_moved = false

	if Input.is_action_pressed("rotate_swarm_clockwise"):
		# Rotate the transformation matrix
		var rotation_speed = 1.5 * _delta
		_swarm_rotation += rotation_speed

		# Adjust the center offset to rotate around the player
		#_swarm_center_offset = _swarm_center_offset.rotated(rotation_speed)

		_needs_full_ellipse_recalc = true
		swarm_moved = true

	# Handle troop lock
	# If the "toggle_lock" key is pressed, toggle the swarm lock state, NOT HELD
	if Input.is_action_just_pressed("toggle_lock"):
		# if no monkeys yet, get out of here
		if not _swarm_monkeys.size() > 0:
			return false

		_troop_locked = not _troop_locked
		if _troop_locked:
			# When locking, freeze the current swarm center.
			_swarm_world_center = global_position + _swarm_center_offset.rotated(_swarm_rotation)
		else:
			# When unlocking, recalculate the offset so the swarm follows the player.
			_swarm_center_offset = (_swarm_world_center - global_position).rotated(-_swarm_rotation)
		swarm_moved = true

		# Update each monkey’s locked flag
		for entry in _swarm_monkeys:
			entry["node"].locked = _troop_locked

		# Update the troop lock UI
		if _troop_locked and _swarm_monkeys.size() > 0:
			_troop_lock_ui.show()
		else:
			_troop_lock_ui.hide()

	# TODO: this is better logic for handling diagonals, but somewhere the troop
	# animations are being called twice and ruining the diagonal animation playing.
	if len(_swarm_monkeys) > 0:
		var move_input = Vector2.ZERO
		if Input.is_action_pressed("translate_up") and Input.is_key_pressed(KEY_SHIFT):
			move_input.y -= 1
		if Input.is_action_pressed("translate_down") and Input.is_key_pressed(KEY_SHIFT):
			move_input.y += 1
		if Input.is_action_pressed("translate_left") and Input.is_key_pressed(KEY_SHIFT):
			move_input.x -= 1
		if Input.is_action_pressed("translate_right") and Input.is_key_pressed(KEY_SHIFT):
			move_input.x += 1
		if move_input != Vector2.ZERO:
			move_input = move_input.normalized()
			_shift_swarm_position(move_input, 200 * _delta)
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
			# Unlock the swarm so they chase instead of snap.
			_troop_locked = false
			_troop_lock_ui.hide()

			# Reset ellipse parameters
			ellipse_width_scale = 175.0
			ellipse_height_scale = 175.0
			_swarm_rotation = 0.0
			_swarm_center_offset = Vector2.ZERO
			_swarm_world_center = global_position

			# Redistribute angles
			var total = float(_swarm_monkeys.size())
			for i in range(_swarm_monkeys.size()):
				var fraction = float(i) / total
				_swarm_monkeys[i]["angle"] = fraction * TAU

			# Mark for recalc so they'll walk to the new positions
			_needs_full_ellipse_recalc = true
			swarm_moved = true
			_current_rotation_speed_in_radians_per_sec = 0.0

			print_debug("Swarm reset: Position, size, rotation, and distribution updated.")

	return swarm_moved


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
	if default_projectile_scene == null or not default_projectile_scene.can_instantiate():
		return

	var projectile = default_projectile_scene.instantiate()

	if projectile == null:
		return

	# Tag the projectile as friendly to distinguish it from enemy projectiles
	projectile.set_meta("friendly", true)
	projectile.set_meta("owner", self)

	$ThrowSound.play()

	var offset_distance = 30.0
	var spawn_offset = shoot_direction.normalized() * offset_distance
	var spawn_global_position = global_position + spawn_offset

	# calculating velocity
	var bullet_speed = 550.0
	var shot_dir = shoot_direction.normalized()
	var main_vel = shot_dir * bullet_speed

	# only add perpendicular portion of players velocity onto shot velocity
	# so if you're walking up while shooting up, it won't slow or speed up the bullet.
	# But if you're walking right while shooting up, the bullet goes diagonal.
	var orth_factor = 0.75

	# shoutout chatgpt for the math
	var parallel = (velocity.dot(shot_dir)) * shot_dir
	var orth_vel = velocity - parallel

	var final_vel = main_vel + (orth_vel * orth_factor)
	projectile.velocity = final_vel

	var projectiles_node = get_tree().root.find_child("Projectiles")

	if projectiles_node == null:
		print_debug("Projectiles node not found! Pwease add.")

		# Defensively add in the node
		projectiles_node = Node2D.new()
		projectiles_node.name = "Projectiles"
		get_tree().root.add_child(projectiles_node)

	var local_spawn_pos = projectiles_node.to_local(spawn_global_position)
	projectile.position = local_spawn_pos

	projectiles_node.call_deferred("add_child", projectile)


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


## Update the display with the current player health.
func update_hearts_display() -> void:
	for i in range(hearts_container.get_child_count()):
		var heart = hearts_container.get_child(i)
		if _current_health > i * 2 + 1:
			heart.play("full")  # Fully filled heart
		elif _current_health == i * 2 + 1:
			heart.play("half")  # Half-filled heart
		else:
			heart.play("empty")  # Empty heart


## Handles death logic for the player. Navigates to the "Died" menu.
func _die() -> void:
	if get_tree():
		get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://menus/DiedMenu/died_menu.tscn")


## Take damage for the player.
## @param amount float amount of damage to be dealt the player.
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

## Removes a monkey from the player's troop by reference.
## @param monkey the monkey Node to delete from the troop.
func remove_monkey(monkey: Node) -> void:
	print_debug("===REMOVED MONNKEY===")
	# Find the entry with the matching monkey node and remove it
	for i in range(_swarm_monkeys.size()):
		if _swarm_monkeys[i]["node"] == monkey:
			_swarm_monkeys.remove_at(i)
			print_debug("Found monkey to remove")
			break

	# Recalculate swarm positions to redistribute the monkeys
	_needs_full_ellipse_recalc = true
	monkey_count_changed.emit(_swarm_monkeys.size())
	print_debug("Monkey removed. Remaining monkeys:", _swarm_monkeys.size())


## Heals the monkey by the given amount.
## @param amount float value to heal the monkey
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

## Applies the blindness overlay to the scene.
## @param duration float time in seconds to apply the overlay
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
	var ui_node = get_tree().root.find_child("UI")
	if ui_node:
		print("ui node")
		ui_node.add_child(overlay)
	else:
		print("fallback")
		# Fallback: add to the scene root.
		get_tree().get_root().add_child(overlay)

	# Start the overlay with the given duration.
	overlay.start(duration)


## Handles the hitbox being entered by another area.
func _on_hitbox_area_entered(area: Area2D) -> void:
	# Handle interactions with Area2D nodes (e.g., projectiles, enemy attacks)
	if area.is_in_group("projectiles"):
		# Ignore friendly projectiles (those spawned by player or troop)
		if area.get_meta("friendly", false):
			return  # Skip damage from player's own banana projectiles
		# Apply damage from non-friendly (enemy) projectiles
		var damage = 1.0  # Default damage if no specific value is provided
		if area.has_method("get_damage"):
			damage = area.get_damage()
		elif "damage" in area:  # Check if the projectile has a damage property
			damage = area.damage
		take_damage(damage)
		print_debug("Player hit by projectile area: ", area.name, " for damage: ", damage)
		## Optionally remove the projectile after hitting
		#if area.has_method("queue_free"):
			#area.queue_free()


## When a body enters the HitBox.
func _on_hitbox_body_entered(body: Node2D) -> void:
	# Handle interactions with physics bodies (e.g., enemies, troop members)
	if body.is_in_group("troop") and body != self:
		print_debug("Player collided with troop member: ", body.name)
	elif body.is_in_group("troop") and body != self:
		# Optional: Handle troop member collision (e.g., push away or ignore)
		print_debug("Player collided with troop member: ", body.name)


## Handles when a body exits the HitBox.
func _on_hitbox_body_exited(body: Node2D) -> void:
	# Handle when a body exits the hitbox
	if body.is_in_group("boids"):
		print_debug("Boid exited player hitbox: ", body.name)
	elif body.is_in_group("troop"):
		print_debug("Troop member exited player hitbox: ", body.name)

func heal_troop() -> void:
	for entry in _swarm_monkeys:
		var monkey = entry["node"]
		if "current_health" in monkey and "max_health" in monkey:
			monkey.current_health = monkey.max_health

			# Update health bar if it exists
			if "health_bar" in monkey and monkey.health_bar:
				monkey.health_bar.value = monkey.current_health
				monkey.health_bar.health = monkey.current_health
				monkey.health_bar.show()  # Always keep health bar visible
