extends ProgressBar
## Health bar that can be used for enemies or players.
##
## This health bar has a damage bar that will show the damage taken by the
## player. The damage bar will be shown for a short period of time and then
## it will disappear.

## The timer that will be used to hide the damage bar
@onready var timer = $Timer

## The damage bar that will be shown when the player takes damage
@onready var damage_bar = $DamageBar

## The maximum health of the health bar
var health = 0 : set = _set_health


## Initialize the health bar
func init_health(_health):
	health = _health
	max_value = health
	value = health
	damage_bar.max_value = health
	damage_bar.value = health


## Set the health of the health bar
func _set_health(new_health):
	var prev_health = health
	health = min(max_value, new_health)
	value = health

	if health <= 0:
		queue_free()

	if health < prev_health:
		timer.start()
	else:
		damage_bar.value = health


## Handle the timer timeout signal
func _on_timer_timeout() -> void:
	damage_bar.value = health
