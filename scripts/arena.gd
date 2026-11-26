extends Node2D

const Mob := preload("res://scripts/mob.gd")
const Pickup := preload("res://scripts/pickup.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
const FULL_HEART := preload("res://Assets/Effect/Heart/Heart full.png")
const EMPTY_HEART := preload("res://Assets/Effect/Heart/Hearth empty.png")
const FULL_DYNAMITE := preload("res://Assets/Weapon/dynamite.png")
const EMPTY_DYNAMITE := preload("res://Assets/Weapon/dynamite empty.png")
const MENU := "res://scenes/menu.tscn"
const CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SHOP_BACKGROUND := 1
const BOSS_BACKGROUND := 3
const COMBAT_BACKGROUNDS: Array[int] = [2, 4]
const STAGE_COUNT := 10
const STARTING_LIVES := 3
const SHOP_STAGES := [5, 9]
const COMBAT_WIDTH := 3900
const SHOP_WIDTH := 1280
const FLOOR_Y := 615
const WAVE_COUNT := 3
const WAVE_PROMPT_DURATION := 1.0
const SPAWN_DISTANCE := 710.0
const MOB_SPACING := 155.0
const SPAWN_JITTER := 48.0
const ALL_MOBS := [Mob.Kind.PISTOL, Mob.Kind.KNIFE, Mob.Kind.DYNAMITE, Mob.Kind.CANNON]

@onready var area_label: Label = %AreaTitle
@onready var enemy_count: Label = %EnemyCount
@onready var wave_banner: Label = %WaveBanner
@onready var health_hearts: HBoxContainer = %HealthHearts
@onready var life_portrait: TextureRect = %LifePortrait
@onready var life_count: Label = %LifeCount
@onready var dynamite_icons: HBoxContainer = %DynamiteIcons
@onready var victory_panel: Panel = %Victory
@onready var game_over_overlay: ColorRect = %GameOver
@onready var upgrade_choice: ColorRect = %UpgradeChoice
@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/Player
@onready var camera: Camera2D = $Camera
@onready var stage_background: Node2D = $StageBackground

var stage_number := 1
var medium_mode := false
var first_combat_background := -1
var spare_lives := STARTING_LIVES - 1
var level_width := COMBAT_WIDTH
var pending_mobs: Array[Mob.Kind] = []
var wave_number := 0
var wave_remaining := 0
var wave_intro_remaining := 0.0
var choosing_upgrade := false
var remaining: int:
	get:
		return pending_mobs.size() + wave_remaining
var finished := false
var gate: CollisionShape2D
var platforms: Array[Rect2] = []


func _ready() -> void:
	medium_mode = get_tree().get_meta(&"medium_mode", false)
	var stage_name := "Medium" if medium_mode else "Easy"
	var mob_count := 15
	var background_theme: int
	if first_combat_background < 0:
		first_combat_background = randi_range(0, COMBAT_BACKGROUNDS.size() - 1)
	if stage_number in SHOP_STAGES:
		stage_name = "Toko"
		mob_count = 0
		level_width = SHOP_WIDTH
		background_theme = SHOP_BACKGROUND
	elif stage_number == STAGE_COUNT:
		stage_name = "Boss"
		background_theme = BOSS_BACKGROUND
	else:
		var combat_index := stage_number - 1
		for shop_stage: int in SHOP_STAGES:
			if stage_number > shop_stage:
				combat_index -= 1
		background_theme = COMBAT_BACKGROUNDS[(first_combat_background + combat_index) % COMBAT_BACKGROUNDS.size()]
		if stage_number < SHOP_STAGES[0]:
			mob_count = 10
	area_label.text = "Stage %d / %d · %s" % [stage_number, STAGE_COUNT, stage_name]
	stage_background.build(background_theme, stage_number)

	_add_terrain(Rect2(0, FLOOR_Y, level_width, 45))
	_add_terrain(Rect2(-32, -500, 32, 1220))
	_add_terrain(Rect2(level_width, -500, 32, 1220))
	if mob_count > 0:
		gate = _add_terrain(Rect2(level_width - 55, -500, 22, FLOOR_Y + 500))
		_add_platforms()
		for index in mob_count:
			pending_mobs.append(ALL_MOBS[index % ALL_MOBS.size()])
		pending_mobs.shuffle()
		_start_wave_intro()

	var head := AtlasTexture.new()
	head.atlas = player.OYEN if player.is_oyen else player.GREY
	head.region = Rect2(45, 16, 146, 105) if player.is_oyen else Rect2(48, 24, 144, 105)
	head.filter_clip = true
	life_portrait.texture = head
	_update_lives()
	_add_resource_icons(health_hearts, player.MAX_HEALTH, Vector2(34.0, 34.0))
	_add_resource_icons(dynamite_icons, player.MAX_DYNAMITE, Vector2(38.0, 42.0))
	player.health_changed.connect(_update_health)
	player.dynamite_changed.connect(_update_dynamite)
	player.defeated.connect(_on_player_defeated)
	player.respawn_finished.connect(func(): _present_upgrade.call_deferred())
	upgrade_choice.chosen.connect(_on_upgrade_chosen)
	_update_health(player.health)
	_update_dynamite(player.dynamite_stock)
	_update_status()
	_update_camera()
	camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_update_camera()
	if finished or choosing_upgrade or player.health <= 0:
		return
	if remaining > 0:
		if wave_remaining == 0:
			_update_wave_intro(delta)
		return
	if player.position.x >= level_width - 35.0:
		_advance_stage.call_deferred()


func _advance_stage() -> void:
	if finished or choosing_upgrade or player.health <= 0:
		return
	if stage_number == STAGE_COUNT and player.respawn_blink_left > 0.0:
		return
	finished = true
	if stage_number == STAGE_COUNT:
		world.process_mode = Node.PROCESS_MODE_DISABLED
		victory_panel.show()
		return

	var arena_scene := load(scene_file_path) as PackedScene
	var next_stage := arena_scene.instantiate()
	next_stage.stage_number = stage_number + 1
	next_stage.first_combat_background = first_combat_background
	next_stage.spare_lives = spare_lives
	var next_player := next_stage.get_node(^"World/Player")
	next_player.health = player.health
	next_player.dynamite_stock = player.dynamite_stock
	next_player.upgrade_levels = player.upgrade_levels.duplicate()
	next_player.shield_cooldown = player.shield_cooldown
	next_player.double_jump_cooldown = player.double_jump_cooldown
	next_player.respawn_blink_left = player.respawn_blink_left
	get_tree().change_scene_to_node(next_stage)


func _add_platforms() -> void:
	for slot in range(6):
		var x := 400.0 + slot * 530.0 + randf_range(0.0, 235.0)
		var platform := Rect2(x, randf_range(468.0, 532.0), randf_range(140.0, 225.0), 17.0)
		platforms.append(platform)
		_add_terrain(platform, true)


func _start_wave_intro() -> void:
	wave_intro_remaining = WAVE_PROMPT_DURATION * 2.0
	wave_banner.text = "WAVE %d" % (wave_number + 1)
	wave_banner.modulate = Color("#ffcf8d")
	wave_banner.visible = player.health > 0


func _update_wave_intro(delta: float) -> void:
	wave_intro_remaining = maxf(wave_intro_remaining - delta, 0.0)
	if wave_intro_remaining <= 0.0:
		wave_banner.hide()
		_spawn_wave()
	elif wave_intro_remaining <= WAVE_PROMPT_DURATION and wave_banner.text != "START!":
		wave_banner.text = "START!"
		wave_banner.modulate = Color("#fff0c2")


func _spawn_wave() -> void:
	var wave_size := ceili(float(pending_mobs.size()) / (WAVE_COUNT - wave_number))
	wave_number += 1
	var farthest_spawn := SPAWN_DISTANCE + (wave_size - 1) * MOB_SPACING + SPAWN_JITTER
	var direction := 1.0 if player.position.x + farthest_spawn <= level_width - 110.0 else -1.0
	var dynamite_index := randi_range(0, wave_size - 1)
	var health_index := (dynamite_index + randi_range(1, wave_size - 1)) % wave_size
	for index in wave_size:
		var mob := Mob.new()
		mob.kind = pending_mobs.pop_back()
		wave_remaining += 1
		mob.player = player
		mob.difficulty_speed = 2.0 if medium_mode else 1.0
		var distance := SPAWN_DISTANCE + index * MOB_SPACING + randf_range(-SPAWN_JITTER, SPAWN_JITTER)
		mob.position = Vector2(player.position.x + distance * direction, FLOOR_Y)
		var drop_kind := Pickup.Kind.NONE
		if index == dynamite_index:
			drop_kind = Pickup.Kind.DYNAMITE
		elif index == health_index:
			drop_kind = Pickup.Kind.HEALTH
		mob.defeated.connect(_on_mob_defeated.bind(mob, drop_kind))
		world.add_child(mob)
	_update_status()


func _on_mob_defeated(mob: CharacterBody2D, drop_kind: Pickup.Kind) -> void:
	if drop_kind != Pickup.Kind.NONE:
		var pickup := Pickup.new()
		pickup.kind = drop_kind
		pickup.player = player
		pickup.position = Vector2(mob.position.x, FLOOR_Y - 24.0)
		world.add_child(pickup)
	wave_remaining -= 1
	if remaining == 0:
		choosing_upgrade = true
		_present_upgrade.call_deferred()
	elif wave_remaining == 0:
		_start_wave_intro()
	_update_status()


func _present_upgrade() -> void:
	if not choosing_upgrade or finished or player.health <= 0 or player.respawn_blink_left > 0.0 or upgrade_choice.visible:
		return
	var options := Upgrades.roll(player.upgrade_levels)
	if options.is_empty():
		_open_exit()
		return
	world.process_mode = Node.PROCESS_MODE_DISABLED
	upgrade_choice.present(options, player.upgrade_levels)


func _on_upgrade_chosen(id: Upgrades.Id) -> void:
	player.apply_upgrade(id)
	player.shoot_ready = false
	world.process_mode = Node.PROCESS_MODE_INHERIT
	_open_exit()


func _open_exit() -> void:
	choosing_upgrade = false
	gate.set_deferred(&"disabled", true)
	queue_redraw()
	_update_status()


func _update_status() -> void:
	if choosing_upgrade:
		enemy_count.text = "Pilih upgrade"
	elif wave_remaining > 0:
		enemy_count.text = "Gel. %d/%d · %d mob" % [wave_number, WAVE_COUNT, wave_remaining]
	elif not pending_mobs.is_empty():
		enemy_count.text = "Gel. %d/%d segera" % [wave_number + 1, WAVE_COUNT]
	elif stage_number in SHOP_STAGES:
		enemy_count.text = "Toko kosong  →"
	else:
		enemy_count.text = "Jalur terbuka  →"


func _update_camera() -> void:
	camera.position = Vector2(clampf(player.position.x + 175.0, 640.0, level_width - 640.0), 360.0)
	if stage_number in SHOP_STAGES:
		stage_background.scroll_shop(player.position.x)


func _add_resource_icons(row: HBoxContainer, count: int, slot_size: Vector2) -> void:
	for _index in count:
		var icon := TextureRect.new()
		icon.custom_minimum_size = slot_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)


func _update_resource_icons(row: HBoxContainer, count: int, full: Texture2D, empty: Texture2D) -> void:
	for index in row.get_child_count():
		var icon: TextureRect = row.get_child(index)
		icon.texture = full if index < count else empty


func _update_health(remaining_health: int) -> void:
	_update_resource_icons(health_hearts, remaining_health, FULL_HEART, EMPTY_HEART)
	if remaining_health > 0:
		wave_banner.visible = wave_intro_remaining > 0.0
		return
	wave_banner.hide()
	get_tree().call_group(&"enemy_projectiles", &"queue_free")
	var mobs := get_tree().get_nodes_in_group(&"enemy_mobs")
	mobs.shuffle()
	for index in mobs.size():
		mobs[index].begin_scattering(-1 if index % 2 == 0 else 1)


func _update_lives() -> void:
	life_count.text = "×%d" % spare_lives


func _update_dynamite(stock: int) -> void:
	_update_resource_icons(dynamite_icons, stock, FULL_DYNAMITE, EMPTY_DYNAMITE)


func _on_player_defeated() -> void:
	if finished:
		return
	if spare_lives > 0:
		spare_lives -= 1
		_update_lives()
		player.respawn()
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
	world.add_child(terrain)
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

	_draw_gate(level_width - 55, remaining == 0 and not choosing_upgrade)


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
