extends Node2D

const ART := preload("res://Assets/Weapon/projectile pistol.png")
const SPEED := 1130.0
const LIFETIME := 1.25

var direction := Vector2.RIGHT
var lifetime := LIFETIME
var previous_position := Vector2.ZERO
var hostile := false
var shooter: Node2D
var firing_position := Vector2.INF
var size_scale := 1.0
var speed_scale := 1.0


func setup(origin: Vector2, muzzle: Vector2, shot_direction: Vector2, range_scale: float = 1.0) -> void:
	previous_position = origin
	position = muzzle
	direction = shot_direction
	lifetime = LIFETIME * range_scale


func _ready() -> void:
	z_index = 4
	if hostile:
		add_to_group(&"enemy_projectiles")
		if is_instance_valid(shooter):
			firing_position = shooter.global_position
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.scale = Vector2.ONE * (0.32 * size_scale)
	sprite.offset.x = -ART.get_width() * 0.5
	sprite.rotation = direction.angle()
	add_child(sprite)


func _physics_process(delta: float) -> void:
	var travel_time := minf(delta * speed_scale, lifetime)
	var next_position := global_position + direction * SPEED * travel_time
	var space := get_world_2d().direct_space_state
	var mask := 5 if hostile else 11
	var hit := {}
	if previous_position != global_position:
		hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(previous_position, global_position, mask))
	if hit.is_empty():
		hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, next_position, mask))
	if not hit.is_empty():
		var collider: Object = hit.collider
		var impact_direction := 1 if direction.x > 0.0 else -1
		if hostile and collider.has_method(&"take_projectile_hit"):
			var attacker_position := shooter.global_position if is_instance_valid(shooter) else firing_position
			collider.take_projectile_hit(hit.position, impact_direction, attacker_position)
		elif collider.has_method(&"take_hit"):
			collider.take_hit(hit.position, impact_direction)
		queue_free()
		return

	global_position = next_position
	previous_position = next_position
	lifetime -= travel_time
	if lifetime <= 0.0:
		queue_free()
