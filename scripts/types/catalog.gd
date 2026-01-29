extends Node

func get_rarity_weight(rarity: Game.Rarity) -> float:
	match rarity:
		Game.Rarity.COMMON:
			return 1000.0
		Game.Rarity.UNCOMMON:
			return 500.0
		Game.Rarity.RARE:
			return 200.0
		Game.Rarity.EPIC:
			return 75.0
		Game.Rarity.LEGENDARY:
			return 25.0
		Game.Rarity.MYTHIC:
			return 10.0
		Game.Rarity.DIVINE:
			return 3.0
		Game.Rarity.SUPREME:
			return 1.0
		Game.Rarity.SECRET:
			return 0.1
	return 100.0  # fallback

func get_fish(location: Game.Location, rod_power: int) -> Fish:
	var catchable_fish = []
	for item in items:
		if item is Fish:
			if item.location == location and rod_power >= item.power_needed:
				catchable_fish.append(item)
	
	if catchable_fish.is_empty():
		return null
	var total_weight = 0.0
	for fish in catchable_fish:
		total_weight += get_rarity_weight(fish.rarity)
	var random_value = randf() * total_weight
	var current_weight = 0.0
	catchable_fish.shuffle()
	for fish in catchable_fish:
		current_weight += get_rarity_weight(fish.rarity)
		if random_value < current_weight:
			return fish
	return null

var items = []

func get_item(id: int) -> ItemType:
	for item in items:
		if item.id == id:
			return item
	return null

func _enter_tree() -> void:
	var atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/items.png")
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	var basic_fishing_rod = FishingRod.new(0, "Basic Fishing Rod", atlas)
	basic_fishing_rod.fishing_power = 1.0
	basic_fishing_rod.description = "The most basic fishing rod ever. You couldn't get more boring than this."
	basic_fishing_rod.single_purchase = true
	basic_fishing_rod.purchasable = true
	basic_fishing_rod.rarity = Game.Rarity.COMMON
	basic_fishing_rod.category = Game.Category.RODS
	basic_fishing_rod.junk_chance = 20.0
	basic_fishing_rod.price = 100.0
	basic_fishing_rod.sell_price = 10.0
	basic_fishing_rod.baitable = false
	items.append(basic_fishing_rod)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	var cod = Fish.new(1, "Cod", atlas) # IDs must iterate no matter what, even if they're on a different list, but they probably won't.
	cod.description = "A common fish very popular as a food choice."
	cod.sell_price = 20.0
	cod.power_needed = 0.0
	cod.rarity = Game.Rarity.COMMON
	cod.location = Game.Location.Crystalwater_Beach
	cod.difficulty = Game.Difficulty.EASY
	items.append(cod)
