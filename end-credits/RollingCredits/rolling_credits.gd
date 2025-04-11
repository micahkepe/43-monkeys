extends "res://menus/default_menu.gd"

## Duration in seconds before a new section starts
const section_time: float = 2.0

## Time in seconds between displaying each line
const line_time: float = 0.3

## Base scrolling speed in pixels per second
const base_speed: float = 80.0

## Multiplier applied to speed when sped up
const speed_up_multiplier: float = 10.0

## Color for section titles
const title_color: Color = Color(0.7, 0.3, 0.9, 1.0) # Brighter purple

## Vertical gap between credit lines
const vertical_spacing: float = 30.0

## Fixed width and height for images
const image_width: float = 600
const image_height: float = 600

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

## Choice parameter ("good" or "evil")
@export var choice: String = "good"

# Credit data as an array of sections, each containing strings
var credits: Array = [
	["A game by alpha studios"],
	["Programming", "Micah Kepe", "Grant Thompson", "Kevin Lei", "Zach Kepe"],
	["Art", "Kevin Lei"],
	["Music", "Kyle Sanderfer", "@Bospad"],
	["Supervision", "Professor Joe Warren"],
	["Tools used", "Developed with Godot Engine", "https://godotengine.org/license", "", "Art created with Aseprite", "https://www.aseprite.org/"]
]

# Image resources for the "good" choice (freedom)
var freedom_images = {
	"blackjack": preload("res://assets/exposition/end-credits/freedom/blackjack.png"),
	"movies": preload("res://assets/exposition/end-credits/freedom/movies.png"),
	"rollercoaster": preload("res://assets/exposition/end-credits/freedom/rollercoaster.png")
}

# Image resources for the "evil" choice (power)
var power_images = {
	"evil_smile": preload("res://assets/exposition/end-credits/new-evil/evil-smile.png"),
	"scientists": preload("res://assets/exposition/end-credits/new-evil/group-of-scientists.png"),
	"scared_monkey": preload("res://assets/exposition/end-credits/new-evil/scared-monkey.png")
}

# Array of dictionaries mapping images to specific lines based on choice
var credits_images: Array = []

## Initializes the credits scene by setting the starting position
func _ready() -> void:
	# Ensure we have a default choice if none is set
	if choice != "good" and choice != "evil":
		choice = "good"
		print("WARNING: Invalid choice, defaulting to 'good'")
		
	print("== READY == Choice: " + choice)
	
	# Add choice-specific section at the beginning for more visibility
	if choice == "good":
		credits.insert(0, ["Freedom Ending", "You chose a life of freedom", "Enjoying the simple pleasures", "Finally at peace"])
		credits_images = [
			{"line": 1, "texture": freedom_images.blackjack},
			{"line": 3, "texture": freedom_images.movies},
			{"line": 5, "texture": freedom_images.rollercoaster}
		]
	else:
		credits.insert(0, ["Power Ending", "You chose to seize control", "The tables have turned", "The experiments continue..."])
		credits_images = [
			{"line": 1, "texture": power_images.evil_smile},
			{"line": 3, "texture": power_images.scientists},
			{"line": 5, "texture": power_images.scared_monkey}
		]
	
	# Initialize the starting position
	_last_y_position = get_viewport().size.y
	
	# Print info for debugging
	print("Credits sections: ", credits.size())
	print("First section: ", credits[0])

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
	elif started and credits.size() == 0:
		print("No more credits and no more lines - finishing")
		finish()  # End credits when all lines are gone and credits array is empty
		
	# Debug - check if the finish condition should be met
	if started and lines.size() == 0 and credits.size() == 0 and not finished:
		print("Credits should be finishing - Started: {0}, Lines: {1}, Credits: {2}, Finished: {3}".format([started, lines.size(), credits.size(), finished]))

## Ends the credits and transitions to the main menu
func finish() -> void:
	if not finished:
		# Set the finished flag to prevent multiple calls
		finished = true
		print("== FINISHED CREDITS ==")  # Debug message to confirm completion
		
		# Stop the debug output that's causing console spam
		set_process(false)
		
		# Use a more direct approach with a shorter delay
		get_tree().create_timer(0.5).timeout.connect(func(): change_scene_to_main_menu())

## Changes scene to the main menu
func change_scene_to_main_menu() -> void:
	print("Changing to main menu")
	# Use safer scene transition method
	get_tree().change_scene_to_file("res://menus/MainMenu/main_menu.tscn")
	# Don't call queue_free() here - it's causing issues
	# Godot will handle the cleanup automatically

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
		
		# Maintain aspect ratio while filling the container
		image_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Force the size by setting both size properties
		image_node.custom_minimum_size = Vector2(image_width, image_height)
		image_node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		image_node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		
		# Explicitly set expand to true to ensure the texture scales
		image_node.expand = true
		
		# Add a subtle drop shadow for depth
		var shadow_stylebox = StyleBoxFlat.new()
		shadow_stylebox.bg_color = Color(0, 0, 0, 0.3)
		shadow_stylebox.shadow_color = Color(0, 0, 0, 0.4)
		shadow_stylebox.shadow_size = 4
		shadow_stylebox.shadow_offset = Vector2(2, 2)
		image_node.add_theme_stylebox_override("panel", shadow_stylebox)
		
		# Make sure it's visible
		image_node.visible = has_image

		# Create and configure the text label
		var label: Label = line.duplicate()  # Duplicate the template label
		label.text = text
		label.visible = true  # Make sure the label is visible
		
		# Set text color (white on black background)
		label.add_theme_color_override("font_color", Color.WHITE)
		
		# Add a subtle text shadow for better visibility
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_constant_override("shadow_as_outline", 0)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		
		if _curr_line == 0:  # First line of a section is a title
			label.add_theme_color_override("font_color", title_color)
			label.add_theme_font_size_override("font_size", 60)  # Larger font for titles
		
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # Center text within label

		# Arrange image and text based on image side
		if has_image:
			if image_side:
				# Create a fixed-size container for the image with rounded corners
				var image_container = PanelContainer.new()
				image_container.custom_minimum_size = Vector2(image_width, image_height)
				image_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				image_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				
				# Add stylebox for the container
				var container_style = StyleBoxFlat.new()
				container_style.bg_color = Color(0, 0, 0, 0) # Transparent background
				container_style.corner_radius_top_left = 10
				container_style.corner_radius_top_right = 10
				container_style.corner_radius_bottom_left = 10
				container_style.corner_radius_bottom_right = 10
				image_container.add_theme_stylebox_override("panel", container_style)
				
				# Add the image to the container
				image_node.anchors_preset = Control.PRESET_FULL_RECT  # Fill the container
				image_container.add_child(image_node)
				
				hbox.add_child(image_container)  # Image container on left
				
				# Add some space between image and text
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(image_margin, 0)
				hbox.add_child(spacer)
				hbox.add_child(label)       # Text on right
			else:
				hbox.add_child(label)       # Text on left
				
				# Add some space between text and image
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(image_margin, 0)
				hbox.add_child(spacer)
				
				# Create a fixed-size container for the image with rounded corners
				var image_container = PanelContainer.new()
				image_container.custom_minimum_size = Vector2(image_width, image_height)
				image_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				image_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				
				# Add stylebox for the container
				var container_style = StyleBoxFlat.new()
				container_style.bg_color = Color(0, 0, 0, 0) # Transparent background
				container_style.corner_radius_top_left = 10
				container_style.corner_radius_top_right = 10
				container_style.corner_radius_bottom_left = 10
				container_style.corner_radius_bottom_right = 10
				image_container.add_theme_stylebox_override("panel", container_style)
				
				# Add the image to the container
				image_node.anchors_preset = Control.PRESET_FULL_RECT  # Fill the container
				image_container.add_child(image_node)
				
				hbox.add_child(image_container)  # Image container on right
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
