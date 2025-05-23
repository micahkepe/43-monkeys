extends Area2D
## A laser that can be deactivated. Casts a red light on the surroundings
## (including entities.)

@onready var animated_sprite = $AnimatedSprite2D
@onready var point_light = $PointLight2D

var static_body: StaticBody2D
var is_active: bool = true
var body_in_laser: Node2D = null

func _ready() -> void:
	animated_sprite.play("laser_on")
	# Connect to the animation_finished signal
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Create a StaticBody2D to hold a collision shape for the laser.
	static_body = StaticBody2D.new()
	add_child(static_body)
	var collision_shape = $CollisionShape2D.duplicate()
	static_body.add_child(collision_shape)

func _on_animation_finished() -> void:
	if not is_active and animated_sprite.animation == "laser_turn_off":
		animated_sprite.play("laser_off")
		point_light.hide()

func _physics_process(delta: float) -> void:
	if is_active and body_in_laser:
		if body_in_laser.is_in_group("player") or body_in_laser.is_in_group("troop"):
			body_in_laser.take_damage(1.0 * delta)

func _on_body_entered(body: Node2D) -> void:
	if is_active and (body.is_in_group("player") or body.is_in_group("troop")):
		print_debug("Player entered the laser!")
		body_in_laser = body
		body.take_damage(1.0)

func _on_body_exited(body: Node2D) -> void:
	if body == body_in_laser:
		body_in_laser = null

# This method permanently deactivates the laser.
func deactivate_laser() -> void:
	# Already deactivated prior, skip
	if not is_active:
		return

	is_active = false
	animated_sprite.play("laser_turn_off")

	if $PowerOff:
		$PowerOff.play()

	# Disable the Area2D's collision shape.
	$CollisionShape2D.set_deferred("disabled", true)

	# Disable the collision shape on the StaticBody2D.
	if static_body and static_body.get_child_count() > 0:
		static_body.get_child(0).set_deferred("disabled", true)
