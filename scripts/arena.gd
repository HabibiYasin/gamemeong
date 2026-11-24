extends Node2D

const Mob := preload("res://scripts/mob.gd")
const DynamitePickup := preload("res://scripts/dynamite_pickup.gd")
const MENU := "res://scenes/menu.tscn"
const CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SECTOR_WIDTH := 5500
const FLOOR_Y := 615
const GATE_OFFSET := SECTOR_WIDTH - 55
const ENCOUNTER_POSITIONS := [1240, 2880, 4640]
const MOB_SPACING := 205
const MOBS_PER_TYPE_PER_GROUP := 2
const WAVES := [
	[Mob.Kind.PISTOL, Mob.Kind.KNIFE, Mob.Kind.DYNAMITE],
	[Mob.Kind.KNIFE, Mob.Kind.PISTOL, Mob.Kind.CANNON],
	[Mob.Kind.DYNAMITE, Mob.Kind.KNIFE, Mob.Kind.CANNON],
	[Mob.Kind.PISTOL, Mob.Kind.DYNAMITE, Mob.Kind.CANNON],
	[Mob.Kind.KNIFE, Mob.Kind.CANNON, Mob.Kind.PISTOL],
	[Mob.Kind.DYNAMITE, Mob.Kind.PISTOL, Mob.Kind.KNIFE],
	[Mob.Kind.CANNON, Mob.Kind.KNIFE, Mob.Kind.DYNAMITE],
	[Mob.Kind.PISTOL, Mob.Kind.CANNON, Mob.Kind.DYNAMITE],
	[Mob.Kind.KNIFE, Mob.Kind.DYNAMITE, Mob.Kind.PISTOL],
	[Mob.Kind.DYNAMITE, Mob.Kind.KNIFE, Mob.Kind.CANNON],
]
const PLATFORM_PATTERNS := [
	[Rect2(345, 503, 185, 17), Rect2(725, 549, 170, 17), Rect2(1120, 510, 200, 17)],
	[Rect2(420, 547, 150, 17), Rect2(650, 471, 178, 17), Rect2(1015, 519, 222, 17)],
	[Rect2(356, 524, 154, 17), Rect2(700, 485, 200, 17), Rect2(1045, 548, 150, 17), Rect2(1285, 486, 130, 17)],
]

@onready var area_label: Label = %AreaTitle
@onready var enemy_count: Label = %EnemyCount
@onready var health_count: Label = %HealthCount
@onready var dynamite_count: Label = %DynamiteCount
@onready var victory_panel: Panel = %Victory
@onready var game_over_overlay: ColorRect = %GameOver
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera

var sector := 0
var level_width := SECTOR_WIDTH * WAVES.size()
var remaining := 0
var cleared := 0
var wave_started := false
var finished := false
var gates: Array[CollisionShape2D] = []
var platforms: Array[Rect2] = []


func _ready() -> void:
	player.position = Vector2(sector * SECTOR_WIDTH + 147, FLOOR_Y)
	_add_terrain(Rect2(0, FLOOR_Y, level_width, 45))
	_add_terrain(Rect2(-32, -500, 32, 1220))
	_add_terrain(Rect2(level_width, -500, 32, 1220))
	for index in WAVES.size():
		var start := index * SECTOR_WIDTH
		for pattern: Rect2 in PLATFORM_PATTERNS[index % PLATFORM_PATTERNS.size()]:
			var platform := Rect2(Vector2(start + pattern.position.x * 3.3, pattern.position.y), pattern.size)
			platforms.append(platform)
			_add_terrain(platform, true)
		var gate := _add_terrain(Rect2(start + GATE_OFFSET, -500, 22, FLOOR_Y + 500))
		gates.append(gate)
	player.health_changed.connect(_update_health)
	player.dynamite_changed.connect(_update_dynamite)
	player.defeated.connect(_on_player_defeated)
	_update_health(player.health)
	_update_dynamite(player.dynamite_stock)
	_update_status()
	_update_camera()
	camera.reset_smoothing()


func _physics_process(_delta: float) -> void:
	_update_camera()
	if finished:
		return
	var distance := player.position.x - sector * SECTOR_WIDTH
	if not wave_started and distance >= 235.0:
		_spawn_wave()
	if cleared <= sector:
		return
	if sector + 1 < WAVES.size() and distance >= SECTOR_WIDTH:
		sector += 1
		wave_started = false
		_update_status()
	elif sector + 1 == WAVES.size() and player.position.x >= level_width - 30:
		finished = true
		player.set_physics_process(false)
		victory_panel.show()


func _spawn_wave() -> void:
	wave_started = true
	var wave: Array = WAVES[sector]
	var group_size := wave.size() * MOBS_PER_TYPE_PER_GROUP
	remaining = group_size * ENCOUNTER_POSITIONS.size()
	for group_index in ENCOUNTER_POSITIONS.size():
		var center: int = sector * SECTOR_WIDTH + ENCOUNTER_POSITIONS[group_index]
		var loot_index := randi_range(0, group_size - 1)
		for index in group_size:
			var mob := Mob.new()
			mob.kind = wave[(group_index + index) % wave.size()]
			mob.player = player
			mob.position = Vector2(center + (index - (group_size - 1) * 0.5) * MOB_SPACING, FLOOR_Y)
			mob.defeated.connect(_on_mob_defeated.bind(mob, index == loot_index))
			add_child(mob)
	_update_status()


func _on_mob_defeated(mob: CharacterBody2D, drops_dynamite: bool) -> void:
	if drops_dynamite:
		var pickup := DynamitePickup.new()
		pickup.player = player
		pickup.position = Vector2(mob.position.x, FLOOR_Y - 24.0)
		add_child(pickup)
	remaining -= 1
	if remaining == 0:
		cleared = sector + 1
		gates[sector].set_deferred(&"disabled", true)
		queue_redraw()
	_update_status()


func _update_status() -> void:
	area_label.text = "Pos %d dari %d" % [sector + 1, WAVES.size()]
	if not wave_started:
		enemy_count.text = "Maju ke kanan  →"
	elif remaining > 0:
		enemy_count.text = "Mob tersisa  %d" % remaining
	else:
		enemy_count.text = "Jalur terbuka  →"


func _update_camera() -> void:
	camera.position = Vector2(clampf(player.position.x + 175.0, 640.0, level_width - 640.0), 360.0)


func _update_health(remaining_health: int) -> void:
	health_count.text = "Nyawa  %d / %d" % [remaining_health, player.MAX_HEALTH]


func _update_dynamite(stock: int) -> void:
	dynamite_count.text = "Dinamit  %d / %d" % [stock, player.MAX_DYNAMITE]


func _on_player_defeated() -> void:
	if finished:
		return
	finished = true
	game_over_overlay.show()
	set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file(CHARACTER_SELECT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU)
	elif event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func _add_terrain(bounds: Rect2, one_way: bool = false) -> CollisionShape2D:
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
	return collider


func _draw() -> void:
	draw_rect(Rect2(0, FLOOR_Y, level_width, 45), Color("#624134"))
	draw_rect(Rect2(0, FLOOR_Y, level_width, 5), Color("#ecad71"))
	draw_rect(Rect2(0, FLOOR_Y + 5, level_width, 5), Color("#b6764c"))
	draw_rect(Rect2(0, FLOOR_Y + 13, level_width, 2), Color("#84583e"))
	for x: int in range(21, level_width, 101):
		draw_rect(Rect2(x, 635, 28, 2), Color("#8f6147"))
		draw_rect(Rect2(x + 42, 641, 20, 2), Color("#4a3029"))
	for platform in platforms:
		_draw_platform(platform)

	for index in WAVES.size():
		_draw_gate(index * SECTOR_WIDTH + GATE_OFFSET, index < cleared)


func _draw_gate(x: float, is_open: bool) -> void:
	var accent := Color("#e6ad65") if is_open else Color("#e27e58")
	draw_rect(Rect2(x - 9, 450, 10, 165), Color("#56352c"))
	draw_rect(Rect2(x + 24, 450, 10, 165), Color("#56352c"))
	draw_rect(Rect2(x - 12, 449, 49, 27), Color("#4a2827"))
	draw_line(Vector2(x - 7, 451), Vector2(x + 31, 451), accent, 3.0)
	if is_open:
		draw_line(Vector2(x + 3, 463), Vector2(x + 22, 463), accent, 3.0)
		draw_line(Vector2(x + 16, 457), Vector2(x + 22, 463), accent, 3.0)
		draw_line(Vector2(x + 16, 469), Vector2(x + 22, 463), accent, 3.0)
	else:
		draw_rect(Rect2(x, 335, 22, 280), Color("#7d4338"))
		for y: int in range(342, FLOOR_Y, 18):
			draw_line(Vector2(x + 3, y), Vector2(x + 19, y + 9), accent, 2.0)


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
