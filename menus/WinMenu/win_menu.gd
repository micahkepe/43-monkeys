extends Control
## The win screen display for the play after defeating the final boss.
##
## Displays a message of the number of fellow monkeys that made it to this
## stage and a continue button to move to the next scene.

## Reference to the win message Label node.
@onready var win_message: Label = $WinMessage

## The number of troop monkeys that the player made it out with.
@export
var final_troop_count: int = 0

## Initialization of the scene with the troop message.
func _ready():
	if final_troop_count > 0:
		if final_troop_count == 1:
			win_message.text = "You and one other made it,\ntwo peas in a pod"
		else:
			win_message.text = "Survival of the fittest,\nyou and %d others made it" % final_troop_count
	else:
		# sole survivor
		win_message.text = "One is the loneliest number,\njust you made it this time"

## Handle the continue button press.
func _on_continue_button_pressed() -> void:
	$SelectSFXPlayer.play()
	await $SelectSFXPlayer.finished
	get_tree().change_scene_to_file("res://cutscenes/Level5/Level5PostBoss/level_5_post_boss.tscn")

