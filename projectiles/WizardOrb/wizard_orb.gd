extends "res://projectiles/projectiles_script.gd"

## Maximum distance to chain between enemies
@export var chain_range: float = 225.0

## Recursively searches for a node with a given name.
func find_node_recursive(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var result = find_node_recursive(child, target)
		if result:
			return result
	return null

func _ready() -> void:
	animation_name = "orb_pulse"
	use_shadow = true

	print("wizard orb at:", global_position)

	# Call the parent _ready() to run the default projectile logic.
	super._ready()

	scale = Vector2(3.5, 3.5)

# When the orb collides with a body, check if it's an enemy.
func _on_body_entered(body: Node) -> void:
	print("====== BODY ENTERED")
	if body.name in ["BackgroundTiles", "ForegroundTiles", "Boundaries"]:
		print("In body entered, collided with", body.name)
		queue_free()
	elif body.is_in_group("enemies") or body.is_in_group("boids"):
		print("===== BODY IS ENEMY OR BOID === ")
		# Immediately apply damage to the enemy hit
		if body.has_method("take_damage"):
			body.take_damage(damage)

		# Start the chaining process from this enemy
		chain_enemies(body)

		queue_free()
	else:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	print("=== AREA ENTERED NEW")
	var enemy = area.get_parent()
	if enemy.is_in_group("enemies") or enemy.is_in_group("boids"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

		chain_enemies(enemy)

		queue_free()
	else:
		print("In area entered, collided with", area.name)
		queue_free()

# Performs a BFS starting at initial_enemy to find nearby enemies and spawns a wizard_laser for each connection.
func chain_enemies(initial_enemy: Node) -> void:
	var visited = {}  # Dictionary to track visited enemies.
	var queue = []    # BFS queue.
	visited[initial_enemy] = true
	queue.push_back(initial_enemy)

	# Cache all enemies once (to avoid repeated group lookups).
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	while queue.size() > 0:
		var current = queue.pop_front()
		for enemy in all_enemies:
			if enemy == current:
				continue
			if visited.has(enemy):
				continue
			# Check if enemy is within chain_range of the current enemy
			if current.global_position.distance_to(enemy.global_position) <= chain_range:
				visited[enemy] = true
				queue.push_back(enemy)
				# Spawn a wizard_laser segment connecting current and enemy
				var wizard_laser_scene: PackedScene = preload("res://projectiles/WizardLaser/WizardLaser.tscn")
				var laser_instance = wizard_laser_scene.instantiate()
				laser_instance.start_enemy = current
				laser_instance.target_enemy = enemy
				laser_instance.duration = 3.0
				var projectiles_node = find_node_recursive(get_tree().root, "Projectiles")
				if projectiles_node:
                	# Use call_deferred to safely add the laser after physics
					# processing is complete
					projectiles_node.call_deferred("add_child", laser_instance)
				else:
					push_error("Projectiles node not found!")
