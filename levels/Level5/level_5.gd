extends "res://levels/default_level.gd"

@onready var post_boss_cutscene: PackedScene = preload("res://cutscenes/Level5/Level5PostBoss/level_5_post_boss.tscn")

@onready var background_music: AudioStreamPlayer = $BackgroundMusic

@onready var dialogue_cutscene: PackedScene = preload("res://cutscenes/Level5/Level5PreBoss/level_5_pre_boss_cutscene.tscn")
var dialogue_cutscene_played: bool = false

# Store references obtained in _ready
var player_node: Player # Type hint helps with autocompletion and type safety
var neuro_boss_node: Node # Or specific type if you know it (e.g., CharacterBody2D)

var _troop_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	# Button-to-laser puzzle configuration
	buttons_to_lasers = {
		["Button1", "Button2"]: ["Laser1"],
		["Button3", "Button4", "Button5", "Button6"]: ["Laser2", "Laser3"],
		["Button7", "Button8", "Button9", "Button10", "Button11"]: ["Laser5", "Laser6", "Laser7"],
	}

	# Gear-to-laser puzzle configuration
	gears_to_lasers = {
		["Gear1", "Gear2"]: ["Laser8", "Laser9", "Laser10"],
		["Gear3"]: ["Laser4"],
	}

	super._ready()

	# Use await to ensure nodes are ready before getting references
	await ready

	background_music.play()

	if not _troop_data.is_empty():
		initialize_from_troop_data()

	# Get references using get_node_or_null for safety
	var potential_player = $World.get_node_or_null("Player")
	neuro_boss_node = $World.get_node_or_null("NeuroBossPhase1")

	# --- Player Node Verification ---
	if not is_instance_valid(potential_player):
		printerr("Level 5 _ready ERROR: Node at $World/Player NOT FOUND!")
		player_node = null
	elif not potential_player is Player:
		printerr("Level 5 _ready ERROR: Node at $World/Player is NOT of type Player!")
		printerr("  Found Node Type: ", potential_player.get_class())
		printerr("  Found Node Script: ", potential_player.get_script())
		player_node = null # Explicitly null if wrong type
	else:
		player_node = potential_player # Assign only if valid and correct type
		print("Level 5 _ready: Successfully found and validated Player node: ", player_node)
		print("  Player Script: ", player_node.get_script())

	# --- NeuroBoss Node Verification ---
	if not is_instance_valid(neuro_boss_node):
		printerr("Level 5 _ready ERROR: NeuroBoss node not found at path $World/NeuroBoss!")
		# Decide if you should return or continue without boss functionality
		return

	# --- Signal Connection (Only if both nodes are valid) ---
	if is_instance_valid(player_node) and is_instance_valid(neuro_boss_node):
		# Clean up any existing connections first to prevent duplicates
		if neuro_boss_node.is_connected("monkey_controlled", Callable(self, "_on_monkey_controlled")):
			neuro_boss_node.disconnect("monkey_controlled", Callable(self, "_on_monkey_controlled"))

		if neuro_boss_node.is_connected("monkey_released", Callable(self, "_on_monkey_released")):
			neuro_boss_node.disconnect("monkey_released", Callable(self, "_on_monkey_released"))

		# Check if boss has the expected signals before connecting
		if not neuro_boss_node.has_signal("monkey_controlled"):
			printerr("Level 5 Error: NeuroBoss node does not have the 'monkey_controlled' signal!")
		else:
			neuro_boss_node.monkey_controlled.connect(_on_monkey_controlled)

		if not neuro_boss_node.has_signal("monkey_released"):
			printerr("Level 5 Error: NeuroBoss node does not have the 'monkey_released' signal!")
		else:
			neuro_boss_node.monkey_released.connect(_on_monkey_released)

		print("Level 5: Successfully connected NeuroBoss signals.")
	else:
		printerr("Level 5 _ready: Cannot connect signals because Player or NeuroBoss node is invalid.")
	
	# Connect to NeuroBossPhase1's death signal
	if is_instance_valid(neuro_boss_node):
		# Check each signal individually before trying to connect
	
		# For phase1_died signal
		if neuro_boss_node.has_signal("phase1_died"):
			if neuro_boss_node.is_connected("phase1_died", Callable(self, "_on_phase1_died")):
				neuro_boss_node.disconnect("phase1_died", Callable(self, "_on_phase1_died"))
			neuro_boss_node.phase1_died.connect(_on_phase1_died)
			print("Level 5: Connected to NeuroBoss Phase 1 death signal")
		else:
			printerr("Level 5 Error: NeuroBoss node does not have the 'phase1_died' signal!")
			
		# For monkey_controlled signal - only connect if it exists
		if neuro_boss_node.has_signal("monkey_controlled"):
			if neuro_boss_node.is_connected("monkey_controlled", Callable(self, "_on_monkey_controlled")):
				neuro_boss_node.disconnect("monkey_controlled", Callable(self, "_on_monkey_controlled"))
			neuro_boss_node.monkey_controlled.connect(_on_monkey_controlled)
		else:
			printerr("Level 5 Error: NeuroBoss node does not have the 'monkey_controlled' signal!")
		
		# For monkey_released signal - only connect if it exists
		if neuro_boss_node.has_signal("monkey_released"):
			if neuro_boss_node.is_connected("monkey_released", Callable(self, "_on_monkey_released")):
				neuro_boss_node.disconnect("monkey_released", Callable(self, "_on_monkey_released"))
			neuro_boss_node.monkey_released.connect(_on_monkey_released)
		else:
			printerr("Level 5 Error: NeuroBoss node does not have the 'monkey_released' signal!")

func _on_phase1_died(phase2_instance):
	print("Level 5: NeuroBoss Phase 1 died, transitioning to Phase 2")
	
	# Update our reference to point to Phase 2 now
	neuro_boss_node = phase2_instance
	
	# Reconnect signals for Phase 2
	if is_instance_valid(neuro_boss_node):
		# Clean up any existing connections first to prevent duplicates
		if neuro_boss_node.is_connected("monkey_controlled", Callable(self, "_on_monkey_controlled")):
			neuro_boss_node.disconnect("monkey_controlled", Callable(self, "_on_monkey_controlled"))

		if neuro_boss_node.is_connected("monkey_released", Callable(self, "_on_monkey_released")):
			neuro_boss_node.disconnect("monkey_released", Callable(self, "_on_monkey_released"))
			
		# Connect to Phase 2 death signal
		if neuro_boss_node.has_signal("boss_died"):
			if neuro_boss_node.is_connected("boss_died", Callable(self, "_on_boss_died")):
				neuro_boss_node.disconnect("boss_died", Callable(self, "_on_boss_died"))
			
			neuro_boss_node.boss_died.connect(_on_boss_died)
			print("Level 5: Connected to NeuroBoss Phase 2 death signal")
		else:
			printerr("Level 5: NeuroBoss Phase 2 doesn't have boss_died signal!")

		# Check if boss has the expected signals before connecting
		if neuro_boss_node.has_signal("monkey_controlled"):
			neuro_boss_node.monkey_controlled.connect(_on_monkey_controlled)
			print("Level 5: Connected monkey_controlled signal to Phase 2")

		if neuro_boss_node.has_signal("monkey_released"):
			neuro_boss_node.monkey_released.connect(_on_monkey_released)
			print("Level 5: Connected monkey_released signal to Phase 2")
	else:
		printerr("Level 5: Phase 2 instance is not valid!")
		
# Handle monkey being controlled
func _on_monkey_controlled(monkey: Node2D): # Add type hint for monkey
	print("--- Level 5 _on_monkey_controlled Triggered ---")

	# --- DETAILED PLAYER NODE DEBUGGING ---
	print("  Current player_node reference: ", player_node)
	print("  Is player_node instance valid? ", is_instance_valid(player_node))

	if not is_instance_valid(player_node):
		printerr("  ERROR: player_node is NOT valid at time of signal!")
		return

	# Check type and script *right now*
	print("  player_node.get_class(): ", player_node.get_class())
	print("  player_node.get_script(): ", player_node.get_script())
	print("  player_node is Player? ", player_node is Player) # Check type again
	print("  player_node.has_method('remove_monkey'): ", player_node.has_method("remove_monkey"))
	# --- END DETAILED DEBUGGING ---

	# Now, attempt the call
	if player_node.has_method("remove_monkey") and is_instance_valid(monkey):
		print("  Attempting to call player_node.remove_monkey...")
		player_node.remove_monkey(monkey)
		print("  Call to remove_monkey completed.")
	else:
		# If has_method check fails, print details
		printerr("  ERROR: has_method('remove_monkey') returned false or monkey is invalid!")
		printerr("    Node Class: ", player_node.get_class() if is_instance_valid(player_node) else "INVALID")
		printerr("    Node Script: ", player_node.get_script() if is_instance_valid(player_node) else "INVALID")


# Handle monkey being released
func _on_monkey_released(monkey: Node2D): # Add type hint for monkey
	print("--- Level 5 _on_monkey_released Triggered ---")

	# Skip if monkey is not valid anymore
	if not is_instance_valid(monkey):
		print("  Monkey is no longer valid, can't add it back")
		return

	# Make sure health bar is visible again if it exists
	if "health_bar" in monkey and is_instance_valid(monkey.health_bar):
		monkey.health_bar.show()

	# Ensure any collision is properly enabled
	if monkey is CollisionObject2D:
		monkey.collision_layer = 4 # Layer 3 - Assuming this is the troop layer
		monkey.collision_mask = 1  # Layer 1 - Assuming this is the world layer

	# Enable collision shapes
	for child in monkey.get_children():
		if not is_instance_valid(child):
			continue

		if child is CollisionShape2D:
			child.disabled = false
		elif child is Area2D:
			child.monitoring = true
			child.monitorable = true

			for grandchild in child.get_children():
				if not is_instance_valid(grandchild):
					continue

				if grandchild is CollisionShape2D:
					grandchild.disabled = false

	# Make sure the monkey is not marked as caged
	if "is_caged" in monkey:
		monkey.is_caged = false

	# Remove from enemies group
	if monkey.is_in_group("enemies"):
		monkey.remove_from_group("enemies")

	# Add to troop group if not already there
	if not monkey.is_in_group("troop"):
		monkey.add_to_group("troop")

	# Wait a bit for the monkey to walk back before rejoining
	await get_tree().create_timer(2.0).timeout

	# Check if monkey and the stored player reference are still valid *after* the wait
	if not is_instance_valid(monkey):
		print("  Monkey became invalid before rejoining.")
		return

	print("  Checking player_node AFTER wait: ", player_node)
	print("  Is player_node valid AFTER wait? ", is_instance_valid(player_node))

	if not is_instance_valid(player_node):
		printerr("  ERROR: Player node became invalid AFTER wait for monkey rejoin!")
		return

	# Check type and script *right now* after wait
	print("  player_node.get_class() AFTER wait: ", player_node.get_class())
	print("  player_node.get_script() AFTER wait: ", player_node.get_script())
	print("  player_node is Player AFTER wait? ", player_node is Player) # Check type again
	print("  player_node.has_method('add_monkey_to_swarm') AFTER wait: ", player_node.has_method("add_monkey_to_swarm"))

	# Call the method on the stored player reference
	if player_node.has_method("add_monkey_to_swarm"):
		print("  Attempting to call player_node.add_monkey_to_swarm...")
		player_node.add_monkey_to_swarm(monkey)
		print("  Call to add_monkey_to_swarm completed.")
	else:
		printerr("  ERROR: has_method('add_monkey_to_swarm') returned false AFTER wait!")
		printerr("    Node Path: ", player_node.get_path())
		printerr("    Node Class: ", player_node.get_class())
		printerr("    Node Script: ", player_node.get_script())

func set_troop_data(data: Dictionary) -> void:
	_troop_data = data

## Initialize the player and troop from the troop data.
func initialize_from_troop_data() -> void:
	var player = $World/Player
	if player and not _troop_data.is_empty():
		player.health = _troop_data["player_health"]
		# Recreate troop
		var current_count = player.get_troop_count()
		var target_count = _troop_data["count"]
		var monkey_health = _troop_data.get("monkey_health", [])

		# Remove excess monkeys if any
		while current_count > target_count:
			if player._swarm_monkeys.size() > 0:
				var monkey = player._swarm_monkeys.pop_back()["node"]
				monkey.queue_free()
			current_count -= 1

		# Add missing monkeys
		while current_count < target_count:
			player.add_monkey_to_swarm()
			current_count += 1

		# Restore monkey health if tracked
		if not monkey_health.is_empty():
			for i in range(min(player._swarm_monkeys.size(), monkey_health.size())):
				var monkey = player._swarm_monkeys[i]["node"]
				if "current_health" in monkey and "health_bar" in monkey:
					monkey.current_health = monkey_health[i]

					# Ensure the health bar is properly initialized and visible
					if monkey.health_bar:
						monkey.health_bar.value = monkey.current_health
						monkey.health_bar.health = monkey.current_health
						monkey.health_bar.show()  # Always show health bar, regardless of health value

					print_debug("Restored monkey #", i, " health to: ", monkey.current_health)


func _on_pre_boss_dialogue_trigger_body_entered(body: Node2D) -> void:
	if dialogue_cutscene_played:
		return

	if body.is_in_group("player"):
		
		dialogue_cutscene_played = true
		var dialogue_cutscene_instance = dialogue_cutscene.instantiate()
		
		get_tree().root.add_child(dialogue_cutscene_instance)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = dialogue_cutscene_instance
		
func _on_boss_died():
	print("Level 5: NeuroBoss Phase 2 has died, transitioning to cutscene in 1 second")
	
	# Wait 1 second before transitioning
	await get_tree().create_timer(2.0).timeout
	
	# Load and instantiate the post-boss cutscene
	var cutscene_instance = post_boss_cutscene.instantiate()
	
	# Add to root and set as current scene
	get_tree().root.add_child(cutscene_instance)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = cutscene_instance
