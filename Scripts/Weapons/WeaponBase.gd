extends Node2D
class_name WeaponBase

@export var fire_cooldown: float = 0.15   # seconds between shots
var _cooldown_timer: float = 0.0

func _process(delta: float) -> void:
	# cooldown tick
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer < 0.0:
			_cooldown_timer = 0.0

# returns true if we are allowed to fire right now
func can_fire() -> bool:
	return _cooldown_timer <= 0.0

# call after a successful shot
func start_cooldown() -> void:
	_cooldown_timer = fire_cooldown

# generic fire entry point
# dir is the direction we want to shoot in (normalized Vector2)
func try_fire(dir: Vector2) -> void:
	if can_fire() == false:
		return
	_fire_projectile(dir)
	start_cooldown()

# override this in child (WeaponPistol, etc.)
func _fire_projectile(dir: Vector2) -> void:
	pass
