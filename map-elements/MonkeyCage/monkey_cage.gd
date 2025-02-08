extends StaticBody2D
## The cage element for holding the monkeys.
##
## This element is responsible for spawning a monkey inside the cage and
## releasing it when the player interacts with it.
## The cage can only be opened when the player is within a certain distance
## from it. The cage has three collision areas: one for closing the cage, and
## two for opening it to the left or right. The cage has an animated sprite
## for opening and closing the cage door.

## Reference to the animated sprite for the cage movement.
@onready var anim_sprite = $AnimatedSprite2D

## Collision body at the base of the cage.
@onready var collision_close = $CollisionClose

## Collision body for opening the cage to the left.
@onready var collision_open_left = $CollisionOpenLeft

## Collision body for opening the cage to the right.
@onready var collision_open_right = $CollisionOpenRight

## Container for the monkeys inside the cage.
@onready var monkey_holder = $MonkeyHolder

@export var open_distance: float = 150.0  # Maximum distance to open

## The available variants of the monkeys to populate the troop.
@export var monkey_scenes: Array[PackedScene] = []

## Reference to the player
var player: Node2D

## Track if the cage is already opened
var is_open: bool = false

## Reference to the monkey inside the cage
var caged_monkey: Node2D

## Called when the node enters the scene tree for the first time.
func _ready():
	anim_sprite.play("cage_close")  # Start with closed cage
	collision_open_left.set_deferred("disabled", true)  # Initially disabled
	collision_open_right.set_deferred("disabled", true)  # Initially disabled

	# Get player node from parent scene
	player = get_parent().get_node("Player")

	# Spawn the monkey immediately inside the cage
	spawn_caged_monkey()


## Process the cage opening when the player is near.
func _process(_delta: float):
	if not is_open and player and Input.is_action_just_pressed("open_cage"):
		if global_position.distance_to(player.global_position) <= open_distance:
			open_cage()  # Only open if player is within range


## Spawns one of the available monkeys at random inside of the cage.
func spawn_caged_monkey() -> void:
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


## Open the cage door and release the monkey inside.
func open_cage() -> void:
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


## Release the monkey from the cage and add it to the player's swarm.
func release_monkey() -> void:
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
