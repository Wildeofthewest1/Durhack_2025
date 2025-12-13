extends RefCounted
class_name InterceptMath

# Returns a unit direction vector from shooter_pos that will intercept a target moving at constant velocity,
# given projectile_speed is the projectile's speed RELATIVE to the shooter/muzzle.
#
# Bullet model assumed by this solver:
#   bullet_world_velocity = aim_dir * projectile_speed + shooter_vel
#
static func get_intercept_direction(
	shooter_pos: Vector2,
	shooter_vel: Vector2,
	target_pos: Vector2,
	target_vel: Vector2,
	projectile_speed: float
) -> Vector2:
	var r := target_pos - shooter_pos              # relative position
	if r.length_squared() < 0.000001:
		return Vector2.RIGHT                        # arbitrary; already overlapping

	# Work in shooter-relative frame:
	# target moves at v = (target_vel - shooter_vel), projectile has speed s (relative to shooter)
	var v := target_vel - shooter_vel
	var s := projectile_speed

	if s <= 0.001:
		return r.normalized()

	var a := v.dot(v) - s * s
	var b := 2.0 * r.dot(v)
	var c := r.dot(r)

	# If a is ~0, equation becomes linear: b t + c = 0
	if abs(a) < 0.0001:
		if abs(b) < 0.0001:
			return r.normalized()                   # target not moving relative to shooter (or too close to resolve)
		var t_lin := -c / b
		if t_lin > 0.0:
			return (r + v * t_lin).normalized()
		return r.normalized()

	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return r.normalized()                       # no real intercept (projectile too slow in this frame)

	var sqrt_disc := sqrt(disc)
	var inv_2a := 1.0 / (2.0 * a)

	var t1 := (-b - sqrt_disc) * inv_2a
	var t2 := (-b + sqrt_disc) * inv_2a

	# Choose smallest positive time
	var t := INF
	if t1 > 0.0:
		t = t1
	if t2 > 0.0 and t2 < t:
		t = t2

	if t == INF:
		return r.normalized()

	return (r + v * t).normalized()
