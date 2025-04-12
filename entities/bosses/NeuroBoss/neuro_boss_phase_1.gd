extends CharacterBody2D
# The BrainBoss is stationary and does not move.

signal monkey_controlled(monkey)
signal monkey_released(monkey)
signal phase1_died(phase2_instance)

# Reference to the AnimatedSprite2D for animations.
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
# Health bar node (assumed to have a method init_health() and a property 'value').
@onready var health_bar = $HealthBar

# Exported scenes for the different attack types.
@export var minion_scene: PackedScene
@export var default_projectile_scene: PackedScene
@export var aoe_projectile_scene: PackedScene
@export var brainbrim_scene: PackedScene
@export var brainfog_scene: PackedScene
@export var phase2_scene: PackedScene

@export var aoe_proj_prob: float = 0.15

# Health settings for the boss.
@export var max_health: float = 10.0
var current_health: float

# Timer for triggering random attacks.
var attack_timer: Timer

# Attack interval settings.
@export var min_attack_interval: float = 2.0
@export var max_attack_interval: float = 4.5

# Optional quick-succession attack settings.
@export var quick_succession_chance: float = 0.25
@export var quick_succession_delay: float = 0.8

# Track if the boss is currently attacking or is dead.
var is_attacking: bool = false
var is_dead: bool = false
var phase2_spawned = false

@export var minion_scale: float = 0.5
@export var bullet_scale: float = 0.5

# List of available attacks with a weight factor for random selection.
var attacks: Array[Dictionary] = [
	{
		"name": "spawn_minions_attack",
		"function": Callable(self, "spawn_minions_attack"),
		"weight": 5,
		"unlocked": true
	},
	{
		"name": "attack_shoot_projectiles_circle",
		"function": Callable(self, "attack_shoot_projectiles_circle"),
		"weight": 2,
		"unlocked": true
	},
	{
		"name": "attack_shoot_projectiles_spiral",
		"function": Callable(self, "attack_shoot_projectiles_spiral"),
		"weight": 2,
		"unlocked": true
	},
	{
		"name": "attack_shoot_bullet_wall_vertical",
		"function": Callable(self, "attack_shoot_bullet_wall_vertical"),
		"weight": 3,
		"unlocked": true
	},
	{
		"name": "attack_shoot_bullet_wall_horizontal",
		"function": Callable(self, "attack_shoot_bullet_wall_horizontal"),
		"weight": 3,
		"unlocked": true
	},
	{
		"name": "attack_brainbeam_cardinal",
		"function": Callable(self, "attack_brainbeam_cardinal"),
		"weight": 1,
		"unlocked": true
	},
	{
		"name": "attack_brainbeam_diagonal",
		"function": Callable(self, "attack_brainbeam_diagonal"),
		"weight": 1,
		"unlocked": true
	},
	{
		"name": "attack_brain_fog",
		"function": Callable(self, "attack_brain_fog"),
		"weight": 4,
		"unlocked": true
	}

]

func _ready() -> void:
	# Initialize the boss health and display.
	current_health = max_health
	health_bar.init_health(current_health)

	_animated_sprite.play("idle")

	# Create and set up a one-shot timer node for triggering attacks.
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_choose_and_execute_attack"))

	# Start the first random attack timer.
	_start_random_attack_timer()

#########################################
# ATTACK TIMER & SELECTION LOGIC
#########################################

# Start or restart the timer with a random wait time.
func _start_random_attack_timer() -> void:
	var wait_time = randf_range(min_attack_interval, max_attack_interval)
	attack_timer.wait_time = wait_time
	attack_timer.start()
	print("Attack timer started, next attack in ", wait_time, " seconds")

# Chooses a random attack based on their weights and then executes it.
func _choose_and_execute_attack() -> void:
	if is_dead:
		return

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
		total_weight += attack["weight"]

	var random_value = randf() * total_weight
	var cumulative_weight: float = 0.0
	for attack in available_attacks:
		cumulative_weight += attack["weight"]
		if random_value <= cumulative_weight:
			# Call the chosen attack function.
			attack.function.call()
			# Randomly: trigger a quick succession attack.
			if randf() < quick_succession_chance:
				print("Quick succession triggered!")
				await _perform_quick_succession_attack(available_attacks)
			break

	# Restart the attack timer.
	_start_random_attack_timer()

# Helper for quick succession attacks after a short delay.
func _perform_quick_succession_attack(available_attacks: Array) -> void:
	await get_tree().create_timer(quick_succession_delay).timeout
	var total_weight: float = 0.0
	for attack in available_attacks:
		total_weight += attack["weight"]

	var random_value = randf() * total_weight
	var cumulative_weight: float = 0.0
	for attack in available_attacks:
		cumulative_weight += attack["weight"]
		if random_value <= cumulative_weight:
			attack.function.call()
			break


#########################################
# ATTACK FUNCTIONS
#########################################

# Utility function to get the player node (expects player to belong to the "player" group).
func find_player_node() -> Node:
	return get_tree().get_first_node_in_group("player")

# ---------------------------
# Attack 1: Spawn Minions
# ---------------------------
# This attack spawns a set number of minion enemies around the BrainBoss.
# It will only spawn minions if fewer than 12 already exist.
func spawn_minions_attack() -> void:
	if not minion_scene:
		print("Minion scene not set!")
		return

	# Check how many minions already exist by counting nodes in the "minions" group
	var current_minions = get_tree().get_nodes_in_group("minions")
	if current_minions.size() >= 12:
		print("Maximum minions reached (", current_minions.size(), "); not spawning any more.")
		return

	var max_spawn = 12 - current_minions.size()
	var num_minions = min(3, max_spawn)

	is_attacking = true
	for i in range(num_minions):
		var minion = minion_scene.instantiate()
		minion.scale = Vector2(minion_scale, minion_scale)
		minion.add_to_group("minions")
		add_child(minion)

		# Spawn each minion with a small random offset from the boss positio
		var x_offset: int
		if randi() % 2 == 0:
			x_offset = -200
		else:
			x_offset = 200

		var y_offset: int
		if randi() % 2 == 0:
			y_offset = -200
		else:
			y_offset = 200

		var offset = Vector2(x_offset, y_offset)

		minion.global_position = global_position + offset
		await get_tree().create_timer(0.1).timeout

	is_attacking = false

# ---------------------------
# Attack 2: Shoot Projectiles in a Circle
# ---------------------------
# This attack fires a series of projectiles evenly around the boss.
func attack_shoot_projectiles_circle() -> void:
	if not default_projectile_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var num_projectiles = 12
	var angle_step = (PI * 2) / num_projectiles
	for i in range(num_projectiles):
		var random_val = randf()  # random float from 0.0 to 1.0
		var projectile: Node
		if random_val < aoe_proj_prob:
			projectile = aoe_projectile_scene.instantiate()
		else:
			projectile = default_projectile_scene.instantiate()

		projectile.scale = Vector2(bullet_scale, bullet_scale)
		add_child(projectile)
		projectile.global_position = global_position
		# Set the projectile velocity so that it moves outward.
		projectile.velocity = Vector2.RIGHT.rotated(i * angle_step) * 300

	await get_tree().create_timer(0.8).timeout
	angle_step = (PI / 12)
	for i in range(24):
		if i % 2 == 0:
			continue

		var projectile = default_projectile_scene.instantiate()
		projectile.scale = Vector2(bullet_scale, bullet_scale)
		add_child(projectile)
		projectile.global_position = global_position
		# Set the projectile velocity so that it moves outward.
		projectile.velocity = Vector2.RIGHT.rotated(i * angle_step) * 300

	await _animated_sprite.animation_finished
	is_attacking = false

func attack_shoot_projectiles_circle2() -> void:
	if not default_projectile_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var _num_projectiles = 12
	var angle_step = (PI / 12)
	for i in range(24):
		if i % 2 == 0:
			continue

		var random_val = randf()  # random float from 0.0 to 1.0
		var projectile: Node
		if random_val < aoe_proj_prob:
			projectile = aoe_projectile_scene.instantiate()
		else:
			projectile = default_projectile_scene.instantiate()
			
		projectile.scale = Vector2(bullet_scale, bullet_scale)
		add_child(projectile)
		projectile.global_position = global_position
		# Set the projectile velocity so that it moves outward.
		projectile.velocity = Vector2.RIGHT.rotated(i * angle_step) * 300

	await _animated_sprite.animation_finished
	is_attacking = false


# ---------------------------
# Attack 3: Shoot Projectiles in a Spiral
# ---------------------------
# This attack fires projectiles in a spiral pattern, one after the other.
func attack_shoot_projectiles_spiral() -> void:
	if not default_projectile_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var num_projectiles = 20
	var angle = 0.0
	var angle_increment = PI / 7.5  # Adjust this for tighter or looser spirals.
	for i in range(num_projectiles):
		
		var random_val = randf()  # random float from 0.0 to 1.0
		var projectile: Node
		if random_val < aoe_proj_prob:
			projectile = aoe_projectile_scene.instantiate()
		else:
			projectile = default_projectile_scene.instantiate()
			
		projectile.scale = Vector2(bullet_scale, bullet_scale)
		add_child(projectile)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(angle) * 300
		angle += angle_increment
		await get_tree().create_timer(0.1).timeout
	await _animated_sprite.animation_finished
	is_attacking = false

# ---------------------------
# Attack 4: Shoot a Vertical Bullet Wall (Centered on Boss)
# ---------------------------
# This attack spawns bullets along a horizontal line through the boss.
# Each bullet's x position is randomly offset within ±300 from the boss,
# and they travel downward.
func attack_shoot_bullet_wall_vertical() -> void:
	if not default_projectile_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var duration = 4.0            # Duration of the effect in seconds.
	var spawn_interval = 0.15     # Time between each bullet spawn.
	var elapsed = 0.0
	while elapsed < duration:
		
		var random_val = randf()  # random float from 0.0 to 1.0
		var projectile: Node
		if random_val < aoe_proj_prob:
			projectile = aoe_projectile_scene.instantiate()
		else:
			projectile = default_projectile_scene.instantiate()
			
		projectile.scale = Vector2(bullet_scale, bullet_scale)
		add_child(projectile)
		var x_offset = randf_range(-800, 800)
		# Spawn along a horizontal line at the boss's y position.
		projectile.global_position = Vector2(global_position.x + x_offset, global_position.y - 1100)
		# Set the projectile to move downward.
		projectile.velocity = Vector2(0, 450)
		await get_tree().create_timer(spawn_interval).timeout
		elapsed += spawn_interval
	await _animated_sprite.animation_finished
	is_attacking = false


# ---------------------------
# Attack 5: Shoot a Horizontal Bullet Wall (Centered on Boss)
# ---------------------------
# This attack spawns bullets along a vertical line through the boss.
# Each bullet's y position is randomly offset within ±300 from the boss,
# and they travel rightward.
func attack_shoot_bullet_wall_horizontal() -> void:
	if not default_projectile_scene:
		print("Projectile scene not set!")
		return

	is_attacking = true
	var duration = 4.0            # Duration of the effect in seconds.
	var spawn_interval = 0.15      # Time between bullet spawns.
	var elapsed = 0.0
	while elapsed < duration:
		
		var random_val = randf()  # random float from 0.0 to 1.0
		var projectile: Node
		if random_val < aoe_proj_prob:
			projectile = aoe_projectile_scene.instantiate()
		else:
			projectile = default_projectile_scene.instantiate()
			
		projectile.scale = Vector2(bullet_scale, bullet_scale)
		add_child(projectile)
		var y_offset = randf_range(-800, 800)
		# Spawn along a vertical line at the boss's x position.
		projectile.global_position = Vector2(global_position.x - 1700.0, global_position.y + y_offset)
		# Set the projectile to move rightward.
		projectile.velocity = Vector2(450, 0)
		await get_tree().create_timer(spawn_interval).timeout
		elapsed += spawn_interval
	await _animated_sprite.animation_finished
	is_attacking = false


# ---------------------------
# Attack 6: Brainbeam Cardinal
# ---------------------------
# Spawns 4 instances of BrainBrim in the cardinal directions (North, East, South, West).
func attack_brainbeam_cardinal() -> void:
	if not brainbrim_scene:
		print("BrainBrim scene not set!")
		return

	is_attacking = true

	# Dictionary mapping cardinal direction names to their parameters..
	var cardinal_data = {
		"north": { "pos": Vector2(6.0, -6998.0), "rotation": 0,    "scale": Vector2(5.0, 14.3) },
		"east":  { "pos": Vector2(976, -6269),  "rotation": PI / 2,   "scale": Vector2(5.0, 24.3) },
		"south": { "pos": Vector2(6.0, -5508),  "rotation": 0,  "scale": Vector2(5.0, 19.0) },
		"west":  { "pos": Vector2(-985, -6269), "rotation": PI / 2,  "scale": Vector2(5.0, 24.3) }
	}

	# Loop through each cardinal direction and spawn a BrainBrim
	for direction in cardinal_data.keys():
		var brainbrim = brainbrim_scene.instantiate()
		var braim_beam_holder = get_parent().get_node("BrainBeamHolder")
		braim_beam_holder.add_child(brainbrim)

		var data = cardinal_data[direction]
		brainbrim.global_position = data["pos"]
		brainbrim.rotation = data["rotation"]
		brainbrim.scale = data["scale"]

	await _animated_sprite.animation_finished
	is_attacking = false

# ---------------------------
# Attack 7: Brainbeam Diagonal
# ---------------------------
# Spawns 4 instances of BrainBrim in the diagonal directions (NE, SE, SW, NW).
func attack_brainbeam_diagonal() -> void:
	print("=== DIAGNOLLA")
	if not brainbrim_scene:
		print("BrainBrim scene not set!")
		return

	is_attacking = true

	# Dictionary for diagonal directions.
	var diagonal_data = {
		"sw": { "pos": Vector2(-642, -5671), "rotation": PI / 4,    "scale": Vector2(5.0, 21.0) },
		"ne":  { "pos": Vector2(453, -6802),  "rotation": PI / 4,   "scale": Vector2(5.0, 16.0) },
		"se": { "pos": Vector2(588, -5671),  "rotation": (3 * PI) / 4,  "scale": Vector2(5.0, 21.0) },
		"nw":  { "pos": Vector2(-481, -6811), "rotation": (3 * PI) / 4,  "scale": Vector2(5.0, 16.0) }
	}

	# Loop through each diagonal direction and spawn a BrainBrim
	for direction in diagonal_data.keys():
		var brainbrim = brainbrim_scene.instantiate()
		var braim_beam_holder = get_parent().get_node("BrainBeamHolder")
		braim_beam_holder.add_child(brainbrim)

		var data = diagonal_data[direction]
		brainbrim.global_position = data["pos"]
		brainbrim.rotation = data["rotation"]
		brainbrim.scale = data["scale"]

	await _animated_sprite.animation_finished
	is_attacking = false

# ---------------------------
# Attack 8: Brain Fog Forcefield
# ---------------------------
# Spawns a layer of fog over the brain, protecting it from all projectiles.
func attack_brain_fog() -> void:
	if not brainfog_scene:
		print("Brain Fog Scene Not Set")
		return

	var brainfog = brainfog_scene.instantiate()
	var brain_beam_holder = get_parent().get_node("BrainBeamHolder")
	brain_beam_holder.add_child(brainfog)
	brainfog.global_position = global_position
	brainfog.scale = Vector2(22,22)

	print("=== BRIAN FOG AT: ", brainfog.global_position)




#########################################
# HELPER ANIMATION FUNCTIONS
#########################################

# Plays the animation if it isn’t already playing.
func play_animation(anim_name: String) -> void:
	if is_dead:
		return
	if _animated_sprite.animation != anim_name:
		_animated_sprite.play(anim_name)


#########################################
# DAMAGE / DEATH LOGIC
#########################################

# This function is called when the boss takes damage.
func take_damage(amount: float) -> void:
	print("BrainBoss took ", amount, " damage!")
	current_health -= amount
	health_bar.value = current_health

	if current_health <= 0:
		_die()
	else:
		# Flash the sprite to indicate damage.
		_animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.5).timeout
		_animated_sprite.modulate = Color(1, 1, 1, 1)

# Called when the boss's health reaches zero.
func _die() -> void:
	if is_dead || phase2_spawned:
		return
	is_dead = true
	phase2_spawned = true
	health_bar.hide()
	set_process(false)
	# Use set_deferred for physics properties instead of direct assignment
	set_deferred("physics_process", false)
	_animated_sprite.play("die")
	print("BrainBoss died!")

	# Use call_deferred to create the phase2 boss to avoid physics issues
	call_deferred("_spawn_phase2")

# New function to handle spawning Phase 2
func _spawn_phase2() -> void:
	var world_node = get_parent()
	var phase2 = phase2_scene.instantiate()
	world_node.add_child(phase2)
	phase2.global_position = global_position
	phase2.scale = Vector2(1, 1)
	
	# Emit signal with the correct instance
	emit_signal("phase1_died", phase2)
	
	# Queue free at the end
	queue_free()

# This function handles any actions needed when an animation finishes.
# For example, after finishing the death animation, the boss is removed.
func _on_animated_sprite_animation_finished() -> void:
	if _animated_sprite.animation == "die":
		queue_free()
