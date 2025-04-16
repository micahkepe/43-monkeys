extends "res://levels/default_level.gd"
## Script for Level 1 logic
##
## Basic tutorial level with boid enemy NPCs, laser puzzles, and the PotionBoss
## boss fight at the end. The troop can grow up to 6 by the end of the level.

# Scene tree references
@onready var door = $World/Doors/Door
@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var boss_music: AudioStreamPlayer = $BossMusic
@onready var potion_boss = $World/PotionBoss
@onready var boss_dead: bool = false

# Level transition scenes
@export var transition_scene: PackedScene = preload("res://cutscenes/LevelTransition/level_transition.tscn")
@export var next_scene: PackedScene = preload("res://levels/Level2/level_2.tscn")

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	buttons_to_lasers = {
		["Buttons1", "Buttons2"]: ["Laser1", "Laser2", "Laser3"],
		["Buttons3", "Buttons4", "Buttons5", "Buttons6"]: ["Laser4"]
	}

	super._ready()

	background_music.play()

# Called every frame
func _process(_delta: float) -> void:
	check_boss_death()

# Check if the boss is dead and handle door/music transition
func check_boss_death() -> void:
	if potion_boss and potion_boss.is_dead and door and door.is_active and not boss_dead:
		door.open_door()
		print("Boss death detected - transitioning music")
		fade_between_tracks(boss_music, background_music)
		boss_dead = true


# Handle level transition when player enters trigger
func _on_next_scene_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Transition to next level
		var player = $World/Player
		var troop_count = player.get_troop_count() if player else 6
		var monkey_health = []
		if player:
			for monkey in player.get_troop():
				# Use current_health instead of health
				monkey_health.append(monkey.current_health if "current_health" in monkey else 6.0)

		var troop_data = {
			"count": troop_count,
			"player_health": player.health if player else 6.0,
			"monkey_health": monkey_health
		}

		if player:
			player.heal(player.max_health - player.health)

		var transition_instance = transition_scene.instantiate()
		transition_instance.next_scene = next_scene
		# transition_instance.level_number = 2
		transition_instance.level_title = "Bioscience Center"
		transition_instance.set_troop_data(troop_data)
		get_tree().root.add_child(transition_instance)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = transition_instance

# Handle boss music trigger
func _on_boss_music_trigger_body_entered(_body: Node2D) -> void:
	if background_music.playing and not boss_dead:
		fade_between_tracks(background_music, boss_music)
