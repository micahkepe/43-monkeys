extends Area2D
## A banana projectile that damages bodies on contact if the body implements
## the `take_damage` method.
##
## The projectile moves in the direction it was spawned in and deals damage
## to the player on contact. The projectile is destroyed after dealing damage or
## after a set lifetime.

## Speed of the projectile
@export var speed: float = 800.0

## Damage dealt to the player on contact
@export var damage: float = 1.0

## The lifetime of the projectile in seconds
@export var lifetime: float = 3.0

## The projectile's velocity
var velocity: Vector2 = Vector2.ZERO

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("banana at:", global_position)
	if $AnimationPlayer.has_animation("banana_spin"):
		$AnimationPlayer.play("banana_spin")

	await get_tree().create_timer(lifetime).timeout
	queue_free()


## Called every frame. 'delta' is the elapsed time since the previous frame.
## @param delta: The time in seconds it took to complete the last frame.
func _physics_process(delta: float) -> void:
	# Move the projectile based on its velocity
	global_position += velocity * delta

	if velocity.length() > 0:
		rotation = velocity.angle()

	# Ensure the shadow container does not rotate
	$ShadowContainer.global_position = global_position


## Called when the projectile collides with a body.
## If the body is in the "enemies" group, the body will take damage.
## If the body is in the "BackgroundTiles" or "ForegroundTiles" group, the
## projectile will be destroyed.
## @param body: The body that the projectile collided with.
func _on_body_entered(body: Node) -> void:
	if body.name == "BackgroundTiles" or body.name == "ForegroundTiles":
		queue_free()
	elif body.is_in_group("enemies") or body.is_in_group("boids"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()


## Handle entering the hit box areas of collidable objects.
## If the object is an enemy, deal damage
## @param area: The area that the projectile collided with.
func _on_area_entered(area:Area2D) -> void:
	# check if root node of the area is an enemy
	if area.get_parent().is_in_group("enemies") or area.get_parent().is_in_group("boids"):
		if area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)
		queue_free()
	else:
		queue_free()
