extends "res://cutscenes/cutscene.gd"

func _ready():
	super._ready()

	# Load images directly as Textures
	var frame_data: Array[CutsceneFrame] = [
		create_frame(load("res://assets/exposition/intro/frame-0.png"), "South Carolina\nNovember 2024"),
		create_frame(load("res://assets/exposition/intro/frame-1.png"), "Deep beneath a rural farm...\nAlpha Genesis conducts their experiments"),
		create_frame(load("res://assets/exposition/intro/frame-2.png"), "Their secret research pushes ethical boundaries\nNo one knows what they're really doing to us"),
		create_frame(load("res://assets/exposition/intro/frame-3.png"), "Days pass slowly in isolation\nWatching, waiting for a chance..."),
		create_frame(load("res://assets/exposition/intro/frame-4.png"), "Until one day...\nA careless mistake changes everything"),
		create_frame(load("res://assets/exposition/intro/frame-5.png"), "Now is our chance for freedom\nI mustn't waste it...")
	]

	initialize(frame_data)

