extends CharacterBody2D

@export var electro_laser_scene: PackedScene
@export var taser_projectile_scene: PackedScene  # Scene for the taser projectile

func _ready() -> void:
	attack_horizontal_wall()
	
# Helper function to find the player based on your node structure
func get_player() -> Node2D:
	var player = get_parent().get_node("ForegroundTiles/Player")
	if player:
		return player
	else:
		print("Player not found!")
		return null
	
	
# --------------------------------------------------
# Attack 1: Single Projectile Towards Player
# --------------------------------------------------
func attack_shoot_at_player():
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	var player = get_player()
	if not player:
		print("Player not found!")
		return

	# Spawn the taser projectile
	var projectile = taser_projectile_scene.instantiate()
	add_child(projectile)

	# Calculate direction to the player and set projectile velocity
	projectile.scale = Vector2(2.25,2.25)
	var direction = (player.global_position - global_position).normalized()
	projectile.global_position = global_position
	projectile.velocity = direction * projectile.speed
	
func attack_burst_shoot_at_player(burst_count: int = 3, delay: float = 0.1) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	var player = get_player()
	if not player:
		print("Player not found!")
		return

	# Fire `burst_count` projectiles with a delay
	for i in range(burst_count):
		await get_tree().create_timer(delay).timeout

		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		add_child(projectile)

		# Calculate direction to the player and set projectile velocity
		projectile.scale = Vector2(2.25,2.25)
		var direction = (player.global_position - global_position).normalized()
		projectile.global_position = global_position
		projectile.velocity = direction * projectile.speed
		

func attack_spread_shoot_at_player(spread_count: int = 5, angle_range: float = PI / 2) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	var player = get_player()
	if not player:
		print("Player not found!")
		return

	# Calculate the base direction to the player
	var base_direction = (player.global_position - global_position).normalized()
	var base_angle = base_direction.angle()

	# Fire `spread_count` projectiles across the angle range
	for i in range(spread_count):
		# Calculate the angle for this projectile
		var angle_offset = lerp(-angle_range / 2, angle_range / 2, float(i) / (spread_count - 1))
		var projectile_angle = base_angle + angle_offset

		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		add_child(projectile)

		# Set its position and velocity
		projectile.scale = Vector2(2.25, 2.25)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(projectile_angle) * projectile.speed
		
func attack_circular_shoot(num_projectiles: int = 8) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	# Fire `num_projectiles` in a circular pattern
	for i in range(num_projectiles):
		# Calculate the angle for this projectile
		var angle = TAU * float(i) / num_projectiles

		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		add_child(projectile)

		# Set its position and velocity
		projectile.scale = Vector2(2.25,2.25)
		projectile.global_position = global_position
		projectile.velocity = Vector2.RIGHT.rotated(angle) * projectile.speed
		
var spiral_angle: float = 0.0  # Keeps track of the current angle

func attack_spiral_shoot(num_projectiles: int = 16, spiral_speed: float = 0.25) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	# Fire projectiles in a rotating spiral
	for i in range(num_projectiles):
		await get_tree().create_timer(spiral_speed).timeout

		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		add_child(projectile)

		# Calculate the angle for this projectile
		spiral_angle += TAU / num_projectiles  # Increment the spiral angle
		var direction = Vector2.RIGHT.rotated(spiral_angle)

		# Set the projectile's position and velocity
		projectile.scale = Vector2(2.25,2.25)
		projectile.global_position = global_position
		projectile.velocity = direction * projectile.speed
		
		
	

func attack_horizontal_wall(num_projectiles: int = 10, spacing: float = 200.0) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	var player = get_player()
	if not player:
		print("Player not found!")
		return

	# Determine starting y position (farthest from the player)
	var start_y: float
	var direction: Vector2

	if abs(-1158 - player.global_position.y) > abs(-404 - player.global_position.y):
		start_y = -1158  # Farthest top
		direction = Vector2(0, 1)  # Move downward
	else:
		start_y = -404  # Farthest bottom
		direction = Vector2(0, -1)  # Move upward

	# Calculate the horizontal center (midpoint) of the range
	var horizontal_center_x = (133 + 1238) / 2.0

	# Calculate the starting position of the wall
	var start_position = Vector2(horizontal_center_x - (num_projectiles - 1) * spacing / 2, start_y)

	# Spawn projectiles in a horizontal line
	for i in range(num_projectiles):
		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		add_child(projectile)

		# Set the projectile's position and velocity
		projectile.lifetime = 10.0
		projectile.scale = Vector2(2, 2)
		projectile.global_position = start_position + Vector2(i * spacing, 0)
		projectile.velocity = direction * projectile.speed
		
		
func attack_vertical_wall(num_projectiles: int = 10, spacing: float = 200.0) -> void:
	if not taser_projectile_scene:
		print("Taser Projectile scene not set!")
		return

	var player = get_player()
	if not player:
		print("Player not found!")
		return

	# Determine starting x position (farthest from the player)
	var start_x: float
	var direction: Vector2

	if abs(133 - player.global_position.x) > abs(1238 - player.global_position.x):
		start_x = 133  # Farthest left
		direction = Vector2(1, 0)  # Move right
	else:
		start_x = 1238  # Farthest right
		direction = Vector2(-1, 0)  # Move left

	# Calculate the vertical center (midpoint) of the range
	var vertical_center_y = (-1158 + -404) / 2.0

	# Calculate the starting position of the wall
	var start_position = Vector2(start_x, vertical_center_y - (num_projectiles - 1) * spacing / 2)

	# Spawn projectiles in a vertical line
	for i in range(num_projectiles):
		# Spawn the taser projectile
		var projectile = taser_projectile_scene.instantiate()
		add_child(projectile)

		# Set the projectile's position and velocity
		projectile.lifetime = 10.0
		projectile.scale = Vector2(2,2)
		projectile.global_position = start_position + Vector2(0, i * spacing)
		projectile.velocity = direction * projectile.speed
	
func spawn_electro_lasers():
	if not electro_laser_scene:
		print("Electro Laser scene not set!")
		return

	# Spawn vertical laser
	print("Spawning vertical laser")
	var vertical_laser = electro_laser_scene.instantiate()
	add_child(vertical_laser)  # Add as child of the boss

	# Set the correct global position for the vertical laser
	var random_x = randf_range(133, 1238)
	vertical_laser.global_position = Vector2(random_x, -783)  # Exact global position
	vertical_laser.scale = Vector2(3, 28.6)  # Proper scale
	print("Vertical laser global position: ", vertical_laser.global_position, " scale: ", vertical_laser.scale)

	# Spawn horizontal laser
	print("Spawning horizontal laser")
	var horizontal_laser = electro_laser_scene.instantiate()
	add_child(horizontal_laser)  # Add as child of the boss

	# Set the correct global position for the horizontal laser
	var random_y = randf_range(-1158, -404)
	horizontal_laser.global_position = Vector2(686, random_y)  # Exact global position
	horizontal_laser.scale = Vector2(3, 41.2)  # Proper scale
	horizontal_laser.rotation = deg_to_rad(90)  # Rotate horizontal laser
	print("Horizontal laser global position: ", horizontal_laser.global_position, " scale: ", horizontal_laser.scale)
