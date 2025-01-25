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
@export var damage: int = 10

## The lifetime of the projectile in seconds
@export var lifetime: float = 3.0

## The projectile's velocity
var velocity: Vector2 = Vector2.ZERO


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("banana at:", global_position)
	if $AnimationPlayer.has_animation("banana_spin"):
		$AnimationPlayer.play("banana_spin")
	self.connect("body_entered", Callable(self, "_on_body_entered"))

	await get_tree().create_timer(lifetime).timeout
	queue_free()


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Move the projectile based on its velocity
	global_position += velocity * delta

	if velocity.length() > 0:
		rotation = velocity.angle()


## Called when the projectile collides with a body.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("World") or body.name == "BackgroundTiles" or body.name == "ForegroundTilles":
		queue_free()
	elif body.is_in_group("Character") or body.is_in_group("boids"):
		queue_free()
	elif body.name == "TaserBoss":
		queue_free()
