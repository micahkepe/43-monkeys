extends "res://projectiles/projectiles_script.gd"

func _ready() -> void:
	animation_name = "snowball_throw"
	use_shadow = true
	
	print("snowball at:", global_position)
	# Call the parent _ready() to run the default projectile logic.
	super._ready()
	
	scale = Vector2(2.5, 2.5)

# When the orb collides with a body, check if it's an enemy.
func _on_body_entered(body: Node) -> void:
	print("====== BODY ENTERED")
	if body.name in ["BackgroundTiles", "ForegroundTiles", "Boundaries"]:
		print("In body entered, collided with", body.name)
		explode_and_free()
	elif body.is_in_group("enemies") or body.is_in_group("boids"):
		print("===== BODY IS ENEMY OR BOID === ")
		# Immediately apply damage to the enemy hit.
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("slow_down"):
			body.slow_down()
		
		explode_and_free()
	else:
		explode_and_free()

func _on_area_entered(area: Area2D) -> void:
	print("=== AREA ENTERED NEW")
	var enemy = area.get_parent()
	if enemy.is_in_group("enemies") or enemy.is_in_group("boids"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		if enemy.has_method("slow_down"):
			enemy.slow_down()
		
		explode_and_free()
	else:
		print("In area entered, collided with", area.name)
		explode_and_free()

# Async function that plays the explode animation and waits for it to finish.
func explode_and_free() -> void:
	velocity = Vector2(0,0)
	$AnimatedSprite2D.play("snowball_explode")
	await $AnimatedSprite2D.animation_finished
	queue_free()
