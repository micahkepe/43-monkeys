# In res://projectiles/projectiles_script.gd
extends Area2D

@export var speed: float = 800.0
@export var damage: float = 1.0
@export var lifetime: float = 3.0
@export var animation_name: String = ""
@export var use_shadow: bool = false

var velocity: Vector2 = Vector2.ZERO
var exploded: bool = false  # New flag

func _ready() -> void:
	#print("projectile at:", global_position)
	$AnimatedSprite2D.play("idle")
	
	# Start the lifetime timer
	await get_tree().create_timer(lifetime).timeout

func _physics_process(delta: float) -> void:
	if not exploded:  # Only move if not exploded
		global_position += velocity * delta
		if velocity.length() > 0:
			rotation = velocity.angle()
	if use_shadow and has_node("ShadowContainer"):
		$ShadowContainer.global_position = global_position

# Collision handling remains unchanged.
func _on_body_entered(body: Node) -> void:
	#print("====== BODY ENTERED")
	if body.name in ["BackgroundTiles", "ForegroundTiles", "Boundaries"]:
		print("In body entered, collided with", body.name)
		explode_and_free()
	elif body.is_in_group("enemies") or body.is_in_group("boids"):
		#print("===== BODY IS ENEMY OR BOID === ")
		if body.has_method("take_damage"):
			body.take_damage(damage)
		explode_and_free()
	else:
		explode_and_free()

func _on_area_entered(area: Area2D) -> void:
	#print("=== AREA ENTERED NEW")
	var enemy = area.get_parent()
	if enemy.is_in_group("enemies") or enemy.is_in_group("boids"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		explode_and_free()
	else:
		#print("In area entered, collided with", area.name)
		explode_and_free()

func explode_and_free() -> void:
	#print("==EXPLODE AND FREE")
	if exploded:
		return
	exploded = true
	velocity = Vector2.ZERO
	$AnimatedSprite2D.play("explode")

func _on_AnimatedSprite2D_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "explode":
		queue_free()
