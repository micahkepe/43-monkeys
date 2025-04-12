extends "res://projectiles/projectiles_script.gd"

func _ready() -> void:
	animation_name = "laser_default"

	# Call the parent _ready() to run the default projectile logic.
	super._ready()

	scale = Vector2(4.0, 4.0)


# Collision handling remains unchanged.
func _on_body_entered(body: Node) -> void:
	#print("====== BODY ENTERED")
	if body.name in ["BackgroundTiles", "ForegroundTiles", "Boundaries"]:
		print("In body entered, collided with", body.name)
		explode_and_free()
	elif body.is_in_group("player") or body.is_in_group("troop"):
		#print("===== BODY IS ENEMY OR BOID === ")
		if body.has_method("take_damage"):
			body.take_damage(damage)
		explode_and_free()
	else:
		explode_and_free()

func _on_area_entered(area: Area2D) -> void:
	print("=== AREA ENTERED NEW: ", area.get_parent().name)
	var enemy = area.get_parent()
	if enemy.is_in_group("player") or enemy.is_in_group("troop"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		explode_and_free()
	else:
		#print("In area entered, collided with", area.name)
		explode_and_free()
		
func explode_and_free() -> void:
	print("+====== NEURO LASER FREE")
	queue_free()
