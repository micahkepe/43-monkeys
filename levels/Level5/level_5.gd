extends "res://levels/default_level.gd"

# Store references obtained in _ready
var player_node: Player # Type hint helps with autocompletion and type safety
var neuro_boss_node: Node # Or specific type if you know it (e.g., CharacterBody2D)

# Called when the node enters the scene tree for the first time.
func _ready():
	# Use await to ensure nodes are ready before getting references (Good practice)
	await ready

	# Get references using get_node_or_null for safety
	var potential_player = $World.get_node_or_null("Player")
	neuro_boss_node = $World.get_node_or_null("NeuroBoss")

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
