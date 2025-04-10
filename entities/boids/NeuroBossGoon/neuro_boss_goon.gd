extends "res://entities/boids/projectile_boid.gd"

func _ready() -> void:
	health = 8.0
	max_health = 8.0
	
	_anim_sprite.play("idle")
	
	super._ready()
