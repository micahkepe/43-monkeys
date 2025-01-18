extends Area2D

func _ready():
	# Play the animation
	if $AnimationPlayer.has_animation("Forcefield"):
		$AnimationPlayer.play("Forcefield")

	# Connect collision detection
	self.connect("body_entered", Callable(self, "_on_body_entered"))
