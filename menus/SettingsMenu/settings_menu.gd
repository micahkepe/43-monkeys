extends "res://menus/default_menu.gd"
## A settings menu that can be toggled to show and hide the settings.
##
## The settings menu has "Music Volume", "SFX Volume", and "Back" Button
## elements.

## The AudioStreamPlayer node that plays the select sound effect.
@onready var select_sfx_player: AudioStreamPlayer = get_node("SelectSFXPlayer")

## The AudioStreamPlayer node that plays the background music.
@onready var music_player: AudioStreamPlayer = get_node("BackgroundMusic")

## The HSlider node that controls the music volume.
@onready var music_volume = $VBoxContainer/MusicVolume

## The HSlider node that controls the sfx volume.
@onready var sfx_volume = $VBoxContainer2/SFXVolume

## The master bus index.
const MASTER_BUS = 0

## The music bus index.
const MUSIC_BUS = 1

## The SFX bus index.
const SFX_BUS = 2

## Slider control constants
const SLIDER_STEP = 0.1  # Amount to change when using keys

## Initialize the necessary variables for the script.
func _ready() -> void:
	if music_volume and sfx_volume:
		# Initialize slider values
		music_volume.value = db_to_linear(AudioServer.get_bus_volume_db(MUSIC_BUS))
		sfx_volume.value = db_to_linear(AudioServer.get_bus_volume_db(SFX_BUS))

		# Set up keyboard focus handling
		music_volume.focus_mode = Control.FOCUS_ALL
		sfx_volume.focus_mode = Control.FOCUS_ALL

	# Set up as popup behavior
	visible = false
	custom_minimum_size = Vector2(400, 300)


## Handle A and D to change the volume sliders on focus.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_pressed():
		var focused_slider = get_viewport().gui_get_focus_owner()
		if focused_slider is HSlider:
			if event.is_action_pressed("ui_left"):
				focused_slider.value -= SLIDER_STEP
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_right"):
				focused_slider.value += SLIDER_STEP
				get_viewport().set_input_as_handled()

## Show the settings menu.
func show_settings() -> void:
	visible = true

	# Set initial focus to music slider
	if music_volume:
		music_volume.grab_focus()

## Hide the settings menu.
func hide_settings() -> void:
	visible = false

## Hide settings when the Back button is pressed.
func _on_back_pressed() -> void:
	if select_sfx_player:
		select_sfx_player.play()
	await select_sfx_player.finished
	hide_settings()

## Change music volume when the slider changes.
func _on_music_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(value))
	if music_player and not music_player.playing:
		music_player.play()

## Change sfx volume when the slider changes.
func _on_sfx_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(value))

