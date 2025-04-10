extends "res://entities/Boids/boid.gd"

@export var projectile_scene: PackedScene
@export var bullet_speed: float

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_timer -= delta
	var target = _get_closest_target()
	var steering = Vector2.ZERO

	# Update the slow effect timer
	if is_slowed:
		slow_timer -= delta
		if slow_timer <= 0:
			is_slowed = false
			_anim_sprite.modulate = Color(1, 1, 1, 1)

	# Movement behavior: if target, move directly toward it.
	if target:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * max_speed
	else:
		# Flocking behavior if no target is detected.
		var neighbors = _get_neighbors()
		steering += _compute_separation(neighbors) * weight_separation
		steering += _compute_alignment(neighbors) * weight_alignment
		steering += _compute_cohesion(neighbors) * weight_cohesion

	# Add wall avoidance force.
	steering += _compute_wall_avoidance() * weight_avoidance

	# Limit the steering force.
	if steering.length() > max_force:
		steering = steering.normalized() * max_force

	velocity += steering * delta

	# Ensure the boid maintains a minimum speed.
	if velocity.length() < minimum_speed:
		velocity = velocity.normalized() * minimum_speed
	elif velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	# Apply slow effect if active.
	if is_slowed:
		velocity = velocity.normalized() * (max_speed * 0.65)

	move_and_slide()

	# --- Projectile Attack Logic ---
	# Instead of dealing melee damage, throw projectile
	if not is_dead and attack_timer <= 0:
		if target:
			_play_attack_animation(target)
			_throw_projectile_at_position(target.global_position)
	_update_animation()


func _throw_projectile_at_position(target_position: Vector2) -> void:
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	if projectile == null:
		return

	# Calculate the shooting direction.
	var shoot_direction = (target_position - global_position).normalized()
	var offset_distance = 30.0
	var spawn_offset = shoot_direction * offset_distance
	var spawn_global_position = global_position + spawn_offset
	print_debug("PROJECTILE SPAWN (global):", spawn_global_position)
	print_debug("BOID POS (global):", global_position)

	# Calculate the projectile velocity.
	# Here we use a bullet_speed of 550.0 as in the banana function.
	var main_velocity = shoot_direction * bullet_speed

	# Add a portion of the boid's current perpendicular velocity.
	var parallel_velocity = velocity.dot(shoot_direction) * shoot_direction
	var perpendicular_velocity = velocity - parallel_velocity
	var orth_factor = 0.75
	var final_velocity = main_velocity + (perpendicular_velocity * orth_factor)

	projectile.velocity = final_velocity
	projectile.scale = Vector2(1.5, 1.5)

	# Attempt to add the projectile to a "Projectiles" node if it exists.
	var current_scene = get_tree().current_scene
	var projectiles_node = current_scene.get_node("Projectiles") if current_scene.has_node("Projectiles") else null
	if projectiles_node:
		var local_spawn_pos = projectiles_node.to_local(spawn_global_position)
		projectile.position = local_spawn_pos
		projectiles_node.call_deferred("add_child", projectile)
		print_debug("Projectile added to the Projectiles node at:", local_spawn_pos)
	else:
		print_debug("Projectiles node not found. Projectile not spawned.")

	# Reset the attack cooldown.
	attack_timer = attack_cooldown
	print_debug("Projectile thrown at position:", target_position)


func _play_attack_animation(target: Node2D) -> void:
	# Use the sprite_frames property to check for the "throw" animation.
	if _anim_sprite.sprite_frames.has_animation("throw"):
		_anim_sprite.play("throw")
	else:
		# Optionally, choose a directional throw animation.
		var direction = (target.global_position - global_position).normalized()
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0 and _anim_sprite.sprite_frames.has_animation("throw_right"):
				_anim_sprite.play("throw_right")
			elif direction.x <= 0 and _anim_sprite.sprite_frames.has_animation("throw_left"):
				_anim_sprite.play("throw_left")
			else:
				_anim_sprite.play("throw")
		else:
			if direction.y > 0 and _anim_sprite.sprite_frames.has_animation("throw_down"):
				_anim_sprite.play("throw_down")
			elif direction.y <= 0 and _anim_sprite.sprite_frames.has_animation("throw_up"):
				_anim_sprite.play("throw_up")
			else:
				_anim_sprite.play("throw")

	is_attacking = true
