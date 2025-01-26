extends Node2D

## A cutscene that plays at the start of the game with typewriter text effect.
##
## The cutscene displays a series of frames with images and text. The player can
## advance through the cutscene by pressing the "ui_select" action. The text appears
## with a typewriter effect. Once complete, transitions to the first level.

# Story frames data
var _frames = [
	{
		"image": "res://assets/exposition/intro/exposition-1.png",
		"text": "South Carolina\nNovember 2024"
	},
	{
		"image": "res://assets/exposition/intro/frame-1.png",
		"text": "Deep beneath a rural farm...\nAlpha Genesis conducts their experiments"
	},
	{
		"image": "res://assets/exposition/intro/frame-2.png",
		"text": "Their secret research pushes ethical boundaries\nNo one knows what they're really doing to us"
	},
	{
		"image": "res://assets/exposition/intro/frame-3.png",
		"text": "Days pass slowly in isolation\nWatching, waiting for a chance..."
	},
	{
		"image": "res://assets/exposition/intro/frame-4.png",
		"text": "Until one day...\nA careless mistake changes everything"
	},
	{
		"image": "res://assets/exposition/intro/frame-5.png", # monkey running away
		"text": "Now is our chance for freedom\nLet's save my brethen..."
	},
]

# Current state variables
var _current_frame = 0
var _is_cutscene_active: bool = true
var _is_typing: bool = false
var _current_text: String = ""
var _target_text: String = ""
var _char_index: int = 0
var _can_advance: bool = false

# Node references
@onready var background: Sprite2D = get_node("Background")
@onready var label: Label = get_node("Label")
@onready var type_timer: Timer = Timer.new()
@onready var frame_timer: Timer = Timer.new()

# Typewriter effect settings
const TYPING_SPEED: float = 0.05  # Seconds between each character
const PUNCTUATION_PAUSE: float = 0.2  # Extra pause for punctuation


## Called when the node enters the scene tree for the first time.
## Initializes any setup required.
func _ready() -> void:
	# Setup typing timer
	type_timer.one_shot = false
	type_timer.connect("timeout", _on_type_timer_timeout)
	add_child(type_timer)
	
	# Setup frame timer
	frame_timer.one_shot = true
	frame_timer.connect("timeout", _on_frame_timer_timeout)
	add_child(frame_timer)

	# Start first frame if available
	if _frames.size() > 0:
		show_frame(_current_frame)


## Input event listeners
## @param event: InputEvent - The input event that occurred.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select") and _is_cutscene_active:
		if _is_typing:
			# Skip typing and show full text
			_complete_typing()
		elif _can_advance:
			frame_timer.stop()
			_current_frame += 1
			show_frame(_current_frame)


## Displays the frame at the given index.
func show_frame(index: int) -> void:
	if index >= _frames.size():
		_end_cutscene()
		return

	var frame = _frames[index]

	# Load and display background
	var texture = load(frame["image"])
	if texture == null:
		print("Failed to load image: ", frame["image"])
	else:
		background.texture = texture

	# Start typewriter effect
	_start_typing(frame["text"])

func _start_typing(text: String) -> void:
	_is_typing = true
	_can_advance = false
	_target_text = text
	_current_text = ""
	_char_index = 0
	label.text = ""
	type_timer.start(TYPING_SPEED)


## Timer callback for the typewriter effect.
func _on_type_timer_timeout() -> void:
	if _char_index >= _target_text.length():
		_complete_typing()
		return

	var next_char = _target_text[_char_index]
	_current_text += next_char
	label.text = _current_text
	_char_index += 1

	# Add extra pause for punctuation
	if next_char in ['.', '?', '!', ',']:
		type_timer.start(PUNCTUATION_PAUSE)
	else:
		type_timer.start(TYPING_SPEED)

## Timer callback for the frame transfer.
func _on_frame_timer_timeout() -> void:
	_current_frame += 1
	show_frame(_current_frame)

## Completes the typing effect and shows the full text.
func _complete_typing() -> void:
	_is_typing = false
	_can_advance = true
	type_timer.stop()
	label.text = _target_text
	frame_timer.start(2.0)


## Ends the cutscene and transitions to the first level.
func _end_cutscene() -> void:
	_is_cutscene_active = false
	get_tree().change_scene_to_file("res://levels/demo_level.tscn")
