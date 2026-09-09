extends NPC

func _ready() -> void:
	npc_name = "Keeper"
	selling = []
	dialogue_trees = {
		"lost": [
			{
				"text": "...Are you lost?",
				"next": "",
				"choices": [
					{ "label": "Yes.", "next": "yes_lost" },
					{ "label": "No.", "next": "no_lost" }
				],
				"immersive": false
			}
		],
		"no_lost": [
			{
				"text": [
					"Who knows?",
					"Perhaps.",
					"Very well.",
					"I'd rather you didn't stay for long.",
					"Good night."
				]
			}
		],
		"yes_lost": [
			{
				"text": "Close your eyes...",
				"next": "go_home"
			}
		],
		"go_home": [
			{
				"text": "And now you are home...",
				"quest_trigger": "teleport_back"
			}
		]
	}
	default_trees = [
		"lost",
	]
	super._ready()

func _on_quest_triggered(quest_id: String) -> void:
	match quest_id:
		"teleport_back":
			if Game.get_player() != null:
				Game.get_player().global_position = Game.SPAWN_POINTS[Game.Island.Crystalwater_Beach]
				Toast.add("And now you are home...")
				
func _open_shop() -> void:
	pass
