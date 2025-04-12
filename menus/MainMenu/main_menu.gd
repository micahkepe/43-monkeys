extends "res://menus/default_menu.gd"
## The main menu for the game.
##
## The main menu has "Start", "Settings", and "Quit" Button elements that can be
## navigated using the defined "ui-up" and "ui-down" mappings. The start button
## will change the scene to the first level. The quit button will exit the game
## by quiting the game tree.

## The AudioStreamPlayer node that plays the select sound effect.
@onready var select_sfx_player: AudioStreamPlayer = get_node("Sound/SelectSFXPlayer")

## The AudioStreamPlayer node that plays the select sound effect.
@onready var navigate_sfx_player: AudioStreamPlayer = get_node("Sound/NavigateSFXPlayer")

## The background music player for the theme
@onready var theme_player: AudioStreamPlayer = get_node("Sound/BackgroundMusic")

const SettingsScene = preload("res://menus/SettingsMenu/settings_menu.tscn")
@onready var settings_menu = null

## ItchIo social icon button
@onready var itch_io_icon = get_node("SocialsContainer/ItchIoButton")

## Github social icon button
@onready var github_icon = get_node("SocialsContainer/GithubButton")

## Whether this is the first time the main menu has focus. This is to prevent
## playing the navigate sound effect when the scene is first loaded.
var _is_first_focus: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().root.ready

	if !settings_menu:
		# Create settings menu if it doesn't exist
		settings_menu = SettingsScene.instantiate()
		add_child(settings_menu)
	$VBoxContainer/StartButton.grab_focus()
	await get_tree().process_frame
	_is_first_focus = false

func _input(event):
	if event.is_action_pressed("ui_accept") and visible:
		select_sfx_player.play()
		await select_sfx_player.finished
		var focused_node = get_viewport().gui_get_focus_owner()
		if focused_node == $VBoxContainer/StartButton:
			theme_player.stop()
			get_tree().change_scene_to_file("res://cutscenes/Intro/intro_cutscene.tscn")
		elif focused_node == $VBoxContainer/SettingsButton:
			if settings_menu:
				settings_menu.show_settings()
		elif focused_node == $VBoxContainer/QuitButton:
			get_tree().quit()

	# Call parent _input for fullscreen toggle
	super._input(event)

## Handles the press event for the start button. Navigates to scene "tutorial".
func _on_start_button_pressed() -> void:
	theme_player.stop()
	get_tree().change_scene_to_file("res://cutscenes/Intro/intro_cutscene.tscn")


## Handle the press event on the settings button. Currently does nothing.
func _on_settings_button_pressed() -> void:
	if settings_menu:
		settings_menu.show_settings()


## Handle the press event on the quit button. Quits the node tree to exit the
## game.
func _on_quit_button_pressed() -> void:
	get_tree().quit()


## Handle the focus entered event for the start button. Plays the navigate sound.
func _on_start_button_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


## Handle the focus entered event for the settings button. Plays the navigate
## sound.
func _on_settings_button_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


## Handle the focus entered event for the quit button. Plays the navigate sound.
func _on_quit_button_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


## Handle clicking the Github social icon. Opens the Github page for the game.
func _on_github_button_pressed() -> void:
	OS.shell_open("https://github.com/micahkepe/43-monkeys")


## Handle clicking the ItchIo social icon. Opens the ItchIo page for the game.
func _on_itch_io_button_pressed() -> void:
	OS.shell_open("https://alpha-prime-studios.itch.io/")
