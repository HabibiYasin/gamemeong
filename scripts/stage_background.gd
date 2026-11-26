extends Node2D

const TILE_SIZE := Vector2(1280.0, 720.0)
const SCROLL_SPEEDS: Array[float] = [0.0, 0.11, 0.21, 0.38, 0.61, 0.86]
const STAGE_TINTS: Array[Color] = [
	Color("#fff0da"),
	Color("#e8f8ff"),
	Color("#ffcaa3"),
	Color("#d8dbff"),
	Color("#f3ffec"),
	Color("#ffde9e"),
	Color("#cfe9e4"),
	Color("#eac1d7"),
	Color("#ffcda0"),
	Color("#d5e5ff"),
]

var start_offset := 0.0


func build(theme: int, stage: int) -> void:
	start_offset = -fposmod((stage - 1) * 173.0, TILE_SIZE.x)
	for index in SCROLL_SPEEDS.size():
		var layer_number := SCROLL_SPEEDS.size() - index
		var texture := _load_layer(theme, layer_number)
		var layer := Parallax2D.new()
		layer.name = "Layer%d" % layer_number
		layer.scroll_scale = Vector2(SCROLL_SPEEDS[index], 0.0)
		layer.scroll_offset = Vector2(start_offset, 0.0)
		layer.repeat_size = Vector2(TILE_SIZE.x, 0.0)
		layer.repeat_times = 2
		if layer_number == 5 and (theme == 2 or theme == 4):
			layer.autoscroll = Vector2(-7.0, 0.0)

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.scale = TILE_SIZE / texture.get_size()
		sprite.modulate = STAGE_TINTS[stage - 1]
		layer.add_child(sprite)
		add_child(layer)


func scroll_shop(player_x: float) -> void:
	for layer: Parallax2D in get_children():
		layer.scroll_offset.x = start_offset - player_x * layer.scroll_scale.x * 0.24


func _load_layer(theme: int, layer: int) -> Texture2D:
	# Theme 4's sixth image duplicates the foreground, so use its sky colors as a gradient.
	if theme == 4 and layer == 6:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.19, 0.28, 1.0])
		gradient.colors = PackedColorArray([Color("#71d2d2"), Color("#caebeb"), Color("#d7efec"), Color("#fff7ef")])
		var sky := GradientTexture2D.new()
		sky.gradient = gradient
		sky.width = 8
		sky.height = int(TILE_SIZE.y)
		sky.fill_to = Vector2(0.0, 1.0)
		return sky
	return load("res://Assets/Background/%d/%d.png" % [theme, layer]) as Texture2D
