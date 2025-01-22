extends Control

@onready var select_sfx_player: AudioStreamPlayer = get_node("SelectSFXPlayer")
@onready var music_player: AudioStreamPlayer = get_node("BackgroundMusic")
@onready var music_volume = $VBoxContainer/MusicVolume
@onready var sfx_volume = $VBoxContainer/SFXVolume

# Audio bus indices
const MASTER_BUS = 0
const MUSIC_BUS = 1
const SFX_BUS = 2

func _ready() -> void:
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

	# Set up as popup behavior
	visible = false  # Start hidden
	custom_minimum_size = Vector2(400, 300)  # Set appropriate size

func show_settings() -> void:
	# Reset position and ensure full size
	position = Vector2.ZERO
	size = get_viewport_rect().size
	# Ensure proper anchoring
	anchor_right = 1.0
	anchor_bottom = 1.0
	visible = true

func hide_settings() -> void:
	visible = false

func _on_back_pressed() -> void:
	if select_sfx_player:
		select_sfx_player.play()
	hide_settings()

func _on_music_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(value))
	if music_player and not music_player.playing:
		music_player.play()

func _on_sfx_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(value))
	if select_sfx_player:
		select_sfx_player.play()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_back_pressed()
