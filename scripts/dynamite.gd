extends CharacterBody2D

const ART := preload("res://Assets/Weapon/dynamite.png")
const MOB_ART := preload("res://Assets/Weapon/Mob 3.png")
const CANNON_ART := preload("res://Assets/Weapon/projectile mob 4.png")
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
var enemy_player: Node2D
var cannonball := false
var mob_frames: Array[AtlasTexture] = []


func launch(direction: int) -> void:
	velocity = Vector2(490.0 * direction, -460.0)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 5 if cannonball else 1
	z_index = 4
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	art = Sprite2D.new()
	art.texture = ART
	art.scale = Vector2.ONE * 0.48
	if cannonball:
		art.texture = CANNON_ART
		art.scale = Vector2.ONE * 0.68
	elif is_instance_valid(enemy_player):
		for column in range(4):
			var frame := AtlasTexture.new()
			frame.atlas = MOB_ART
			frame.region = Rect2(column * 543, 0, 543, 724)
			frame.filter_clip = true
			mob_frames.append(frame)
		art.texture = mob_frames[0]
		art.scale = Vector2.ONE * 0.056
	add_child(art)


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		_explode()
		return
	velocity.y += (210.0 if cannonball else GRAVITY) * delta
	if mob_frames.is_empty():
		art.rotation += velocity.x * delta * 0.023
	else:
		art.texture = mob_frames[int(maxf(0.0, 1.05 - fuse) * 13.0) % mob_frames.size()]
	var collision := move_and_collide(velocity * delta)
	if collision:
		if cannonball:
			_explode()
		else:
			velocity = velocity.bounce(collision.get_normal()) * 0.43


func _explode() -> void:
	if is_instance_valid(enemy_player):
		enemy_player.take_blast(global_position, 85.0 if cannonball else BLAST_RADIUS)
	else:
		get_tree().call_group(&"practice_targets", &"take_blast", global_position, BLAST_RADIUS)
		get_tree().call_group(&"enemy_mobs", &"take_blast", global_position, BLAST_RADIUS)

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
