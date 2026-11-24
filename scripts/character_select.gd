extends Control

const CHARACTERS := [&"grey", &"oyen"]
const ARENA := "res://scenes/arena.tscn"
const MENU := "res://scenes/menu.tscn"

@export var cards: Array[Panel]
@export var selected_style: StyleBoxFlat

var selection := 0
var normal_style: StyleBox


func _ready() -> void:
	normal_style = cards[0].get_theme_stylebox(&"panel")
	_update_cards()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_left"):
		selection = maxi(0, selection - 1)
		_update_cards()
	elif event.is_action_pressed(&"move_right"):
		selection = mini(CHARACTERS.size() - 1, selection + 1)
		_update_cards()
	elif event.is_action_pressed(&"shoot"):
		get_viewport().set_input_as_handled()
		get_tree().set_meta(&"selected_character", CHARACTERS[selection])
		get_tree().change_scene_to_file(ARENA)
		return
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(MENU)
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _update_cards() -> void:
	for index in cards.size():
		var selected := selection == index
		cards[index].add_theme_stylebox_override(&"panel", selected_style if selected else normal_style)
		var label: Label = cards[index].get_node("Name")
		label.modulate = Color("#ffc17d") if selected else Color("#e0c5ac")
