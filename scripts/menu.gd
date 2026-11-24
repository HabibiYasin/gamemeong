extends Control

const ARENA := "res://scenes/arena.tscn"

@onready var play: Button = %Play
@onready var exit: Button = %Exit


func _ready() -> void:
	play.pressed.connect(_play)
	exit.pressed.connect(_exit)
	play.grab_focus()


func _play() -> void:
	get_tree().change_scene_to_file(ARENA)


func _exit() -> void:
	get_tree().quit()
