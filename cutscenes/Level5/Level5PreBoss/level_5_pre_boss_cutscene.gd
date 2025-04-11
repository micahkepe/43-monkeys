extends "res://cutscenes/cutscene.gd"

## Called when the node enters the scene tree.
func _ready():
	super._ready()

	# Load images directly as Textures
	var frame_data: Array[CutsceneFrame] = [
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "Wait... No. It can't be.\nDr.Simian... you're one of us?"),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "You really expected some human\npulling the strings?"),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "No, George. The real mind behind\nall this was always a monkey."),
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "You... did this?\nTo your own kind?"),
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "How could you experiment on us?\nYou betrayed your species!"),
		
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "I didn't betray us\nI liberated us!"),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "We were just animals, waiting for\nhumans to capture and exploit us."),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "I made us more.\nThe humans will fear us!"),
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "You're just as evil as the humans.\nYou made us prisoners."),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "Prisoners today,\ngods tomorrow."),
		create_frame(load("res://assets/exposition/side-profiles/evil_monkey_speaking.png"), "My experiments give us purpose,\npower, evolution!"),
		create_frame(load("res://assets/exposition/side-profiles/george_speaking.png"), "No.\nDr.Simian, this ends now.")
	]
	
	

	initialize(frame_data)
