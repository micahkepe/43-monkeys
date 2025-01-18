extends Control

@onready var sfx_player: AudioStreamPlayer = get_node("SFXPlayer")
@onready var music_player: AudioStreamPlayer = get_node("BackgroundMusic")
@onready var music_volume = $VBoxContainer/MusicVolume
@onready var sfx_volume = $VBoxContainer/SFXVolume

# Audio bus indices
const MASTER_BUS = 0
const MUSIC_BUS = 1
const SFX_BUS = 2

# Scene paths
const PAUSE_MENU_SCENE = "res://menus/pause-menu/pause-menu.tscn"
const MAIN_MENU_SCENE = "res://menus/main-menu/main-menu.tscn"

func _ready() -> void:
	# First verify the nodes exist before setting values
	if music_volume and sfx_volume:
		music_volume.value = db_to_linear(AudioServer.get_bus_volume_db(MUSIC_BUS))
		sfx_volume.value = db_to_linear(AudioServer.get_bus_volume_db(SFX_BUS))
	
	# Connect signals
	var back_button = $VBoxContainer/Back
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if music_volume:
		music_volume.value_changed.connect(_on_music_volume_changed)
	if sfx_volume:
		sfx_volume.value_changed.connect(_on_sfx_volume_changed)

func _on_back_pressed() -> void:
	if sfx_player:
		sfx_player.play()
	
	var tree = get_tree()
	if tree == null:
		return
	
	if tree.paused:
		# We came from pause menu, go back there
		var error = tree.change_scene_to_file(PAUSE_MENU_SCENE)
		if error == OK:
			# Keep the game paused during transition
			tree.paused = true
	else:
		# We came from main menu
		tree.change_scene_to_file(MAIN_MENU_SCENE)

func _on_music_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(value))
	if music_player and not music_player.playing:
		music_player.play()

func _on_sfx_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(value))
	if sfx_player:
		sfx_player.play()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_back_pressed()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_W or event.keycode == KEY_A or event.keycode == KEY_S or event.keycode == KEY_D:
			if sfx_player:
				sfx_player.play()
