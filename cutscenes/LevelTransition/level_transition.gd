extends Node2D

@export var level_number: int
@export var level_title: String = ""
@export var next_scene: PackedScene = null  # Scene to load after transition
@export var display_duration: float = 2.0         # Time the full text stays visible
@export var fade_duration: float = 0.5            # Fade in/out duration
@export var typing_speed: float = 0.05            # Speed of typewriter effect
@export var punctuation_pause: float = 0.2        # Pause for punctuation marks

# Troop data to pass to next level
var troop_data: Dictionary = {}

# Node references
@onready var label: Label = get_node("Label")
@onready var fade_rect: ColorRect = get_node("FadeRect")
@onready var type_timer: Timer = Timer.new()      # Timer for typewriter effect

# Typewriter state variables
var _target_text: String = ""
var _current_text: String = ""
var _char_index: int = 0
var _is_typing: bool = false

func _ready():
	# Setup typewriter timer
	type_timer.one_shot = false
	type_timer.connect("timeout", _on_type_timer_timeout)
	add_child(type_timer)

	# Ensure the node is at the top of everything
	z_index = 100

	# Center the label
	var viewport_size = get_viewport_rect().size
	fade_rect.set_deferred("size", viewport_size)
	label.set_deferred("position", Vector2(viewport_size.x / 2 - label.size.x / 2,
							 viewport_size.y / 2 - label.size.y / 2))

	# Start fade-in
	fade_rect.modulate.a = 1.0
	label.text = ""
	if level_number:
		_target_text = "Level %d: %s" % [level_number, level_title]
	else:
		_target_text = "%s" % [level_title]

	_is_typing = true

	fade_in()

func fade_in():
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0, fade_duration)
	tween.tween_callback(Callable(self, "_on_fade_in_complete"))

func _on_fade_in_complete():
	# Start typewriter effect after fade-in
	_start_typing()

func _start_typing():
	_current_text = ""
	_char_index = 0
	label.text = ""
	type_timer.start(typing_speed)

func _on_type_timer_timeout():
	if _char_index >= _target_text.length():
		_complete_typing()
		return

	var next_char = _target_text[_char_index]
	_current_text += next_char
	label.text = _current_text
	_char_index += 1

	# Add extra pause for punctuation
	if next_char in ['.', '?', '!', ',']:
		type_timer.start(punctuation_pause)
	else:
		type_timer.start(typing_speed)

func _complete_typing():
	_is_typing = false
	type_timer.stop()
	label.text = _target_text

	# Wait before fading out
	await get_tree().create_timer(display_duration).timeout
	fade_out()

func fade_out():
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1, fade_duration)
	tween.tween_callback(Callable(self, "_on_fade_out_complete"))

func _on_fade_out_complete():
	print_debug("Transition completed, loading next level.")

	# Load the next level with troop data
	if next_scene:
		var next_level = next_scene.instantiate()
		if next_level.has_method("set_troop_data") and not troop_data.is_empty():
			next_level.set_troop_data(troop_data)
		get_tree().root.add_child(next_level)
		get_tree().current_scene = next_level
	else:
		push_error("No next level scene specified.")

	queue_free()  # Remove the transition scene

# Setter for troop data
func set_troop_data(data: Dictionary) -> void:
	troop_data = data
