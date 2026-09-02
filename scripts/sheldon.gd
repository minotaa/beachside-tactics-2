extends NPC

func _ready() -> void:
	npc_name = "Sheldon"
	selling = [
		Catalog.get_item(0), 
		Catalog.get_item(13),
		Catalog.get_item(14),
		Catalog.get_item(15),
		Catalog.get_item(24),
		Catalog.get_item(25),
		Catalog.get_item(26),
		Catalog.get_item(27),
		Catalog.get_item(35)
	]
	dialogue_trees = {
		"intro1": [
			{
				"text": "Hey, you! Yeah, you, the one just standing there.",
				"next": "intro2",
				"condition": "tutorial_not_complete",
				"immersive": true
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
					{ "label": ["Yeah.", "ye", "Ye", "Yes."].pick_random(), "next": "called_out" },
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
		"can_buy_bait1": [
			{
				"text": "Hey there! Congrats on reaching Level 5 there kid.",
				"next": "can_buy_bait2",
				"condition": "bait_prompt"
			}
		],
		"can_buy_bait2": [
			{
				"text": "I got some bait in stock for you, it can help you fish faster.",
				"next": null,
				"quest_trigger": "finish_bait"
			}
		],
		"can_buy_traps1": [
			{
				"text": "Hey kid, congrats on reaching Level 10.",
				"next": "can_buy_traps2",
				"condition": "trap_prompt"
			}
		],
		"can_buy_traps2": [
			{
				"text": "You're working your way up in the world and such, I got something new in stock for ya.",
				"next": "can_buy_traps3"
			}
		],
		"can_buy_traps3": [
			{
				"text": "They're fishing traps, they let you catch fish a little passively. Give them a try.",
				"next": null,
				"quest_trigger": "finish_traps"
			}
		],
		"already_has_rod": [
			{
				"text": [
					"Looking for something?",
					"You gonna fish or just stand there?",
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
		"can_buy_bait1",
		"can_buy_traps1",
		"already_has_rod",
		"reminder",
		"intro1"
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
		"bait_prompt":
			return not Game.flags.get("heard_about_bait", false) and Game.level >= 5
		"trap_prompt":
			return not Game.flags.get("heard_about_traps", false) and Game.level >= 10
	return true

func _on_quest_triggered(quest_id: String) -> void:
	match quest_id:
		"give_starter_money":
			if not Game.flags.get("got_starter_money", false):
				Network.request_starter_money.rpc_id(1)
		"open_shop":
			dialogue_finished.connect(_open_shop, CONNECT_ONE_SHOT)
		"told_about_shelly":
			Network.request_set_flag.rpc_id(1, "heard_about_shelly", true)
		"finish_bait":
			Network.request_set_flag.rpc_id(1, "heard_about_bait", true)
		"finish_traps":
			Network.request_set_flag.rpc_id(1, "heard_about_traps", true)
			
func _open_shop() -> void:
	pass
