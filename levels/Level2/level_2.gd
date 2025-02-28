extends "res://levels/default_level.gd"

var troop_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not troop_data.is_empty():
		initialize_from_troop_data()

## Set the troop data for this level.
func set_troop_data(data: Dictionary) -> void:
	troop_data = data

## Initialize the player and troop from the troop data.
func initialize_from_troop_data() -> void:
	var player = $World/Player
	if player and not troop_data.is_empty():
		player.health = troop_data["player_health"]

		# Recreate troop
		var current_count = player.get_troop_count()
		var target_count = troop_data["count"]
		var monkey_health = troop_data.get("monkey_health", [])

		# Remove excess monkeys if any
		while current_count > target_count:
			if player._swarm_monkeys.size() > 0:
				var monkey = player._swarm_monkeys.pop_back()["node"]
				monkey.queue_free()
			current_count -= 1

		# Add missing monkeys
		while current_count < target_count:
			player.add_monkey_to_swarm()
			current_count += 1

		# Restore monkey health if tracked
		if not monkey_health.is_empty():
			for i in range(min(player._swarm_monkeys.size(), monkey_health.size())):
				if "health" in player._swarm_monkeys[i]:
					player._swarm_monkeys[i]["health"] = monkey_health[i]

## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
