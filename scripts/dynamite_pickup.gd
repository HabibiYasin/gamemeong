extends Node2D

const ART := preload("res://Assets/Weapon/dynamite.png")
const PICKUP_RADIUS := 43.0

var player: CharacterBody2D
var sprite := Sprite2D.new()
var elapsed := 0.0


func _ready() -> void:
	z_index = 1
	sprite.texture = ART
	sprite.scale = Vector2.ONE * 0.57
	add_child(sprite)


func _process(delta: float) -> void:
	elapsed += delta
	sprite.position.y = sin(elapsed * 4.0) * 4.0


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var player_center := player.global_position + Vector2(0, -44)
	if global_position.distance_squared_to(player_center) <= PICKUP_RADIUS * PICKUP_RADIUS:
		if player.refill_dynamite():
			queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 27, Color(0.32, 0.15, 0.11, 0.88), true, -1.0, true)
	draw_circle(Vector2.ZERO, 27, Color("#ffd282"), false, 2.5, true)
