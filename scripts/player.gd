extends CharacterBody2D

signal health_changed(remaining: int)
signal dynamite_changed(remaining: int)
signal defeated

const MAX_HEALTH := 5
const MAX_DYNAMITE := 3
const Bullet := preload("res://scripts/bullet.gd")
const Dynamite := preload("res://scripts/dynamite.gd")
const GREY := preload("res://Assets/Character/Main/Grey full.png")
const OYEN := preload("res://Assets/Character/Main/Oyen full.png")
const THROW_ATLAS := preload("res://Assets/Character/Main/Grey throw dynamite.png")
const GREY_AIM := [
	preload("res://Assets/Character/Main/Four-frame grey cowboy cat firing skyward-2.png"),
	preload("res://Assets/Character/Main/Grey cowboy cat firing downward-4.png"),
	preload("res://Assets/Character/Main/Grey Cat Cowboy_ Walking and Firing-1.png"),
	preload("res://Assets/Character/Main/Grey Cowboy Cat Walking Fire Cycle-3.png"),
]
const OYEN_AIM := [
	preload("res://Assets/Character/Main/Four sprite poses with a muzzle flash-5.png"),
	preload("res://Assets/Character/Main/Oyen’s four-frame downward firing sequence-4.png"),
	preload("res://Assets/Character/Main/Oyen's Upward Gun-Flash Walk Cycle-3.png"),
	preload("res://Assets/Character/Main/Oyen’s four-frame downward gun walk-1.png"),
]
const AIM_FLOORS_GREY := [624, 623, 624, 647]
const AIM_FLOORS_OYEN := [635, 610, 657, 647]
const FRAME_SIZE := Vector2i(237, 222)
const SPEED := 335.0
const ACCELERATION := 2500.0
const GRAVITY := 1750.0
const JUMP_SPEED := 800.0
const JUMP_GRACE := 0.10
const SHOT_INTERVAL := 0.24
const OYEN_SHOT_INTERVAL := SHOT_INTERVAL / 0.70
const SHOT_POSE_DURATION := 0.20

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := 1
var coyote_time := 0.0
var jump_buffer := 0.0
var shot_cooldown := 0.0
var throwing := false
var dynamite_released := false
var is_oyen := false
var shoot_ready := false
var aim := 0
var health := MAX_HEALTH
var dynamite_stock := MAX_DYNAMITE
var hit_cooldown := 0.0


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	is_oyen = get_tree().get_meta(&"selected_character", &"grey") == &"oyen"
	shoot_ready = not Input.is_action_pressed(&"shoot")
	_add_animation(frames, &"idle", 226 if not is_oyen else 215, [0, 1, 2, 3], 5.0)
	_add_animation(frames, &"run", 463 if not is_oyen else 437, [0, 1, 2, 3], 12.0)
	_add_animation(frames, &"shoot", 688 if not is_oyen else 658, [1, 2, 3], 15.0, false)
	_add_animation(frames, &"run_shoot", 914 if not is_oyen else 879, [1, 2, 3], 15.0, false)
	_add_animation(frames, &"jump", 1380 if not is_oyen else 1543, [1], 1.0)
	_add_animation(frames, &"fall", 1380 if not is_oyen else 1543, [2], 1.0)
	_add_animation(frames, &"throw", 724 if not is_oyen else 1099, [0, 1, 2, 3], 12.0, false)
	var aim_atlases := OYEN_AIM if is_oyen else GREY_AIM
	for index in aim_atlases.size():
		var pose_columns: Array[int] = [1]
		if index >= 2:
			pose_columns.append(3)
		_add_frames(frames, _aim_animation(index, false), aim_atlases[index], Vector2i(543, 724), 724, pose_columns, 8.0, true)
		_add_frames(frames, _aim_animation(index, true), aim_atlases[index], Vector2i(543, 724), 724, [2, 3], 12.0, false)
	sprite.sprite_frames = frames
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"idle")


func _add_animation(
	frames: SpriteFrames,
	animation: StringName,
	bottom: int,
	columns: Array[int],
	fps: float,
	loop: bool = true
) -> void:
	var atlas: Texture2D = OYEN if is_oyen else GREY
	var size := Vector2i(222, 222) if is_oyen else FRAME_SIZE
	if animation == &"throw" and not is_oyen:
		atlas = THROW_ATLAS
		size = Vector2i(543, 724)
	_add_frames(frames, animation, atlas, size, bottom, columns, fps, loop)


func _add_frames(
	frames: SpriteFrames, animation: StringName, atlas: Texture2D, size: Vector2i,
	bottom: int, columns: Array[int], fps: float, loop: bool
) -> void:
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
	for column: int in columns:
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		var frame_origin := Vector2i(column * size.x, maxi(0, bottom - size.y))
		var width := mini(size.x, atlas.get_width() - frame_origin.x)
		frame.region = Rect2i(frame_origin, Vector2i(width, size.y))
		frame.filter_clip = true
		frames.add_frame(animation, frame)


func _physics_process(delta: float) -> void:
	hit_cooldown = maxf(hit_cooldown - delta, 0.0)
	sprite.modulate = Color("#ff9380") if hit_cooldown > 0.42 else Color.WHITE
	var direction := Input.get_axis(&"move_left", &"move_right")
	if direction != 0.0 and not throwing:
		facing = 1 if direction > 0.0 else -1
		sprite.flip_h = facing < 0
	velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)

	if is_on_floor():
		coyote_time = JUMP_GRACE
	else:
		coyote_time = maxf(coyote_time - delta, 0.0)
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer = JUMP_GRACE
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	if coyote_time > 0.0 and jump_buffer > 0.0:
		velocity.y = -JUMP_SPEED
		coyote_time = 0.0
		jump_buffer = 0.0
	move_and_slide()

	var next_aim := int(Input.is_action_pressed(&"aim_down")) - int(Input.is_action_pressed(&"aim_up"))
	var aim_changed := next_aim != aim
	aim = next_aim
	shot_cooldown = maxf(shot_cooldown - delta, 0.0)
	if not Input.is_action_pressed(&"shoot"):
		shoot_ready = true
	if throwing:
		return
	if Input.is_action_just_pressed(&"throw_dynamite") and dynamite_stock > 0:
		_start_throw()
	elif shoot_ready and Input.is_action_pressed(&"shoot") and shot_cooldown <= 0.0:
		_shoot()
	elif shot_cooldown <= _shot_interval() - SHOT_POSE_DURATION or aim_changed:
		_animate_movement()


func _start_throw() -> void:
	dynamite_stock -= 1
	dynamite_changed.emit(dynamite_stock)
	throwing = true
	dynamite_released = false
	_reset_sprite_layout()
	if not is_oyen:
		sprite.scale = Vector2.ONE * 0.22
		sprite.position.y = -57.0
	sprite.play(&"throw")


func refill_dynamite() -> bool:
	if dynamite_stock >= MAX_DYNAMITE or health <= 0:
		return false
	dynamite_stock += 1
	dynamite_changed.emit(dynamite_stock)
	return true


func _on_sprite_frame_changed() -> void:
	if not throwing or dynamite_released or sprite.animation != &"throw" or sprite.frame < 2:
		return
	dynamite_released = true
	var dynamite := Dynamite.new()
	dynamite.position = get_parent().to_local(global_position + Vector2(38.0 * facing, -65.0))
	dynamite.launch(facing)
	get_parent().add_child(dynamite)


func _on_animation_finished() -> void:
	if not throwing:
		return
	throwing = false
	_animate_movement()


func _shoot() -> void:
	var moving_on_ground := is_on_floor() and absf(velocity.x) > 25.0
	if aim != 0:
		_play_aim(moving_on_ground, true)
	else:
		_reset_sprite_layout()
		sprite.play(&"run_shoot" if moving_on_ground else &"shoot")
	sprite.set_frame_and_progress(0, 0.0)
	shot_cooldown = _shot_interval()

	var forward := Vector2(facing, 0.0)
	var muzzle_offset := Vector2(43.0, -55.0)
	if aim < 0:
		var elevation := 53.0 if is_oyen else 80.0
		forward = forward.rotated(deg_to_rad(-elevation * facing))
		muzzle_offset = Vector2(40.0, -99.0)
	elif aim > 0:
		var depression := 45.0 if is_oyen else 58.0
		forward = forward.rotated(deg_to_rad(depression * facing))
		muzzle_offset = Vector2(36.0, -18.0)
	if is_oyen:
		for angle: float in [-PI / 4.0, 0.0, PI / 4.0]:
			_spawn_bullet(forward.rotated(angle), muzzle_offset, 1.0 / 3.0)
	else:
		_spawn_bullet(forward, muzzle_offset)


func _shot_interval() -> float:
	return OYEN_SHOT_INTERVAL if is_oyen else SHOT_INTERVAL


func _spawn_bullet(direction: Vector2, muzzle_offset: Vector2, range_scale: float = 1.0) -> void:
	var bullet := Bullet.new()
	var origin := global_position + Vector2(0.0, -55.0)
	var muzzle := global_position + Vector2(muzzle_offset.x * facing, muzzle_offset.y)
	bullet.setup(origin, muzzle, direction, range_scale)
	get_parent().add_child(bullet)


func _animate_movement() -> void:
	if aim != 0:
		_play_aim(is_on_floor() and absf(velocity.x) > 25.0, false)
		return
	_reset_sprite_layout()
	if not is_on_floor():
		sprite.play(&"jump" if velocity.y < 0.0 else &"fall")
	elif absf(velocity.x) > 25.0:
		sprite.play(&"run")
	else:
		sprite.play(&"idle")


func _aim_animation(index: int, firing: bool) -> StringName:
	return StringName("aim_fire_%d" % index if firing else "aim_hold_%d" % index)


func _play_aim(moving: bool, firing: bool) -> void:
	var index := int(aim > 0) + (2 if moving else 0)
	var floors := AIM_FLOORS_OYEN if is_oyen else AIM_FLOORS_GREY
	var scale_factor := 0.25 if not is_oyen and aim < 0 else 0.22
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position.y = (362.0 - floors[index]) * scale_factor
	sprite.play(_aim_animation(index, firing))


func _reset_sprite_layout() -> void:
	sprite.scale = Vector2.ONE * 0.57
	sprite.position.y = -63.27


func take_hit(_point: Vector2, _direction: int) -> void:
	if hit_cooldown > 0.0 or health <= 0:
		return
	hit_cooldown = 0.62
	health -= 1
	health_changed.emit(health)
	if health == 0:
		defeated.emit()


func take_blast(center: Vector2, radius: float) -> void:
	if (global_position + Vector2(0.0, -51.0)).distance_squared_to(center) <= radius * radius:
		take_hit(center, 1 if global_position.x >= center.x else -1)
