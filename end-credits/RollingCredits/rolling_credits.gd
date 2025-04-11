extends "res://menus/default_menu.gd"
## Manages scrolling credits with modular sections and clickable links.
##
## Scrolling credits with sections that can be added dynamically. Each section
## can contain a title, description, and a list of people with optional roles
## and links. The credits scroll up the screen, and the user can fast-scroll by
## holding down a key. The script also handles loading images for each person
## and displaying them alongside their information. The credits are displayed
## in a visually appealing manner with customizable colors, fonts, and styles.
## The script is designed to be modular and reusable, allowing for easy
## customization and extension.

# --- Configuration ---

@export_group("Timing")

## Delay between sections in seconds
@export var section_delay: float = 2.0

## Delay between lines in seconds
@export var line_delay: float = 0.3

## Base scroll speed in pixels per second
@export var base_scroll_speed: float = 80.0

## Multiplier for fast scrolling
@export var fast_scroll_multiplier: float = 10.0

@export_group("Colors")

## The color for the title text
@export var title_color: Color = Color(0.7, 0.3, 0.9, 1.0)

## The color for the text
@export var text_color: Color = Color.WHITE

## The color for the link text
@export var link_color: Color = Color(0.4, 0.7, 1.0, 1.0)

## The color for the background
@export var background_color: Color = Color(0.0, 0.0, 0.0, 1.0)

@export_group("Spacing")

## Spacing between lines
@export var vertical_spacing: float = 60.0

## Spacing between people
@export var person_spacing: float = 60.0

## Margin for images
@export var image_margin: float = 40.0

@export_group("Images")

## Size of the images displayed in the credits
@export var image_size: Vector2 = Vector2(400, 400)

@export_group("Fonts")

## Font size for the title
@export var title_font_size: int = 60

## Font size for the text
@export var text_font_size: int = 45

## Font size for the link text
@export var link_font_size: int = 35

## Font for the link text
@export var link_font: Font

@export_group("Style")

## Style for the background
@export var background_panel: StyleBox

## Style for the images
@export var image_panel: StyleBox

@export_group("Game")

## Player choice ("good" or "evil")
@export var player_choice: String = "good"

# --- Nodes ---
@onready var credits_container = $CreditsContainer
@onready var line_template = $CreditsContainer/Line
@onready var background = $Background

# --- Internal State ---
var current_scroll_speed = base_scroll_speed
var is_fast_scrolling = false
var started = false
var finished = false

var section_timer = 0.0
var line_timer = 0.0
var active_lines = []
var next_y_position = 0.0
var wait_for_next_section = true
var image_alternate_counter = 0

# --- Credits Data ---
var credits_sections = []
var current_section = null

# --- Image Paths ---
const IMAGES = {
	"good": [
		"res://assets/exposition/end-credits/freedom/blackjack.png",
		"res://assets/exposition/end-credits/freedom/movies.png",
		"res://assets/exposition/end-credits/freedom/rollercoaster.png"
	],
	"evil": [
		"res://assets/exposition/end-credits/new-evil/evil-smile.png",
		"res://assets/exposition/end-credits/new-evil/group-of-scientists.png",
		"res://assets/exposition/end-credits/new-evil/scared-monkey.png"
	]
}

# --- Image Cache ---
var loaded_images = {}

func _ready():
	# Set background color
	if background:
		background.color = background_color

	# Set initial position to bottom of screen
	next_y_position = get_viewport().size.y

	# Setup credits data
	_setup_credits()

	# Preload images
	_preload_all_images()

func _process(delta) -> void:
	# Handle scrolling speed
	var current_delta_speed = base_scroll_speed * delta
	if is_fast_scrolling:
		current_delta_speed *= fast_scroll_multiplier

	# Handle section and line timing
	if wait_for_next_section:
		section_timer += delta * (fast_scroll_multiplier if is_fast_scrolling else 1.0)
		if section_timer >= section_delay:
			section_timer = 0.0
			_start_next_section()
	else:
		line_timer += delta * (fast_scroll_multiplier if is_fast_scrolling else 1.0)
		if line_timer >= line_delay:
			line_timer = 0.0
			_add_next_person()

	# Scroll active lines
	for line in active_lines:
		line.position.y -= current_delta_speed
		# Remove lines that have scrolled off the top
		if line.position.y < -line.size.y - 100:
			active_lines.erase(line)
			line.queue_free()

	# Check if credits are finished
	if started and active_lines.size() == 0 and credits_sections.size() == 0:
		_end_credits()

func _unhandled_input(event) -> void:
	if event.is_action_pressed("ui_cancel"):
		_end_credits()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		is_fast_scrolling = true
	if event.is_action_released("ui_down"):
		is_fast_scrolling = false

# --- Credits Data Setup ---

## Setup all credit sections. Includes images and people.
func _setup_credits() -> void:
	credits_sections.clear()

	# Get images for the selected choice
	var images = IMAGES["good"] if player_choice == "good" else IMAGES["evil"]
	var image_index = 0

	# Add ending section based on player choice
	if player_choice == "good":
		_add_section("FREEDOM",
			"You chose a life of freedom, \nfinally experiencing peace and simple pleasures.",
			[["No longer living in fear", "", [], images[image_index]]])
	else:
		_add_section("POWER",
			"You chose to seize control. \nThe tables have turned, and now you run the show.",
			[["The New Order begins...", "", [], images[image_index]]])
	image_index += 1

	# Programming section
	_add_section("PROGRAMMING", "", [
		["Micah Kepe", "Project Lead", [["GitHub", "https://github.com/micahkepe"]]],
		["Grant Thompson", "Game Architect", [["LinkedIn", "https://www.linkedin.com/in/grantwthompson/"]]],
		["Kevin Lei", "Artistic Director", [["LinkedIn", "https://www.linkedin.com/in/lei-kevin/"]]],
		["Zach Kepe", "Software Developer", [["GitHub", "https://github.com/zachkepe"]]]
	])

	# Art section
	_add_section("ART", "", [
		["Kevin Lei", "Lead Artist", [], images[image_index]]
	])
	image_index += 1

	# Music section
	_add_section("MUSIC", "", [
		["Kyle Sanderfer (Bospad)", "Composer", [["Spotify", "https://open.spotify.com/artist/6Z9DPgoBu600ZbUbdQqZQf?si=IqUu-Tg0T9K7kVdWd1_35Q"]]]
	])

	# Supervision section
	_add_section("SUPERVISION", "", [
		["Professor Joe Warren", "Faculty Advisor", [["Website", "https://cs.rice.edu/~jwarren"]], images[image_index]]
	])
	image_index += 1

	# Thanks section
	var thanks_people = [
		["The Godot community", ""],
		["Our countless beta testers", ""],
		["YOU for playing!", ""]
	]

	_add_section("SPECIAL THANKS", "", thanks_people)

# Helper function to add a section to the credits
func _add_section(title, description="", people=[]) -> void:
	credits_sections.append({
		"title": title,
		"description": description,
		"people": people
	})

# Preload all images
func _preload_all_images():
	for path_array in IMAGES.values():
		for path in path_array:
			if path and not path.is_empty():
				loaded_images[path] = load(path)

# --- Display Functions ---

# Start displaying the next section
func _start_next_section() -> void:
	# Check if there are more sections
	if credits_sections.size() > 0:
		started = true
		current_section = credits_sections.pop_front()
		_add_section_title()
	else:
		wait_for_next_section = true

## Add the section title and description
func _add_section_title() -> void:
	# Create title container
	var title_container = HBoxContainer.new()
	title_container.position = Vector2(0, next_y_position)
	title_container.anchor_right = 1.0
	title_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Create and configure title label
	var title_label = line_template.duplicate()
	title_label.text = current_section.title
	title_label.visible = true
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_font_size_override("font_size", title_font_size)
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))

	title_container.add_child(title_label)
	credits_container.add_child(title_container)
	active_lines.append(title_container)

	# Add description if available
	if current_section.description:
		next_y_position += vertical_spacing

		var desc_container = HBoxContainer.new()
		desc_container.position = Vector2(0, next_y_position)
		desc_container.anchor_right = 1.0
		desc_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_container.alignment = BoxContainer.ALIGNMENT_CENTER

		var desc_label = line_template.duplicate()
		desc_label.text = current_section.description
		desc_label.visible = true
		desc_label.add_theme_color_override("font_color", text_color)
		desc_label.add_theme_font_size_override("font_size", text_font_size)
		desc_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		desc_container.add_child(desc_label)
		credits_container.add_child(desc_container)
		active_lines.append(desc_container)

	next_y_position += vertical_spacing * 1.5

	# Check if there are people to display
	wait_for_next_section = current_section.people.size() == 0
	if wait_for_next_section:
		next_y_position += vertical_spacing * 2


## Add the next person in the current section
func _add_next_person() -> void:
	if current_section.people.size() == 0:
		next_y_position += vertical_spacing * 2
		wait_for_next_section = true
		return

	var person = current_section.people.pop_front()
	var person_name = person[0]
	var role = person[1]
	var links = person[2] if person.size() > 2 else []
	var image_path = person[3] if person.size() > 3 else ""

	# Create main container
	var container = HBoxContainer.new()
	container.position = Vector2(0, next_y_position)
	container.anchor_right = 1.0
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Create content container
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.custom_minimum_size.x = 300

	# Add name label
	var name_label = line_template.duplicate()
	name_label.text = person_name
	name_label.visible = true
	name_label.add_theme_color_override("font_color", text_color)
	name_label.add_theme_font_size_override("font_size", text_font_size)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	# Add role label if available
	if role:
		var role_label = line_template.duplicate()
		role_label.text = role
		role_label.visible = true
		role_label.add_theme_color_override("font_color", text_color.darkened(0.2))
		role_label.add_theme_font_size_override("font_size", text_font_size - 4)
		role_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(role_label)

	# Add links if available
	if links.size() > 0:
		# Create a centered container for links
		var links_container = HBoxContainer.new()
		links_container.alignment = BoxContainer.ALIGNMENT_CENTER
		links_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		for link_data in links:
			var link_button = LinkButton.new()
			link_button.text = link_data[0]
			link_button.uri = link_data[1]
			link_button.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
			link_button.add_theme_color_override("font_color", link_color)
			link_button.add_theme_font_size_override("font_size", link_font_size)
			if link_font:
				link_button.add_theme_font_override("font", link_font)
			links_container.add_child(link_button)

		content.add_child(links_container)

	# Handle image if available
	var image_container = null
	if image_path and not image_path.is_empty() and loaded_images.has(image_path):
		image_container = PanelContainer.new()
		image_container.custom_minimum_size = image_size

		# Apply panel style
		if image_panel:
			image_container.add_theme_stylebox_override("panel", image_panel)
		else:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0.2)
			style.set_corner_radius_all(10)
			image_container.add_theme_stylebox_override("panel", style)

		# Add image
		var image = TextureRect.new()
		image.texture = loaded_images[image_path]
		image.expand = true
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = image_size
		image_container.add_child(image)

	# Arrange content and image
	if image_container:
		# Alternate image position
		var image_on_left = image_alternate_counter % 2 == 0
		image_alternate_counter += 1

		if image_on_left:
			container.add_child(image_container)
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(image_margin, 0)
			container.add_child(spacer)
			container.add_child(content)
		else:
			container.add_child(content)
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(image_margin, 0)
			container.add_child(spacer)
			container.add_child(image_container)

		next_y_position += image_size.y + vertical_spacing
	else:
		container.add_child(content)
		next_y_position += vertical_spacing * 1.5

	credits_container.add_child(container)
	active_lines.append(container)

	next_y_position += person_spacing
	wait_for_next_section = current_section.people.size() == 0

# --- End Credits ---

## Handle the end of the credits
func _end_credits() -> void:
	if finished:
		return
	finished = true
	set_process(false)
	get_tree().create_timer(0.5).timeout.connect(_return_to_main_menu)

func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://menus/MainMenu/main_menu.tscn")
