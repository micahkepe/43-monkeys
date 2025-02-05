
extends StaticBody2D

@onready var anim_sprite = $AnimatedSprite2D
@onready var collision_close = $CollisionClose
@onready var collision_open_left = $CollisionOpenLeft
@onready var collision_open_right = $CollisionOpenRight
@onready var monkey_holder = $MonkeyHolder  # This node holds the monkey

@export var open_distance: float = 150.0  # Maximum distance to open

## The available variants of the monkeys to populate the troop.
@export var monkey_scenes: Array[PackedScene] = []

var player: Node2D  # Reference to the player
var is_open: bool = false  # Track if the cage is already opened
var caged_monkey: Node2D  # Reference to the monkey inside

func _ready():
	anim_sprite.play("cage_close")  # Start with closed cage
	collision_open_left.set_deferred("disabled", true)  # Initially disabled
	collision_open_right.set_deferred("disabled", true)  # Initially disabled

	# Get player node from parent scene
	player = get_parent().get_node("Player")

	# Spawn the monkey immediately inside the cage
	spawn_caged_monkey()

func _process(delta):
	if not is_open and player and Input.is_action_just_pressed("open_cage"):
		if global_position.distance_to(player.global_position) <= open_distance:
			open_cage()  # Only open if player is within range

func spawn_caged_monkey():
	if monkey_scenes.is_empty():
		print("No monkey scenes available!")
		return

	var new_monkey_scene = monkey_scenes[randi() % monkey_scenes.size()]
	var new_monkey = new_monkey_scene.instantiate()

	# Set global position correctly
	new_monkey.position = Vector2(0, -5)

	# Set global scale correctly
	var desired_global_scale = Vector2(1.87125, 1.87125)
	new_monkey.scale = desired_global_scale / monkey_holder.global_scale

	# Add monkey as a child of MonkeyHolder
	monkey_holder.add_child(new_monkey)

	# Store reference to caged monkey for later release
	caged_monkey = new_monkey

	print("Monkey spawned inside the cage with correct global scale!")
	print("Monkey spawned inside cage at:", caged_monkey.global_position)


func open_cage():
	is_open = true  # Mark cage as opened
	anim_sprite.play("cage_close_to_open")  # Play opening animation

	# Wait for the animation to finish before proceeding
	await anim_sprite.animation_finished

	# Open collisions after animation
	collision_close.set_deferred("disabled", true)  # Disable closed collision
	collision_open_left.set_deferred("disabled", false)  # Enable left opening
	collision_open_right.set_deferred("disabled", false)  # Enable right opening

	# Release the monkey from the cage
	release_monkey()


func release_monkey():
	if caged_monkey and player:
		# Enable movement again
		caged_monkey.set_physics_process(true)

		# Immediately add to player's swarm
		if player.has_method("add_monkey_to_swarm"):
			player.add_monkey_to_swarm(caged_monkey)
		else:
			print("ERROR: Player does not have 'add_monkey_to_swarm' method!")

		# Clear reference since it's no longer in the cage
		caged_monkey = null
