extends PointLight2D
## A flickering square light that casts light on to z-layers up to 1 (FG
## included). The `flicker_probability` adjusts the flicker probability
## flicker rate (higher meaning more flickering).

## The probability of the light flickering.
@export
var flicker_probability: float = 0.02

## Call on entering the scene.
func _ready() -> void:
	show()

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if randf() < flicker_probability:
		hide()
	else:
		show()

