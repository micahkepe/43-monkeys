extends Area2D

# Speed of the projectile.
@export var speed: float = 800.0

# Damage dealt on contact.
@export var damage: float = 1.0

# Lifetime in seconds.
@export var lifetime: float = 3.0

# Name of the animation to play (if any).
@export var animation_name: String = ""

# Toggle if the projectile has a ShadowContainer node.
@export var use_shadow: bool = false

# The projectile's velocity.
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("projectile at:", global_position)
	# If an animation name is provided and AnimatedSprite2D has the animation, play it.
	if animation_name != "" and $AnimatedSprite2D.sprite_frames.has_animation(animation_name):
		$AnimatedSprite2D.play(animation_name)

	# Wait for the lifetime duration before freeing the projectile.
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# Move the projectile.
	global_position += velocity * delta

	# Rotate the projectile to face its velocity.
	if velocity.length() > 0:
		rotation = velocity.angle()

	# Update the position of the shadow container if it exists and is enabled.
	if use_shadow and has_node("ShadowContainer"):
		$ShadowContainer.global_position = global_position

func _on_body_entered(body: Node) -> void:
	print("== BODY ENTER OG")
	# If colliding with specific environment nodes, remove the projectile.
	if body.name in ["BackgroundTiles", "ForegroundTiles", "Boundaries"]:
		print("In body entered, collided with", body.name)
		queue_free()
	# If colliding with an enemy or boid, deal damage.
	elif body.is_in_group("enemies") or body.is_in_group("boids"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	print("===AREA ENTERED OG")
	# If the area belongs to an enemy or boid, deal damage.
	if area.get_parent().is_in_group("enemies") or area.get_parent().is_in_group("boids"):
		if area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)
		queue_free()
	else:
		print("In area entered, collided with", area.name)
		queue_free()
