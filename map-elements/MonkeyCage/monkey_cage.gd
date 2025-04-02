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

## Maximum distance to open
@export var open_distance: float = 150.0

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

	# Make sure collision shapes are properly configured initially
	if collision_close:
		collision_close.set_deferred("disabled", false)  # Initially enabled for closed cage
	if collision_open_left:
		collision_open_left.set_deferred("disabled", true)  # Initially disabled
	if collision_open_right:
		collision_open_right.set_deferred("disabled", true)  # Initially disabled

	# Get player node from parent scene
	player = find_player_node()

	# Spawn the monkey immediately inside the cage
	spawn_caged_monkey()

## Returns the Player node if found, otherwise returns null.
## @param root: The root node to start the search from.
## @return The Player node if found, otherwise null.
func find_player_node() -> Node:
	return get_tree().get_first_node_in_group("player")

## Process the cage opening when the player is near.
func _process(_delta: float):
	if not is_open and player and Input.is_action_just_pressed("interact"):
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

	# Add monkey as a child of MonkeyHolder
	monkey_holder.add_child(new_monkey)

	# Store reference to caged monkey for later release
	caged_monkey = new_monkey

	# Ensure monkey is marked as caged
	caged_monkey.is_caged = true

	# Remove from "troop" group if already in it
	if caged_monkey and caged_monkey.is_in_group("troop"):
		caged_monkey.remove_from_group("troop")

	print_debug("Monkey spawned inside cage at:", caged_monkey.global_position)


## Open the cage door and release the monkey inside.
func open_cage() -> void:
	# Play hinge effect
	var open_player = $OpenPlayer
	if open_player:
		open_player.play()

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

		# Show the health bar if hidden
		if caged_monkey.has_node("HealthBar"):
			caged_monkey.get_node("HealthBar").show()

		# Add monkey back to the "troop" group
		caged_monkey.add_to_group("troop")

		# set the monkey `is_caged` flag
		caged_monkey.is_caged = false

		# Immediately add to player's swarm
		if player.has_method("add_monkey_to_swarm"):
			player.add_monkey_to_swarm(caged_monkey)
		else:
			push_error("ERROR: Player does not have 'add_monkey_to_swarm' method!")

		# Clear reference since it's no longer in the cage
		caged_monkey = null
