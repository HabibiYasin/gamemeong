extends CharacterBody2D

const ART := preload("res://Assets/Weapon/dynamite.png")
const EXPLOSION := [
	preload("res://Assets/Effect/dynamite_explosion/2_1.png"),
	preload("res://Assets/Effect/dynamite_explosion/2_2.png"),
	preload("res://Assets/Effect/dynamite_explosion/2_3.png"),
	preload("res://Assets/Effect/dynamite_explosion/2_4.png"),
	preload("res://Assets/Effect/dynamite_explosion/2_5.png"),
	preload("res://Assets/Effect/dynamite_explosion/2_6.png"),
	preload("res://Assets/Effect/dynamite_explosion/2_7.png"),
	preload("res://Assets/Effect/dynamite_explosion/2_8.png"),
	preload("res://Assets/Effect/dynamite_explosion/2_9.png")
]
const BLAST_RADIUS := 118.0
const GRAVITY := 1450.0

var fuse := 1.05
var art: Sprite2D


func launch(direction: int) -> void:
	velocity = Vector2(490.0 * direction, -460.0)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	z_index = 4
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	art = Sprite2D.new()
	art.texture = ART
	art.scale = Vector2.ONE * 0.48
	add_child(art)


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		_explode()
		return
	velocity.y += GRAVITY * delta
	art.rotation += velocity.x * delta * 0.023
	var collision := move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.get_normal()) * 0.43


func _explode() -> void:
	get_tree().call_group(&"practice_targets", &"take_blast", global_position, BLAST_RADIUS)

	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 20.0)
	frames.set_animation_loop(&"default", false)
	for texture: Texture2D in EXPLOSION:
		frames.add_frame(&"default", texture)
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.position = position + Vector2(0.0, -44.0)
	effect.z_index = 5
	effect.animation_finished.connect(effect.queue_free)
	get_parent().add_child(effect)
	effect.play()
	queue_free()
