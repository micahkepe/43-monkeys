extends CharacterBody2D
## A single monkey in the monkey troop.
##
## Handles walking animation, collision avoidance, and enemy detection.

@warning_ignore("unused_signal")
signal monkey_died(monkey)

var locked: bool = false

## The AnimatedSprite2D node that plays the monkey's walking animation.
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_tree = $AnimationTree

## RayCast nodes for collision avoidance
@onready var _raycast_front: RayCast2D = null
@onready var _raycast_left: RayCast2D = null
@onready var _raycast_right: RayCast2D = null

## Vision detection RayCast
@onready var _raycast_vision: RayCast2D = null

## RayCast vision left (short)
@onready var _raycast_vision_7_5_left: RayCast2D

## RayCast vision right (short)
@onready var _raycast_vision_7_5_right: RayCast2D

## RayCast vision left (long)
@onready var _raycast_vision_15_left: RayCast2D

## RayCast vision right (long)
@onready var _raycast_vision_15_right: RayCast2D

## The HealthBar node to display the monkey's health
@onready var health_bar = $HealthBar

## The PackedScene for the monkey's default projectile
@export var default_projectile_scene: PackedScene

## The monkey's attack range
@export var attack_range: float = 400.0

## The monkey's attack cool down
var attack_timer: float = 0.0

## The time (in seconds) between attacks; the effective cooldown period
@export var attack_cooldown = 1.3

## Whether the monkey is currently detecting an enemy
var _enemy_in_sight: bool = false

## The detected enemy, if any
var _current_enemy = null

## Collision avoidance settings
@export var collision_avoidance_distance: float = 50.0
@export var collision_avoidance_angle: float = 45.0

## Vision detection settings
@export var vision_range: float = 200.0

## The range of the monkey's vision angle
@export var vision_angle: float = 60.0

## The maximum health of the monkey (in total heart units)
@export var max_health: int = 5

## The current health of the monkey
var current_health : int

## Cooldown for taking damage
var damage_cooldown: float = 1.5

## The current cooldown for taking damage
var current_cooldown: float = 0.0

## Whether the monkey is currently caged.
var _is_caged: bool = false

## Getter/setter for is_caged property
var is_caged: bool:
	get:
		return _is_caged
	set(value):
		_is_caged = value
		# When cage state changes, update health bar visibility
		if health_bar:
			if value: # If being caged
				health_bar.hide()
			else: # If being released from cage
				health_bar.show()

## Track the last velocity of the monkey to check for changes.
var _last_velocity: Vector2 = Vector2.ZERO

@export var paralyzed: bool = false
var frozen_position: Vector2

## Whether the monkey is currently attacking
var is_attacking: bool = false

## The damage dealt by the monkey's slash attack
@export var attack_damage: int = 1


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	health_bar.init_health(current_health)

	# Hide health bar initially - will be shown when monkey joins the troop
	health_bar.hide()

	# Setup RayCasts for collision avoidance
	_setup_collision_raycasts()

	# Setup RayCast for vision detection
	_setup_vision_raycast()

	# Ensure signal is connected
	if not _animated_sprite.is_connected("animation_finished", Callable(self, "_on_animated_sprite_2d_animation_finished")):
		_animated_sprite.connect("animation_finished", Callable(self, "_on_animated_sprite_2d_animation_finished"))
		print_debug("Connected animation_finished signal")


## Setup RayCasts for collision detection
func _setup_collision_raycasts() -> void:
	# Front RayCast
	_raycast_front = RayCast2D.new()
	_raycast_front.name = "RayCastFront"
	_raycast_front.enabled = true
	_raycast_front.target_position = Vector2(collision_avoidance_distance, 0)
	add_child(_raycast_front)

	# Left RayCast
	_raycast_left = RayCast2D.new()
	_raycast_left.name = "RayCastLeft"
	_raycast_left.enabled = true
	_raycast_left.target_position = Vector2(collision_avoidance_distance, 0).rotated(deg_to_rad(-collision_avoidance_angle))
	add_child(_raycast_left)

	# Right RayCast
	_raycast_right = RayCast2D.new()
	_raycast_right.name = "RayCastRight"
	_raycast_right.enabled = true
	_raycast_right.target_position = Vector2(collision_avoidance_distance, 0).rotated(deg_to_rad(collision_avoidance_angle))
	add_child(_raycast_right)

func _setup_vision_raycast() -> void:
	# Angles for vision rays
	var angles = {
		"0": 0.0,
		"-7.5": -7.5,
		"7.5": 7.5,
		"-15": -15.0,
		"15": 15.0
	}

	# Iterate and create raycasts dynamically
	for angle_label in angles.keys():
		var raycast = RayCast2D.new()
		raycast.name = "RayCastVision_" + angle_label
		raycast.enabled = true
		raycast.target_position = Vector2(vision_range, 0).rotated(deg_to_rad(angles[angle_label]))
		raycast.collision_mask = 2  # Assuming enemies are on layer 2
		add_child(raycast)

		# Assign raycast to its corresponding variable
		match angle_label:
			"0":
				_raycast_vision = raycast
			"-7.5":
				_raycast_vision_7_5_left = raycast
			"7.5":
				_raycast_vision_7_5_right = raycast
			"-15":
				_raycast_vision_15_left = raycast
			"15":
				_raycast_vision_15_right = raycast


## Collision avoidance logic
## Vision detection logic
func _check_vision_detection() -> void:
	var raycasts = [
		_raycast_vision,
		_raycast_vision_7_5_left,
		_raycast_vision_7_5_right,
		_raycast_vision_15_left,
		_raycast_vision_15_right
	]

	# Reset defaults
	_enemy_in_sight = false
	_current_enemy = null

	# Iterate through raycasts to check for collisions
	for raycast in raycasts:
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider and global_position.distance_to(collider.global_position) <= attack_range:
				# Set enemy detected and break early
				_enemy_in_sight = true
				_current_enemy = collider.global_position
				break


## Physics processing to handle collision avoidance and vision
func _physics_process(_delta: float) -> void:
	if is_caged:
		velocity = Vector2.ZERO
		_stop_walk()
		if health_bar:
			health_bar.hide()
		return

	if paralyzed:
		# Override any external movement:
		global_position = frozen_position
		velocity = Vector2.ZERO
		_animated_sprite.pause()
		return

	# Check for enemy vision
	_check_vision_detection()

	# Manage attack cooldown
	if attack_timer > 0:
		attack_timer -= _delta

	# Handle attack logic
	if not locked and not is_attacking and attack_timer <= 0:
		var overlapping_bodies = $Hitbox.get_overlapping_bodies()
		var targets = []
		for body in overlapping_bodies:
			if body.is_in_group("enemies"):
				targets.append(body)

		if targets.size() > 0:
			var closest_target = _get_closest_target_from_list(targets)
			if closest_target:
				is_attacking = true
				_play_attack_animation(closest_target)
				if closest_target.has_method("take_damage"):
					closest_target.take_damage(attack_damage)
				attack_timer = attack_cooldown

	# Banana throwing logic
	if _enemy_in_sight and _current_enemy and attack_timer <= 0:
		_throw_banana_at_position(_current_enemy)

	# Update damage cooldown
	if current_cooldown > 0:
		current_cooldown -= _delta

	# Update last velocity
	_last_velocity = velocity

	# Update animation state every frame
	_update_animation()

## Helper function to get the closest target from a list
func _get_closest_target_from_list(target_list: Array) -> Node2D:
	if target_list.is_empty():
		return null
	var closest_target = target_list[0]
	var min_distance = global_position.distance_to(closest_target.global_position)
	for target in target_list.slice(1):
		var distance = global_position.distance_to(target.global_position)
		if distance < min_distance:
			closest_target = target
			min_distance = distance
	return closest_target

## Plays the attack animation and applies damage to the target node
func _play_attack_animation(target: Node2D) -> void:
	var direction = (target.global_position - global_position).normalized()
	print("==DIRECTION:", direction)
	# Set blend parameter based on the direction vector.
	# (Assumes you've added a Vector2 blend parameter in your state machine called "attack_blend")
	animation_tree.get("parameters/playback").travel("Attack")
	animation_tree.set("parameters/Attack/BlendSpace2D/blend_position", direction)
	# Transition to the attack state.
	is_attacking = true

func _update_animation() -> void:
	if paralyzed:
		return

	# If locked, stop animation
	if locked:
		_stop_walk()
		return

	if is_attacking:
		return

	# Only update movement animations if not attacking
	if not is_attacking:
		animate_walk(velocity)

func animate_walk(input_velocity: Vector2) -> void:
	if paralyzed or is_attacking:
		return

	if input_velocity == Vector2.ZERO and not is_input_pressed():
		#print("==== IDLING WITH VELOCITY: ", input_velocity)
		animation_tree.get("parameters/playback").travel("Idle")
		var blend_dir: Vector2 = animation_tree.get("parameters/Idle/BlendSpace2D/blend_position")
		_update_vision_rays(blend_dir)
	else:
		#print("==== WALKING WITH VELOCITY: ", input_velocity)
		if input_velocity != Vector2.ZERO:
			animation_tree.get("parameters/playback").travel("Walk")
			animation_tree.set("parameters/Walk/BlendSpace2D/blend_position", input_velocity)
			animation_tree.set("parameters/Idle/BlendSpace2D/blend_position", input_velocity)
			_update_vision_rays(input_velocity)


func is_input_pressed() -> bool:
	return (Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_left") or
	Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_up"))


## Utility method for the monkey to play the walk left animation and adjust its
## raycasts accordingly.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _walk_left() -> void:
	if paralyzed:
		return
	_animated_sprite.play("walk_left")
	_update_vision_rays(Vector2(-vision_range, 0))


## Utility method for the monkey to play the walk right animation and adjust its
## raycasts accordingly.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _walk_right() -> void:
	if paralyzed:
		return
	_animated_sprite.play("walk_right")
	_update_vision_rays(Vector2(vision_range, 0))


## Utility method for the monkey to play the walk up animation and adjust its
## raycasts accordingly.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _walk_up() -> void:
	if paralyzed:
		return
	_animated_sprite.play("walk_up")
	_update_vision_rays(Vector2(0, -vision_range))


## Utility method for the monkey to play the walk down animation and adjust its
## raycasts accordingly.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _walk_down() -> void:
	if paralyzed:
		return
	_animated_sprite.play("walk_down")
	_update_vision_rays(Vector2(0, vision_range))


## Utility method for the monkey to stop animating. The monkey essentially is
## visually frozen in place. Resets the monkey's last velocity to ZERO.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _stop_walk() -> void:
	if paralyzed:
		return
	_animated_sprite.pause()
	_last_velocity = Vector2.ZERO


## Helper function to update all vision ray casts
func _update_vision_rays(direction: Vector2) -> void:
	# Define the angle offsets (in degrees) for each vision raycast.
	var angle_offsets = {
		_raycast_vision: 0.0,
		_raycast_vision_7_5_left: -7.5,
		_raycast_vision_7_5_right: 7.5,
		_raycast_vision_15_left: -15.0,
		_raycast_vision_15_right: 15.0
	}

	# Normalize the direction vector to avoid scaling issues.
	var norm_direction = direction.normalized()

	# Update each raycast's target_position by rotating the normalized direction by the angle offset
	# and then scaling by vision_range.
	for raycast in angle_offsets.keys():
		var offset_radians = deg_to_rad(angle_offsets[raycast])
		raycast.target_position = norm_direction.rotated(offset_radians) * vision_range


## Handles monkey death. Plays the death animation and cleans the monkey from
## the scene.
## Handles monkey death. Plays the death animation and cleans the monkey from
## the scene.
func _die() -> void:
	print_debug("Trying to _die for monkey", self)

	# Debug check if animation exists
	if is_instance_valid(_animated_sprite) and _animated_sprite.sprite_frames:
		print_debug("Available animations:", _animated_sprite.sprite_frames.get_animation_names())
		print_debug("Current animation:", _animated_sprite.animation)
	else:
		print_debug("Could not get animations for dying monkey.")

	set_physics_process(false)
	set_process(false) # Also disable _process if used
	collision_layer = 0
	collision_mask = 0

	# Hide the health bar
	if is_instance_valid(health_bar):
		health_bar.hide()
		print_debug("Health bar hidden for dying monkey")

	# zero out the velocity to stop additional movement
	velocity = Vector2.ZERO

	var parent = get_parent()
	if parent:
		var grandparent = parent.get_parent()
		# Only call remove_monkey if the grandparent is the Player
		if is_instance_valid(grandparent) and grandparent is Player:
			print_debug("Monkey dying, telling Player to remove it: ", self.name)
			grandparent.remove_monkey(self)
		else:
			print_debug("Monkey dying, but grandparent is not Player (Parent: %s, Grandparent: %s). Not calling remove_monkey." % [parent.name if is_instance_valid(parent) else "Invalid Parent", grandparent.name if is_instance_valid(grandparent) else "Invalid/None Grandparent"])

	# --- Corrected AnimationTree Travel ---
	if is_instance_valid(animation_tree):
		# Attempt to get the playback parameter state machine
		var playback = animation_tree.get("parameters/playback")
		# Check if playback exists (is a valid AnimationNodeStateMachinePlayback)
		if playback:
			print_debug("Attempting to play 'die' animation via AnimationTree for monkey: ", self.name)
			# Directly attempt to travel. If "die" state doesn't exist,
			# playback.travel() might print an error but often won't crash.
			playback.travel("die")
			# Note: The actual queue_free should happen AFTER the animation finishes.
			# This is handled by the _on_animation_tree_animation_finished signal handler.
		else:
			# This case means the "parameters/playback" doesn't exist or isn't a state machine
			printerr("Could not get valid 'playback' state machine from AnimationTree for monkey: ", self.name)
			queue_free() # Fallback to immediate removal if no playback found
	else:
		# Fallback if no AnimationTree node found
		printerr("No valid AnimationTree node found for dying monkey: ", self.name)
		queue_free()


## Takes the specified amount of damage from the monkey's health.
func take_damage(amount: float) -> void:
	if current_cooldown <= 0:
		current_health = max(0, current_health - amount)
		current_cooldown = damage_cooldown
		print_debug("Monkey took damage. Current health:", current_health)

		# momentarily recolor the monkey to indicate damage
		_animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.5).timeout
		_animated_sprite.modulate = Color(1, 1, 1, 1)

		if health_bar:
			health_bar.value = current_health
			health_bar.health = current_health
			health_bar.show()  # Ensure health bar is always visible when damaged

		if current_health <= 0:
			print_debug("Health <= 0, calling _die()")
			_die()

## Function to throw a banana at a specific position
func _throw_banana_at_position(target_position: Vector2) -> void:
	if default_projectile_scene == null:
		return

	var projectile = default_projectile_scene.instantiate()
	if projectile == null:
		return

	# Tag the projectile as friendly
	projectile.set_meta("friendly", true)
	projectile.set_meta("owner", self)

	var shoot_direction = (target_position - global_position).normalized()
	var offset_distance = 30.0
	var spawn_offset = shoot_direction * offset_distance
	var spawn_global_position = global_position + spawn_offset
	print_debug("BANANA POS (global):", spawn_global_position)
	print_debug("MONKEY POS (global):", global_position)

	# Calculate the projectile velocity
	var bullet_speed = 550.0
	var main_velocity = shoot_direction * bullet_speed

	# Calculate the perpendicular component of the monkey's velocity
	var orth_factor = 0.75  # Scaling for the perpendicular component
	var parallel_velocity = velocity.dot(shoot_direction) * shoot_direction
	var perpendicular_velocity = velocity - parallel_velocity

	# Final velocity is a combination of the main velocity and a portion of the perpendicular velocity
	var final_velocity = main_velocity + (perpendicular_velocity * orth_factor)

	projectile.velocity = final_velocity

	# Add the projectile to the 'Projectiles' node safely
	var projectiles_node = get_tree().get_current_scene().get_node("Projectiles") if get_tree().get_current_scene().has_node("Projectiles") else null
	if projectiles_node:
		# Convert the global spawn position to the local coordinate system of the 'Projectiles' node
		var local_spawn_pos = projectiles_node.to_local(spawn_global_position)
		projectile.position = local_spawn_pos

		projectiles_node.call_deferred("add_child", projectile)
		print_debug("Projectile added to the Projectiles node at:", local_spawn_pos)
	else:
		print_debug("Projectiles node not found. Projectile not spawned.")

	# Reset the attack cooldown
	attack_timer = attack_cooldown

	# Play attack animation or effects if needed
	print("Banana thrown at position:", target_position)


func heal(amount: float) -> void:
	# Increase current health but do not exceed max_health.
	current_health = min(max_health, current_health + amount)

	# Update the health bar if it exists.
	if health_bar:
		health_bar.value = current_health
		health_bar.health = current_health  # If you use a separate property for health

	# Apply a light blue tint to indicate healing.
	_animated_sprite.modulate = Color(0.7, 0.7, 1, 1)  # Light blue tint
	await get_tree().create_timer(0.5).timeout  # Wait 0.5 seconds
	_animated_sprite.modulate = Color(1, 1, 1, 1)    # Reset to normal color

	print_debug("Monkey healed by ", amount, ". Current health: ", current_health)


func apply_blindness(seconds: float) -> void:
	var prev_range = attack_range
	attack_range = 0

	# momentarily recolor the monkey to indicate damage
	_animated_sprite.modulate = Color(1, 0.55, 0, 1)
	await get_tree().create_timer(seconds).timeout
	_animated_sprite.modulate = Color(1, 1, 1, 1)
	attack_range = prev_range

func paralyze(duration: float) -> void:
	paralyzed = true
	frozen_position = global_position  # Save the current position
	_animated_sprite.modulate = Color(0.7, 0.7, 1, 1)  # Light blue tint
	await get_tree().create_timer(duration).timeout
	_animated_sprite.modulate = Color(1, 1, 1, 1)
	paralyzed = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	# Handle interactions with Area2D nodes (e.g., projectiles)
	if area.is_in_group("projectiles"):
		# Ignore friendly projectiles (those spawned by player or troop)
		if area.get_meta("friendly", false):
			return  # Skip damage from this monkey's own banana projectiles
		# Apply damage from non-friendly (enemy) projectiles
		var damage = 1.0  # Default damage if no specific value is provided
		if area.has_method("get_damage"):
			damage = area.get_damage()
		elif "damage" in area:  # Check if the projectile has a damage property
			damage = area.damage
		take_damage(damage)
		print_debug("Monkey hit by projectile area: ", area.name, " for damage: ", damage)
		# Optionally remove the projectile after hitting
		if area.has_method("queue_free"):
			area.queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Handle interactions with physics bodies (e.g., enemies)
	if body.is_in_group("player") or body.is_in_group("troop"):
		print_debug("Monkey collided with: ", body.name)
	elif body.is_in_group("player") or body.is_in_group("troop"):
		# Optional: Handle player or troop collision (e.g., ignore or push)
		print_debug("Monkey collided with: ", body.name)

func _on_hitbox_body_exited(body: Node2D) -> void:
	# Handle when a body exits the hitbox
	if body.is_in_group("boids"):
		print_debug("Boid exited monkey hitbox: ", body.name)
	elif body.is_in_group("player") or body.is_in_group("troop"):
		print_debug("Player or troop exited monkey hitbox: ", body.name)

# Make sure this signal handler exists and is connected in the editor or _ready
# to the animation_tree's "animation_finished" signal (or appropriate signal)
func _on_animation_tree_animation_finished(anim_name):
	print_debug("AnimationTree finished animation: ", anim_name)
	# You might need to adjust "die" if your actual state name in the AnimationTree is different
	if anim_name == "die":
		print_debug("Die animation finished via AnimationTree, queueing free for monkey: ", self.name)
		queue_free()
	elif "slash" in anim_name: # Keep your existing slash logic
		print_debug("Slash animation finished, resetting is_attacking for monkey: ", self.name)
		is_attacking = false

