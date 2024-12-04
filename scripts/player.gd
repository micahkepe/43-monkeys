extends CharacterBody2D

@onready var _animated_sprite = $AnimatedSprite2D

var speed: float = 200.0

# TODO: dynamically set these from the viewport size
var bounds_min = Vector2(-1024, -1024)  # Top-left corner of the allowed area
var bounds_max = Vector2(1024, 1024)  # Bottom-right corner of the allowed area


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var velocity = Vector2.ZERO
	
	# Movement input
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
		_animated_sprite.play("walk_right")
	elif Input.is_action_pressed("ui_left"):
		velocity.x -= 1
		_animated_sprite.play("walk_left")
	elif Input.is_action_pressed("ui_up"):
		velocity.y -= 1
		_animated_sprite.play("walk_up")
	elif Input.is_action_pressed("ui_down"):
		velocity.y += 1
		_animated_sprite.play("walk_down")
	else:
		_animated_sprite.stop()
	
	# Normalize diagonal movement
	if velocity != Vector2.ZERO:
			velocity = velocity.normalized()
	
	# Apply movement
	position += velocity * speed * delta

	# Clamp position to bounds
	position = position.clamp(bounds_min, bounds_max)
