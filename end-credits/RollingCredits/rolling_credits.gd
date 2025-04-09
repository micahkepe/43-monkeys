extends Node2D

const section_time := 2.0
const line_time := 0.3
const base_speed := 100
const speed_up_multiplier := 10.0
const title_color := Color.BLUE_VIOLET
const vertical_spacing := 20.0
const image_width := 50.0
const image_margin := 20.0

var scroll_speed := base_speed
var speed_up := false

var started := false
var finished := false

var section
var section_next := true
var section_timer := 0.0
var line_timer := 0.0
var curr_line := 0
var lines := []
@onready var line = $CreditsContainer/Line
var total_line := -1
var last_y_position := 0.0
var image_index := 0

var credits = [
	["A game by Awesome Game Company"],
	["Programming", "Programmer Name", "Programmer Name 2"],
	["Art", "Artist Name"],
	["Music", "Musician Name"],
	["Sound Effects", "SFX Name"],
	["Testers", "Name 1", "Name 2", "Name 3"],
	["Tools used", "Developed with Godot Engine", "https://godotengine.org/license", "", "Art created with My Favourite Art Program", "https://myfavouriteartprogram.com"],
	["Special thanks", "My parents", "My friends", "My pet rabbit"]
]

var img_blackjack = preload("res://assets/exposition/end-credits/freedom/blackjack.png")
var img_movies = preload("res://assets/exposition/end-credits/freedom/movies.png")
var img_rollercoaster = preload("res://assets/exposition/end-credits/freedom/rollercoaster.png")

var credits_images = [
	{"line": 1, "texture": img_blackjack},
	{"line": 3, "texture": img_movies},
	{"line": 5, "texture": img_rollercoaster}
]

func _ready():
	last_y_position = get_viewport().size.y
	print("== READY ==")

func _process(delta):
	var current_scroll_speed = base_speed * delta
	if speed_up:
		current_scroll_speed *= speed_up_multiplier

	if section_next:
		section_timer += (delta * speed_up_multiplier) if speed_up else delta
		if section_timer >= section_time:
			section_timer -= section_time
			if credits.size() > 0:
				started = true
				section = credits.pop_front()
				curr_line = 0
				add_line()
	else:
		line_timer += (delta * speed_up_multiplier) if speed_up else delta
		if line_timer >= line_time:
			line_timer -= line_time
			add_line()

	if lines.size() > 0:
		for l in lines:
			l.position.y -= current_scroll_speed
			if l.position.y < -l.size.y:
				lines.erase(l)
				l.queue_free()
	elif started:
		finish()

func finish():
	if not finished:
		finished = true
		print("== FINISHED CREDITS ==")
		# get_tree().change_scene("res://scenes/MainMenu.tscn")

func add_line():
	total_line += 1
	if section.size() > 0:
		var text = section.pop_front()

		var hbox = HBoxContainer.new()
		hbox.position = Vector2(0, last_y_position)
		hbox.anchor_right = 1.0
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var has_image = false
		var image_side = image_index % 2 == 0  # true = left, false = right
		var image_texture = null

		for img in credits_images:
			if img["line"] == total_line:
				image_texture = img["texture"]
				has_image = true
				image_index += 1
				break

		# Image node
		var image_node = TextureRect.new()
		image_node.texture = image_texture
		image_node.stretch_mode = TextureRect.STRETCH_SCALE
		image_node.size = Vector2(image_width, image_width)
		image_node.custom_minimum_size = image_node.size
		image_node.visible = has_image

		# Text label
		var label = line.duplicate()
		label.text = text
		if curr_line == 0:
			label.add_theme_color_override("font_color", title_color)
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# Add in proper order for left/right alignment
		if has_image:
			if image_side:
				hbox.add_child(image_node)
				hbox.add_child(label)
			else:
				hbox.add_child(label)
				hbox.add_child(image_node)
		else:
			hbox.add_child(label)

		$CreditsContainer.add_child(hbox)
		lines.append(hbox)

		# Positioning
		var height = max(label.size.y, image_node.size.y)
		last_y_position += height + vertical_spacing
		curr_line += 1
		section_next = section.size() == 0
	else:
		last_y_position += vertical_spacing * 2
		section_next = true

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		finish()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		speed_up = true
	if event.is_action_released("ui_down"):
		speed_up = false
