extends CanvasLayer

@export var hole_radius: float = 100.0
@export var smoothness: float = 20.0

var duration: float = 0.0

func _ready() -> void:
	$Timer.timeout.connect(Callable(self, "_on_Timer_timeout"))
	set_process(true)

func find_player_node() -> Node:
	return get_tree().get_first_node_in_group("player")

func start(_duration: float) -> void:
	print("=====STARTING!! WITH DURATION ", _duration)
	duration = _duration
	$Timer.wait_time = duration
	$Timer.start()

## Called every frame.
func _process(_delta: float) -> void:
	# Find the player somewhere in the scene tree.
	var player = find_player_node()

	if player:
		print("PLAYER FOUND")
		var camera = get_viewport().get_camera_2d()
		if camera:
			# Get the viewport size (visible area in pixels).
			var viewport_size = get_viewport().get_visible_rect().size
			var screen_center = viewport_size / 2.0

			# Calculate the player's offset from the camera center.
			var player_offset = (player.global_position - camera.global_position) * camera.zoom

			# Compute the player's screen position.
			var screen_pos = screen_center + player_offset

			# Update the shader parameters on the ColorRect's material.
			$ColorRect.material.set_shader_parameter("circle_center", screen_pos)
			$ColorRect.material.set_shader_parameter("hole_radius", hole_radius)
			$ColorRect.material.set_shader_parameter("smoothness", smoothness)

func _on_Timer_timeout() -> void:
	print("====TIMEOUT")
	queue_free()
