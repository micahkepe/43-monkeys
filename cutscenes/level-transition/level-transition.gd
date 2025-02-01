extends Node2D

@export var level_number: int = 1
@export var level_title: String = ""
@export var next_level_scene: PackedScene = null  # Scene to load after transition
@export var display_duration: float = 2.0
@export var fade_duration: float = 0.5

# Node references
@onready var label: Label = get_node("Label")
@onready var fade_rect: ColorRect = get_node("FadeRect")

signal transition_completed

func _ready():
	# Ensure the node is at the top of everything
	z_index = 100

	# Set text
	label.text = "Level %d: %s" % [level_number, level_title]
	label.visible = true

	# Center the label
	var viewport_size = get_viewport_rect().size
	fade_rect.size = viewport_size
	label.position = Vector2(viewport_size.x / 2 - label.size.x / 2,
	                         viewport_size.y / 2 - label.size.y / 2)

	# Start fade-in
	fade_rect.modulate.a = 1.0
	fade_in()

func fade_in():
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0, fade_duration)
	tween.tween_callback(Callable(self, "_on_fade_in_complete"))

func _on_fade_in_complete():
	# Display the text for a duration, then fade out
	await get_tree().create_timer(display_duration).timeout
	fade_out()

func fade_out():
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1, fade_duration)
	tween.tween_callback(Callable(self, "_on_fade_out_complete"))

func _on_fade_out_complete():
	emit_signal("transition_completed")
	print_debug("Transition completed, loading next level.")

	# Load the next level directly from here
	if next_level_scene:
		get_tree().change_scene_to_packed(next_level_scene)
	else:
		push_error("No next level scene specified.")

	queue_free()  # Optionally free the transition scene

