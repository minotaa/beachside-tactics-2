extends NPC
class_name Simon

func _ready() -> void:
	action = Action.OPEN_SHOP
	npc_name = "Simon"
	selling = []

	dialogue_trees = {
		"offer_suit": [
			{
				"text": "Hey there champ!!! Turtles are AMAZING swimmers you know, and I would know!!! I'm a turtle!",
				"condition": "suit_not_owned",
				"else": "offer_first_swim",
				"next": "offer_suit2"
			}
		],
		"offer_suit2": [
			{
				"text": "I could teach you a thing or two about swimming if you want you know!!! All I need is just a little STARTER one time fee of $1000!",
				"next": "offer_suit3",
				"immersive": true
			}
		],
		"offer_suit3": [
			{
				"text": "Sounds steep right?! Don't worry, in this economy that's worth PENNIES.",
				"next": "offer_suit4"
			}
		],
		"offer_suit4": [
			{
				"text": "Anyways, you ready to sign up?",
				"choices": [
					{ "label": "Yes", "condition": "has_1000", "next_true": "sold", "next_false": "too_poor" },
					{ "label": "No", "next": "declined" }
				]
			}
		],
		"offer_first_swim": [
			{
				"text": "Look at you in that suit champ!!! Time for your VERY FIRST SWIM! Rule one: watch your stamina. Rule two: mind the dark spots. Rule three: HAVE FUN!",
				"condition": "never_swam",
				"else": "offer_swim",
				"next": "offer_first_swim2",
				"immersive": true
			}
		],
		"offer_first_swim2": [
			{
				"text": "Every dip costs $250. Cheap for a whole ocean, right?! Ready to jump in?",
				"choices": [
					{ "label": "Yes", "condition": "has_250", "next_true": "first_swim_start", "next_false": "swim_too_poor" },
					{ "label": "No", "next": "swim_declined" }
				]
			}
		],
		"first_swim_start": [
			{
				"text": "THAT'S MY STUDENT! Go make a splash!!!",
				"next": null,
				"quest_trigger": "start_swim_session"
			}
		],
		"sold": [
			{
				"text": "GREAT CHOICE! You won't be sorry! As per the course, you'll be given your very own bathing suit! You'll now be able to swim in the water and enjoy the nice beach!",
				"next": null,
				"quest_trigger": "give_diving_suit"
			}
		],
		"too_poor": [
			{
				"text": "Ooh looks like you're a bit short there bud! How about you save up a bit more and then I can help you hit the BIG leagues.",
				"next": null
			}
		],
		"declined": [
			{
				"text": "Ah well, swimming isn't for everyone!!",
				"next": null
			}
		],
		"offer_swim": [
			{
				"text": [
					"Back for more?! There you go! Well, what're you waiting for, the water's calling for you!",
					"There you are! Ready to make some waves?!",
					"Hey! Perfect timing, the tide's just right for it!"
				],
				"next": "offer_swim2",
				"immersive": true
			}
		],
		"offer_swim2": [
			{
				"text": "Same deal as always... $250 and I'll let you loose out there. Cheap for what you're getting, trust me!",
				"choices": [
					{ "label": "Yes", "condition": "has_250", "next_true": "swim_start", "next_false": "swim_too_poor" },
					{ "label": "No", "next": "swim_declined" }
				]
			}
		],
		"swim_start": [
			{
				"text": "THAT'S THE SPIRIT CHAMP! Go get 'em! Watch your stamina out there, and mind the dark spots!",
				"next": null,
				"quest_trigger": "start_swim_session"
			}
		],
		"swim_too_poor": [
			{
				"text": "Ooh, tapped out huh? Go scrounge up some cash, the water's not going anywhere!",
				"next": null
			}
		],
		"swim_declined": [
			{
				"text": "No? Aw, come on, live a little! ...Suit yourself. Get it? HA! Come back whenever!",
				"next": null
			}
		],
		"idle_chatter": [
			{
				"text": [
					"How's swimming turning out for ya?",
					"Remember to conserve your stamina!",
					"Remember to look out for dark spots in the water!",
					"You know, in MY day, we didn't need fancy suits to swim. Kids these days.",
					"I practically INVENTED the backstroke. Don't quote me on that.",
					"Best part of the job? Watching you all splash around out there. Great stuff."
				],
				"next": null
			}
		]
	}
	
	default_trees = [
		"offer_suit",
		"idle_chatter"
	]
	super._ready()

func _evaluate_condition(condition: String) -> bool:
	match condition:
		"suit_not_owned":
			return not Game.upgrades.has_item(Catalog.get_item(39))
		"has_1000":
			return Game.balance >= 1000
		"has_250":
			return Game.balance >= 250
		"never_swam":
			return Game.swims <= 0
		_:
			return true

func _on_quest_triggered(quest_id: String) -> void:
	match quest_id:
		"give_diving_suit":
			Network.request_give_diving_suit.rpc_id(1)
		"start_swim_session":
			Network.request_start_swim_session.rpc_id(1)
