extends "res://levels/default_level.gd"

var troop_data: Dictionary = {}

@export var root_boss_scene: PackedScene  # Assign res://entities/bosses/RootBoss/root_boss.tscn in the editor
var boss_spawned: bool = false
var boss_instance: Node = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not troop_data.is_empty():
		initialize_from_troop_data()
	if has_node("World/BossTrigger"):
		$World/BossTrigger.connect("body_entered", Callable(self, "_on_boss_trigger_body_entered"))

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

## Spawn the RootBoss at a specific position.
func spawn_root_boss() -> void:
	if not root_boss_scene:
		print("Error: RootBoss scene not set!")
		return

	boss_instance = root_boss_scene.instantiate()

	# Set the spawn position (e.g., center of the room)
	@warning_ignore("integer_division")
	var room_center = Vector2((1779 + 3016) / 2, (-3798 + -2446) / 2)  # (2397.5, -3122)

	boss_instance.global_position = room_center
	$World.call_deferred("add_child", boss_instance)
	print("RootBoss spawned at: ", boss_instance.global_position)

## Called when a body enters the boss trigger area.
func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not boss_spawned:
		spawn_root_boss()
		boss_spawned = true
