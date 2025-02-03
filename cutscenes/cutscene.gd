extends Node2D

## Configuration for the cutscene
class CutsceneFrame:
	var image: Texture2D
	var text: String

	func _init(img: Texture2D, txt: String):
		image = img
		text = txt

## Export variables for easy configuration in the editor
@export var transition_scene: PackedScene = null  # Optional Level Transition Scene
@export var next_level_scene: PackedScene = null  # Target Level Scene
@export var transition_level_number: int = 1      # Configurable Level Number
@export var transition_level_title: String = ""   # Configurable Level Title
@export var auto_advance_delay: float = 2.0
@export var typing_speed: float = 0.05            # Base typing speed
@export var punctuation_pause: float = 0.2        # Additional pause for punctuation
@export var typing_variation: float = 0.02        # New: Variation in typing speed

## Current state variables
var _frames: Array[CutsceneFrame] = []
var _current_frame: int = 0
var _is_cutscene_active: bool = true
var _is_typing: bool = false
var _current_text: String = ""
var _target_text: String = ""
var _char_index: int = 0
var _can_advance: bool = false

# Node references
@onready var background: Sprite2D = get_node("Background")
@onready var label: Label = get_node("Label")
@onready var keystroke_player: AudioStreamPlayer = get_node("KeyStrokePlayer")
@onready var type_timer: Timer = Timer.new()
@onready var frame_timer: Timer = Timer.new()

## Signal emitted when the cutscene completes
signal cutscene_completed

## Called when the node enters the scene tree.
func _ready() -> void:
	_setup_timers()

## Utility to create frames easily
func create_frame(image: Texture2D, text: String) -> CutsceneFrame:
	return CutsceneFrame.new(image, text)

## Initializes the cutscene with the given frames data
func initialize(frame_data: Array[CutsceneFrame]) -> void:
	_frames = frame_data
	if _frames.size() > 0:
		show_frame(_current_frame)

## Sets up the required timers
func _setup_timers() -> void:
	type_timer.one_shot = false
	type_timer.connect("timeout", _on_type_timer_timeout)
	add_child(type_timer)

	frame_timer.one_shot = true
	frame_timer.connect("timeout", _on_frame_timer_timeout)
	add_child(frame_timer)

## Input event listeners
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select") and _is_cutscene_active:
		if _is_typing:
			_complete_typing()
		elif _can_advance:
			frame_timer.stop()
			_current_frame += 1
			show_frame(_current_frame)

## Displays the frame at the given index
func show_frame(index: int) -> void:
	if index >= _frames.size():
		_end_cutscene()
		return

	var frame = _frames[index]
	background.texture = frame.image
	_start_typing(frame.text)

## Starts the typewriter effect for the given text
func _start_typing(text: String) -> void:
	_is_typing = true
	_can_advance = false
	_target_text = text
	_current_text = ""
	_char_index = 0
	label.text = ""
	type_timer.start(_get_random_typing_speed())

## Timer callback for the typewriter effect
func _on_type_timer_timeout() -> void:
	if _char_index >= _target_text.length():
		_complete_typing()
		return

	var next_char = _target_text[_char_index]
	_current_text += next_char
	label.text = _current_text
	keystroke_player.play()
	_char_index += 1

	# Determine delay for next character
	var delay = punctuation_pause if next_char in ['.', '?', '!', ','] else _get_random_typing_speed()
	type_timer.start(delay)

## Generates a random typing speed to simulate natural typing
func _get_random_typing_speed() -> float:
	return typing_speed + randf_range(-typing_variation, typing_variation)

## Timer callback for the frame transfer
func _on_frame_timer_timeout() -> void:
	_current_frame += 1
	show_frame(_current_frame)

## Completes the typing effect and shows the full text
func _complete_typing() -> void:
	_is_typing = false
	_can_advance = true
	type_timer.stop()
	label.text = _target_text
	frame_timer.start(auto_advance_delay)

## Ends the cutscene and triggers either a transition or level load
func _end_cutscene() -> void:
	_is_cutscene_active = false
	emit_signal("cutscene_completed")

	# Trigger level transition if defined
	if transition_scene:
		var transition = transition_scene.instantiate()
		transition.level_number = transition_level_number
		transition.level_title = transition_level_title
		transition.next_level_scene = next_level_scene  # Pass next level to the transition

		# Defer the freeing of the current scene
		call_deferred("_switch_to_transition_scene", transition)
	else:
		_on_transition_completed()

## Defer switching to the transition scene to avoid freeing locked objects
func _switch_to_transition_scene(transition):
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()  # Use queue_free() for safety
	get_tree().current_scene = transition
	get_tree().root.add_child(transition)

## Load the next gameplay level after the transition (or immediately if no transition)
func _on_transition_completed():
	if next_level_scene:
		get_tree().change_scene_to_packed(next_level_scene)
	else:
		push_error("No next level scene specified after cutscene.")

