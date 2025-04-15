extends Sprite2D

@onready var _beam: Light2D = $Beam

@export
var beam_speed_degs: float = 360.0

func _process(delta: float) -> void:
	# rotate the beam about
	_beam.rotation_degrees += beam_speed_degs * delta
