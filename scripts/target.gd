extends StaticBody2D

signal struck

const CAN := Rect2(-17, -78, 34, 44)
const RESPAWN_TIME := 1.35
const SPARK_VELOCITIES := [
	Vector2(140, -135),
	Vector2(205, -74),
	Vector2(216, -14),
	Vector2(129, 52),
	Vector2(80, -110),
	Vector2(-102, -70),
	Vector2(-84, 32)
]

var respawn_remaining := 0.0
var impact := Vector2.ZERO
var shot_direction := 1


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = CAN.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = CAN.get_center()
	add_child(collider)
	set_process(false)


func take_hit(hit_position: Vector2, direction: int) -> void:
	if respawn_remaining > 0.0:
		return
	impact = to_local(hit_position)
	shot_direction = direction
	respawn_remaining = RESPAWN_TIME
	set_deferred(&"collision_layer", 0)
	set_process(true)
	struck.emit()
	queue_redraw()


func _process(delta: float) -> void:
	respawn_remaining = maxf(respawn_remaining - delta, 0.0)
	if respawn_remaining <= 0.0:
		collision_layer = 2
		set_process(false)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-10, -33, 20, 33), Color("#57352c"))
	draw_rect(Rect2(-6, -33, 4, 33), Color("#9c6644"))
	draw_rect(Rect2(-25, -38, 50, 8), Color("#472a25"))
	draw_rect(Rect2(-25, -38, 50, 3), Color("#d39662"))
	if respawn_remaining <= 0.0:
		_draw_can()
	else:
		_draw_impact()


func _draw_can() -> void:
	draw_rect(CAN.grow(2), Color("#3d2930"))
	draw_rect(CAN, Color("#bd4a3f"))
	draw_rect(Rect2(-16, -73, 5, 31), Color("#ef7d59"))
	draw_rect(Rect2(11, -73, 5, 31), Color("#923435"))
	draw_rect(Rect2(-17, -77, 34, 5), Color("#ffce8d"))
	draw_rect(Rect2(-17, -40, 34, 5), Color("#e6a66c"))
	draw_circle(Vector2(0, -56), 10, Color("#ffe4b1"), true, -1.0, true)
	draw_circle(Vector2(0, -56), 6, Color("#872e2a"), true, -1.0, true)
	draw_circle(Vector2(0, -56), 2.5, Color("#ffe4b1"), true, -1.0, true)


func _draw_impact() -> void:
	var elapsed := RESPAWN_TIME - respawn_remaining
	if elapsed > 0.34:
		return
	var alpha := 1.0 - elapsed / 0.34
	for spark: Vector2 in SPARK_VELOCITIES:
		var velocity := Vector2(spark.x * shot_direction, spark.y)
		var tip := impact + velocity * elapsed + Vector2(0.0, 240.0 * elapsed * elapsed)
		var tail := tip - velocity * 0.028
		draw_line(tail, tip, Color(1.0, 0.76, 0.36, alpha), 3.0, true)
	draw_circle(impact, 5.0 + 32.0 * elapsed, Color(1.0, 0.88, 0.61, alpha), false, 2.0, true)
