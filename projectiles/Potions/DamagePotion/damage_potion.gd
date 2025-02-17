extends PotionProjectile
class_name DamagePotion
## Represents a damage potion that can be thrown by an enemy.

@export var immediate_damage: float = 1.0  # Damage dealt on immediate hit (in SPIN state)
@export var pool_damage: float = 2.0         # Damage dealt each tick while in POOL state

# Timer variables for pool damage
@export var pool_damage_interval: float = 1.0  # Time in seconds between damage ticks
var pool_damage_timer: float = 0.0

# Keep track of bodies that already received immediate damage
var damaged_bodies: Array = []

# Override to apply immediate damage when hit during SPIN state.
func on_effect_body_entered(body: Node) -> void:
	print("body name:", body.name)
	if state == PotionState.SPIN:
		if body.has_method("take_damage") and not (body in damaged_bodies):
			print("DamagePotion: Applying immediate damage to ", body.name)
			body.take_damage(immediate_damage)
			damaged_bodies.append(body)
	# Do nothing here in POOL state; continuous damage is handled in _physics_process.

func _physics_process(delta: float) -> void:
	# Call the base class _physics_process for movement and state changes.
	super._physics_process(delta)

	# When in the POOL state, apply continuous damage using a timer.
	if state == PotionState.POOL:
		pool_damage_timer += delta
		if pool_damage_timer >= pool_damage_interval:
			pool_damage_timer = 0.0  # Reset the timer
			var overlapping = get_overlapping_bodies()
			print("DamagePotion: Overlapping bodies count =", overlapping.size())
			for body in overlapping:
				if _is_target(body) and body.has_method("take_damage"):
					print("DamagePotion: Applying pool damage to ", body.name)
					body.take_damage(pool_damage)
