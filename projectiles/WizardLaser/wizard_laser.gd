extends Area2D

@export var duration: float = 3.0          # Seconds the electricity persists for

@export var damage_interval: float = 1.0  # Time in seconds between damage ticks
var damage_timer: float = 0.0
@export var damage: float = 0.25

@export var start_enemy: Node = null         # Enemy where this segment starts
@export var target_enemy: Node = null        # Enemy where this segment ends

var elapsed_time: float = 0.0

@export var base_width: float = 64.0         # Original width of the laser sprite

func _ready() -> void:
	$AnimatedSprite2D.play("LaserMove")
	print("LASER SCEN READY==")
	
	if start_enemy == null or target_enemy == null:
		if start_enemy != null:
			target_enemy = find_target(start_enemy)
		if target_enemy == null:
			print("===wizard_laser: start_enemy or target_enemy not set!===")
			queue_free()
			return
	update_laser_visual()

func _process(delta: float) -> void:
	# If either enemy dies, remove this chain
	if not is_instance_valid(start_enemy) or not is_instance_valid(target_enemy):
		queue_free()
		return
	
	update_laser_visual()
	
	damage_timer += delta
	if damage_timer >= damage_interval:
		damage_timer = 0
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(damage)
		if start_enemy.has_method("take_damage"):
			start_enemy.take_damage(damage)
	
	elapsed_time += delta
	if elapsed_time >= duration:
		queue_free()

func update_laser_visual() -> void:
	global_position = Vector2(start_enemy.global_position.x, start_enemy.global_position.y + 40)

	# Compute the vector from start_enemy to target_enemy.
	var diff: Vector2 = target_enemy.global_position - start_enemy.global_position

	# Rotate this node so that its local +X axis points toward target_enemy.
	rotation = diff.angle()

	# Scale the AnimatedSprite2D node along X so that its right end touches target_enemy.
	scale.x = diff.length() / base_width
	scale.y = 3
	
	
func find_target(from_enemy: Node) -> Node:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest: Node = null
	var closest_distance: float = 10000.0
	for enemy in enemies:
		if enemy == from_enemy:
			continue
		var dist = from_enemy.global_position.distance_to(enemy.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest = enemy
	return closest
