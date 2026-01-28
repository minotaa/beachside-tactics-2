extends Node

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC,
	DIVINE,
	SUPREME,
	SECRET
}

enum Category {
	RODS,
	UPGRADES
}

func get_fish(location: Game.Location, rod_power: int) -> Fish:
	var catchable_fish = []
	for item in items:
		if item is Fish:
			if item.location == location and rod_power >= item.power_needed:
				catchable_fish.append(item)
	if catchable_fish.is_empty():
		return null
	return catchable_fish[randi() % catchable_fish.size()]

var items = []

func _enter_tree() -> void:
	var atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/items.png")
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	var basic_fishing_rod = FishingRod.new(0, "Basic Fishing Rod", atlas)
	basic_fishing_rod.fishing_power = 1.0
	basic_fishing_rod.description = "The most basic fishing rod ever. You couldn't get more boring than this."
	basic_fishing_rod.single_purchase = true
	basic_fishing_rod.purchasable = true
	basic_fishing_rod.category = Category.RODS
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
	cod.location = Game.Location.Crystalwater_Beach
	cod.difficulty = Game.Difficulty.EASY
	items.append(cod)
