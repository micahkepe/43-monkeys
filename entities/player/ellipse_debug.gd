# EllipseDebug.gd
extends Node2D

# These variables will be updated from the player.
var ellipse_width_scale: float = 175.0
var ellipse_height_scale: float = 175.0
var swarm_rotation: float = 0.0

func _draw() -> void:
	# Compute the major (red) and minor (blue) axes.
	var major_axis = Vector2(ellipse_width_scale, 0).rotated(swarm_rotation)
	var minor_axis = Vector2(0, ellipse_height_scale).rotated(swarm_rotation)
	
	# Draw the major axis in red.
	draw_line(-major_axis, major_axis, Color(1, 0, 0), 2)
	# Draw the minor axis in blue.
	draw_line(-minor_axis, minor_axis, Color(0, 0, 1), 2)

# Optional: a helper function to force a redraw.
func refresh() -> void:
	queue_redraw()
