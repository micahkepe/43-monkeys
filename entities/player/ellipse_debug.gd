extends Node2D

@export var ellipse_width_scale: float = 175.0
@export var ellipse_height_scale: float = 175.0
@export var swarm_rotation: float = 0.0
@export var line_thickness: float = 10.0
@export var line_color: Color = Color(1, 1, 0, 1)  # Yellow

func _ready():
	# Ensure the node has a material assigned
	if material and material is ShaderMaterial:
		print("======RAHHAHAH")
		# Set the 'glow_color' parameter to yellow
		material.set_shader_parameter("glow_color", line_color)
	else:
		print("ShaderMaterial not found on this node.")

func _draw() -> void:
	var segments = 64
	var points = []

	for i in range(segments + 1):
		var angle = (i / float(segments)) * TAU
		var point = Vector2(ellipse_width_scale * cos(angle), ellipse_height_scale * sin(angle)).rotated(swarm_rotation)
		points.append(point)

	draw_polyline(points, line_color, line_thickness)
