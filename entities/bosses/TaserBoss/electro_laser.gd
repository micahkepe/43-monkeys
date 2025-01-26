extends Area2D

@onready var _animated_sprite = $AnimatedSprite2D
@onready var _collision_shape = $CollisionShape2D

# Set to store all bodies currently inside the laser
var bodies_in_laser: Array = []

# Damage interval
@export var damage_interval: float = 1.0  # Time in seconds between damage ticks
var damage_timer: float = 0.0  # Tracks the elapsed time since the last damage tick

func _ready() -> void:
	# Connect the animation_finished signal
	_animated_sprite.animation_finished.connect(_on_animation_finished)

	# Disable the collision box initially
	_collision_shape.disabled = true

	# Connect signals
	self.connect("body_entered", Callable(self, "_on_body_entered"))
	self.connect("body_exited", Callable(self, "_on_body_exited"))

	# Play the start_up animation
	_animated_sprite.play("start_up")

func _on_animation_finished():
	if _animated_sprite.animation == "start_up":
		# Switch to the idle animation
		_animated_sprite.play("idle")
		# Enable the collision box when idle is playing
		_collision_shape.disabled = false

func _on_body_entered(body: Node) -> void:
	# Add the body to the set of tracked bodies
	if body.has_method("take_damage"):
		bodies_in_laser.append(body)

func _on_body_exited(body: Node) -> void:
	# Remove the body from the set when it exits the laser
	bodies_in_laser.erase(body)

func _process(delta: float) -> void:
	# Only deal damage if the laser is in the "idle" state
	if _animated_sprite.animation != "idle":
		return

	# Update the damage timer
	damage_timer += delta

	# If the timer exceeds the damage interval, deal damage
	if damage_timer >= damage_interval:
		damage_timer = 0.0  # Reset the timer

		# Deal damage to all bodies currently in the laser
		for body in bodies_in_laser:
			if body and body.has_method("take_damage"):  # Ensure the body still exists
				body.take_damage(2.0)
