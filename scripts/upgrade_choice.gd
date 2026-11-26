extends ColorRect

const Upgrades := preload("res://scripts/upgrades.gd")
const CONFIRM_DELAY := 2.0

signal chosen(id: Upgrades.Id)

@onready var cards: Array[Button] = [%FirstChoice, %SecondChoice]
@onready var panel: PanelContainer = $Panel
@onready var controls: Label = %Controls

var options: Array[Upgrades.Id] = []
var confirm_time_left := 0.0


func _ready() -> void:
	set_process(false)
	for index in cards.size():
		cards[index].action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		cards[index].pressed.connect(_select.bind(index))


func present(choices: Array[Upgrades.Id], levels: Dictionary) -> void:
	options = choices
	for index in cards.size():
		var card := cards[index]
		card.visible = index < options.size()
		if not card.visible:
			continue
		var id := options[index]
		var upgrade: Dictionary = Upgrades.DATA[id]
		card.get_node(^"Copy/Title").text = upgrade.name
		card.get_node(^"Copy/Effect").text = upgrade.effect
		card.get_node(^"Copy/Level").text = "Level %d / %d" % [levels.get(id, 0) + 1, upgrade.max_level] if upgrade.max_level > 1 else ""
	confirm_time_left = CONFIRM_DELAY
	_update_controls()
	show()
	cards[0].grab_focus()
	set_process(true)

	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.88
	panel.modulate.a = 0.6
	var entrance := create_tween().set_parallel()
	entrance.tween_property(panel, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(panel, "modulate:a", 1.0, 0.20)


func _process(delta: float) -> void:
	var previous_seconds := ceili(confirm_time_left)
	confirm_time_left = maxf(confirm_time_left - delta, 0.0)
	if ceili(confirm_time_left) != previous_seconds:
		_update_controls()
	if confirm_time_left == 0.0:
		set_process(false)


func _update_controls() -> void:
	if confirm_time_left > 0.0:
		controls.text = "A / D atau ← / → pilih    ·    Konfirmasi dalam %d dtk" % ceili(confirm_time_left)
	else:
		controls.text = "A / D atau ← / → pilih    ·    J atau klik untuk konfirmasi"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"move_left"):
		cards[0].grab_focus()
	elif event.is_action_pressed(&"move_right"):
		cards[options.size() - 1].grab_focus()
	elif event.is_action_pressed(&"shoot"):
		_select(1 if cards[1].has_focus() else 0)
	else:
		return
	get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	if not visible or confirm_time_left > 0.0 or index >= options.size():
		return
	hide()
	chosen.emit(options[index])
