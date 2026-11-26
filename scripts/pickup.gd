extends Node2D

const DYNAMITE_ART := preload("res://Assets/Weapon/dynamite.png")
const HEART_ART := preload("res://Assets/Effect/Heart/Heart full.png")
const PICKUP_RADIUS := 43.0

enum Kind { NONE, DYNAMITE, HEALTH }

var kind := Kind.DYNAMITE
var player: CharacterBody2D
var sprite: Sprite2D
var elapsed := 0.0


func _ready() -> void:
	z_index = 1
	sprite = Sprite2D.new()
	sprite.texture = HEART_ART if kind == Kind.HEALTH else DYNAMITE_ART
	var scale_factor := 40.0 / HEART_ART.get_height() if kind == Kind.HEALTH else 0.57
	sprite.scale = Vector2.ONE * scale_factor
	add_child(sprite)


func _process(delta: float) -> void:
	elapsed += delta
	sprite.position.y = sin(elapsed * 4.0) * 4.0


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var player_center := player.global_position + Vector2(0, -44)
	if global_position.distance_squared_to(player_center) > PICKUP_RADIUS * PICKUP_RADIUS:
		return
	var collected: bool = player.restore_health() if kind == Kind.HEALTH else player.refill_dynamite()
	if collected:
		queue_free()


func _draw() -> void:
	if kind == Kind.HEALTH:
		draw_circle(Vector2.ZERO, 27, Color("#4b212a"), true, -1.0, true)
		draw_circle(Vector2.ZERO, 27, Color("#f5a39f"), false, 2.5, true)
	else:
		draw_circle(Vector2.ZERO, 27, Color(0.32, 0.15, 0.11, 0.88), true, -1.0, true)
		draw_circle(Vector2.ZERO, 27, Color("#ffd282"), false, 2.5, true)
