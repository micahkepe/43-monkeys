extends Control
## A pause menu that can be toggled to pause and resume the game.
##
## The pause menu has "Resume", "Main Menu", "Settings", and "Quit" Button
## elements. The resume button will resume the game. The main menu button will
## change the scene to the main menu. The quit button will exit the game by
## quiting the game tree.

## The AudioStreamPlayer node that plays the select sound effect.
@onready var sfx_player: AudioStreamPlayer = get_node("Sound/SelectSFXPlayer")

## The AudioStreamPlayer node that plays the navigate sound effect.
@onready var navigate_sfx_player: AudioStreamPlayer = get_node("Sound/NavigateSFXPlayer")

const SettingsScene = preload("res://menus/settings-menu/settings-menu.tscn")
@onready var settings_menu = $SettingsMenu

# Paths to scenes (update these with the actual paths in your project)
const MAIN_MENU_SCENE = "res://menus/main-menu/main-menu.tscn"

## If the pause menu is visible
var _pause_menu_visible: bool = false

## Whether this is the first time the main menu has focus. This is to prevent
## playing the navigate sound effect when the scene is first loaded.
var _is_first_focus: bool = true


## Called when the node enters the scene tree for the first time.
func _ready():
	if !settings_menu:
		# Create settings menu if it doesn't exist
		settings_menu = SettingsScene.instantiate()
		add_child(settings_menu)
	
	# Connect button signals using Callable
	$VBoxContainer/Resume.connect("pressed", Callable(self, "_on_resume_pressed"))
	$VBoxContainer/MainMenu.connect("pressed", Callable(self, "_on_main_menu_pressed"))
	$VBoxContainer/Settings.connect("pressed", Callable(self, "_on_settings_pressed"))
	$VBoxContainer/Quit.connect("pressed", Callable(self, "_on_quit_pressed"))
	hide()


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"): # Escape key is "ui_cancel" by default
		toggle_pause_menu()


func toggle_pause_menu() -> void:
	if _pause_menu_visible:
		resume_game()
	else:
		pause_game()


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


func resume_game() -> void:
	_pause_menu_visible = false
	hide()
	get_tree().paused = false # Unpause the game
	_is_first_focus = true # Reset first focus flag


func _on_resume_pressed() -> void:
	sfx_player.play()
	resume_game()


func _on_main_menu_pressed() -> void:
	sfx_player.play()
	get_tree().paused = false # Ensure the game is unpaused
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)



func _on_settings_pressed() -> void:
	sfx_player.play()
	if settings_menu:
		# Ensure settings menu is properly positioned
		settings_menu.position = Vector2.ZERO
		settings_menu.show_settings()


func _on_quit_pressed() -> void:
	sfx_player.play()
	get_tree().quit()


func _on_resume_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


func _on_main_menu_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


func _on_settings_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()


func _on_quit_focus_entered() -> void:
	if not _is_first_focus:
		navigate_sfx_player.play()
