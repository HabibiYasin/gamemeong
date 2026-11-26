extends RefCounted

enum Id { DOUBLE_SHOT, BACK_SHOT, DOUBLE_JUMP, MISS_YOU, SHIELD, BIG_SHOT, DOUBLE_D, BIG_D }

const DATA := {
	Id.DOUBLE_SHOT: {"name": "Double shot", "effect": "Gandakan peluru ke depan.", "max_level": 1},
	Id.BACK_SHOT: {"name": "Back shot", "effect": "+1 peluru ke belakang saat menembak.", "max_level": 3},
	Id.DOUBLE_JUMP: {"name": "Double jump", "effect": "+1 lompatan di udara. Jeda 2 detik.", "max_level": 1},
	Id.MISS_YOU: {"name": "Miss you", "effect": "+10% peluang menghindari tembakan.", "max_level": 3},
	Id.SHIELD: {"name": "Shield", "effect": "Tahan 1 serangan. Pulih 10 detik setelah pecah.", "max_level": 1},
	Id.BIG_SHOT: {"name": "Big shot", "effect": "Ukuran peluru +100%.", "max_level": 3},
	Id.DOUBLE_D: {"name": "Double D", "effect": "+1 dinamit per lemparan, dengan jarak berbeda.", "max_level": 1},
	Id.BIG_D: {"name": "Big D", "effect": "Ukuran dinamit dan radius ledakan +50%.", "max_level": 2},
}


static func roll(levels: Dictionary) -> Array[Id]:
	var options: Array[Id] = []
	for id: Id in DATA:
		if levels.get(id, 0) < DATA[id].max_level:
			options.append(id)
	options.shuffle()
	options.resize(mini(options.size(), 2))
	return options
