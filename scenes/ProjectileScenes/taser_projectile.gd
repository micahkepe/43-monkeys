extends Area2D

@export var SPEED: float = 100.0  # Speed of the projectile
@export var damage: int = 10     # Damage dealt to the player

# Direction and spawn settings
@export var dir: float = 0.0  # Direction angle in radians
@export var spawnPos: Vector2
@export var spawnRot: float

func _ready():
	#global_position = spawnPos
	#global_rotation = spawnRot
	print("TaserProjectile is ready and at position: ", global_position)

	# Play the animation
	if $AnimationPlayer.has_animation("taser_spin"):
		$AnimationPlayer.play("taser_spin")
	
	# Connect collision detection
	self.connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta):
	# Calculate velocity and update position
	var velocity = Vector2(0, -SPEED).rotated(dir)
	global_position += velocity * delta

	# Destroy the projectile if it's off-screen
	if not get_viewport_rect().has_point(global_position):
		queue_free()

# Handle collision with a body
func _on_body_entered(body):
	print("TASER TOUCHED MONKEY!")
	if body.name == "Player":  # Replace with player's node name
		# Call the player's damage function (ADD LATER)
		if body.has_method("take_damage"):
			body.take_damage(damage)
		# Destroy the projectile after dealing damage
		queue_free()
