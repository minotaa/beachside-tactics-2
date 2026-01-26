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
