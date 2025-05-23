extends "res://menus/default_menu.gd"
## A pause menu that can be toggled to pause and resume the game.
##
## The pause menu has "Resume", "Main Menu", "Settings", and "Quit" Button
## elements. The resume button will resume the game. The main menu button will
## change the scene to the main menu. The quit button will exit the game by
## quiting the game tree.

## The AudioStreamPlayer node that plays the select sound effect.
@onready var select_sfx_player: AudioStreamPlayer = get_node("Sound/SelectSFXPlayer")

## The AudioStreamPlayer node that plays the navigate sound effect.
@onready var navigate_sfx_player: AudioStreamPlayer = get_node("Sound/NavigateSFXPlayer")

## The setting scene loaded from the settings-menu.tscn file.
const SettingsScene = preload("res://menus/SettingsMenu/settings_menu.tscn")
@onready var settings_menu = null

# Paths to scenes (update these with the actual paths in your project)
const MAIN_MENU_SCENE = "res://menus/MainMenu/main_menu.tscn"

## If the pause menu is visible
var _pause_menu_visible: bool = false

## Whether this is the first time the main menu has focus. This is to prevent
## playing the navigate sound effect when the scene is first loaded.
var _is_first_focus: bool = true

## Whether the game should remain in a paused state. This patches certain
## instances where you need control over the game paused state.
@export
var bg_remain_paused: bool = false

## Called when the node enters the scene tree for the first time.
func _ready():
	if !settings_menu:
		# Create settings menu if it doesn't exist
		settings_menu = SettingsScene.instantiate()
		add_child(settings_menu)
	hide()

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"): # Escape key is "ui_cancel" by default
		toggle_pause_menu()

## Called when the user presses 'esc'. If the user is in the pause menu, then 'esc' closes the
## pause scene; otherwise, it opens.
func toggle_pause_menu() -> void:
	if _pause_menu_visible:
		resume_game()
	else:
		pause_game()

## Show the pause menu.
func pause_game() -> void:
	_pause_menu_visible = true
	show()

	# Pause the game
	get_tree().paused = true

	# Focus on the resume button
	$VBoxContainer/Resume.grab_focus()

	# Allow UI to settle before tracking focus changes
	await get_tree().process_frame
	_is_first_focus = false


## Close the pause menu and resume the game.
func resume_game() -> void:
	_pause_menu_visible = false
	hide()
	if !bg_remain_paused:
		get_tree().paused = false # Unpause the game
	_is_first_focus = true # Reset first focus flag


## If the resume button is pressed, resume the game.
func _on_resume_pressed() -> void:
	select_sfx_player.play()
	await select_sfx_player.finished
	resume_game()


## Take the user to the main menu if they press the Main Menu button.
func _on_main_menu_pressed() -> void:
	select_sfx_player.play()
	await select_sfx_player.finished
	get_tree().paused = false # Ensure the game is unpaused
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Open the settings menu if the Settings button is pressed.
func _on_settings_pressed() -> void:
	select_sfx_player.play()
	await select_sfx_player.finished
	if settings_menu:
		# Ensure settings menu is properly positioned
		settings_menu.position = Vector2.ZERO
		settings_menu.show_settings()


## Quit the game if the Quit button is pressed.
func _on_quit_pressed() -> void:
	select_sfx_player.play()
	await select_sfx_player.finished
	get_tree().quit()


## Play a sound on focus for the Resume button.
func _on_resume_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


## Play a sound on focus for the Main Menu button.
func _on_main_menu_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


## Play a sound on focus for the Settings button.
func _on_settings_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


## Play a sound on focus for the Quit button.
func _on_quit_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()
