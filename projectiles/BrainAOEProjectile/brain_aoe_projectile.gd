extends "res://projectiles/projectiles_script.gd"

func _ready() -> void:
	randomize()  # Ensures randomness on each run.
	damage = 1.0

	animation_name = "idle"
	use_shadow = true

	# Call the parent _ready() to run the default projectile logic.
	super._ready()
	scale = Vector2(0.5, 0.5)

# When the orb collides with a body, check if it's a valid target.
func _on_body_entered(body: Node) -> void:
	print("====== BODY ENTERED")
	if body.name in ["BackgroundTiles", "ForegroundTiles", "Boundaries"]:
		print("In body entered, collided with", body.name)
		explode_and_free()
	elif body.is_in_group("player") or body.is_in_group("troop"):
		print("===== BODY IS PLAYER OR TROOP === ")
		# Immediately apply damage to the target.
		if body.has_method("take_damage"):
			body.take_damage(damage)

		explode_and_free()
	else:
		explode_and_free()

func _on_area_entered(area: Area2D) -> void:
	print("=== AREA ENTERED NEW: ", area.get_parent().name)
	var enemy = area.get_parent()
	if enemy.is_in_group("player") or enemy.is_in_group("troop"):
		print("=== IN HERE!!!!")
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

		explode_and_free()
	else:
		print("In area entered, collided with", area.name)
		explode_and_free()

# Async function that applies random scaling/rotation, deals explosion AOE damage,
# plays the explosion animation, and frees the projectile.
func explode_and_free() -> void:
	print("EXPLODE CALL")
	# Stop movement.
	velocity = Vector2(0, 0)

	# Randomly scale the projectile along the x and y axes and randomly rotate it.
	var x_scale = randf_range(0.5, 1.75)
	var y_scale = randf_range(0.5, 1.75)

	scale.x = scale.x * x_scale
	scale.y = scale.y * y_scale

	rotation_degrees = randf_range(0, 360)

	var bodies = $AOE.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage"):
			body.take_damage(damage)

	# Visual explosion effects.
	var light_node = get_node("PointLight2D")
	light_node.scale = Vector2(10.0, 10.0)
	$AnimatedSprite2D.play("explode")
	await $AnimatedSprite2D.animation_finished
	queue_free()
