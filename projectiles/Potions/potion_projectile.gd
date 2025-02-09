extends Area2D
class_name PotionProjectile

#------------------------------------------------------------------
# STATES:
#  SPIN   - The potion is thrown (playing "bottle_spin")
#  SPLASH - The potion has hit something or reached max distance (playing "potion_splash")
#  POOL   - After splash, a random pool animation is played ("pool_1" ... "pool_4")
#------------------------------------------------------------------
enum PotionState { SPIN, SPLASH, POOL }
var state: int = PotionState.SPIN

#------------------------------------------------------------------
# CONFIGURABLE VARIABLES
#------------------------------------------------------------------
@export var initial_velocity: Vector2 = Vector2(600, -800)  # Initial throw velocity
@export var potion_gravity: float = 1500.0                    # Gravity (for arc?)
@export var max_distance: float = 800.0                       # Maximum distance before auto-splash
@export var pool_linger_time: float = 5.0                     # Time the pool lingers before deletion

# Internal variables
var traveled_distance: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var has_triggered_effect: bool = false

#------------------------------------------------------------------
# NODE REFERENCES (make sure your potion scene has these nodes with these names)
#------------------------------------------------------------------
@onready var animation_player: AnimatedSprite2D = $AnimatedSprite2D

# Collision areas:
# • BottleCollision is active during SPIN and SPLASH.
# • Pool1Collision, Pool2Collision, Pool3Collision, and Pool4Collision are for the pool state.
@onready var bottle_collision: Area2D = $BottleCollision
@onready var pool1_collision: Area2D = $Pool1Collision
@onready var pool2_collision: Area2D = $Pool2Collision
@onready var pool3_collision: Area2D = $Pool3Collision
@onready var pool4_collision: Area2D = $Pool4Collision

#------------------------------------------------------------------
# _ready(): Initialize state, start the bottle_spin animation,
#          and set up collision signals.
#------------------------------------------------------------------
func _ready() -> void:
	state = PotionState.SPIN
	traveled_distance = 0.0
	velocity = initial_velocity
	animation_player.play("bottle_spin")
	
	# In SPIN (and SPLASH) state, enable only the bottle collision.
	_enable_bottle_collision()
	_disable_all_pool_collisions()
	
	# Connect collision signals using Callable.
	bottle_collision.connect("body_entered", Callable(self, "_on_body_entered"))
	pool1_collision.connect("body_entered", Callable(self, "_on_body_entered"))
	pool2_collision.connect("body_entered", Callable(self, "_on_body_entered"))
	pool3_collision.connect("body_entered", Callable(self, "_on_body_entered"))
	pool4_collision.connect("body_entered", Callable(self, "_on_body_entered"))

#------------------------------------------------------------------
# _physics_process(): Update the projectile’s position and apply gravity.
#                      When max_distance is reached, switch to splash.
#------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if state == PotionState.SPIN:
		# Apply gravity to vertical velocity.
		velocity.y += potion_gravity * delta
		var displacement: Vector2 = velocity * delta
		position += displacement
		traveled_distance += displacement.length()
		
		# If maximum travel distance is reached, switch to splash.
		if traveled_distance >= max_distance:
			_switch_to_splash()

#------------------------------------------------------------------
# State Transition: Switch to SPLASH state.
#------------------------------------------------------------------
func _switch_to_splash() -> void:
	if state != PotionState.SPIN:
		return  # Already splashed or in pool state
	state = PotionState.SPLASH
	_disable_bottle_collision()  # In splash, disable bottle collision.
	_disable_all_pool_collisions()
	animation_player.play("potion_splash")
	# When the splash animation finishes, switch to pool.
	animation_player.connect("animation_finished", Callable(self, "_on_splash_animation_finished"), CONNECT_ONE_SHOT)

func _on_splash_animation_finished(anim_name: String) -> void:
	if anim_name == "potion_splash":
		_switch_to_pool()

#------------------------------------------------------------------
# State Transition: Switch to POOL state.
#------------------------------------------------------------------
func _switch_to_pool() -> void:
	if state != PotionState.SPLASH:
		return
	state = PotionState.POOL
	# Randomly select one of the pool animations.
	var pool_anims: Array[String] = ["pool_1", "pool_2", "pool_3", "pool_4"]
	var chosen_anim: String = pool_anims[randi() % pool_anims.size()]
	animation_player.play(chosen_anim)
	
	# In the POOL state, disable the bottle collision and enable the corresponding pool collision.
	_disable_bottle_collision()
	match chosen_anim:
		"pool_1":
			_enable_pool1_collision()
		"pool_2":
			_enable_pool2_collision()
		"pool_3":
			_enable_pool3_collision()
		"pool_4":
			_enable_pool4_collision()
	
	# Start a timer so that the pool lingers before deletion.
	var pool_timer: Timer = Timer.new()
	pool_timer.wait_time = pool_linger_time
	pool_timer.one_shot = true
	add_child(pool_timer)
	pool_timer.connect("timeout", Callable(self, "_on_pool_timeout"))
	pool_timer.start()

func _on_pool_timeout() -> void:
	queue_free()

#------------------------------------------------------------------
# Collision Enable/Disable Helper Functions
#------------------------------------------------------------------
func _enable_bottle_collision() -> void:
	bottle_collision.monitoring = true

func _disable_bottle_collision() -> void:
	bottle_collision.monitoring = false

func _disable_all_pool_collisions() -> void:
	_disable_pool1_collision()
	_disable_pool2_collision()
	_disable_pool3_collision()
	_disable_pool4_collision()

func _enable_pool1_collision() -> void:
	pool1_collision.monitoring = true
func _disable_pool1_collision() -> void:
	pool1_collision.monitoring = false

func _enable_pool2_collision() -> void:
	pool2_collision.monitoring = true
func _disable_pool2_collision() -> void:
	pool2_collision.monitoring = false

func _enable_pool3_collision() -> void:
	pool3_collision.monitoring = true
func _disable_pool3_collision() -> void:
	pool3_collision.monitoring = false

func _enable_pool4_collision() -> void:
	pool4_collision.monitoring = true
func _disable_pool4_collision() -> void:
	pool4_collision.monitoring = false

#------------------------------------------------------------------
# Collision Callback: Called when any connected collision area detects a body.
#------------------------------------------------------------------
func _on_body_entered(body: Node) -> void:
	if _is_target(body):
		on_effect_body_entered(body)
		has_triggered_effect = true
		# If the potion is still in flight, switch immediately to splash.
		if state == PotionState.SPIN:
			_switch_to_splash()

# Helper to determine if the body is a target.
func _is_target(body: Node) -> bool:
	return body.is_in_group("player") or body.is_in_group("monkey")

#------------------------------------------------------------------
# VIRTUAL FUNCTION: Override this in your potion-specific scripts to apply custom effects.
#------------------------------------------------------------------
func on_effect_body_entered(body: Node) -> void:
	print("Potion projectile hit ", body.name)
