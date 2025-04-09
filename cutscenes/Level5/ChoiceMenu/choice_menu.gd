extends Node2D

## The AudioStreamPlayer node that plays the select sound effect.
@onready var select_sfx_player: AudioStreamPlayer = get_node("SelectSFXPlayer")

@export
var next_scene: PackedScene

func _on_evil_pressed() -> void:
	print_debug("pressed evil choice")
	_handle_choice("evil")

func _on_good_pressed() -> void:
	print_debug("pressed good choice")
	_handle_choice("good")

func _handle_choice(choice="good"):
	if next_scene:
		select_sfx_player.play()
		await select_sfx_player.finished

		var next = next_scene.instantiate()
		next.choice = choice
		get_tree().root.add_child(next)
		get_tree().current_scene = next
		queue_free()
	else:
		push_error("No next scene for choice menu selected; exiting")
