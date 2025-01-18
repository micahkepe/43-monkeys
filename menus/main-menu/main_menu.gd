extends Control
## The main menu for the game.
##
## The main menu has "Start", "Settings", and "Quit" Button elements that can be
## navigated using the defined "ui-up" and "ui-down" mappings. The start button
## will change the scene to the first level. The quit button will exit the game
## by quiting the game tree.
##
## @tutorial: https://docs.godotengine.org/en/3.0/getting_started/step_by_step/ui_main_menu.html#prepare-the-main-menu-scene

# The AudioStreamPlayer node that plays sound effects.
@onready var sfx_player: AudioStreamPlayer = get_node("SFXPlayer")

# The background music player for the theme
@onready var theme_player: AudioStreamPlayer = get_node("BackgroundMusic")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$VBoxContainer/StartButton.grab_focus()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


## Handles the press event for the start button. Navigates to scene "tutorial".
func _on_start_button_pressed() -> void:
	theme_player.stop()
	sfx_player.play()
	get_tree().change_scene_to_file("res://cutscenes/intro-cutscene/intro_cutscene.tscn")


## Handle the press event on the settings button. Currently does nothing.
func _on_settings_button_pressed() -> void:
	sfx_player.play()
	get_tree().change_scene_to_file("res://menus/settings-menu/settings-menu.tscn")


## Handle the press event on the quit button. Quits the node tree to exit the
## game.
func _on_quit_button_pressed() -> void:
	sfx_player.play()
	get_tree().quit()
