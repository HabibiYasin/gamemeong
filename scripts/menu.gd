extends Control

const CHARACTER_SELECT := "res://scenes/character_select.tscn"

@onready var play: Button = %Play
@onready var exit: Button = %Exit


func _ready() -> void:
	play.pressed.connect(_play)
	exit.pressed.connect(_exit)
	play.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"aim_up") or event.is_action_pressed(&"aim_down"):
		get_viewport().set_input_as_handled()
		if exit.has_focus():
			play.grab_focus()
		else:
			exit.grab_focus()
	elif event.is_action_pressed(&"shoot"):
		get_viewport().set_input_as_handled()
		if exit.has_focus():
			_exit()
		else:
			_play()


func _play() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT)


func _exit() -> void:
	get_tree().quit()
