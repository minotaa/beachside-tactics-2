extends NPC

func _ready() -> void:
	npc_name = "Warren"
	dialogue_trees = {
		"requirement_not_met": [
			{
				"text": "Hmpf, talk to me when you're Level 10.",
				"next": null,
				"condition": "requirement_not_met"
			}
		],
		"first_time1": [
			{
				"text": "Hff... hey there. I'm Warren, I'm a... purveyor of fine cuisine. Have you ever heard of turtles?",
				"condition": "hasnt_heard_spiel",
				"next": "first_time2"
			}
		],
		"first_time2": [
			{
				"text": "Ever heard of Turtles?",
				"choices": [
					{ "label": ["...Yeah, Shelly and Sheldon"].pick_random(), "next": "clarification" },
					{ "label": "...No", "next": "dumb" }
				]
			}
		],
		"clarification": [
			{
				"text": "Not really, well, kinda. Shelly, Sheldon, and I are sorta different. More... intelligent in a way.",
				"next": "clarification2"		
			}
		],
		"clarification2": [
			{
				"text": "The Turtles I'm referring to are of the mercurial variety. They're sort of... elusive.",
				"next": "first_time3"
			}
		],
		"dumb": [
			{
				"text": "Makes sense... Turtles are shelled reptiles, typically they're found near water.",
				"next": "first_time3"
			}
		],
		"first_time3": [
			{
				"text": "I find that they're quite a delicacy. However, you need a specific type of bait to find them.",
				"next": "first_time4"
			}
		],
		"first_time4": [
			{
				"text": "I can give you the bait, and if you can find those turtles for me, I'll reward you handsomely.",
				"next": "first_time5"
			}
		],
		"first_time5": [
			{
				"text": "Get to it.",
				"next": null
			}
		]
	}
	default_trees = [
		"requirement_not_met",
		"first_time1"
	]
	super._ready()

func _evaluate_condition(condition: String) -> bool:
	match condition:
		"requirement_not_met": 
			return Game.level < 10
		"hasnt_heard_spiel":
			return Game.level >= 10 and not Game.flags.get("hasnt_heard_warren_spiel", false)
	return true

func _on_quest_triggered(quest_id: String) -> void:
	#match quest_id:
	pass
