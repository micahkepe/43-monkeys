extends Control
## Default menu settings that all menus inherit.

## Called when there is an input event. The input event propagates up through
## the node tree until a node consumes it.
func _input(event):
	if event.is_action_pressed("toggle_full_screen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

