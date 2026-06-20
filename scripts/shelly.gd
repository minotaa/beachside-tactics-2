extends NPC

func _ready() -> void:
	npc_name = "Shelly"
	dialogue_trees = {
		"unacknowledged": [
			{
				"text": "Hey there! You discovered some new species today!",
				"next": "reward",
				"condition": "has_unacknowledged_fish"
			}
		],
		"reward": [
			{
				"text": "Good job! You received a reward for doing so.",
				"quest_trigger": "give_bestiary_reward"
			}
		],
		"default": [
			{
				"text": [
					"Hey there! Come to check on your catches?",
					"Every fish tells a story, you know.",
					"The sea's full of surprises. Keep fishing!",
					"I've been cataloguing fish here for years. Never gets old.",
					"My husband sells the rods, I keep the records. Fair trade.",
					"You'd be surprised what's hiding in these waters.",
					"A good fisherman always checks their bestiary."
				],
				"immersive": false
			}
		]
	}
	default_trees = [
		"unacknowledged",
		"default"
	]
	super._ready()

var money_table := {
	Game.Rarity.COMMON:    50.0,
	Game.Rarity.UNCOMMON:  100.0,
	Game.Rarity.RARE:      250.0,
	Game.Rarity.EPIC:      500.0,
	Game.Rarity.LEGENDARY: 1000.0
}

var xp_table := {
	Game.Rarity.COMMON:    100.0,
	Game.Rarity.UNCOMMON:  500.0,
	Game.Rarity.RARE:      1500.0,
	Game.Rarity.EPIC:      5000.0,
	Game.Rarity.LEGENDARY: 12500.0
}

func calculate_money_earned() -> float:
	var total = 0.0
	for id in Game.bestiary:
		var catchable = Catalog.get_item(int(id))
		if catchable is Fish:
			if catchable.location == Game.Location.Crystalwater_Beach or catchable.location == Game.Location.Crystalwater_Shore:
				if Game.acknowledged_bestiary.get(id, null) == null:
					total += money_table.get(catchable.rarity)
	return total

func calculate_xp_earned() -> float:
	var total = 0.0
	for id in Game.bestiary:
		var catchable = Catalog.get_item(int(id))
		if catchable is Fish:
			if catchable.location == Game.Location.Crystalwater_Beach or catchable.location == Game.Location.Crystalwater_Shore:
				if Game.acknowledged_bestiary.get(id, null) == null:
					total += xp_table.get(catchable.rarity)
	return total
				
func get_unacknowledged_fish() -> Array:
	var to_ack = []
	for id in Game.bestiary:
		var catchable = Catalog.get_item(int(id))
		if catchable is Fish:
			if catchable.location == Game.Location.Crystalwater_Beach or catchable.location == Game.Location.Crystalwater_Shore:
				if Game.acknowledged_bestiary.get(id, null) == null:
					to_ack.append(catchable)
	return to_ack

func _evaluate_condition(condition: String) -> bool:
	match condition:
		"has_unacknowledged_fish": 
			return not get_unacknowledged_fish().is_empty() and get_unacknowledged_fish().size() >= 5
	return true

func _on_quest_triggered(quest_id: String) -> void:
	match quest_id:
		"give_bestiary_reward":
			var money = calculate_money_earned()
			var xp = calculate_xp_earned()
			Game.balance += money
			Game.add_xp(xp)
			Toast.add("You received $%s and %s XP!" % [roundi(money), roundi(xp)])

			var before = Game.inventory_upgrade_bestiary_bonus
			for id in Game.bestiary:
				Game.acknowledged_bestiary[id] = true
			Game.inventory_upgrade_bestiary_bonus = (Game.acknowledged_bestiary.size() / 5) * 5
			if Game.inventory_upgrade_bestiary_bonus > before:
				Toast.add("Your tackle box grew! +%d slots." % (Game.inventory_upgrade_bestiary_bonus - before))
