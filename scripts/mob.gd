extends CharacterBody2D

signal defeated

const Bullet := preload("res://scripts/bullet.gd")
const Dynamite := preload("res://scripts/dynamite.gd")
const SHEETS := [
	[preload("res://Assets/Character/Mob/Mob1.1.png"), preload("res://Assets/Character/Mob/Mob1.2.png"), preload("res://Assets/Character/Mob/Mob1.3.png")],
	[preload("res://Assets/Character/Mob/Mob2.1.png"), preload("res://Assets/Character/Mob/Mob2.2.png"), preload("res://Assets/Character/Mob/Mob2.3.png")],
	[preload("res://Assets/Character/Mob/Mob3.1.png"), preload("res://Assets/Character/Mob/Mob3.2.png"), preload("res://Assets/Character/Mob/Mob3.3.png")],
	[preload("res://Assets/Character/Mob/Mob4.1.png"), preload("res://Assets/Character/Mob/Mob4.2.png"), preload("res://Assets/Character/Mob/Mob4.3.png")],
]
const MOVE_SPEED := 145.0
const KNIFE_MOVE_SPEED := 225.0
const KNIFE_JUMP_SPEED := 810.0
const KNIFE_JUMP_RANGE := 175.0
const ATTACK_RANGES: Array[float] = [285.0, 72.0, 305.0, 340.0]
const ATTACK_HEIGHTS: Array[float] = [225.0, 63.0, 115.0, 115.0]
const ATTACK_INTERVALS := [1.25, 0.90, 1.85, 2.35]
const BASE_FLOORS := [[264, 254, 243], [266, 260, 250], [263, 263, 253], [220, 218, 209]]
const HURT_FLOORS := [249, 253, 257, 215]
const FALL_DOWN_EDGES := [
	[0, 280, 524, 807, 1122],
	[0, 280, 560, 820, 1122],
	[0, 280, 560, 814, 1122],
	[0, 350, 701, 1051, 1402],
]
const ATTACK_FLOORS := [[333, 318], [338, 330], [333, 327], [277, 275]]
const MAX_HEALTH := 3
const HEALTH_BAR := Rect2(-26.0, -131.0, 52.0, 7.0)

enum Kind { PISTOL, KNIFE, DYNAMITE, CANNON }

var kind := Kind.PISTOL
var player: CharacterBody2D
var health := MAX_HEALTH
var facing := -1
var cooldown := 0.5
var attacking := false
var released := false
var sprite: AnimatedSprite2D
var floors := {}


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 5.0
	z_index = 1
	add_to_group(&"enemy_mobs")
	var shape := CapsuleShape2D.new()
	shape.radius = 20.0
	shape.height = 92.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position.y = -46.0
	add_child(collider)

	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	var build: Array = SHEETS[kind]
	_add_frames(&"idle", build[0], 4, 5, 0, BASE_FLOORS[kind][0], 5.0, true)
	_add_frames(&"run", build[0], 4, 5, 1, BASE_FLOORS[kind][1], 10.0, true)
	_add_frames(&"hurt", build[0], 4, 5, 2, HURT_FLOORS[kind], 16.0, false)
	_add_frames(&"fall_down", build[0], 4, 5, 4, BASE_FLOORS[kind][2], 9.0, false)
	var attack_columns := 6 if kind == Kind.CANNON else 4
	_add_frames(&"attack", build[1], attack_columns, 3, 1, ATTACK_FLOORS[kind][0], 9.0, false)
	_add_frames(&"attack_moving", build[2], attack_columns, 3, 1, ATTACK_FLOORS[kind][1], 11.0, false)
	if kind == Kind.PISTOL:
		_add_frames(&"attack_up", build[1], 4, 3, 0, 332, 9.0, false)
		_add_frames(&"attack_down", build[1], 4, 3, 2, 332, 9.0, false)
	elif kind == Kind.KNIFE:
		_add_frames(&"jump", build[0], 4, 5, 3, 253, 8.0, false)
		_add_frames(&"attack_air", build[1], 4, 3, 0, 338, 13.0, false)
	add_child(sprite)
	sprite.frame_changed.connect(_on_attack_frame)
	sprite.animation_finished.connect(_on_animation_finished)
	_play(&"idle")


func _add_frames(
	animation: StringName, atlas: Texture2D, columns: int, rows: int,
	row: int, floor_y: int, fps: float, loop: bool
) -> void:
	var frames := sprite.sprite_frames
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
	var cell := atlas.get_size() / Vector2(columns, rows)
	for column in columns:
		var start := (Vector2(column, row) * cell).round()
		var end := (Vector2(column + 1, row + 1) * cell).round()
		if animation == &"fall_down":
			start.x = FALL_DOWN_EDGES[kind][column]
			end.x = FALL_DOWN_EDGES[kind][column + 1]
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(start, end - start)
		frame.filter_clip = true
		frames.add_frame(animation, frame)
	var scale_factor := 105.0 / (floor_y - cell.y * 0.10)
	floors[animation] = Vector2(scale_factor, (cell.y * 0.5 - floor_y) * scale_factor)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	cooldown = maxf(cooldown - delta, 0.0)
	if health <= 0 or sprite.animation == &"hurt":
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += 1750.0 * delta
		move_and_slide()
		return
	var offset := player.global_position - global_position
	var distance := absf(offset.x)
	var player_above := offset.y < -30.0 and offset.y > -205.0
	if kind == Kind.KNIFE and is_on_floor() and distance < KNIFE_JUMP_RANGE and player_above and not released:
		velocity.y = -KNIFE_JUMP_SPEED
	var knife_airborne := kind == Kind.KNIFE and (not is_on_floor() or velocity.y < 0.0)
	var moving := false
	if not attacking:
		facing = -1 if offset.x < 0.0 else 1
		var within_height := absf(offset.y) < ATTACK_HEIGHTS[kind]
		if distance <= ATTACK_RANGES[kind] and within_height and cooldown <= 0.0:
			attacking = true
			cooldown = ATTACK_INTERVALS[kind]
			released = false
			var rushing := kind == Kind.KNIFE and distance > 48.0
			if kind == Kind.PISTOL:
				_play(_pistol_animation(offset))
			elif knife_airborne:
				_play(&"attack_air")
			else:
				_play(&"attack_moving" if rushing else &"attack")
		else:
			var stopping_distance := 32.0 if knife_airborne or not within_height else ATTACK_RANGES[kind] * 0.82
			moving = distance > stopping_distance
			if knife_airborne:
				_play(&"jump")
			else:
				_play(&"run" if moving else &"idle")

	if kind == Kind.PISTOL and attacking and not released:
		_update_pistol_aim(offset)

	var move_speed := KNIFE_MOVE_SPEED if kind == Kind.KNIFE else MOVE_SPEED
	var target_speed := move_speed if moving else 0.0
	if attacking and (sprite.animation == &"attack_moving" or (knife_airborne and distance > 48.0)):
		target_speed = move_speed * 0.45
	velocity.x = move_toward(velocity.x, facing * target_speed, 2100.0 * delta)
	if not is_on_floor():
		velocity.y += 1750.0 * delta
	move_and_slide()


func _play(animation: StringName) -> void:
	var layout: Vector2 = floors[animation]
	sprite.scale = Vector2.ONE * layout.x
	sprite.position.y = layout.y
	sprite.flip_h = facing > 0
	sprite.play(animation)


func _pistol_animation(offset: Vector2) -> StringName:
	var tilt_threshold := absf(offset.x) * 0.30
	if offset.y < -tilt_threshold:
		return &"attack_up"
	if offset.y > tilt_threshold:
		return &"attack_down"
	return &"attack"


func _update_pistol_aim(offset: Vector2) -> void:
	if not is_zero_approx(offset.x):
		facing = -1 if offset.x < 0.0 else 1
	sprite.flip_h = facing > 0
	var animation := _pistol_animation(offset)
	if sprite.animation == animation:
		return
	var frame := sprite.frame
	var progress := sprite.frame_progress
	_play(animation)
	sprite.set_frame_and_progress(frame, progress)


func _on_attack_frame() -> void:
	var release_frame := 3 if kind == Kind.CANNON else 2
	if not attacking or released or sprite.frame < release_frame or not is_instance_valid(player):
		return
	released = true
	match kind:
		Kind.PISTOL:
			var offset := player.global_position - global_position
			_update_pistol_aim(offset)
			var direction := offset.normalized() if not offset.is_zero_approx() else Vector2(facing, 0.0)
			var bullet := Bullet.new()
			var origin := global_position + Vector2(0.0, -49.0)
			var muzzle := origin + direction * 43.0
			bullet.hostile = true
			bullet.setup(origin, muzzle, direction, 0.48)
			get_parent().add_child(bullet)
		Kind.KNIFE:
			var offset := player.global_position - global_position
			if absf(offset.y) < 59.0 and offset.x * facing >= -16.0 and absf(offset.x) <= 88.0:
				player.take_hit(global_position, facing)
		Kind.DYNAMITE, Kind.CANNON:
			var bomb := Dynamite.new()
			bomb.enemy_player = player
			bomb.cannonball = kind == Kind.CANNON
			bomb.position = position + Vector2(facing * 43.0, -53.0)
			if bomb.cannonball:
				bomb.velocity = Vector2(facing * 540.0, -45.0)
			else:
				var distance := absf(player.global_position.x - global_position.x)
				bomb.velocity = Vector2(facing * clampf(distance * 1.55, 115.0, 480.0), -425.0)
			get_parent().add_child(bomb)


func _on_animation_finished() -> void:
	if health <= 0:
		queue_free()
	elif sprite.animation == &"hurt":
		_play(&"idle")
	elif attacking:
		attacking = false
		released = false


func take_hit(_point: Vector2, _direction: int, damage: int = 1) -> void:
	if health <= 0:
		return
	health = maxi(health - damage, 0)
	queue_redraw()
	attacking = false
	released = false
	if health == 0:
		remove_from_group(&"enemy_mobs")
		set_deferred(&"collision_layer", 0)
		_play(&"fall_down")
		defeated.emit()
	else:
		_play(&"hurt")
		sprite.set_frame_and_progress(0, 0.0)


func take_blast(center: Vector2, radius: float, damage: int = 1) -> void:
	if (global_position + Vector2(0.0, -46.0)).distance_squared_to(center) <= radius * radius:
		take_hit(center, 1 if global_position.x >= center.x else -1, damage)


func _draw() -> void:
	if health <= 0:
		return
	draw_rect(HEALTH_BAR.grow(2.0), Color("#2e2223"))
	draw_rect(HEALTH_BAR, Color("#703536"))
	var fill := HEALTH_BAR
	fill.size.x *= float(health) / MAX_HEALTH
	draw_rect(fill, Color("#f57d67"))
