extends NPC

const TROPHY_TURTLE_IDS = {
	"regular": 29,
	"day": 30,
	"night": 31,
	"trap": 32,
	"glitch": 33,
}

func _ready() -> void:
	npc_name = "Warren"
	selling = [Catalog.get_item(34)]
	dialogue_trees = {
		"requirement_not_met": [
			{
				"text": "Oh- you're not even Level 10 yet? Yeah, no, come back when you're... more credible.",
				"next": null,
				"condition": "requirement_not_met"
			}
		],
		"first_time1": [
			{
				"text": "Oh- oh hey! Didn't see you there. I'm Warren, I'm sort of a... wellness researcher, you could say. Have you heard of turtles?",
				"condition": "hasnt_heard_spiel",
				"next": "first_time2",
				"immersive": true
			}
		],
		"first_time2": [
			{
				"text": "Turtles. You've heard of them, right?",
				"choices": [
					{ "label": "...Yeah, Shelly and Sheldon", "next": "clarification" },
					{ "label": "...No", "next": "dumb" }
				]
			}
		],
		"clarification": [
			{
				"text": "No, no, not like them. Well- kind of like them. I mean I'm basically the same as them too but that's not the point.",
				"next": "clarification2"		
			}
		],
		"clarification2": [
			{
				"text": "The turtles I'm talking about are the mercurial ones. Rare. Elusive. Ancient, probably. Nobody believes me but I've done the research.",
				"next": "first_time3"
			}
		],
		"dumb": [
			{
				"text": "Okay, so, quick biology lesson: turtles are shelled reptiles, they live near water, and some of them hold the secret to eternal youth. That last part isn't in the textbooks yet.",
				"next": "first_time3"
			}
		],
		"first_time3": [
			{
				"text": "See, turtles live forever, right? Which means somewhere in there is the actual secret. I just have to find enough of it. Consistently. Regularly.",
				"next": "first_time4"
			}
		],
		"first_time4": [
			{
				"text": "I can give you the bait to find them. Bring them to me and I'll pay you well- better than well, I'm loaded, don't worry about that part.",
				"next": "hint_regular",
				"quest_trigger": "heard_spiel"
			}
		],
		"hint_regular": [
			{
				"text": "Okay so- step one. There's a turtle that just... shows up. Regularly. If you fish enough, in the right spot, it's basically guaranteed eventually. That's your baseline. Start there.",
				"condition": "trophy_regular_not_caught",
				"next": null
			}
		],
		"hint_night": [
			{
				"text": "Next one only comes out at night. I don't know why. Melatonin, probably. That's a turtle thing too, I think. Just- fish at night. Trust the process.",
				"condition": "trophy_night_not_caught",
				"next": null
			}
		],
		"hint_day": [
			{
				"text": "This next one's the opposite- daytime only. Photosynthesis? No wait, that's not- okay, I don't actually know why, but it's a day thing. Go fish during the day.",
				"condition": "trophy_day_not_caught",
				"next": null
			}
		],
		"hint_trap": [
			{
				"text": "This one won't bite a line. You need a trap. Patience, see, that's the real secret ingredient. The youth thing doesn't work if you rush it. I read that somewhere.",
				"condition": "trophy_trap_not_caught",
				"next": null
			}
		],
		"hint_glitch": [
			{
				"text": "Okay, this one's- don't tell anyone I told you this. There's a spot on the cliffs. You're not supposed to be able to fish there. But if you line it up just right... anyway. I never said anything.",
				"condition": "trophy_glitch_not_caught",
				"next": null
			}
		],
		"trophy_turnin": [
			{
				"text": "Oh- oh wow, you actually- okay. Okay! This is- yes. This is exactly what I needed. Here, take this, don't ask where the money came from.",
				"next": null,
				"condition": "has_trophy_turtle_to_turn_in",
				"quest_trigger": "give_trophy_turtle_reward"
			}
		],

		"default": [
			{
				"text": "Still working on it? Good. Good. The research doesn't stop just because it's inconvenient.",
				"next": null
			}
		]
	}
	default_trees = [
		"requirement_not_met",
		"first_time1",
		"trophy_turnin",
		"hint_regular",
		"hint_day",
		"hint_night",
		"hint_trap",
		"hint_glitch",
		"default"
	]
	super._ready()

func _evaluate_condition(condition: String) -> bool:
	match condition:
		"requirement_not_met":
			return Game.level < 10
		"hasnt_heard_spiel":
			return Game.level >= 10 and not Game.flags.get("heard_warren_spiel", false)
		"trophy_regular_not_caught":
			return not Game.flags.get("trophy_regular_caught", false)
		"trophy_day_not_caught":
			return not Game.flags.get("trophy_day_caught", false)
		"trophy_night_not_caught":
			return not Game.flags.get("trophy_night_caught", false)
		"trophy_trap_not_caught":
			return not Game.flags.get("trophy_trap_caught", false)
		"trophy_glitch_not_caught":
			return not Game.flags.get("trophy_glitch_caught", false)
		"has_trophy_turtle_to_turn_in":
			return _next_uncaught_trophy_turtle_in_bag() != ""
	return true

func _on_quest_triggered(quest_id: String) -> void:
	match quest_id:
		"heard_spiel":
			Network.request_set_flag.rpc_id(1, "heard_warren_spiel", true)
		"give_trophy_turtle_reward":
			Network.request_turn_in_trophy_turtle.rpc_id(1)
	pass

func _next_uncaught_trophy_turtle_in_bag() -> String:
	for turtle_key in TROPHY_TURTLE_IDS.keys():
		if not Game.flags.get("trophy_%s_caught" % turtle_key, false):
			if Game.bag.has_item(Catalog.get_item(TROPHY_TURTLE_IDS[turtle_key])):
				return turtle_key
	return ""
