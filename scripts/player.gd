extends CharacterBody2D

const Bullet := preload("res://scripts/bullet.gd")
const Dynamite := preload("res://scripts/dynamite.gd")
const ATLAS := preload("res://Assets/Character/Main/Grey full.png")
const THROW_ATLAS := preload("res://Assets/Character/Main/Grey throw dynamite.png")
const FRAME_SIZE := Vector2i(237, 222)
const SPEED := 335.0
const ACCELERATION := 2500.0
const GRAVITY := 1750.0
const JUMP_SPEED := 675.0
const JUMP_GRACE := 0.10
const SHOT_INTERVAL := 0.24

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := 1
var coyote_time := 0.0
var jump_buffer := 0.0
var shot_cooldown := 0.0
var throwing := false
var dynamite_released := false


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"idle", 226, [0, 1, 2, 3], 5.0)
	_add_animation(frames, &"run", 463, [0, 1, 2, 3], 12.0)
	_add_animation(frames, &"shoot", 688, [1, 2, 3], 15.0, false)
	_add_animation(frames, &"run_shoot", 914, [1, 2, 3], 15.0, false)
	_add_animation(frames, &"jump", 1380, [1], 1.0)
	_add_animation(frames, &"fall", 1380, [2], 1.0)
	frames.add_animation(&"throw")
	frames.set_animation_speed(&"throw", 12.0)
	frames.set_animation_loop(&"throw", false)
	for column in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = THROW_ATLAS
		frame.region = Rect2(column * 543, 0, 543, 724)
		frame.filter_clip = true
		frames.add_frame(&"throw", frame)
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
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
	for column: int in columns:
		var frame := AtlasTexture.new()
		frame.atlas = ATLAS
		var frame_origin := Vector2i(column * FRAME_SIZE.x, bottom - FRAME_SIZE.y)
		frame.region = Rect2i(frame_origin, FRAME_SIZE)
		frame.filter_clip = true
		frames.add_frame(animation, frame)


func _physics_process(delta: float) -> void:
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
	if Input.is_action_just_released(&"jump") and velocity.y < -300.0:
		velocity.y = -300.0
	move_and_slide()

	shot_cooldown = maxf(shot_cooldown - delta, 0.0)
	if throwing:
		return
	if Input.is_action_just_pressed(&"throw_dynamite"):
		_start_throw()
	elif Input.is_action_pressed(&"shoot") and shot_cooldown <= 0.0:
		_shoot()
	elif shot_cooldown <= 0.04:
		_animate_movement()


func _start_throw() -> void:
	throwing = true
	dynamite_released = false
	sprite.scale = Vector2.ONE * 0.22
	sprite.position.y = -57.0
	sprite.play(&"throw")


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
	sprite.scale = Vector2.ONE * 0.57
	sprite.position.y = -63.27
	_animate_movement()


func _shoot() -> void:
	var moving_on_ground := is_on_floor() and absf(velocity.x) > 25.0
	var animation: StringName = &"run_shoot" if moving_on_ground else &"shoot"
	sprite.play(animation)
	sprite.set_frame_and_progress(0, 0.0)
	shot_cooldown = SHOT_INTERVAL

	var bullet := Bullet.new()
	var muzzle := global_position + Vector2(43.0 * facing, -55.0)
	bullet.setup(global_position + Vector2(0.0, -55.0), muzzle, facing)
	get_parent().add_child(bullet)


func _animate_movement() -> void:
	if not is_on_floor():
		sprite.play(&"jump" if velocity.y < 0.0 else &"fall")
	elif absf(velocity.x) > 25.0:
		sprite.play(&"run")
	else:
		sprite.play(&"idle")
