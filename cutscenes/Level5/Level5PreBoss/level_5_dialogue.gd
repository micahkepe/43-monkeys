extends Control

# Configuration for the cutscene
class CutsceneFrame:
	var image: Texture2D
	var text: String

	func _init(img: Texture2D, txt: String):
		image = img
		text = txt



# Time to switch to next slide if no user input (in seconds)
@export var auto_advance_delay: float = 2.0

@export_group("Typewriter Variables")
# Time between characters; inverse to typing speed; (in seconds)
@export var base_time_btwn_chars: float = 0.05

# Additional pause for punctuation
@export var punctuation_pause: float = 0.2

# Variation in typing speed
@export var typing_variation: float = 0.02

# Current state variables
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

# Signal for the end of the cutscene.
signal cutscene_completed

func _process(_delta):
	if Input.is_action_just_pressed("ui_end"): # Escape key is "ui_cancel" by default
		show()
		# Pause the game
		get_tree().paused = true
		run()

## Called when the node enters the scene tree.
func run() -> void:
	_setup_timers()

	# Load images directly as Textures
	var frame_data: Array[CutsceneFrame] = [
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "Wait... No. It can't be.\nDr.Simian... you're one of us?"),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "You really expected some human\npulling the strings?"),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "No, George. The real mind behind\nall this was always a monkey."),
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "You... did this?\nTo your own kind?"),
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "How could you experiment on us?\nYou betrayed your species!"),
		
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "I didn't betray us\nI liberated us!"),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "We were just animals, waiting for\nhumans to capture and exploit us."),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "I made us more.\nThe humans will fear us!"),
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "You're just as evil as the humans.\nYou made us prisoners."),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "Prisoners today,\ngods tomorrow."),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "My experiments give us purpose,\npower, evolution!"),
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "No.\nDr.Simian, this ends now.")
	]

	initialize(frame_data)
	
	# get_tree().paused = false
	
	
	

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
	return base_time_btwn_chars + randf_range(-typing_variation, typing_variation)

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
	cutscene_completed.emit()

# Function to create each CutsceneFrame
func create_frame(image: Texture2D, text: String) -> CutsceneFrame:
	return CutsceneFrame.new(image, text)

func _on_cutscene_completed() -> void:
	queue_free()
	get_tree().paused = false
