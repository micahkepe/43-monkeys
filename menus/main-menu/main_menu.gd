extends Control
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

## Whether this is the first time the main menu has focus. This is to prevent
## playing the navigate sound effect when the scene is first loaded.
var _is_first_focus: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$VBoxContainer/StartButton.grab_focus()

	# Allow UI to settle before tracking focus changes
	await get_tree().process_frame
	_is_first_focus = false


## Handles the press event for the start button. Navigates to scene "tutorial".
func _on_start_button_pressed() -> void:
	theme_player.stop()
	select_sfx_player.play()
	get_tree().change_scene_to_file("res://cutscenes/intro-cutscene/intro_cutscene.tscn")


## Handle the press event on the settings button. Currently does nothing.
func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://menus/settings-menu/settings-menu.tscn")
	select_sfx_player.play()


## Handle the press event on the quit button. Quits the node tree to exit the
## game.
func _on_quit_button_pressed() -> void:
	select_sfx_player.play()
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
