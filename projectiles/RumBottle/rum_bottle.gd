extends "res://projectiles/projectiles_script.gd"

var is_pool: bool = false

func _ready() -> void:
	# Override default values for the banana projectile.
	animation_name = "spin"
	use_shadow = true

	# Call the parent _ready() to run the default projectile logic.
	scale = Vector2(2.5,2.5)
	super._ready()

# When the banana collides with a body, check if it's an enemy.
func _on_body_entered(body: Node) -> void:
	# World elements
	if body.name in ["BackgroundTiles", "ForegroundTiles"]:
		if not is_pool:
			explode_and_free()
	elif body.is_in_group("enemies") or body.is_in_group("boids"):
		# Immediately apply damage to the enemy hit.
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if not is_pool:
			explode_and_free()
	else:
		# Fallback case
		if not is_pool:
			explode_and_free()

func _on_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if enemy.is_in_group("enemies") or enemy.is_in_group("boids"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		if not is_pool:
			explode_and_free()
	else:
		if not is_pool:
			explode_and_free()

# Play explode, then pool_idle; randomize scale; wait 4s; free.
func explode_and_free() -> void:
	is_pool = true
	velocity = Vector2.ZERO
	$ShadowContainer.visible = false
	$AnimatedSprite2D.play("explode")
	await $AnimatedSprite2D.animation_finished
	z_index = -1
	# Switch to pool_idle
	$AnimatedSprite2D.play("pool_idle")

	# Randomize scale.x and scale.y between 1.0 and 3.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	scale = Vector2(rng.randf_range(2.5, 5.0), rng.randf_range(2.5, 5.0))

	# Deal damage once per second for 4 seconds
	var elapsed := 0.0
	var interval := 1.0
	while elapsed < 4.0:
		for body in get_overlapping_bodies():
			if (body.is_in_group("enemies") or body.is_in_group("boids")) and body.has_method("take_damage"):
				body.take_damage(damage)
		await get_tree().create_timer(interval).timeout
		elapsed += interval

	queue_free()
