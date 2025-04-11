extends "res://menus/default_menu.gd"

## Settings for controlling credit scrolling and timing
class_name CreditsController

## Data class for individual credit contributors
class CreditPerson:
	var name: String
	var role: String
	var social_link: String = ""
	var image_path: String = ""

	func _init(p_name: String, p_role: String = "", p_social_link: String = "", p_image_path: String = ""):
		name = p_name
		role = p_role
		social_link = p_social_link
		image_path = p_image_path

## Data class for credit sections
class CreditSection:
	var title: String
	var people: Array[CreditPerson] = []
	var description: String = ""
	var section_image_path: String = ""

	func _init(p_title: String, p_description: String = "", p_section_image_path: String = ""):
		title = p_title
		description = p_description
		section_image_path = p_section_image_path

	func add_person(person: CreditPerson) -> void:
		people.append(person)

## Duration in seconds before a new section starts
@export var section_time: float = 2.0

## Time in seconds between displaying each line
@export var line_time: float = 0.3

## Base scrolling speed in pixels per second
@export var base_speed: float = 80.0

## Multiplier applied to speed when sped up
@export var speed_up_multiplier: float = 10.0

## Color for section titles
@export var title_color: Color = Color(0.7, 0.3, 0.9, 1.0)

## Regular text color
@export var text_color: Color = Color.WHITE

## Social link color
@export var link_color: Color = Color(0.4, 0.7, 1.0, 1.0)

## Background color
@export var background_color: Color = Color(0.0, 0.0, 0.0, 1.0)

## Vertical gap between credit lines
@export var vertical_spacing: float = 60.0

## Vertical gap between people in a section
@export var person_spacing: float = 80.0

## Fixed width for images
@export var image_width: float = 400

## Fixed height for images
@export var image_height: float = 400

## Margin between image and text
@export var image_margin: float = 40.0

## Font size for titles
@export var title_font_size: int = 60

## Font size for regular text
@export var text_font_size: int = 32

## Font size for social links
@export var link_font_size: int = 28

## Background panel style
@export var background_panel: StyleBox

## Image panel style
@export var image_panel: StyleBox

## Choice parameter ("good" or "evil")
@export var choice: String = "good"

## Current scrolling speed
var scroll_speed: float = base_speed

## Flag indicating if scrolling is sped up
var speed_up: bool = false

## Whether credits have begun scrolling
var started: bool = false

## Whether credits have completed
var finished: bool = false

## Current section of credits being processed
var current_section: CreditSection

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

## Y-position for the next line
var _last_y_position: float = 0.0

## Array of all credit sections
var credits_sections: Array[CreditSection] = []

## Dictionary of preloaded images mapped by path
var preloaded_images: Dictionary = {}

## Counter to distribute images throughout credits
var image_counter: int = 0

func _ready() -> void:
	# Configure background
	var bg = $Background
	if bg:
		bg.color = background_color

	# Initialize the starting position
	_last_y_position = get_viewport().size.y

	# Load the appropriate credits based on choice
	setup_credits_data()

	# Preload all images
	preload_images()

	print("Credits sections: ", credits_sections.size())

## Create and setup all credit data
func setup_credits_data() -> void:
	# Ensure we have a default choice if none is set
	if choice != "good" and choice != "evil":
		choice = "good"
		print_debug("WARNING: Invalid choice, defaulting to 'good'")

	# Clear any existing data
	credits_sections.clear()

	# Add appropriate ending section based on choice
	if choice == "good":
		var ending_section = CreditSection.new("FREEDOM",
			"You chose a life of freedom, \nfinally experiencing peace and simple pleasures.\n")
		ending_section.add_person(CreditPerson.new("No longer living in fear", "", "",
			"res://assets/exposition/end-credits/freedom/blackjack.png"))
		credits_sections.append(ending_section)
	else:
		var ending_section = CreditSection.new("POWER",
			"You chose to seize control. \nThe tables have turned, and now you run the show.")
		ending_section.add_person(CreditPerson.new("The New Order Begins", "", "",
			"res://assets/exposition/end-credits/new-evil/evil-smile.png"))
		credits_sections.append(ending_section)

	# # Create core credits sections
	# var credits_intro = CreditSection.new("A Game By Alpha Studios")
	# credits_sections.append(credits_intro)

	# Programming section with social links
	var programming = CreditSection.new("PROGRAMMING")
	programming.add_person(CreditPerson.new("Micah Kepe", "", "github.com/micahkepe"))
	programming.add_person(CreditPerson.new("Grant Thompson", "", "https://www.linkedin.com/in/grantwthompson/"))
	programming.add_person(CreditPerson.new("Kevin Lei", "", "https://www.linkedin.com/in/lei-kevin/"))
	programming.add_person(CreditPerson.new("Zach Kepe", "", "github.com/zachkepe"))
	credits_sections.append(programming)

	# Art section with image
	var art = CreditSection.new("ART")
	art.add_person(CreditPerson.new("Kevin Lei", "Lead Artist", "",
		"res://assets/exposition/end-credits/freedom/movies.png"))
	credits_sections.append(art)

	# Music section
	var music = CreditSection.new("MUSIC")
	music.add_person(CreditPerson.new("Kyle Sanderfer (Bospad)", "Composer", "https://open.spotify.com/artist/6Z9DPgoBu600ZbUbdQqZQf?si=IqUu-Tg0T9K7kVdWd1_35Q"))
	credits_sections.append(music)

	# Supervision section with image
	var supervision = CreditSection.new("SUPERVISION")
	supervision.add_person(CreditPerson.new("Professor Joe Warren", "Faculty Advisor", "cs.rice.edu/~jwarren",
		 "res://assets/exposition/end-credits/freedom/rollercoaster.png" if choice == "good" else
						   "res://assets/exposition/end-credits/new-evil/group-of-scientists.png"))
	credits_sections.append(supervision)

	# Thank you section with image
	var thanks = CreditSection.new("SPECIAL THANKS")
	thanks.add_person(CreditPerson.new("The Godot community"))
	thanks.add_person(CreditPerson.new("Our countless beta testers"))
	thanks.add_person(CreditPerson.new("You for playing!", "", "",
		 "res://assets/exposition/end-credits/new-evil/scared-monkey.png" if choice == "evil" else ""))
	credits_sections.append(thanks)

## Preload all images referenced in the credits
func preload_images() -> void:
	for section in credits_sections:
		if section.section_image_path != "":
			if not preloaded_images.has(section.section_image_path):
				preloaded_images[section.section_image_path] = load(section.section_image_path)

		for person in section.people:
			if person.image_path != "":
				if not preloaded_images.has(person.image_path):
					preloaded_images[person.image_path] = load(person.image_path)

## Updates the credits scrolling each frame
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
			if credits_sections.size() > 0:
				started = true
				current_section = credits_sections.pop_front()  # Get the next section
				_curr_line = 0
				add_section_title()  # Add section title first
	else:
		# Handle line timing within a section
		line_timer += delta * speed_up_multiplier if speed_up else delta
		if line_timer >= line_time:
			line_timer -= line_time
			add_person_line()  # Add the next person line

	# Scroll all active lines and remove those off-screen
	if lines.size() > 0:
		for l in lines:
			l.position.y -= current_scroll_speed  # Move line upward
			if l.position.y < -l.size.y - 100:  # Check if line is fully off-screen (with margin)
				lines.erase(l)
				l.queue_free()  # Free the node to avoid memory leaks
	elif started and credits_sections.size() == 0:
		finish()  # End credits when all lines are gone and credits array is empty

## Adds the section title to the credits
func add_section_title() -> void:
	# Create a horizontal container for the line
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.position = Vector2(0, _last_y_position)
	hbox.anchor_right = 1.0
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Create and configure the title label
	var title_label: Label = line.duplicate()
	title_label.text = current_section.title
	title_label.visible = true
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_font_size_override("font_size", title_font_size)
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Add drop shadow for better visibility
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))

	hbox.add_child(title_label)

	$CreditsContainer.add_child(hbox)
	lines.append(hbox)

	# Add section description if it exists
	if current_section.description != "":
		_last_y_position += vertical_spacing
		var desc_hbox: HBoxContainer = HBoxContainer.new()
		desc_hbox.position = Vector2(0, _last_y_position)
		desc_hbox.anchor_right = 1.0
		desc_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var desc_label: Label = line.duplicate()
		desc_label.text = current_section.description
		desc_label.visible = true
		desc_label.add_theme_color_override("font_color", text_color)
		desc_label.add_theme_font_size_override("font_size", text_font_size)
		desc_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		desc_hbox.add_child(desc_label)
		$CreditsContainer.add_child(desc_hbox)
		lines.append(desc_hbox)

	_last_y_position += vertical_spacing * 1.5

	# Check if we need to add people or move to next section
	section_next = current_section.people.size() == 0

## Adds a credit person line to the scene
func add_person_line() -> void:
	if current_section.people.size() > 0:
		var person: CreditPerson = current_section.people.pop_front()

		# Create a horizontal container for the line
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.position = Vector2(0, _last_y_position)
		hbox.anchor_right = 1.0
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER

		# Create the content container
		var content: VBoxContainer = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.custom_minimum_size.x = 300 # Ensure consistent width

		# Add the person's name
		var name_label: Label = line.duplicate()
		name_label.text = person.name
		name_label.visible = true
		name_label.add_theme_color_override("font_color", text_color)
		name_label.add_theme_font_size_override("font_size", text_font_size)
		name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(name_label)

		# Add the person's role if it exists
		if person.role != "":
			var role_label: Label = line.duplicate()
			role_label.text = person.role
			role_label.visible = true
			role_label.add_theme_color_override("font_color", text_color.darkened(0.2))
			role_label.add_theme_font_size_override("font_size", text_font_size - 4)
			role_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(role_label)

		# Add the person's social link if it exists
		if person.social_link != "":
			var link_label: Label = line.duplicate()
			link_label.text = person.social_link
			link_label.visible = true
			link_label.add_theme_color_override("font_color", link_color)
			link_label.add_theme_font_size_override("font_size", link_font_size)
			link_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			link_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(link_label)

		# Handle image if available
		if person.image_path != "":
			var image_texture = preloaded_images[person.image_path]

			# Create the image container
			var img_container: PanelContainer = PanelContainer.new()
			img_container.custom_minimum_size = Vector2(image_width, image_height)
			if image_panel:
				img_container.add_theme_stylebox_override("panel", image_panel)
			else:
				# Create a default panel style if none provided
				var panel_style = StyleBoxFlat.new()
				panel_style.bg_color = Color(0, 0, 0, 0.2)
				panel_style.corner_radius_top_left = 10
				panel_style.corner_radius_top_right = 10
				panel_style.corner_radius_bottom_left = 10
				panel_style.corner_radius_bottom_right = 10
				img_container.add_theme_stylebox_override("panel", panel_style)

			# Create the image
			var img: TextureRect = TextureRect.new()
			img.texture = image_texture
			img.expand = true
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size = Vector2(image_width, image_height)
			img_container.add_child(img)

			# Alternate image sides for visual interest
			var image_side = image_counter % 2 == 0
			image_counter += 1

			if image_side:
				hbox.add_child(img_container)

				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(image_margin, 0)
				hbox.add_child(spacer)

				hbox.add_child(content)
			else:
				hbox.add_child(content)

				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(image_margin, 0)
				hbox.add_child(spacer)

				hbox.add_child(img_container)

			# Images need more space
			_last_y_position += image_height + vertical_spacing
		else:
			# Center the content for text-only entries
			hbox.add_child(content)
			_last_y_position += vertical_spacing

		$CreditsContainer.add_child(hbox)
		lines.append(hbox)

		_last_y_position += person_spacing

		# Increment counter for tracking position in section
		_curr_line += 1

		# Check if we're done with this section
		section_next = current_section.people.size() == 0
	else:
		# Add extra spacing between sections
		_last_y_position += vertical_spacing * 2
		section_next = true

## Ends the credits and transitions to the main menu
func finish() -> void:
	if not finished:
		# Set the finished flag to prevent multiple calls
		finished = true
		print("== FINISHED CREDITS ==")

		# Stop processing to prevent console spam
		set_process(false)

		# Use a short timer then transition to main menu
		get_tree().create_timer(0.5).timeout.connect(func(): change_scene_to_main_menu())

## Changes scene to the main menu
func change_scene_to_main_menu() -> void:
	print("Changing to main menu")
	get_tree().change_scene_to_file("res://menus/MainMenu/main_menu.tscn")

## Handles user input for skipping or speeding up credits
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		finish()  # Skip credits and go to main menu
	if event.is_action_pressed("ui_down") and not event.is_echo():
		speed_up = true  # Speed up scrolling
	if event.is_action_released("ui_down"):
		speed_up = false  # Return to normal speed
