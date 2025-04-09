extends "res://menus/default_menu.gd"

## Duration in seconds before a new section starts
const section_time: float = 2.0

## Time in seconds between displaying each line
const line_time: float = 0.3

## Base scrolling speed in pixels per second
const base_speed: float = 100.0

## Multiplier applied to speed when sped up
const speed_up_multiplier: float = 10.0

## Color for section titles
const title_color: Color = Color.BLUE_VIOLET

## Vertical gap between credit lines
const vertical_spacing: float = 20.0

## Fixed width and height for images
const image_width: float = 50.0

## Margin between image and text (not currently used)
const image_margin: float = 20.0

## Current scrolling speed
var scroll_speed: float = base_speed

## Flag indicating if scrolling is sped up
var speed_up: bool = false

## Whether credits have begun scrolling
var started: bool = false

## Whether credits have completed
var finished: bool = false

## Current section of credits being processed
var section: Array

## Flag to start the next section
var section_next: bool = true

## Timer for section delay
var section_timer: float = 0.0

## Timer for line delay
var line_timer: float = 0.0

## Current line index within the section
var _curr_line: int = 0

## Array of active credit line nodes
var lines: Array = []

## Template label duplicated for each credit line
@onready var line: Label = $CreditsContainer/Line

## Total number of lines processed
var _total_lines_seen: int = -1

## Y-position for the next line
var _last_y_position: float = 0.0

## Index for alternating image sides
var _image_index: int = 0

## Choice parameter ("good" or "bad")
@export var choice: String = "good"

# Credit data as an array of sections, each containing strings
# TODO: do this smarter, make some object definition for credit sections
var credits: Array = [
	["A game by alpha studios"],
	["Programming", "Micah Kepe", "Grant Thompson", "Kevin Lei", "Zach Kepe"],
	["Art", "Artist Name"],
	["Music", "Kyle Sanderfer"],
	["Tools used", "Developed with Godot Engine", "https://godotengine.org/license", "", "Art created with My Favourite Art Program", "https://myfavouriteartprogram.com"],
	["Special thanks", "My parents", "My friends", "My pet rabbit"]
]

# Preloaded image resources for credits
# TODO: make this just an exported var of Array of images you can just drag in
# the editor or something
var img_blackjack: Texture = preload("res://assets/exposition/end-credits/freedom/blackjack.png")
var img_movies: Texture = preload("res://assets/exposition/end-credits/freedom/movies.png")
var img_rollercoaster: Texture = preload("res://assets/exposition/end-credits/freedom/rollercoaster.png")

# Array of dictionaries mapping images to specific lines
var credits_images: Array = [
	{"line": 1, "texture": img_blackjack},
	{"line": 3, "texture": img_movies},
	{"line": 5, "texture": img_rollercoaster}
]

## Initializes the credits scene by setting the starting position
func _ready() -> void:
	_last_y_position = get_viewport().size.y
	print("== READY ==")

## Updates the credits scrolling each frame
## @param delta: Time elapsed since the last frame (in seconds)
func _process(delta: float) -> void:
	# Calculate the current scroll speed based on delta and speed-up state
	var current_scroll_speed: float = base_speed * delta
	if speed_up:
		current_scroll_speed *= speed_up_multiplier

	# Handle section timing
	if section_next:
		section_timer += delta * speed_up_multiplier if speed_up else delta
		if section_timer >= section_time:
			section_timer -= section_time
			if credits.size() > 0:
				started = true
				section = credits.pop_front()  # Get the next section
				_curr_line = 0
				add_line()  # Add the first line of the section
	else:
		# Handle line timing within a section
		line_timer += delta * speed_up_multiplier if speed_up else delta
		if line_timer >= line_time:
			line_timer -= line_time
			add_line()  # Add the next line

	# Scroll all active lines and remove those off-screen
	if lines.size() > 0:
		for l in lines:
			l.position.y -= current_scroll_speed  # Move line upward
			if l.position.y < -l.size.y:  # Check if line is fully off-screen
				lines.erase(l)
				l.queue_free()  # Free the node to avoid memory leaks
	elif started:
		finish()  # End credits when all lines are gone and started

## Ends the credits and transitions to the main menu
func finish() -> void:
	if not finished:
		finished = true
		print("== FINISHED CREDITS ==")  # Debug message to confirm completion
		get_tree().change_scene_to_file("res://menus/MainMenu/main_menu.tscn")  # Switch to main menu

## Adds a new credit line to the scene
func add_line() -> void:
	_total_lines_seen += 1  # Increment total lines processed

	if section.size() > 0:
		var text: String = section.pop_front()  # Get the next line text

		# Create a horizontal container for the line
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.position = Vector2(0, _last_y_position)  # Position at the last Y coordinate
		hbox.anchor_right = 1.0  # Stretch across the full width
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Expand to fill horizontally
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER  # Center contents

		# Check if this line has an associated image
		var has_image: bool = false
		var image_side: bool = _image_index % 2 == 0  # True for left, false for right
		var image_texture = null  # Texture for the image, if any

		for img in credits_images:
			if img["line"] == _total_lines_seen:
				image_texture = img["texture"]
				has_image = true
				_image_index += 1
				break

		# Create and configure the image node
		var image_node: TextureRect = TextureRect.new()
		image_node.texture = image_texture
		image_node.stretch_mode = TextureRect.STRETCH_SCALE  # Scale image proportionally
		image_node.size = Vector2(image_width, image_width)  # Set fixed size
		image_node.custom_minimum_size = image_node.size  # Ensure minimum size
		image_node.visible = has_image  # Show only if there’s an image

		# Create and configure the text label
		var label: Label = line.duplicate()  # Duplicate the template label
		label.text = text
		if _curr_line == 0:  # First line of a section is a title
			label.add_theme_color_override("font_color", title_color)
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # Center text within label

		# Arrange image and text based on image side
		if has_image:
			if image_side:
				hbox.add_child(image_node)  # Image on left
				hbox.add_child(label)       # Text on right
			else:
				hbox.add_child(label)       # Text on left
				hbox.add_child(image_node)  # Image on right
		else:
			hbox.add_child(label)  # Only text if no image

		# Add the container to the scene and track it
		$CreditsContainer.add_child(hbox)
		lines.append(hbox)

		# Update the Y position for the next line
		var height: float = max(label.size.y, image_node.size.y)
		_last_y_position += height + vertical_spacing
		_curr_line += 1
		section_next = section.size() == 0  # Move to next section if current one is empty
	else:
		# Add extra spacing between sections
		_last_y_position += vertical_spacing * 2
		section_next = true

## Handles user input for skipping or speeding up credits
## @param event: The input event to process
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		finish()  # Skip credits and go to main menu
	if event.is_action_pressed("ui_down") and not event.is_echo():
		speed_up = true  # Speed up scrolling
	if event.is_action_released("ui_down"):
		speed_up = false  # Return to normal speed
