extends "res://cutscenes/cutscene.gd"

## Called when the node enters the scene tree.
func _ready():
	super._ready()

	# Load images directly as Textures
	var frame_data: Array[CutsceneFrame] = [
		create_frame(load("res://assets/exposition/level5/post-fight/capture.png"), "I was brought here as a child,\n alone and scared..."),
		create_frame(load("res://assets/exposition/level5/post-fight/experimenting.png"), "All those years, all those tests..."),
		create_frame(load("res://assets/exposition/level5/post-fight/open-door.png"), "My freedom could be right out that door...\n A fresh start, a brand new life."),
		create_frame(load("res://assets/exposition/level5/post-fight/eyepatch.png"), "Or I can become the master of my prison..."),
	]

	initialize(frame_data)
