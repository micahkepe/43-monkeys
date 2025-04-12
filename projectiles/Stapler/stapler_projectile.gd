extends "res://projectiles/projectiles_script.gd"

func _ready() -> void:
	# Override default values for the banana projectile.
	animation_name = "spin"
	use_shadow = true

	# Call the parent _ready() to run the default projectile logic.
	super._ready()

# When the banana collides with a body, check if it's an enemy.
func _on_body_entered(body: Node) -> void:
	# World elements
	if body.name in ["BackgroundTiles", "ForegroundTiles"]:
		explode_and_free()
	elif body.is_in_group("enemies") or body.is_in_group("boids"):
		# Immediately apply damage to the enemy hit.
		if body.has_method("take_damage"):
			body.take_damage(damage)
		explode_and_free()
	else:
		# Fallback case
		explode_and_free()

func _on_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if enemy.is_in_group("enemies") or enemy.is_in_group("boids"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		explode_and_free()
	else:
		print("In area entered, collided with", area.name)
		explode_and_free()

# Async function that plays the explode animation and waits for it to finish.
func explode_and_free() -> void:
	velocity = Vector2(0,0)
	$AnimatedSprite2D.play("explode")
	await $AnimatedSprite2D.animation_finished
	queue_free()
