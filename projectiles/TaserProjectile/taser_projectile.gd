extends Area2D
## A taser projectile that damages entities on contact if the body implements
## the `take_damage` method or is within specific groups. The projectile moves
## in a straight line and destroys itself after a set lifetime.

## Speed of the taser projectile
@export var speed: float = 175.0

## Damage dealt by the taser on contact
@export var damage: int = 1

## Lifetime of the taser projectile in seconds
@export var lifetime: float = 8.0

## Velocity of the taser projectile
var velocity: Vector2 = Vector2.ZERO

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Play an animation if available
	if $AnimationPlayer.has_animation("taser_spin"):
		$AnimationPlayer.play("taser_spin")

	# Only connect if not already connected
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

	# Schedule projectile destruction after its lifetime expires
	await get_tree().create_timer(lifetime).timeout
	queue_free()

## Called every frame. Handles movement and rotation.
func _physics_process(delta: float) -> void:
	# Move the taser based on its velocity
	global_position += velocity * delta

	# Adjust rotation to align with the direction of motion
	if velocity.length() > 0:
		rotation = velocity.angle()

## Called when the taser collides with another body.
func _on_body_entered(body: Node) -> void:
	# Check if the body has a `take_damage` method and is an enemy
	if body.has_method("take_damage") and not body.is_in_group("enemies"):
		body.take_damage(0.5)  # Deal 0.5 damage
		queue_free()  # Remove the taser projectile
	else:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Check if root node of the area is an enemy
	if area.get_parent().is_in_group("player") or area.get_parent().is_in_group("troop"):
		if area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)
		queue_free()
	else:
		queue_free()
