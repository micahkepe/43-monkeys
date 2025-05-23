extends CharacterBody2D
## The PotionBoss is a powerful enemy that can throw potions at the player.
##
## The PotionBoss has four different attacks:
## 1. Single Damage Potion Projectile
## 2. Spread of 3 Damage Potion Projectiles
## 3. Single Heal Potion Projectile
## 4. Spread of 3 Heal Potion Projectiles
## The PotionBoss will randomly choose one of these attacks to perform.
##
## The PotionBoss will move to a random waypoint on the screen and wait for a
## random amount of time before moving to the next waypoint.

## AnimatedSprite2D node for the PotionBoss's sprite.
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Packed scene for the specific potions projs
@export var damage_potion_scene: PackedScene
@export var heal_potion_scene: PackedScene
@export var blindness_potion_scene: PackedScene
@export var paralyze_potion_scene: PackedScene

## Distance to start avoiding obstacles
@export var avoid_distance: float = 100.0

## The PotionBoss has a health bar that displays its current health.
@onready var health_bar = $HealthBar

## The PotionBoss's maximum health value.
@export var max_health: float = 50.0

## The PotionBoss's current health value.
var current_health: float

## Minimum interval between attacks
@export var min_attack_interval: float = 3.0

## Maximum interval between attacks
@export var max_attack_interval: float = 8.0

## The current waypoint the boss is moving to
var current_target: Vector2 = Vector2.ZERO

## The probability of quick succession attacks.
@export var quick_succession_chance: float = 0.25

## The delay between quick succession attacks (in seconds)
@export var quick_succession_delay: float = 0.8

## Movement speed
@export var move_speed: float = 150.0

## How close to the target before picking a new one
@export var proximity_threshold: float = 10.0

## Minimum wait time between moves (in seconds)
@export var min_wait_time: float = 0.5

## Maximum wait time between moves (in seconds)
@export var max_wait_time: float = 2

## Track the last animation played
var last_animation: String = "idle_down"

## Used to prevent movement animations from interrupting attack animations
var is_attacking: bool = false

## Unalive or nah?
var is_dead: bool = false

## Timer for random attacks
var attack_timer: Timer

## Slash damage
var slash_damage: int = 1


## Initialize the PotionBoss.
func _ready() -> void:
	current_health = max_health
	health_bar.init_health(current_health)

	move_to_next_waypoint()

	attack_timer = Timer.new()
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_choose_and_execute_attack"))
	_start_random_attack_timer()


## Choose a waypoint for the PotionBoss to move to.
## The waypoint is chosen within the bounds of the screen.
## @return Vector2 The random waypoint.
func choose_next_waypoint() -> Vector2:
	var max_attempts = 10
	var attempts = 0
	var waypoint = Vector2.ZERO

	# Level bounds
	var min_x = 6562 + 50
	var max_x = 7560 - 50
	var min_y = -1785 + 50
	var max_y = -368 - 50

	while attempts < max_attempts:
		var target = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, target, 1) # Mask for layer 1
		var result = space_state.intersect_ray(query)

		if result:
			var distance_to_obstacle = global_position.distance_to(result.position)
			print("Raycast hit at: ", result.position, " Distance: ", distance_to_obstacle)
			if distance_to_obstacle < avoid_distance:
				attempts += 1
				continue
		else:
			print("Raycast found no obstacles to ", target)

		waypoint = target
		break

	if waypoint == Vector2.ZERO:  # Fallback if all attempts fail
		print("Warning: Could not find clear waypoint after ", max_attempts, " attempts")
		waypoint = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))

	return waypoint


## Move the PotionBoss to the next random waypoint.
func move_to_next_waypoint() -> void:
	current_target = choose_next_waypoint()

## Called every frame. Handles movement and attack logic.
func _physics_process(_delta: float) -> void:
	if is_dead or current_target == Vector2.ZERO:
		return

	# Update animation
	_update_boss_animation()
	
	# Update the slow effect timer
	if is_slowed:
		slow_timer -= _delta
		if slow_timer <= 0:
			is_slowed = false
			_animated_sprite.modulate = Color(1, 1, 1, 1)

	# Check for colliding monkeys to attack
	var overlapping_bodies = $HitBox.get_overlapping_bodies()
	var targets = []
	for body in overlapping_bodies:
		if body.is_in_group("player") or body.is_in_group("troop"):
				targets.append(body)

	if targets.size() > 0:
			var closest_target = _get_closest_target_from_list(targets)
			if closest_target:
				_play_attack_animation(closest_target)
				if closest_target.has_method("take_damage"):
					closest_target.take_damage(slash_damage)
	else:
		# Move toward target with obstacle avoidance
		var direction = (current_target - global_position).normalized()
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direction * avoid_distance, 1)
		var result = space_state.intersect_ray(query)

		if result and global_position.distance_to(result.position) < avoid_distance:
			# Obstacle detected, adjust direction
			var normal = result.normal
			direction = direction.slide(normal).normalized()

		velocity = direction * move_speed
		if is_slowed:
			velocity = velocity * 0.65
		move_and_slide()

		if global_position.distance_to(current_target) <= proximity_threshold:
			velocity = Vector2.ZERO
			current_target = Vector2.ZERO
			start_wait_timer()


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

## Plays the attack animation and applies damage to the target node.
## @param target: Node2D - The target node to attack.
func _play_attack_animation(target: Node2D) -> void:
	var direction = (target.global_position - global_position).normalized()
	print_debug("Playing attack animation. Direction: ", direction)

	if abs(direction.x) > abs(direction.y):
		# Horizontal attack
		_animated_sprite.play("slash_right" if direction.x > 0 else "slash_left")
		print_debug("Playing horizontal attack animation: ", "slash_right" if direction.x > 0 else "slash_left")
	else:
		# Vertical attack
		_animated_sprite.play("slash_down" if direction.y > 0 else "slash_up")
		print_debug("Playing vertical attack animation: ", "slash_down" if direction.y > 0 else "slash_up")

	is_attacking = true


func _update_boss_animation() -> void:
	if current_target != Vector2.ZERO:
		var direction = (current_target - global_position).normalized()
		velocity = direction * move_speed
		if not is_attacking:
			if abs(direction.x) > abs(direction.y):
				if direction.x > 0:
					play_animation("walk_right")
				else:
					play_animation("walk_left")
			else:
				if direction.y > 0:
					play_animation("walk_down")
				else:
					play_animation("walk_up")

		# move_and_slide()

		if global_position.distance_to(current_target) <= proximity_threshold:
			velocity = Vector2.ZERO
			current_target = Vector2.ZERO
			play_idle_animation()
			start_wait_timer()
	else:
		velocity = Vector2.ZERO
		play_idle_animation()


## Take damage and update the health bar.
## @param amount float The amount of damage to take.
func take_damage(amount: float) -> void:
	print("PotionBoss took ", amount, " damage!")
	current_health -= amount
	health_bar.value = current_health

	if current_health <= 0:
		_die()
	else:
		# momentarily recolor the boss to indicate damage
		_animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.5).timeout
		if not is_slowed:
			_animated_sprite.modulate = Color(1, 1, 1, 1)


## Start a timer to wait before moving to the next waypoint.
func start_wait_timer() -> void:
	var wait_time = randf_range(min_wait_time, max_wait_time)
	await get_tree().create_timer(wait_time).timeout
	move_to_next_waypoint()


## Returns the Player node if found, otherwise returns null.
## @param root: The root node to start the search from.
## @return The Player node if found, otherwise null.
func find_player_node() -> Node:
	return get_tree().get_first_node_in_group("player")


## Recursively searches for a node with the given name starting from the
## given root node. Returns the node if found, otherwise returns null.
## @param root: The root node to start the search from.
## @param target: The name of the node to search for.
## @return The node with the given name if found, otherwise null.
func find_node_recursive(root: Node, target: String) -> Node:
	if root.name == target:
		return root

	for child in root.get_children():
		var result = find_node_recursive(child, target)
		if result:
			return result

	return null


## Adds a projectile to a container if available; otherwise adds it as a child.
## @param projectile Node The projectile to add.
func add_projectile(projectile: Node) -> void:
	var container = find_node_recursive(get_tree().root, "Projectiles")
	if container:
		container.add_child(projectile)
	else:
		add_child(projectile)


##################################################
# ATTACK 1: Single Damage Potion Projectile
##################################################

## Perform the attack: throw a single damage potion projectile.
func attack_throw_damage_potion() -> void:
	if not damage_potion_scene:
		print("DamagePotion scene not set!")
		return
	var player = find_player_node()
	if not player:
		return

	is_attacking = true

	# Instantiate and add the damage potion projectile.
	var projectile = damage_potion_scene.instantiate()
	add_projectile(projectile)
	projectile.global_position = global_position

	# Calculate the direction toward the player.
	var direction: Vector2 = (player.global_position - global_position).normalized()
	projectile.velocity = direction * 235 # Adjust speed of potion here

	# Play the appropriate attack animation.
	play_spell_animation(direction)
	await _animated_sprite.animation_finished
	is_attacking = false


##################################################
# ATTACK 2: Spread of 3 Damage Potion Projectiles
##################################################

## Attack that throws a spread of 3 damage potion projectiles.
func attack_throw_damage_potion_spread() -> void:
	if not damage_potion_scene:
		print("DamagePotion scene not set!")
		return
	var player = find_player_node()
	if not player:
		return

	is_attacking = true

	# Determine the base direction toward the player.
	var base_direction: Vector2 = (player.global_position - global_position).normalized()
	var base_angle: float = base_direction.angle()

	# Configure the spread: 3 projectiles with a total angular spread of 30° (PI/6 radians).
	var spread_count: int = 3
	var angle_range: float = PI / 6

	# Spawn each projectile with an even angular offset.
	for i in range(spread_count):
		var t: float = float(i) / (spread_count - 1) if spread_count > 1 else 0.5
		var offset_angle: float = lerp(-angle_range / 2, angle_range / 2, t)
		var projectile_angle: float = base_angle + offset_angle
		var projectile = damage_potion_scene.instantiate()
		add_projectile(projectile)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(projectile_angle) * 235

		# Small delay between each projectile (optional)
		await get_tree().create_timer(0.1).timeout

	play_spell_animation(base_direction)
	await _animated_sprite.animation_finished
	is_attacking = false

##################################################
# ATTACK 3: Single Heal Potion Projectile
##################################################

## Attack that throws a single heal potion projectile.
func attack_throw_heal_potion() -> void:
	if not heal_potion_scene:
		print("HealPotion scene not set!")
		return
	var player = find_player_node()
	if not player:
		return

	is_attacking = true

	# Instantiate and add the heal potion projectile.
	var projectile = heal_potion_scene.instantiate()
	add_projectile(projectile)
	projectile.global_position = global_position

	# Calculate the direction toward the player.
	var direction: Vector2 = (player.global_position - global_position).normalized()
	projectile.velocity = direction * 235  # Adjust speed as needed

	# Play the appropriate attack animation.
	play_spell_animation(direction)
	await _animated_sprite.animation_finished
	is_attacking = false

##################################################
# ATTACK 4: Spread of 3 Heal Potion Projectiles
##################################################

## Attack that throws a spread of 3 heal potion projectiles.
func attack_throw_heal_potion_spread() -> void:
	if not heal_potion_scene:
		print("HealPotion scene not set!")
		return

	var player = find_player_node()

	if not player:
		return

	is_attacking = true

	# Determine the base direction toward the player.
	var base_direction: Vector2 = (player.global_position - global_position).normalized()
	var base_angle: float = base_direction.angle()

	# Configure the spread: 3 projectiles with a total angular spread of 30° (PI/6 radians).
	var spread_count: int = 3
	var angle_range: float = PI / 6  # 30 degrees in radians

	# Spawn each projectile with an even angular offset.
	for i in range(spread_count):
		var t: float = float(i) / (spread_count - 1) if spread_count > 1 else 0.5
		var offset_angle: float = lerp(-angle_range / 2, angle_range / 2, t)
		var projectile_angle: float = base_angle + offset_angle
		var projectile = heal_potion_scene.instantiate()
		add_projectile(projectile)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(projectile_angle) * 235  # Same speed multiplier

		# Optional small delay between projectiles.
		await get_tree().create_timer(0.1).timeout

	play_spell_animation(base_direction)
	await _animated_sprite.animation_finished
	is_attacking = false


##################################################
# ATTACK 5: Single Blindness Potion Projectile
##################################################

## Attack that throws a single heal potion projectile.
func attack_throw_blindness_potion() -> void:
	if not blindness_potion_scene:
		print("HealPotion scene not set!")
		return
	var player = find_player_node()
	if not player:
		return

	is_attacking = true

	# Instantiate and add the heal potion projectile.
	var projectile = blindness_potion_scene.instantiate()
	add_projectile(projectile)
	projectile.global_position = global_position

	# Calculate the direction toward the player.
	var direction: Vector2 = (player.global_position - global_position).normalized()
	projectile.velocity = direction * 235  # Adjust speed as needed

	# Play the appropriate attack animation.
	play_spell_animation(direction)
	await _animated_sprite.animation_finished
	is_attacking = false

##################################################
# ATTACK 6: Spread of 3 Blindness Potion Projectiles
##################################################

## Attack that throws a spread of 3 heal potion projectiles.
func attack_throw_blindness_potion_spread() -> void:
	if not heal_potion_scene:
		print("HealPotion scene not set!")
		return

	var player = find_player_node()

	if not player:
		return

	is_attacking = true

	# Determine the base direction toward the player.
	var base_direction: Vector2 = (player.global_position - global_position).normalized()
	var base_angle: float = base_direction.angle()

	# Configure the spread: 3 projectiles with a total angular spread of 30° (PI/6 radians).
	var spread_count: int = 3
	var angle_range: float = PI / 6  # 30 degrees in radians

	# Spawn each projectile with an even angular offset.
	for i in range(spread_count):
		var t: float = float(i) / (spread_count - 1) if spread_count > 1 else 0.5
		var offset_angle: float = lerp(-angle_range / 2, angle_range / 2, t)
		var projectile_angle: float = base_angle + offset_angle
		var projectile = blindness_potion_scene.instantiate()
		add_projectile(projectile)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(projectile_angle) * 235  # Same speed multiplier

		# Optional small delay between projectiles.
		await get_tree().create_timer(0.1).timeout

	play_spell_animation(base_direction)
	await _animated_sprite.animation_finished
	is_attacking = false

##################################################
# ATTACK 7: Single Paralyze Potion Projectile
##################################################

## Attack that throws a single heal potion projectile.
func attack_throw_paralyze_potion() -> void:
	if not blindness_potion_scene:
		print("HealPotion scene not set!")
		return
	var player = find_player_node()
	if not player:
		return

	is_attacking = true

	# Instantiate and add the heal potion projectile.
	var projectile = paralyze_potion_scene.instantiate()
	add_projectile(projectile)
	projectile.global_position = global_position

	# Calculate the direction toward the player.
	var direction: Vector2 = (player.global_position - global_position).normalized()
	projectile.velocity = direction * 235  # Adjust speed as needed

	# Play the appropriate attack animation.
	play_spell_animation(direction)
	await _animated_sprite.animation_finished
	is_attacking = false

##################################################
# ATTACK 8: Spread of 3 paralyze Potion Projectiles
##################################################

## Attack that throws a spread of 3 heal potion projectiles.
func attack_throw_paralyze_potion_spread() -> void:
	if not heal_potion_scene:
		print("HealPotion scene not set!")
		return

	var player = find_player_node()

	if not player:
		return

	is_attacking = true

	# Determine the base direction toward the player.
	var base_direction: Vector2 = (player.global_position - global_position).normalized()
	var base_angle: float = base_direction.angle()

	# Configure the spread: 3 projectiles with a total angular spread of 30° (PI/6 radians).
	var spread_count: int = 3
	var angle_range: float = PI / 6  # 30 degrees in radians

	# Spawn each projectile with an even angular offset.
	for i in range(spread_count):
		var t: float = float(i) / (spread_count - 1) if spread_count > 1 else 0.5
		var offset_angle: float = lerp(-angle_range / 2, angle_range / 2, t)
		var projectile_angle: float = base_angle + offset_angle
		var projectile = paralyze_potion_scene.instantiate()
		add_projectile(projectile)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(projectile_angle) * 235  # Same speed multiplier

		# Optional small delay between projectiles.
		await get_tree().create_timer(0.1).timeout

	play_spell_animation(base_direction)
	await _animated_sprite.animation_finished
	is_attacking = false


##################################################
# Helper Animation Functions
##################################################

## Play the appropriate spell animation based on the direction.
## @param direction Vector2 The direction to play the animation.
func play_spell_animation(direction: Vector2) -> void:
	if is_dead:
		return
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			play_animation("spell_right")
		else:
			play_animation("spell_left")
	else:
		if direction.y > 0:
			play_animation("spell_down")
		else:
			play_animation("spell_up")


## Play the specified animation.
## @param anim_name String The name of the animation to play.
func play_animation(anim_name: String) -> void:
	if is_dead:
		return
	if _animated_sprite.animation != anim_name:
		_animated_sprite.play(anim_name)
		last_animation = anim_name



## Play the idle animation based on the last animation played.
func play_idle_animation() -> void:
	if is_dead:
		return
	if "down" in last_animation:
		play_animation("idle_down")
	elif "up" in last_animation:
		play_animation("idle_up")
	elif "left" in last_animation:
		play_animation("idle_left")
	elif "right" in last_animation:
		play_animation("idle_right")
	else:
		play_animation("idle_down")

#############################################################
# ATTACK LOGIC
#
# NOTE: Only two attacks are used in this version
#############################################################
var attacks = [
	{
		"name": "attack_throw_damage_potion",
		"function": Callable(self, "attack_throw_damage_potion"),
		"weight": 3,
		"unlocked": true
	},
	{
		"name": "attack_throw_damage_potion_spread",
		"function": Callable(self, "attack_throw_damage_potion_spread"),
		"weight": 2,
		"unlocked": true
	},
	{
		"name": "attack_throw_heal_potion",
		"function": Callable(self, "attack_throw_heal_potion"),
		"weight": 2,
		"unlocked": true
	},
	{
		"name": "attack_throw_heal_potion_spread",
		"function": Callable(self, "attack_throw_heal_potion_spread"),
		"weight": 1,
		"unlocked": true
	},
	{
		"name": "attack_throw_blindness_potion",
		"function": Callable(self, "attack_throw_blindness_potion"),
		"weight": 2,
		"unlocked": true
	},
	{
		"name": "attack_throw_blindness_potion_spread",
		"function": Callable(self, "attack_throw_blindness_potion_spread"),
		"weight": 1,
		"unlocked": true
	},
	{
		"name": "attack_throw_paralyze_potion",
		"function": Callable(self, "attack_throw_paralyze_potion"),
		"weight": 2,
		"unlocked": true
	},
	{
		"name": "attack_throw_paralyze_potion_spread",
		"function": Callable(self, "attack_throw_paralyze_potion_spread"),
		"weight": 1,
		"unlocked": true
	}
]


## Start a timer to trigger a random attack.
func _start_random_attack_timer():
	var wait_time = randf_range(min_attack_interval, max_attack_interval)
	attack_timer.wait_time = wait_time
	attack_timer.start()
	print("Attack timer started, next attack in ", wait_time, " seconds")


## Choose and execute an attack.
func _choose_and_execute_attack() -> void:
	var available_attacks = []
	for attack in attacks:
		if attack.unlocked:
			available_attacks.append(attack)
	if available_attacks.size() == 0:
		print("No available attacks!")
		_start_random_attack_timer()
		return
	var total_weight: float = 0.0
	for attack in available_attacks:
		total_weight += attack.weight
	var random_value = randf() * total_weight
	var cumulative_weight: float = 0.0
	for attack in available_attacks:
		cumulative_weight += attack.weight
		if random_value <= cumulative_weight:
			attack.function.call()
			if randf() < quick_succession_chance:
				print("Quick succession triggered!")
				await _perform_quick_succession_attack(available_attacks)
			break
	_start_random_attack_timer()


## Perform a quick succession attack.
## @param available_attacks Array The available attacks to choose from.
func _perform_quick_succession_attack(available_attacks: Array) -> void:
	await get_tree().create_timer(quick_succession_delay).timeout
	var total_weight: float = 0.0
	for attack in available_attacks:
		total_weight += attack.weight
	var random_value = randf() * total_weight
	var cumulative_weight: float = 0.0
	for attack in available_attacks:
		cumulative_weight += attack.weight
		if random_value <= cumulative_weight:
			attack.function.call()
			break

##########################################
# DAMAGE/ DEATH LOGIC
##########################################
## Handles the boid's death.
func _die():
	# welp, this is it.
	is_dead = true
	health_bar.hide()

	## Disable physics and processing
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0

	# Stop all movement and attacks
	velocity = Vector2.ZERO
	attack_timer.stop()
	current_target = Vector2.ZERO
	is_attacking = false

	# Disable the hitbox to prevent further interactions
	if is_instance_valid($HitBox):
		$HitBox.set_deferred("monitoring", false)
		$HitBox.set_deferred("monitorable", false)

	print("PotionBoss died!")
	_animated_sprite.play("die")

	if $DieSFX:
		$DieSFX.play()

	# NOTE: The boss will be removed from the scene tree when the animation finishes

## Handles the animation finished signal for the boid.
func _on_animated_sprite_2d_animation_finished() -> void:
	if _animated_sprite.animation == "die":
		_animated_sprite.stop()
		if $DieSFX.playing:
			await $DieSFX.finished
		queue_free()
	elif _animated_sprite.animation.begins_with("spell"):
		is_attacking = false

## Handles the hit box area entered signal.
func _on_hit_box_body_exited(body:Node2D) -> void:
	if is_dead:
		return
	print_debug("Boid hit box exited body: ", body)
	is_attacking = false

	# Reset the animation to the walk animation
	_animated_sprite.play("walk_down")


# Variables to track slow effect state
var is_slowed: bool = false
var slow_timer: float = 0.0

func slow_down() -> void:
	is_slowed = true
	slow_timer = 5.0  # Effect lasts 5 seconds
	# Tint the sprite light blue
	_animated_sprite.modulate = Color(0.5, 0.8, 1, 1)
