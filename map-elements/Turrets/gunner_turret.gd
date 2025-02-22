extends CharacterBody2D
## The Gunner Turret is a stationary enemy that shoots at the player.
##
## The turret will detect the player within a certain radius and shoot at them.

# -- Shooting & detection properties
@export var detect_radius := 600.0
@onready var animated_sprite := $AnimatedSprite2D
@onready var taser_scene := preload("res://projectiles/TaserProjectile/taser_projectile.tscn")
@onready var health_bar := $HealthBar

# -- Health properties (hits required to kill)
@export var hits_to_kill: int = 3
var is_dead: bool = false
var death_animation_complete: bool = false  # Tracks if the death animation has already finished

# -- Turret state variables
var current_direction: String = "right"
var can_shoot: bool = true
var shoot_timer: Timer

func _ready() -> void:
	# Set up shooting timer
	shoot_timer = Timer.new()
	shoot_timer.one_shot = true
	shoot_timer.wait_time = 1.0
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)

	animated_sprite.play("idle_right")

	health_bar.value = hits_to_kill
	health_bar.max_value = hits_to_kill

	# Connect the turret's hitbox signals
	if has_node("HitBox"):
		$HitBox.connect("area_entered", Callable(self, "_on_hit_box_area_entered"))
		$HitBox.connect("body_entered", Callable(self, "_on_hit_box_body_entered"))

	# Connect the animation_finished signal so we can switch from "die" to "idle_die"
	animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)


func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	var targets = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("troop")
	var closest_target: Node2D = null
	var closest_distance := INF

	# Find the closest target within detect_radius
	for target in targets:
		var distance = global_position.distance_to(target.global_position)
		if distance < detect_radius and distance < closest_distance:
			closest_target = target
			closest_distance = distance

	if closest_target and can_shoot:
		shoot_at_target(closest_target)

func shoot_at_target(target: Node2D) -> void:
	if is_dead:
		return

	var shoot_direction = global_position.direction_to(target.global_position)
	var angle = shoot_direction.angle()
	var deg_angle = rad_to_deg(angle)
	var new_direction: String

	if deg_angle >= -45 and deg_angle < 45:
		new_direction = "right"
	elif deg_angle >= 45 and deg_angle < 135:
		new_direction = "down"
	elif deg_angle >= -135 and deg_angle < -45:
		new_direction = "up"
	else:
		new_direction = "left"

	if new_direction != current_direction:
		current_direction = new_direction
		animated_sprite.play("shoot_" + current_direction)
	else:
		animated_sprite.play("shoot_" + current_direction)

	var taser = taser_scene.instantiate()
	taser.global_position = global_position
	taser.velocity = shoot_direction * taser.speed
	taser.set_meta("owner", self)  # Tag the taser with its owner
	get_tree().current_scene.add_child(taser)

	can_shoot = false
	shoot_timer.start()

	await animated_sprite.animation_finished
	if is_dead:
		return
	animated_sprite.play("idle_" + current_direction)

func _on_shoot_timer_timeout() -> void:
	can_shoot = true

# -------------------
# Damage & Health Logic
# -------------------
func take_damage(amount: float) -> void:
	if is_dead:
		return

	print_debug("Turret taking damage:", amount, " | Hits left:", hits_to_kill)

	if hits_to_kill > 0:
		if amount > 1:
			hits_to_kill -= int(amount)
		else:
			hits_to_kill -= 1

		health_bar.value = hits_to_kill


		print_debug("Hits to kill: ", hits_to_kill)

		# Kill off the turret if it has no more hits left
		if hits_to_kill <= 0:
			_die()

		# Momentarily recolor the turret to indicate damage
		animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.5).timeout
		animated_sprite.modulate = Color(1, 1, 1, 1)


## Handles when the gunner is dead.
func _die() -> void:
	is_dead = true
	death_animation_complete = false  # Reset death animation state

	# Disable physics and processing
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0

	health_bar.hide()

	# Disable the hitbox to prevent further interactions
	if is_instance_valid($HitBox):
		$HitBox.set_deferred("monitoring", false)
		$HitBox.set_deferred("monitorable", false)

	print_debug("Turret died", self)

	if $BoomPlayer:
		$BoomPlayer.play()

	# Ensure the "die" animation does not loop so it can finish
	animated_sprite.sprite_frames.set_animation_loop("die", false)
	animated_sprite.play("die")

# -------------------
# Collision Handling
# -------------------

## Handles the hit detection for the turret.
func _handle_hit(hit: Node) -> void:
	if hit.is_in_group("projectiles") and hit.get_meta("owner", null) != self:
		take_damage(1.0)
		hit.queue_free()

## Handles the area_entered signal for the HitBox.
func _on_hit_box_area_entered(area: Area2D) -> void:
	_handle_hit(area)

## Handles the body_entered signal for the HitBox.
func _on_hit_box_body_entered(body: Node) -> void:
	_handle_hit(body)

## Handles the animation_finished signal for the AnimatedSprite2D.
func _on_animated_sprite_2d_animation_finished() -> void:
	# When the "die" animation finishes, switch to "idle_die" (and then stop the animation)
	if animated_sprite.animation == "die" and not death_animation_complete:
		death_animation_complete = true
		animated_sprite.play("idle_die")
		animated_sprite.stop()

		# NOTE: change z-index to 0
		# while the turret is alive,it lives on z-index 1 (same as player),
		# when it dies, it should be behind the player (now just a crater)
		z_index = 0
