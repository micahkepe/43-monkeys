extends PotionProjectile
class_name BlindnessPotion

# Duration of the blindness effect in seconds.
@export var blindness_duration: float = 5.0

# Keep track of bodies that have already received the blindness effect.
var blinded_bodies: Array = []

# Override the base on_effect_body_entered to apply blindness.
func on_effect_body_entered(body: Node) -> void:
	# Only apply the effect if it hasn't been applied already.
	if body in blinded_bodies:
		return

	# Check if the body can receive blindness.
	if body.has_method("apply_blindness"):
		print("BlindnessPotion: Applying blindness effect to ", body.name)
		body.apply_blindness(blindness_duration)
		blinded_bodies.append(body)
	else:
		print("BlindnessPotion: ", body.name, " does not have an apply_blindness method.")
