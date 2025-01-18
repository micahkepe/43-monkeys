extends Area2D

@export var SPEED: float = 300.0  # Speed of the projectile
@export var damage: int = 10     # Damage dealt to the player
@export var lifetime: float = 3.0

var velocity: Vector2 = Vector2.ZERO  # The projectile's velocity

func _ready() -> void:
	print("banana at:", global_position)
	if $AnimationPlayer.has_animation("banana_spin"):
		$AnimationPlayer.play("banana_spin")
	self.connect("body_entered", Callable(self, "_on_body_entered"))
	
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# Move the projectile based on its velocity
	global_position += velocity * delta

	if velocity.length() > 0:
		rotation = velocity.angle()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("World") or body.name == "BackgroundTiles" or body.name == "ForegroundTilles":
		print("BANANA TOUCHED WORLD!")
		queue_free()
	elif body.is_in_group("Character") or body.is_in_group("boids"):
		print("BANANA TOUCHED A CHARACTER/BOID!")
		queue_free()
