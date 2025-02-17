extends CharacterBody2D
## The ChemistBoss is a powerful enemy that can throw potions at the player.
##
## The ChemistBoss has four different attacks:
## 1. Single Damage Potion Projectile
## 2. Spread of 3 Damage Potion Projectiles
## 3. Single Heal Potion Projectile
## 4. Spread of 3 Heal Potion Projectiles
## The ChemistBoss will randomly choose one of these attacks to perform.
##
## The ChemistBoss will move to a random waypoint on the screen and wait for a
## random amount of time before moving to the next waypoint.

## AnimatedSprite2D node for the ChemistBoss's sprite.
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Packed scene for the specific potions projs
@export var damage_potion_scene: PackedScene
@export var heal_potion_scene: PackedScene
@export var blindness_potion_scene: PackedScene

## The ChemistBoss has a health bar that displays its current health.
@onready var health_bar = $HealthBar

## The ChemistBoss's maximum health value.
@export var max_health: float = 100.0

## The ChemistBoss's current health value.
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

## Minimum wait time between moves
@export var min_wait_time: float = 0.8

## Maximum wait time between moves
@export var max_wait_time: float = 2.5

## Track the last animation played
var last_animation: String = "idle_down"

## Used to prevent movement animations from interrupting attack animations
var is_attacking: bool = false

## Unalive or nah?
var is_dead: bool = false

## Timer for random attacks
var attack_timer: Timer


## Initialize the ChemistBoss.
func _ready() -> void:
	current_health = max_health
	health_bar.init_health(current_health)

	move_to_next_waypoint()

	attack_timer = Timer.new()
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_choose_and_execute_attack"))
	_start_random_attack_timer()


## Choose a random waypoint for the ChemistBoss to move to.
## The waypoint is chosen within the bounds of the screen.
## @return Vector2 The random waypoint.
func choose_random_waypoint() -> Vector2:
	var min_x = 6562 + 50
	var max_x = 7560 - 50
	var min_y = -1785 + 50
	var max_y = -368 - 50
	return Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))


## Move the ChemistBoss to the next random waypoint.
func move_to_next_waypoint() -> void:
	current_target = choose_random_waypoint()

## Called every frame. Handles movement and attack logic.
func _physics_process(_delta: float) -> void:
	if is_dead:
		return

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
		move_and_slide()
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
	print("ChemistBoss took ", amount, " damage!")
	current_health -= amount
	health_bar.value = current_health
	
	if current_health <= 0:
		_die()
	else:
		# momentarily recolor the boss to indicate damage
		_animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.5).timeout
		_animated_sprite.modulate = Color(1, 1, 1, 1)


## Start a timer to wait before moving to the next waypoint.
func start_wait_timer() -> void:
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
	var player = find_player_node(get_tree().get_root())
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
	#projectile.scale = Vector2(1.5, 1.5)

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
	var player = find_player_node(get_tree().get_root())
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
		#projectile.scale = Vector2(1.5, 1.5)
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
	var player = find_player_node(get_tree().get_root())
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
	#projectile.scale = Vector2(1.5, 1.5)

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

	var player = find_player_node(get_tree().get_root())

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
		#projectile.scale = Vector2(1.5, 1.5)
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
	var player = find_player_node(get_tree().get_root())
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
	#projectile.scale = Vector2(1.5, 1.5)

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

	var player = find_player_node(get_tree().get_root())

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
		#projectile.scale = Vector2(1.5, 1.5)
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
		"weight": 200,
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
		"weight": 200,
		"unlocked": true
	},
	{
		"name": "attack_throw_blindness_potion_spread",
		"function": Callable(self, "attack_throw_blindness_potion_spread"),
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

	print("ChemistBoss died!")
	_animated_sprite.play("die")
	# NOTE: The boss will be removed from the scene tree when the animation finishes

## Handles the animation finished signal for the boid.
func _on_animated_sprite_2d_animation_finished() -> void:
	if _animated_sprite.animation == "die":
		_animated_sprite.stop()
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
