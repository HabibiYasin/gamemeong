extends Node2D

const ART := preload("res://Assets/Weapon/projectile pistol.png")
const SPEED := 1130.0
const LIFETIME := 1.25

var direction := 1
var lifetime := LIFETIME
var previous_position := Vector2.ZERO


func setup(origin: Vector2, muzzle: Vector2, shot_direction: int) -> void:
	previous_position = origin
	position = muzzle
	direction = shot_direction


func _ready() -> void:
	z_index = 4
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.scale = Vector2(0.32, 0.32)
	sprite.offset.x = -ART.get_width() * 0.5
	sprite.rotation = PI if direction < 0 else 0.0
	add_child(sprite)


func _physics_process(delta: float) -> void:
	var next_position := global_position + Vector2(direction * SPEED * delta, 0.0)
	var ray := PhysicsRayQueryParameters2D.create(previous_position, next_position, 3)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var collider: Object = hit.collider
		if collider.has_method(&"take_hit"):
			collider.take_hit(hit.position, direction)
		queue_free()
		return

	global_position = next_position
	previous_position = next_position
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
