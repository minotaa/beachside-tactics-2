extends NPC

func _ready() -> void:
	npc_name = "Sheldon"
	dialogue_trees = {
		"default": [
			{
				"text": "Hey, you! Yeah, you, the one just standing there.",
				"next": "intro2",
				"condition": "tutorial_not_complete"
			}
		],
		"intro2": [
			{
				"text": "You look lost. You here to fish or what?",
				"next": "intro3"
			}
		],
		"intro3": [
			{
				"text": "You got a fishing rod on you?",
				"choices": [
					{ "label": "Yeah.", "next": "called_out" },
					{ "label": "No, sorry.", "next": "honest" }
				]
			}
		],
		"called_out": [
			{
				"text": "Sure you do. I can see your hands are empty, kid.",
				"next": "give_money"
			}
		],
		"honest": [
			{
				"text": "At least you're honest.",
				"next": "give_money"
			}
		],
		"give_money": [
			{
				"text": "Look, I'll spot you enough to buy one from me. Don't make me regret it.",
				"next": "open_shop",
				"quest_trigger": "give_starter_money"
			}
		],
		"open_shop": [
			{
				"text": "Take a look. Get the rod. Then go fish.",
				"next": null,
				"quest_trigger": "open_shop"
			}
		],
		"already_has_rod": [
			{
				"text": [
					"Looking for something?",
					"You fishing or just standing there?",
					"Buy something or git!"
				],
				"next": null,
				"condition": "has_rod"
			}
		],
		"reminder": [
			{
				"text": "What are you waiting for? Go buy the rod, then get fishing.",
				"next": null,
				"condition": "no_rod_after_money"
			}
		],
		"intro_shelly": [
			{
				"text": "Oh, I should mention, my wife Shelly handles fish records around here.",
				"next": "intro_shelly2",
				"condition": "introduce_shelly"
			}
		],
		"intro_shelly2": [
			{
				"text": "Talk to her when you catch something decent.",
				"next": "intro_shelly3"
			}
		],

		"intro_shelly3": [
			{
				"text": "Don't ask me why she cares so much. She's always been like that.",
				"next": null,
				"quest_trigger": "told_about_shelly"
			}
		]
	}
	default_trees = [
		"intro_shelly",
		"already_has_rod",
		"reminder",
		"default"
	]
	super._ready()

func _has_fishing_rod() -> bool:
	for item_id in [0, 13, 14]:
		if Game.inventory.has_item(Catalog.get_item(item_id)):
			return true
	return false

func _evaluate_condition(condition: String) -> bool:
	match condition:
		"tutorial_not_complete":
			return not Game.flags.get("tutorial_complete", false)
		"has_rod":
			return _has_fishing_rod()
		"no_rod_after_money":
			return Game.flags.get("got_starter_money", false) and not _has_fishing_rod()
		"introduce_shelly":
			return not Game.flags.get("heard_about_shelly", false) and _has_fishing_rod()
	return true

func _on_quest_triggered(quest_id: String) -> void:
	match quest_id:
		"give_starter_money":
			if not Game.flags.get("got_starter_money", false):
				Game.balance += 100
				Game.flags["got_starter_money"] = true
		"open_shop":
			dialogue_finished.connect(_open_shop, CONNECT_ONE_SHOT)
		"told_about_shelly":
			Game.flags["heard_about_shelly"] = true
			
func _open_shop() -> void:
	pass
