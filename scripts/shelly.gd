extends NPC

func _ready() -> void:
	npc_name = "Shelly"
	dialogue_trees = {
		"default": [
			{
				"text": "Hey.",
				"immersive": false
			}
		]
	}
	default_trees = [
		"default"
	]
	super._ready()

func _evaluate_condition(condition: String) -> bool:
	return true

func _on_quest_triggered(quest_id: String) -> void:
	pass

func _open_bestiary() -> void:
	pass
