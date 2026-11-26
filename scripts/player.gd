extends CharacterBody2D

signal health_changed(remaining: int)
signal dynamite_changed(remaining: int)
signal defeated
signal respawn_finished

const MAX_HEALTH := 5
const MAX_DYNAMITE := 3
const Bullet := preload("res://scripts/bullet.gd")
const Dynamite := preload("res://scripts/dynamite.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
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
const DOUBLE_JUMP_COOLDOWN := 2.0
const SHIELD_COOLDOWN := 10.0
const SHOT_INTERVAL := 0.24
const OYEN_SHOT_INTERVAL := SHOT_INTERVAL / 0.50
const SHOT_POSE_DURATION := 0.20
const DEATH_BLINK_DURATION := 2.0
const HIDDEN_DURATION := 1.0
const RESPAWN_BLINK_DURATION := 2.0
const BLINK_INTERVAL := 0.15
const MISS_LABEL_DURATION := 1.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shield: Sprite2D = $Shield

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
var upgrade_levels: Dictionary[Upgrades.Id, int] = {}
var air_jump_available := true
var double_jump_cooldown := 0.0
var shield_cooldown := 0.0
var death_time_left := 0.0
var respawn_blink_left := 0.0


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
	_add_animation(frames, &"hurt", 1141 if not is_oyen else 1320, [0, 1, 2, 3], 16.0, false)
	_add_animation(frames, &"fall_down", 1628 if not is_oyen else 1767, [0, 1, 2, 3], 9.0, false)
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
	_update_shield()
	if respawn_blink_left > 0.0:
		_blink(RESPAWN_BLINK_DURATION - respawn_blink_left)


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
		if animation == &"fall_down" and atlas == GREY:
			frame_origin.x += [0, 0, -12, -8][column]
		var width := mini(size.x, atlas.get_width() - frame_origin.x)
		frame.region = Rect2i(frame_origin, Vector2i(width, size.y))
		frame.filter_clip = true
		frames.add_frame(animation, frame)


func _physics_process(delta: float) -> void:
	if health <= 0:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		_update_death(delta)
		return
	if respawn_blink_left > 0.0:
		respawn_blink_left = maxf(respawn_blink_left - delta, 0.0)
		if respawn_blink_left > 0.0:
			_blink(RESPAWN_BLINK_DURATION - respawn_blink_left)
		else:
			show()
			respawn_finished.emit()
	hit_cooldown = maxf(hit_cooldown - delta, 0.0)
	double_jump_cooldown = maxf(double_jump_cooldown - delta, 0.0)
	if shield_cooldown > 0.0:
		shield_cooldown = maxf(shield_cooldown - delta, 0.0)
		if shield_cooldown == 0.0:
			_update_shield()
	var direction := Input.get_axis(&"move_left", &"move_right")
	if direction != 0.0 and not throwing and sprite.animation != &"hurt":
		facing = 1 if direction > 0.0 else -1
		sprite.flip_h = facing < 0
	velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)

	if is_on_floor():
		coyote_time = JUMP_GRACE
		air_jump_available = true
	else:
		coyote_time = maxf(coyote_time - delta, 0.0)
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer = JUMP_GRACE
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	var can_air_jump := air_jump_available and double_jump_cooldown <= 0.0 and _upgrade_level(Upgrades.Id.DOUBLE_JUMP) > 0
	if jump_buffer > 0.0 and (coyote_time > 0.0 or can_air_jump):
		if coyote_time <= 0.0:
			air_jump_available = false
			double_jump_cooldown = DOUBLE_JUMP_COOLDOWN
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
	if throwing or sprite.animation == &"hurt":
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


func restore_health() -> bool:
	if health <= 0 or health >= MAX_HEALTH:
		return false
	health += 1
	health_changed.emit(health)
	return true


func respawn() -> void:
	health = MAX_HEALTH
	hit_cooldown = 0.0
	respawn_blink_left = RESPAWN_BLINK_DURATION
	velocity = Vector2.ZERO
	coyote_time = 0.0
	jump_buffer = 0.0
	shot_cooldown = 0.0
	air_jump_available = true
	shoot_ready = not Input.is_action_pressed(&"shoot")
	aim = 0
	_reset_sprite_layout()
	sprite.play(&"idle")
	show()
	health_changed.emit(health)


func _update_death(delta: float) -> void:
	if death_time_left <= 0.0:
		return
	death_time_left = maxf(death_time_left - delta, 0.0)
	if death_time_left > HIDDEN_DURATION:
		_blink(DEATH_BLINK_DURATION + HIDDEN_DURATION - death_time_left)
	else:
		hide()
	if death_time_left == 0.0:
		defeated.emit()


func _blink(elapsed: float) -> void:
	visible = floori(elapsed / BLINK_INTERVAL) % 2 == 0


func apply_upgrade(id: Upgrades.Id) -> void:
	var level := _upgrade_level(id)
	if level >= Upgrades.DATA[id].max_level:
		return
	upgrade_levels[id] = level + 1
	if id == Upgrades.Id.SHIELD:
		_update_shield()


func _upgrade_level(id: Upgrades.Id) -> int:
	return upgrade_levels.get(id, 0)


func _update_shield() -> void:
	shield.visible = _upgrade_level(Upgrades.Id.SHIELD) > 0 and shield_cooldown <= 0.0


func _on_sprite_frame_changed() -> void:
	if not throwing or dynamite_released or sprite.animation != &"throw" or sprite.frame < 2:
		return
	dynamite_released = true
	_spawn_dynamite(1.0)
	if _upgrade_level(Upgrades.Id.DOUBLE_D) > 0:
		_spawn_dynamite(0.65)


func _spawn_dynamite(distance_scale: float) -> void:
	var dynamite := Dynamite.new()
	dynamite.position = get_parent().to_local(global_position + Vector2(38.0 * facing, -65.0))
	dynamite.size_scale = 1.0 + 0.50 * _upgrade_level(Upgrades.Id.BIG_D)
	dynamite.launch(facing, distance_scale)
	get_parent().add_child(dynamite)


func _on_animation_finished() -> void:
	match sprite.animation:
		&"fall_down":
			death_time_left = DEATH_BLINK_DURATION + HIDDEN_DURATION
		&"hurt", &"throw":
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
	var range_scale := 1.0 / 3.0 if is_oyen else 1.0
	if is_oyen:
		for angle: float in [-PI / 4.0, 0.0, PI / 4.0]:
			_fire_forward(forward.rotated(angle), muzzle_offset, range_scale)
	else:
		_fire_forward(forward, muzzle_offset, range_scale)
	var back_shots := _upgrade_level(Upgrades.Id.BACK_SHOT)
	for index in back_shots:
		var height := -55.0 + (index - (back_shots - 1) * 0.5) * 12.0
		_spawn_bullet(Vector2(-facing, 0.0), Vector2(-43.0, height), range_scale)


func _shot_interval() -> float:
	return OYEN_SHOT_INTERVAL if is_oyen else SHOT_INTERVAL


func _fire_forward(direction: Vector2, muzzle_offset: Vector2, range_scale: float) -> void:
	if _upgrade_level(Upgrades.Id.DOUBLE_SHOT) == 0:
		_spawn_bullet(direction, muzzle_offset, range_scale)
		return
	var separation := direction.orthogonal() * 7.0
	_spawn_bullet(direction, muzzle_offset, range_scale, -separation)
	_spawn_bullet(direction, muzzle_offset, range_scale, separation)


func _spawn_bullet(
	direction: Vector2, muzzle_offset: Vector2, range_scale: float, separation: Vector2 = Vector2.ZERO
) -> void:
	var bullet := Bullet.new()
	bullet.size_scale = 1.0 + _upgrade_level(Upgrades.Id.BIG_SHOT)
	var origin := global_position + Vector2(0.0, -55.0) + separation
	var muzzle := global_position + Vector2(muzzle_offset.x * facing, muzzle_offset.y) + separation
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


func take_projectile_hit(point: Vector2, direction: int, attacker_position: Vector2 = Vector2.INF) -> void:
	take_hit(point, direction, true, 1, attacker_position)


func take_hit(
	_point: Vector2, _direction: int, projectile: bool = false, damage: int = 1,
	attacker_position: Vector2 = Vector2.INF
) -> void:
	if hit_cooldown > 0.0 or health <= 0 or respawn_blink_left > 0.0:
		return
	var miss_chance := 0.10 * _upgrade_level(Upgrades.Id.MISS_YOU)
	if projectile and miss_chance > 0.0 and randf() < miss_chance:
		if attacker_position.is_finite():
			_show_miss(attacker_position)
		return
	if _upgrade_level(Upgrades.Id.SHIELD) > 0 and shield_cooldown <= 0.0:
		shield_cooldown = SHIELD_COOLDOWN
		_update_shield()
		return
	hit_cooldown = 0.62
	health = maxi(health - damage, 0)
	health_changed.emit(health)
	if throwing and not dynamite_released and health > 0:
		refill_dynamite()
	throwing = false
	_reset_sprite_layout()
	if health == 0:
		velocity.x = 0.0
		sprite.play(&"fall_down")
	else:
		sprite.play(&"hurt")
		sprite.set_frame_and_progress(0, 0.0)


func take_blast(
	center: Vector2, radius: float, projectile: bool = false, damage: int = 1,
	attacker_position: Vector2 = Vector2.INF
) -> void:
	if (global_position + Vector2(0.0, -51.0)).distance_squared_to(center) <= radius * radius:
		take_hit(center, 1 if global_position.x >= center.x else -1, projectile, damage, attacker_position)


func _show_miss(attacker_position: Vector2) -> void:
	var label := Label.new()
	label.text = "Miss"
	label.size = Vector2(96.0, 32.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 6
	label.add_theme_color_override(&"font_color", Color("#ff4f4f"))
	label.add_theme_color_override(&"font_outline_color", Color("#3a1a1d"))
	label.add_theme_constant_override(&"outline_size", 5)
	label.add_theme_font_size_override(&"font_size", 26)
	label.position = get_parent().to_local(attacker_position) + Vector2(-48.0, -169.0)
	get_parent().add_child(label)

	var rise := label.create_tween().set_parallel()
	rise.tween_property(label, "position:y", label.position.y - 56.0, MISS_LABEL_DURATION)
	rise.tween_property(label, "modulate:a", 0.0, MISS_LABEL_DURATION)
	rise.chain().tween_callback(label.queue_free)
