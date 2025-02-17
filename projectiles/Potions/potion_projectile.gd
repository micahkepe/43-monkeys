extends Area2D
class_name PotionProjectile

#------------------------------------------------------------------
# STATES:
#   SPIN   - The potion is fired (plays "bottle_spin")
#   SPLASH - The potion has reached max distance or hit something (plays "bottle_splash")
#   POOL   - After splash, a random pool animation is played ("pool_1" ... "pool_4")
#------------------------------------------------------------------
enum PotionState { SPIN, SPLASH, POOL }
var state: int = PotionState.SPIN

#------------------------------------------------------------------
# CONFIGURABLE VARIABLES
#------------------------------------------------------------------
# Adjusted for a constant-velocity projectile.
@export var initial_velocity: Vector2 = Vector2(0, 0)  		 # might be useless?
@export var max_distance: float = 400.0                    # Maximum travel distance before auto-splash
@export var pool_linger_time: float = 5.0                  # How long the pool lingers before deletion

# Internal variables
var traveled_distance: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var has_triggered_effect: bool = false

#------------------------------------------------------------------
# NODE REFERENCES
#------------------------------------------------------------------
@onready var animation_player: AnimatedSprite2D = $AnimatedSprite2D

# The collision zones are defined by CollisionShape2D nodes.
@onready var bottle_shape: CollisionShape2D = $BottleCollision
@onready var pool13_shape: CollisionShape2D = $Pool13Collision
@onready var pool4_shape: CollisionShape2D = $Pool4Collision

func _ready() -> void:
	# Initialize state and start the bottle_spin animation.
	state = PotionState.SPIN
	traveled_distance = 0.0
	velocity = initial_velocity
	animation_player.play("bottle_spin")
	self.scale = Vector2(1.75,1.75)

	_enable_bottle_shape()
	_disable_all_pool_shapes()

	# Connect the root Area2D's body_entered signal.
	self.connect("body_entered", Callable(self, "_on_body_entered"))
	print("PotionProjectile _ready: Fired with velocity ", velocity)

func _physics_process(delta: float) -> void:
	if state == PotionState.SPIN:
		# Move in a straight line at constant velocity.
		var displacement: Vector2 = velocity * delta
		position += displacement
		traveled_distance += displacement.length()
		# If the projectile has traveled its maximum distance, switch to splash.
		if traveled_distance >= max_distance:
			print("PotionProjectile _physics_process: Max distance reached.")
			_switch_to_splash()

#------------------------------------------------------------------
# State Transitions
#------------------------------------------------------------------
func _switch_to_splash() -> void:
	if state != PotionState.SPIN:
		return  # Already splashed or in pool state.
	state = PotionState.SPLASH
	print("PotionProjectile: Switching to SPLASH state.")
	_disable_bottle_shape()
	_disable_all_pool_shapes()

	animation_player.animation_finished.connect(_on_splash_animation_finished)

	animation_player.stop()
	animation_player.frame = 0  # Reset to the first frame
	animation_player.play("bottle_splash")
	print("PotionProjectile: Playing 'bottle_splash' animation.")

# Runs on animation finished signal
func _on_splash_animation_finished() -> void:
	print("PotionProjectile: splash animation finished. Current animation:", animation_player.animation)
	if animation_player.animation == "bottle_splash":
		_switch_to_pool()

func _switch_to_pool() -> void:
	self.scale = Vector2(3,3)
	if state != PotionState.SPLASH:
		return
	state = PotionState.POOL
	print("PotionProjectile: Switching to POOL state.")
	# Randomly choose one of the pool animations.
	var pool_anims: Array[String] = ["pool_1", "pool_2", "pool_3", "pool_4"]
	var chosen_anim: String = pool_anims[randi() % pool_anims.size()]
	print("PotionProjectile: Chosen pool animation:", chosen_anim)
	animation_player.stop()
	animation_player.play(chosen_anim)

	_disable_bottle_shape()
	# Explicitly check for each pool animation, enable specific pool shape accordingly:
	if chosen_anim == "pool_1" or chosen_anim == "pool_2" or chosen_anim == "pool_3":
		_enable_pool13_shape()
		print("PotionProjectile: Pool 1 enabled (using pool13 shape).")
	elif chosen_anim == "pool_4":
		_enable_pool4_shape()
		print("PotionProjectile: Pool 4 enabled.")
	else:
		_enable_pool13_shape()
		print("PotionProjectile: Unknown pool animation; defaulting to pool13 shape.")

	# Start a timer to remove the projectile after the pool lingers.
	var pool_timer: Timer = Timer.new()
	pool_timer.wait_time = pool_linger_time
	pool_timer.one_shot = true
	add_child(pool_timer)
	pool_timer.connect("timeout", Callable(self, "_on_pool_timeout"))
	pool_timer.start()
	print("PotionProjectile: Pool will linger for ", pool_linger_time, " seconds.")

func _on_pool_timeout() -> void:
	print("PotionProjectile: Pool timer finished, queueing free.")
	queue_free()

#------------------------------------------------------------------
# Collision Shape Enable/Disable Helpers
#------------------------------------------------------------------
func _enable_bottle_shape() -> void:
	print("ENABLE BOTTLE SHAPE")
	bottle_shape.disabled = false

func _disable_bottle_shape() -> void:
	bottle_shape.disabled = true

func _disable_all_pool_shapes() -> void:
	_disable_pool13_shape()
	_disable_pool4_shape()

func _enable_pool13_shape() -> void:
	print("ENABLE POOL13 SHAPE")
	pool13_shape.disabled = false

func _disable_pool13_shape() -> void:
	pool13_shape.disabled = true

func _enable_pool4_shape() -> void:
	print("ENABLE POOL4 SHAPE")
	pool4_shape.disabled = false

func _disable_pool4_shape() -> void:
	pool4_shape.disabled = true

#------------------------------------------------------------------
# Collision Callback (via the root Area2D signal)
#------------------------------------------------------------------
func _on_body_entered(body: Node) -> void:
	if _is_target(body):
		print("PotionProjectile: Collision detected with ", body.name)
		on_effect_body_entered(body)
		has_triggered_effect = true
		# If the projectile is still in flight, switch immediately to splash.
		if state == PotionState.SPIN:
			_switch_to_splash()

# Helper: Returns true if the body belongs to target groups.
func _is_target(body: Node) -> bool:
	return body.is_in_group("player") or body.is_in_group("troop")

#------------------------------------------------------------------
# VIRTUAL FUNCTION: Override this in potion-specific scripts.
#------------------------------------------------------------------
func on_effect_body_entered(body: Node) -> void:
	print("PotionProjectile: Default on_effect_body_entered called for ", body.name)
