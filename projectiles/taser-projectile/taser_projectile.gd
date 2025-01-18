extends Area2D
## A taser projectile that damages bodies on contact if the body implements
## the `take_damage` method.
##
## The projectile moves in the direction it was spawned in and deals damage
## to the player on contact. The projectile is destroyed after dealing damage.

## The speed of the banana projectile.
@export var speed: float = 100.0

## The amount of damage the banana deals to the player.
@export var damage: int = 10

## The direction the banana is moving in radians.
@export var dir_rads: float = 0.0

## The position the banana is spawned at.
@export var spawn_pos_vec: Vector2

## The rotation of the banana when spawned.
@export var spawn_rotation: float


## Called when the node enters the scene tree for the first time.
func _ready():
	# Play the animation
	if $AnimationPlayer.has_animation("taser_spin"):
		$AnimationPlayer.play("taser_spin")

	# Connect collision detection
	self.connect("body_entered", Callable(self, "_on_body_entered"))


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# Calculate velocity and update position
	var velocity = Vector2(0, -speed).rotated(dir_rads)
	global_position += velocity * delta

	# Destroy the projectile if it's off-screen
	if not get_viewport_rect().has_point(global_position):
		queue_free()


## Called when the projectile collides with a body.
## If the body is the player, deal damage and destroy the projectile.
func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)

	# Destroy the projectile after dealing damage
	queue_free()
