extends Node2D

@export var ellipse_width_scale: float = 175.0
@export var ellipse_height_scale: float = 175.0
@export var swarm_rotation: float = 0.0
@export var line_thickness: float = 10.0
@export var line_color: Color = Color(1, 1, 0, 1)  # Yellow
@export var glow_thickness: float = 15.0  # Thickness of the glow
@export var glow_intensity: float = 2.0  # How strong the glow is

var line: Line2D
var glow_line: Line2D

func _ready() -> void:
	_create_lines()
	_update_ellipse()

func _create_lines() -> void:
	line = Line2D.new()
	line.width = line_thickness
	line.default_color = line_color
	add_child(line)

	glow_line = Line2D.new()
	glow_line.width = line_thickness + glow_thickness
	glow_line.default_color = Color(line_color.r, line_color.g, line_color.b, 0.5)  # Semi-transparent

	add_child(glow_line)  
	add_child(line) 

func _update_ellipse() -> void:
	var segments = 64
	var points = []

	for i in range(segments + 1):
		var angle = (i / float(segments)) * TAU
		var point = Vector2(
			ellipse_width_scale * cos(angle),
			ellipse_height_scale * sin(angle)
		).rotated(swarm_rotation)
		points.append(point)

	line.points = points 
	glow_line.points = points 
	glow_line.width = line_thickness + glow_thickness 

func _process(_delta: float) -> void:
	_update_ellipse() 
