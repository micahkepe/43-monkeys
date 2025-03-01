extends "res://menus/default_menu.gd"
## The menu that appears when the player dies
##
## The died menu has "Restart", "Main Menu", and "Quit" Button elements that can
## be navigated using the defined "ui-up" and "ui-down" mappings.
## The restart button will change the scene to the first level.
## The main menu button will change the screen the main menu.
## The quit button will exit the game by quiting the game tree.

## The AudioStreamPlayer node that plays the select sound effect.
@onready var sfx_player: AudioStreamPlayer = get_node("Sound/SelectSFXPlayer")

## The AudioStreamPlayer node that plays the navigate sound effect.
@onready var navigate_sfx_player: AudioStreamPlayer = get_node("Sound/NavigateSFXPlayer")

## The path to the main menu scene.
const MAIN_MENU_SCENE = "res://menus/MainMenu/main_menu.tscn"

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect button signals
	var restart_button = $VBoxContainer/RestartButton
	var main_menu_button = $VBoxContainer/MainMenuButton
	var quit_button = $VBoxContainer/QuitButton
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

## Handle the press event on the restart button. Changes the scene to the
## first level.
func _on_restart_pressed() -> void:
	var tree = get_tree()
	if tree == null:
		return
	tree.change_scene_to_file("res://levels/Level1/level_1.tscn")

## Handle the press event on the main menu button. Changes the scene to the
## main menu.
func _on_main_menu_pressed() -> void:
	print("Main Menu Pressed")
	if sfx_player:
		sfx_player.play()
	var tree = get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(MAIN_MENU_SCENE)

## Handle the press event on the quit button. Quits the node tree to exit the
## game.
func _on_quit_pressed() -> void:
	if sfx_player:
		sfx_player.play()
	var tree = get_tree()
	if tree == null:
		return
	tree.quit()
