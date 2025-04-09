extends CharacterBody2D
# The BrainBoss is stationary and does not move.

# Reference to the AnimatedSprite2D for animations.
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
# Health bar node (assumed to have a method init_health() and a property 'value').
@onready var health_bar = $HealthBar

# Exported scenes for the different attack types.
@export var minion_scene: PackedScene

# Health settings for the boss.
@export var max_health: float = 100.0
var current_health: float

# Timer for triggering random attacks.
var attack_timer: Timer

# Attack interval settings.
@export var min_attack_interval: float = 3.0
@export var max_attack_interval: float = 8.0

# Optional quick-succession attack settings.
@export var quick_succession_chance: float = 0.25
@export var quick_succession_delay: float = 0.8

# Track if the boss is currently attacking or is dead.
var is_attacking: bool = false
var is_dead: bool = false

# List of available attacks with a weight factor for random selection.
var attacks = [
	{
		"name": "spawn_minions_attack",
		"function": Callable(self, "spawn_minions_attack"),
		"weight": 3,
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
		total_weight += attack.weight
	
	var random_value = randf() * total_weight
	var cumulative_weight: float = 0.0
	for attack in available_attacks:
		cumulative_weight += attack.weight
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
		total_weight += attack.weight
	
	var random_value = randf() * total_weight
	var cumulative_weight: float = 0.0
	for attack in available_attacks:
		cumulative_weight += attack.weight
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
		minion.scale = Vector2(0.5, 0.5)
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
	is_dead = true
	health_bar.hide()
	set_process(false)
	set_physics_process(false)
	_animated_sprite.play("die")
	print("BrainBoss died!")

	queue_free()

# This function handles any actions needed when an animation finishes.
# For example, after finishing the death animation, the boss is removed.
func _on_animated_sprite_animation_finished() -> void:
	if _animated_sprite.animation == "die":
		queue_free()
