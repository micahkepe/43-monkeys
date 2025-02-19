extends PotionProjectile
class_name ParalyzePotion

@export var paralyze_duration: float = 8.0  # Duration (in seconds) of the paralysis effect

var paralyzed_bodies: Array = []

func on_effect_body_entered(body: Node) -> void:
	if body.has_method("paralyze") and not (body in paralyzed_bodies):
		print("ParalyzePotion: Applying paralysis to", body.name)
		body.paralyze(paralyze_duration)
		paralyzed_bodies.append(body)
		# Wait for the paralyze duration, then allow reapplication by removing the body from the list
		await get_tree().create_timer(paralyze_duration).timeout
		paralyzed_bodies.erase(body)
