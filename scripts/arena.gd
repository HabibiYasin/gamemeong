extends Node2D

const Target := preload("res://scripts/target.gd")
const MENU := "res://scenes/menu.tscn"
const GROUND := Rect2(0, 615, 1280, 45)
const PLATFORMS := [
	Rect2(340, 508, 200, 17),
	Rect2(650, 554, 164, 17),
	Rect2(850, 464, 160, 17),
	Rect2(1050, 527, 150, 17)
]

@onready var hit_count: Label = %HitCount

var hits := 0


func _ready() -> void:
	_add_terrain(GROUND)
	_add_terrain(Rect2(-32, 0, 32, 720))
	_add_terrain(Rect2(1280, 0, 32, 720))
	for platform: Rect2 in PLATFORMS:
		_add_terrain(platform, true)
	_add_target(Vector2(480, PLATFORMS[0].position.y))
	_add_target(Vector2(598, GROUND.position.y))
	_add_target(Vector2(962, PLATFORMS[2].position.y))
	_add_target(Vector2(1145, PLATFORMS[3].position.y))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU)
	elif event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func _add_terrain(bounds: Rect2, one_way: bool = false) -> void:
	var terrain := StaticBody2D.new()
	terrain.position = bounds.get_center()
	terrain.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.one_way_collision = one_way
	terrain.add_child(collider)
	add_child(terrain)


func _add_target(at: Vector2) -> void:
	var target := Target.new()
	target.position = at
	target.struck.connect(_on_target_struck)
	add_child(target)


func _on_target_struck() -> void:
	hits += 1
	hit_count.text = str(hits)


func _draw() -> void:
	draw_rect(GROUND, Color("#624134"))
	draw_rect(Rect2(0, 615, 1280, 5), Color("#ecad71"))
	draw_rect(Rect2(0, 620, 1280, 5), Color("#b6764c"))
	draw_rect(Rect2(0, 628, 1280, 2), Color("#84583e"))
	for x: int in range(21, 1280, 101):
		draw_rect(Rect2(x, 635, 28, 2), Color("#8f6147"))
		draw_rect(Rect2(x + 42, 641, 20, 2), Color("#4a3029"))

	for platform: Rect2 in PLATFORMS:
		_draw_platform(platform)


func _draw_platform(bounds: Rect2) -> void:
	var top := bounds.position
	draw_rect(bounds.grow(2.0), Color("#4c3029"))
	draw_rect(bounds, Color("#9b5b3a"))
	draw_rect(Rect2(top, Vector2(bounds.size.x, 4)), Color("#f5be82"))
	draw_rect(Rect2(top + Vector2(0, 11), Vector2(bounds.size.x, 2)), Color("#75442e"))
	for offset: float in [10.0, bounds.size.x - 10.0]:
		draw_circle(top + Vector2(offset, 9), 2.0, Color("#3e2926"), true, -1.0, true)
	for offset: float in [20.0, bounds.size.x - 27.0]:
		draw_rect(Rect2(top + Vector2(offset, 17.0), Vector2(7.0, 8.0)), Color("#5f3b31"))
