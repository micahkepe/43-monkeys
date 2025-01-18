extends Control

@onready var sfx_player: AudioStreamPlayer = get_node("SFXPlayer")

# Paths to scenes (update these with the actual paths in your project)
const MAIN_MENU_SCENE = "res://menus/main-menu/main-menu.tscn"

# References to nodes
var pause_menu_visible := false


func _ready():
	# Connect button signals using Callable
	$VBoxContainer/Resume.connect("pressed", Callable(self, "_on_resume_pressed"))
	$VBoxContainer/MainMenu.connect("pressed", Callable(self, "_on_main_menu_pressed"))
	$VBoxContainer/Settings.connect("pressed", Callable(self, "_on_settings_pressed"))
	$VBoxContainer/Quit.connect("pressed", Callable(self, "_on_quit_pressed"))

	# Start with pause menu hidden
	hide()


func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"): # Escape key is "ui_cancel" by default
		toggle_pause_menu()


func toggle_pause_menu() -> void:
	if pause_menu_visible:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	pause_menu_visible = true
	show()

	# Pause the game
	get_tree().paused = true

	# Focus on the resume button
	$VBoxContainer/Resume.grab_focus()


func resume_game() -> void:
	pause_menu_visible = false
	hide()
	get_tree().paused = false # Unpause the game


func _on_resume_pressed() -> void:
	sfx_player.play()
	resume_game()


func _on_main_menu_pressed() -> void:
	sfx_player.play()
	get_tree().paused = false # Ensure the game is unpaused
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_settings_pressed() -> void:
	sfx_player.play()
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	sfx_player.play()
	get_tree().quit()
