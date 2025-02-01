extends "res://cutscenes/cutscene.gd"
## The intro cutscene for the game. This cutscene establishes the setting and
## George's first escape from the lab.

func _ready():
	super._ready()

	# Load images directly as Textures
	var frame0_img = load("res://assets/exposition/intro/frame-0.png")
	var frame1_img = load("res://assets/exposition/intro/frame-1.png")
	var frame2_img = load("res://assets/exposition/intro/frame-2.png")
	var frame3_img = load("res://assets/exposition/intro/frame-3.png")
	var frame4_img = load("res://assets/exposition/intro/frame-4.png")
	var frame5_img = load("res://assets/exposition/intro/frame-5.png")

	# Create a properly typed array
	var frame_data: Array[CutsceneFrame] = []
	frame_data.append(create_frame(frame0_img, "South Carolina\nNovember 2024"))
	frame_data.append(create_frame(frame1_img, "Deep beneath a rural farm...\nAlpha Genesis conducts their experiments"))
	frame_data.append(create_frame(frame2_img, "Their secret research pushes ethical boundaries\nNo one knows what they're really doing to us"))
	frame_data.append(create_frame(frame3_img, "Days pass slowly in isolation\nWatching, waiting for a chance..."))
	frame_data.append(create_frame(frame4_img, "Until one day...\nA careless mistake changes everything"))
	frame_data.append(create_frame(frame5_img, "Now is our chance for freedom\nI mustn't waste it..."))

	initialize(frame_data)

