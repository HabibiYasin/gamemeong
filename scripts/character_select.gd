extends Control

const CHARACTERS := [&"grey", &"oyen"]
const ARENA := "res://scenes/arena.tscn"
const MENU := "res://scenes/menu.tscn"

@export var cards: Array[Panel]
@export var selected_style: StyleBoxFlat

@onready var easy_mode: Button = %EasyMode
@onready var medium_mode: Button = %MediumMode
@onready var difficulty: Control = $Difficulty
@onready var heading: Label = $Heading
@onready var guide: Label = $Guide
@onready var hero_name: Label = $Difficulty/HeroName

var selection := 0
var normal_style: StyleBox


func _ready() -> void:
	normal_style = cards[0].get_theme_stylebox(&"panel")
	var mode := medium_mode if get_tree().get_meta(&"medium_mode", false) else easy_mode
	mode.button_pressed = true
	easy_mode.pressed.connect(_start_run.bind(false))
	medium_mode.pressed.connect(_start_run.bind(true))
	_update_cards()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_left"):
		_move_choice(-1)
	elif event.is_action_pressed(&"move_right"):
		_move_choice(1)
	elif event.is_action_pressed(&"shoot"):
		get_viewport().set_input_as_handled()
		if difficulty.visible:
			_start_run(medium_mode.button_pressed)
		else:
			_show_difficulty(true)
		return
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if difficulty.visible:
			_show_difficulty(false)
		else:
			get_tree().change_scene_to_file(MENU)
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _move_choice(direction: int) -> void:
	if difficulty.visible:
		var mode := easy_mode if direction < 0 else medium_mode
		mode.button_pressed = true
		return
	selection = clampi(selection + direction, 0, CHARACTERS.size() - 1)
	_update_cards()


func _show_difficulty(show_modes: bool) -> void:
	for card in cards:
		card.visible = not show_modes
	difficulty.visible = show_modes
	if show_modes:
		var name_label: Label = cards[selection].get_node(^"Name")
		hero_name.text = "Bermain sebagai %s" % name_label.text
		heading.text = "Pilih Tingkat Kesulitan"
		guide.text = "← / → atau A / D  Pilih mode     ·     J  Mulai     ·     Esc  Kembali"
	else:
		heading.text = "Pilih Karakter"
		guide.text = "← / → atau A / D  Pilih karakter     ·     J  Lanjut     ·     Esc  Kembali"


func _start_run(use_medium: bool) -> void:
	if not difficulty.visible:
		return
	get_tree().set_meta(&"selected_character", CHARACTERS[selection])
	get_tree().set_meta(&"medium_mode", use_medium)
	get_tree().change_scene_to_file(ARENA)


func _update_cards() -> void:
	for index in cards.size():
		var selected := selection == index
		cards[index].add_theme_stylebox_override(&"panel", selected_style if selected else normal_style)
		var label: Label = cards[index].get_node("Name")
		label.modulate = Color("#ffc17d") if selected else Color("#e0c5ac")
