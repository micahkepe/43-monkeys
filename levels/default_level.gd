extends Node2D
## Default level settings that all levels inherit.

## Called when there is an input event. The input event propagates up through
## the node tree until a node consumes it.
func _input(event):
	if event.is_action_pressed("toggle_full_screen"):
		# Toggle fullscreen mode
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

		# Reset all input actions to prevent "stuck" keys
		reset_input_actions()

## Helper function to release all actions that might be held down
func reset_input_actions():
	# Comprehensive list of actions from player.gd and standard UI actions
	var actions = [
		# Player movement
		"ui_right", "ui_left", "ui_up", "ui_down",
		# Swarm controls
		"rotate_swarm_clockwise", "toggle_lock",
		"translate_up", "translate_down", "translate_left", "translate_right",
		"inc_height_ellipse", "dec_height_ellipse",
		"inc_width_ellipse", "dec_width_ellipse",
		"reset_swarm",
		# Shooting
		"shoot_up", "shoot_down", "shoot_left", "shoot_right",
		# UI navigation (from menus)
		"ui_accept", "ui_cancel", "ui_select"
	]
	for action in actions:
		if Input.is_action_pressed(action):
			Input.action_release(action)
