# EllipseDebug.gd
extends Node2D

# These variables will be updated from the player.
@export var ellipse_width_scale: float = 175.0
@export var ellipse_height_scale: float = 175.0
@export var swarm_rotation: float = 0.0

# Exported variables for line appearance
@export var line_thickness: float = 8.0  # Increased thickness
@export var line_color: Color = Color(0, 1, 0)  # Default green

func _draw() -> void:
	# Number of segments to approximate the ellipse
	var segments = 64
	var points = []
	
	for i in range(segments + 1):
		var angle = (i / float(segments)) * TAU
		# Calculate the point on the ellipse and rotate by swarm_rotation
		var point = Vector2(ellipse_width_scale * cos(angle), ellipse_height_scale * sin(angle)).rotated(swarm_rotation)
		points.append(point)
	
	# Draw the ellipse outline with the exported color and thickness
	draw_polyline(points, line_color, line_thickness)

func refresh() -> void:
	queue_redraw()
