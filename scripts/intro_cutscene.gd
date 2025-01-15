extends Node2D
## A cutscene that plays at the start of the game.
##
## The cutscene displays a series of frames with images and text. The player can
## advance through the cutscene by pressing the "ui_select" action. Once the
## cutscene is complete, the game will transition to the first level.

## The frames of the cutscene. Each frame contains an image and text.
## TODO: make the formatting and layout nice and have more options
var _frames = [
	{
		"image": "res://assets/exposition/intro/exposition-1.png",
		"text": "South Carolina \n2024"
	},
	{
		"image": "res://assets/exposition/intro/frame-1.png",
		"text": "Placeholder"
	},
	{
		"image": "res://assets/exposition/intro/frame-2.png",
		"text": "Placeholder"
	},
	{
		"image": "res://assets/exposition/intro/frame-3.png",
		"text": "Placeholder"
	},
	{
		"image": "res://assets/exposition/intro/frame-4.png",
		"text": "Placeholder"
	},
	{
		"image": "res://assets/exposition/intro/frame-5.png",
		"text": "Placeholder"
	},
]

## The current frame index.
var _current_frame = 0

## Flag to indicate if the cutscene is active.
var _is_cutscene_active: bool = true

## The background sprite node.
@onready var background: Sprite2D = get_node("Background")

## The label node for displaying text.
@onready var label: Label = get_node("Label")

## Called when the node enters the scene tree for the first time.
## Initializes any setup required.
func _ready() -> void:
	if _frames.size() > 0:
			_show_frame(_current_frame)


## Input event listeners
## @param event: InputEvent - The input event that occurred.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select") and _is_cutscene_active:
		_current_frame += 1
		_show_frame(_current_frame)


## Show the next frame in the cutscene.
## If there are no more frames, end the cutscene.
func _show_frame(index):
	if index >= _frames.size():
		_end_cutscene()
		return

	var _frame = _frames[index]

	# Load and display the background image
	var texture = load(_frame["image"])
	background.texture = texture

	if texture == null:
		print("Failed to load image: ", _frame["image"])
	else:
		background.texture = texture

	label.text = _frame["text"]


## Handles the end of cutscene slides and advances to the fist level.
func _end_cutscene():
	_is_cutscene_active = false
	get_tree().change_scene_to_file("res://scenes/levels/level-0.tscn")
