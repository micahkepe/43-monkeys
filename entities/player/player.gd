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
##   U/O/H/; => Translate swarm center up/down/left/right
##   Shift+I => Increase ellipse height
##   Shift+K => Decrease ellipse height
##   Shift+J => Decrease ellipse width
##   Shift+L => Increase ellipse width
##   I/K/J/L => Shoot up/down/left/right
##

@onready var _animated_sprite = $AnimatedSprite2D

## The base speed at which the player moves
@export
var speed: float = 300.0

## The player's current health
@export
var health: int = 100

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


# -----------------------------------------------------------------
# TROOP VARIABLES
# -----------------------------------------------------------------
@export var troopDefaultMonkey: PackedScene

@export var swarm_ellipse_width: float = 200.0
@export var swarm_ellipse_height: float = 200

# Rotation of ellipse in radians
var swarm_rotation: float = 0.0

# Whether swarm is "locked" (Does not move with player on WASD)
var swarm_locked: bool = false

# Additional offset from the player's position
# (Changed by U, O, H, ;)
var swarm_center_offset: Vector2 = Vector2.ZERO

# Each entry: { "node": <DefaultMonkey>, "angle": float (0..X) }
var swarm_monkeys: Array = []

# The center of the swarm/troop ellipse
var swarm_world_center: Vector2


## Called when the node enters the scene tree for the first time.
## Initializes any setup required for the player character.
func _ready() -> void:
	## Set the player's initial animation
	_animated_sprite.play("walk_down")
	
	swarm_world_center = global_position
	
	# Spawn 5 monkeys in the swarm for testing
	for i in range(10):
		add_monkey_to_swarm()
	
	# Update positions after adding monkeys
	_update_swarm_positions()


## Called every frame.
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame in seconds.
func _physics_process(_delta: float) -> void:
	## The player's current velocity
	var input_velocity = Vector2.ZERO

	# Get current movement speed (base or sprint)
	var current_speed = speed * sprint_multiplier if Input.is_key_pressed(KEY_SHIFT) else speed

	# Movement input
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
		
	# Grab player's old position
	var old_position = global_position
	
	## Set the velocity and move the character
	velocity = input_velocity * current_speed
	move_and_slide()
	

	# Decrement the shoot cooldown
	if _current_shoot_cooldown > 0.0:
		_current_shoot_cooldown -= _delta
		if _current_shoot_cooldown < 0.0:
			_current_shoot_cooldown = 0.0

	#Handle banana shooting
	handle_shooting()
	
	
	
	var swarm_modified = handle_swarm_input(_delta)
	
	#If swam unlocked, move with WASD as the player moves
	if not swarm_locked and input_velocity != Vector2.ZERO:
		var shift_amount = velocity * _delta
		#Animate the monkeys in the correct direction
		if input_velocity.x > 0:
			_swarm_monkeys_walk_right()
		elif input_velocity.x < 0:
			_swarm_monkeys_walk_left()
		elif input_velocity.y < 0:
			_swarm_monkeys_walk_up()
		elif input_velocity.y > 0:
			_swarm_monkeys_walk_down()
		
		swarm_modified = true
	elif not swarm_modified:
		_swarm_monkeys_stop_walk()
	
	#If changed rotation/size, do angle recalc
	if _needs_full_ellipse_recalc:
		_update_swarm_positions()
		
		
		
		
		
##
# Instantiates a new DefaultMonkey and evenly distributes the group across the 
# ellipse
##
func add_monkey_to_swarm() -> void:
	var new_monkey = troopDefaultMonkey.instantiate()
	new_monkey.scale = Vector2(2.5, 2.5)
	add_child(new_monkey)
	
	var count = swarm_monkeys.size()
	var new_angle  = 0.0
	if count >= 1:
		new_angle = float(count) / float(count + 1) * TAU
	
	swarm_monkeys.append({
		"node": new_monkey,
		"angle": new_angle
	})
	
	print("?")
	var total = float(swarm_monkeys.size())
	for i in range(swarm_monkeys.size()):
		print("done: ", i)
		var fraction = float(i) / total
		swarm_monkeys[i]["angle"] = fraction * TAU
	
	#recalc angles?
	_needs_full_ellipse_recalc = true

func _update_swarm_center() -> void:
	swarm_world_center = global_position + swarm_center_offset

##
# positions each monkey on the ellipse boundary using their angle, plus
# 'swarm_center_offset', plus Player.global_position
##
func _update_swarm_positions() -> void:
	if not swarm_locked:
		swarm_world_center = global_position + swarm_center_offset
	#else, use old center

	var rx = swarm_ellipse_width * 0.5
	var ry = swarm_ellipse_height * 0.5
	
	for entry in swarm_monkeys:
		var angle = entry["angle"]
		var monkey = entry["node"]
		
		var local_pos  = Vector2(rx * cos(angle), ry * sin(angle))
		local_pos = local_pos.rotated(swarm_rotation)
		monkey.global_position = swarm_world_center + local_pos
		
##
# Translates all monkeys by the same offset for WASD movement or swarm keys
##
func _shift_swarm_position(shift: Vector2) -> void:
	# Shift the "center" offset so future rotations know we've moved
	swarm_center_offset += shift
	
	#Move each monkey's global position
	for entry in swarm_monkeys:
		entry["node"].global_position += shift

# Store flag to indicate if a full ellipse recalc is needed
var _needs_full_ellipse_recalc: bool = false

## 
# Checks keys for ellipse rotation, resizing, lock toggle, and manual swarm
# translation.
# Returns 'true' if any translation or animation occured on the swarm in this 
# frame
##
func handle_swarm_input(_delta: float) -> bool:
	var swarm_moved = false
	
	#Rotations keys
	if Input.is_action_pressed("rotate_swarm_clockwise"):
		swarm_rotation += 1.5 * _delta
		_needs_full_ellipse_recalc = true
		swarm_moved = true
	
	# Handle troop lock
	if Input.is_action_pressed("toggle_lock"):
		var was_locked = swarm_locked
		swarm_locked = not swarm_locked

		if was_locked and not swarm_locked:
			swarm_center_offset = swarm_world_center - global_position
			
		swarm_moved = true #maybe delete
	
	# Manual Swarm Translation (U/O/H/;)
	var manual_shift = Vector2.ZERO
	if Input.is_action_pressed("translate_up"):
		_swarm_monkeys_walk_up()
		manual_shift.y -= 100.0 * _delta
		swarm_moved = true
	if Input.is_action_pressed("translate_down"):
		_swarm_monkeys_walk_down()
		manual_shift.y += 100.0 * _delta
		swarm_moved = true
	if Input.is_action_pressed("translate_left"):
		_swarm_monkeys_walk_left()
		manual_shift.x -= 100.0 * _delta
		swarm_moved = true
	if Input.is_action_pressed("translate_right"):
		_swarm_monkeys_walk_right()
		manual_shift.x += 100 * _delta
		swarm_moved = true
	
	# Apply the shift if not zero
	if manual_shift != Vector2.ZERO:
		_shift_swarm_position(manual_shift)
	
	# Ellipse resizing
	if Input.is_action_pressed("inc_height_ellipse"):
		swarm_ellipse_height += 100.0 * _delta
		_needs_full_ellipse_recalc = true
		swarm_moved = true
	if Input.is_action_pressed("dec_height_ellipse"):
		swarm_ellipse_height = max(0.0, swarm_ellipse_height - 100.0 * _delta)
		_needs_full_ellipse_recalc = true
		swarm_moved = true
	if Input.is_action_pressed("dec_width_ellipse"):
		swarm_ellipse_width = max(0.0, swarm_ellipse_width - 100.0 * _delta)
		_needs_full_ellipse_recalc = true
		swarm_moved = true
	if Input.is_action_pressed("inc_width_ellipse"):
		swarm_ellipse_width += 200.0 * _delta
		_needs_full_ellipse_recalc = true
		swarm_moved = true
	
	return swarm_moved
	
##
# Utility to stop monkey animations if no movement keys pressed
##
func _swarm_monkeys_stop_walk() -> void:
	for entry in swarm_monkeys:
		entry["node"].stop_walk()
func _swarm_monkeys_walk_up() -> void:
	for entry in swarm_monkeys:
		entry["node"].walk_up()
func _swarm_monkeys_walk_down() -> void:
	for entry in swarm_monkeys:
		entry["node"].walk_down()
func _swarm_monkeys_walk_left() -> void:
	for entry in swarm_monkeys:
		entry["node"].walk_left()
func _swarm_monkeys_walk_right() -> void:
	for entry in swarm_monkeys:
		entry["node"].walk_right()

# Shooting logic
func handle_shooting() -> void:
# Depending on which button is pressed, pass a direction vector
# If we are still in the cooldown, do nothing
	if _current_shoot_cooldown > 0.0:
		return
	if Input.is_action_pressed("shoot_up"):
		print()
		spawn_projectile(Vector2.UP)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_down"):
		spawn_projectile(Vector2.DOWN)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_left"):
		spawn_projectile(Vector2.LEFT)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_right"):
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

	var offset_distance = 90.0
	var spawn_offset = shoot_direction.normalized() * offset_distance
	var spawn_global_position = global_position + spawn_offset

	# calculating velocity
	var bullet_speed = 375.0
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

	# CASE 1: standalone player node, no world --> spawn projectile in local space
	if get_parent() == null or get_parent().get_parent() == null or get_parent().get_parent().get_node("Projectiles") == null:
		print_debug("Projectiles node not found, projectile not spawned. Remember to add to projectile node to scene.")
		return

	var projectiles_node = get_parent().get_parent().get_node("Projectiles")

	var local_spawn_pos = projectiles_node.to_local(spawn_global_position)
	projectile.position = local_spawn_pos

	projectiles_node.call_deferred("add_child", projectile)
