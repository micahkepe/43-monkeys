extends PotionProjectile
class_name HealPotion

# Amount of healing applied immediately on hit while in SPIN state.
@export var immediate_heal: float = 1.0

# Healing applied each tick while the potion is in POOL state (per second).
@export var pool_heal: float = 1.0

# The interval (in seconds) between pool healing ticks.
@export var pool_heal_interval: float = 1.0
var pool_heal_timer: float = 0.0

# Keep track of bodies that already received immediate healing
var healed_bodies: Array = []

# Override to apply immediate healing when hit during SPIN state.
func on_effect_body_entered(body: Node) -> void:
	if state == PotionState.SPIN:
		if body.has_method("heal") and not (body in healed_bodies):
			print("HealPotion: Applying immediate heal to ", body.name)
			body.heal(immediate_heal)
			healed_bodies.append(body)
	# In POOL state, continuous healing is handled in _physics_process.

func _physics_process(delta: float) -> void:
	# Call the base class _physics_process for movement and state changes.
	super._physics_process(delta)
	
	# When in the POOL state, apply continuous healing using a timer.
	if state == PotionState.POOL:
		pool_heal_timer += delta
		if pool_heal_timer >= pool_heal_interval:
			pool_heal_timer = 0.0  # Reset the timer
			var overlapping = get_overlapping_bodies()
			print("HealPotion: Overlapping bodies count =", overlapping.size())
			for body in overlapping:
				if _is_target(body) and body.has_method("heal"):
					print("HealPotion: Applying pool heal to ", body.name)
					body.heal(pool_heal)
