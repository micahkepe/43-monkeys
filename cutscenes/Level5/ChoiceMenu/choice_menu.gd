extends Node2D

## The scene to transition to after making a choice
@export var next_scene: PackedScene

# Audio player for click sound
@onready var select_sfx_player = $SelectSFXPlayer

## Called when the node enters the scene tree for the first time
func _ready():
	pass

## Handles the Freedom (good) choice
func _on_good_pressed():
	select_sfx_player.play()
	# Simpler transition method
	var credits_scene = next_scene.instantiate()
	credits_scene.player_choice = "good"  # Set the choice parameter for credits

	# Use a more reliable scene transition method
	get_tree().root.add_child(credits_scene)
	# Set the current scene but don't call queue_free right away
	get_tree().current_scene = credits_scene
	# Mark this scene for deletion after a brief delay
	call_deferred("queue_free")

## Handles the Power (evil) choice
func _on_evil_pressed():
	select_sfx_player.play()
	# Simpler transition method
	var credits_scene = next_scene.instantiate()
	credits_scene.player_choice = "evil"  # Set the choice parameter for credits

	# Use a more reliable scene transition method
	get_tree().root.add_child(credits_scene)
	# Set the current scene but don't call queue_free right away
	get_tree().current_scene = credits_scene
	# Mark this scene for deletion after a brief delay
	call_deferred("queue_free")

## Handles pausing the game
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		$UI/PauseMenu.visible = true
		get_tree().paused = true
