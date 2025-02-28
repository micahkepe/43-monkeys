extends CharacterBody2D

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar = $HealthBar
@onready var grow_shrink_sound: AudioStreamPlayer = $Sound/GrowAndShrinkPlayer
@onready var spawn_sound: AudioStreamPlayer = $Sound/SpawnPlayer
@onready var attack_sound: AudioStreamPlayer = $Sound/AttackPlayer

@export var max_health: float = 200.0
var current_health: float

@export var min_attack_interval: float = 0.0
@export var max_attack_interval: float = 1.0
@export var min_wait_time: float = 5.0
@export var max_wait_time: float = 10.0
@export var boid_plant_scene: PackedScene

var last_animation: String = "idle_down"
var is_attacking: bool = false
var is_dead: bool = false
var is_teleporting: bool = false
var attack_timer: Timer
var spawn_timer: Timer

var grow_animations := {
	"up": "grow_up",
	"down": "grow_down",
	"left": "grow_left",
	"right": "grow_right"
}

var shrink_animations := {
	"up": "shrink_up",
	"down": "shrink_down",
	"left": "shrink_left",
	"right": "shrink_right"
}

var attacks = [
	{
		"name": "attack",
		"function": Callable(self, "attack"),
		"weight": 3,
		"unlocked": true
	}
]

func _ready() -> void:
	current_health = max_health
	health_bar.init_health(current_health)
	
	if $HitBox:
		print("HitBox found and signals connected")
		$HitBox.connect("area_entered", Callable(self, "_on_hit_box_area_entered"))
		$HitBox.connect("body_entered", Callable(self, "_on_hit_box_body_entered"))
	
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.connect("timeout", Callable(self, "_choose_and_execute_attack"))
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 10.0
	spawn_timer.autostart = true
	add_child(spawn_timer)
	spawn_timer.connect("timeout", Callable(self, "_spawn_boid_plants"))
	
	_animated_sprite.connect("animation_finished", Callable(self, "_on_animated_sprite_2d_animation_finished"))
	
	teleport_cycle()
	_start_random_attack_timer()

func teleport_cycle() -> void:
	while not is_dead:
		if is_attacking:
			await get_tree().create_timer(0.1).timeout
			continue
		
		is_teleporting = true
		var new_target = choose_random_waypoint()
		var direction = (new_target - global_position).normalized()
		var animation_direction = get_direction_string(direction)
		
		# Play shrink sound
		if grow_shrink_sound:
			grow_shrink_sound.play()
		play_animation(shrink_animations[animation_direction])
		await _animated_sprite.animation_finished
		
		global_position = new_target
		# Play grow sound
		if grow_shrink_sound:
			grow_shrink_sound.play()
		play_animation(grow_animations[animation_direction])
		await _animated_sprite.animation_finished
		
		is_teleporting = false
		play_idle_animation()
		var wait_time = randf_range(min_wait_time, max_wait_time)
		await get_tree().create_timer(wait_time).timeout

func choose_random_waypoint() -> Vector2:
	var min_x = -2094 + 50
	var max_x = -903 - 50
	var min_y = -498 + 50
	var max_y = 731 - 50
	return Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))

func _spawn_boid_plants() -> void:
	if is_dead or not boid_plant_scene:
		print("Cannot spawn boid plants: dead or scene not set!")
		return
	
	var player = find_player_node(get_tree().root)
	if not player:
		print("No player found for boid plant spawning!")
		return
	
	# Play spawn sound
	if spawn_sound:
		spawn_sound.play()
	
	var player_pos = player.global_position
	var spawn_positions = []
	var attempts = 0
	var max_attempts = 10
	
	while spawn_positions.size() < 3 and attempts < max_attempts:
		var pos = choose_random_waypoint()
		var too_close_to_player = pos.distance_to(player_pos) < 100.0
		var too_close_to_existing = spawn_positions.any(func(p): return p.distance_to(pos) < 50.0)
		
		if not too_close_to_player and not too_close_to_existing:
			spawn_positions.append(pos)
		attempts += 1
	
	for pos in spawn_positions:
		var boid_plant = boid_plant_scene.instantiate()
		boid_plant.global_position = pos
		var parent_node = get_parent()
		if parent_node:
			parent_node.add_child(boid_plant)
		else:
			get_tree().root.add_child(boid_plant)
		print("Spawned boid plant at: ", pos)

func get_direction_string(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "left" if direction.x < 0 else "right"
	return "up" if direction.y < 0 else "down"

func play_animation(anim_name: String) -> void:
	if is_dead:
		print("Animation blocked: dead")
		return
	
	if is_teleporting and not (anim_name.begins_with("shrink") or anim_name.begins_with("grow")):
		return
	if is_attacking and not anim_name.begins_with("attack"):
		return
	
	print("Playing animation: ", anim_name)
	_animated_sprite.play(anim_name)
	last_animation = anim_name

func play_idle_animation() -> void:
	if is_dead or is_attacking or is_teleporting:
		return
	
	var direction = "down"
	if "down" in last_animation:
		direction = "down"
	elif "up" in last_animation:
		direction = "up"
	elif "left" in last_animation:
		direction = "left"
	elif "right" in last_animation:
		direction = "right"
	
	play_animation("idle_" + direction)

func attack() -> void:
	if is_dead or is_teleporting:
		print("Attack blocked: dead=", is_dead, " teleporting=", is_teleporting)
		return
	
	is_attacking = true
	attack_timer.stop()
	
	var player = find_player_node(get_tree().root)
	if player:
		var direction_to_player = (player.global_position - global_position).normalized()
		var animation_direction = get_direction_string(direction_to_player)
		var attack_anim = "attack_" + animation_direction
		print("Attempting to play attack animation: ", attack_anim)
		
		# Play attack sound
		if attack_sound:
			attack_sound.play()
		
		play_animation(attack_anim)
		
		await _animated_sprite.animation_finished
		
		var attack_radius = 100.0
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= attack_radius:
			player.take_damage(1.0)
			print("RootBoss dealt damage to player!")
	else:
		print("No player found for attack")
	
	is_attacking = false
	print("Attack finished")
	_start_random_attack_timer()

func _choose_and_execute_attack() -> void:
	if is_dead or is_attacking or is_teleporting:
		print("Attack execution blocked: dead=", is_dead, " attacking=", is_attacking, " teleporting=", is_teleporting)
		_start_random_attack_timer()
		return
	
	attack_timer.stop()
	var available_attacks = attacks.filter(func(attack): return attack.unlocked)
	if available_attacks.is_empty():
		print("No available attacks")
		_start_random_attack_timer()
		return
	
	var total_weight = available_attacks.reduce(func(acc, attack): return acc + attack.weight, 0.0)
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	
	for attack in available_attacks:
		cumulative_weight += attack.weight
		if random_value <= cumulative_weight:
			print("Executing attack: ", attack.name)
			attack.function.call()
			break

func _start_random_attack_timer() -> void:
	if is_dead or is_attacking:
		return
	
	var wait_time = randf_range(min_attack_interval, max_attack_interval)
	attack_timer.wait_time = wait_time
	attack_timer.start()

func _on_animated_sprite_2d_animation_finished() -> void:
	print("Animation finished: ", _animated_sprite.animation)
	if _animated_sprite.animation == "die":
		_animated_sprite.stop()
		queue_free()
	elif _animated_sprite.animation.begins_with("attack"):
		is_attacking = false
		print("Attack animation completed, switching to idle")
		play_idle_animation()

func take_damage(amount: float) -> void:
	if is_dead:
		return
	print("RootBoss took ", amount, " damage!")
	current_health -= amount
	health_bar.value = current_health

	if current_health <= 0:
		_die()
	else:
		_animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.5).timeout
		_animated_sprite.modulate = Color(1, 1, 1, 1)

func _die() -> void:
	is_dead = true
	health_bar.hide()
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	attack_timer.stop()
	spawn_timer.stop()
	is_attacking = false
	is_teleporting = false
	
	if is_instance_valid($HitBox):
		$HitBox.set_deferred("monitoring", false)
		$HitBox.set_deferred("monitorable", false)
	
	_animated_sprite.play("die")

func find_player_node(root: Node) -> Node:
	if root.name == "Player":
		return root
	for child in root.get_children():
		var result = find_player_node(child)
		if result:
			return result
	return null

func find_node_recursive(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var result = find_node_recursive(child, target)
		if result:
			return result
	return null

func _physics_process(_delta: float) -> void:
	if not is_dead:
		move_and_slide()

func _on_hit_box_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	print("RootBoss HitBox entered by area: ", area)
	if "BananaBoomerang" in str(area):
		take_damage(1.0)
	else:
		print("Area not a BananaBoomerang!")

func _on_hit_box_body_entered(body: Node2D) -> void:
	print("RootBoss HitBox entered by body: ", body)
	if is_dead or not is_attacking:
		return
	if body.name == "Player" or body.is_in_group("troop"):
		body.take_damage(1.0)
		print("RootBoss dealt damage to player via HitBox!")
