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
			return 0.01
	return 100.0  # fallback

func get_fish_drop(location: Game.Location, rod_power: int) -> ItemType:
	# 10% chance to get junk instead of fish
	if randf() > 0.90:
		return get_junk(location, rod_power)
	else:
		return get_fish(location, rod_power)

func get_fish(location: Game.Location, rod_power: int) -> Fish:
	var catchable_fish = []
	var current_time := Game.time / Game.TIME_IN_DAY
	
	for item in items:
		if item is Fish:
			if item.location == location and rod_power >= item.power_needed:
				# hour_start == hour_end means always available
				var time_ok = item.hour_start == item.hour_end
				if not time_ok:
					if item.hour_start < item.hour_end:
						time_ok = current_time >= item.hour_start and current_time < item.hour_end
					else:
						# Wraps midnight e.g. 0.9 -> 0.1
						time_ok = current_time >= item.hour_start or current_time < item.hour_end
				if time_ok:
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

func get_junk(location: Game.Location, rod_power: int) -> ItemType:
	var catchable_junk = []
	for item in items:
		if item is Junk:
			if item.location == location and rod_power >= item.power_needed:
				catchable_junk.append(item)
	
	if catchable_junk.is_empty():
		return null
	
	var total_weight = 0.0
	for junk in catchable_junk:
		total_weight += get_rarity_weight(junk.rarity)
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	catchable_junk.shuffle()
	
	for junk in catchable_junk:
		current_weight += get_rarity_weight(junk.rarity)
		if random_value < current_weight:
			return junk
	
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
	basic_fishing_rod.purchase_limit = 1
	basic_fishing_rod.purchasable = true
	basic_fishing_rod.rarity = Game.Rarity.COMMON
	basic_fishing_rod.category = Game.Category.RODS
	basic_fishing_rod.junk_chance = 20.0
	basic_fishing_rod.price = 100.0
	basic_fishing_rod.sell_price = 10.0
	basic_fishing_rod.baitable = false
	basic_fishing_rod.data = { 
		"extra_stats": {
			"Baitable": "No",
			"Rod Power": "+1"
		}
	}
	items.append(basic_fishing_rod)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	var cod = Fish.new(1, "Cod", atlas) # IDs must iterate no matter what, even if they're on a different list, but they probably won't.
	cod.description = "A hefty, pale-fleshed fish that lurks in cool waters. Most active at dawn and dusk when the light is low."
	cod.sell_price = 20.0
	cod.power_needed = 0.0
	cod.threshold = 10.0
	cod.rarity = Game.Rarity.COMMON
	cod.category = Game.Category.FISH
	cod.location = Game.Location.Crystalwater_Beach
	cod.difficulty = Game.Difficulty.EASY
	cod.hour_start = 0.125
	cod.hour_end = 0.500
	items.append(cod)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(16.0, 0.0, 16.0, 16.0)
	var driftwood_plank = Junk.new(2, "Driftwood Plank", atlas)
	driftwood_plank.description = "A plank of wood that washed up on the shore."
	driftwood_plank.sell_price = 10.0
	driftwood_plank.category = Game.Category.JUNK
	driftwood_plank.power_needed = 0.0
	driftwood_plank.rarity = Game.Rarity.COMMON
	driftwood_plank.location = Game.Location.Crystalwater_Beach
	items.append(driftwood_plank)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(32.0, 0, 16.0, 16.0)
	var seaweed = Junk.new(3, "Seaweed", atlas)
	seaweed.description = "A clump of seaweed, your fishing rod probably scraped it off the seabed."
	seaweed.sell_price = 8.0
	seaweed.category = Game.Category.JUNK
	seaweed.power_needed = 0.0
	seaweed.rarity = Game.Rarity.COMMON
	seaweed.location = Game.Location.Crystalwater_Beach
	items.append(seaweed)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(48.0, 0.0, 16.0, 16.0)
	var red_snapper = Fish.new(4, "Red Snapper", atlas)
	red_snapper.description = "A vibrant, deep-water predator with a firm bite. Hunts confidently under the full heat of the midday sun."
	red_snapper.sell_price = 45.0
	red_snapper.power_needed = 0.0
	red_snapper.threshold = 30.0
	red_snapper.rarity = Game.Rarity.UNCOMMON
	red_snapper.category = Game.Category.FISH
	red_snapper.location = Game.Location.Crystalwater_Beach
	red_snapper.difficulty = Game.Difficulty.MEDIUM
	red_snapper.hour_start = 0.333
	red_snapper.hour_end = 0.750
	items.append(red_snapper)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(64.0, 0.0, 16.0, 16.0)
	var minnow = Fish.new(5, "Minnow", atlas)
	minnow.description = "A tiny, skittish baitfish that darts through the shallows at all hours. Never hard to find, just hard to catch in numbers."
	minnow.sell_price = 15.0
	minnow.power_needed = 0.0
	minnow.threshold = 10.0
	minnow.rarity = Game.Rarity.COMMON
	minnow.category = Game.Category.FISH
	minnow.location = Game.Location.Crystalwater_Beach
	minnow.difficulty = Game.Difficulty.EASY
	minnow.hour_start = 0.0
	minnow.hour_end = 0.0
	items.append(minnow)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(80.0, 0.0, 16.0, 16.0)
	var sea_bass = Fish.new(6, "Sea Bass", atlas)
	sea_bass.description = "A sharp-eyed, hard-fighting fish that patrols the shallows from sunrise through early afternoon before retreating to cooler depths."
	sea_bass.rarity = Game.Rarity.RARE
	sea_bass.sell_price = 100.0
	sea_bass.power_needed = 0.0
	sea_bass.difficulty = Game.Difficulty.HARD
	sea_bass.category = Game.Category.FISH
	sea_bass.location = Game.Location.Crystalwater_Beach
	sea_bass.hour_start = 0.167 
	sea_bass.hour_end = 0.667
	sea_bass.threshold = 100.0
	items.append(sea_bass)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(96.0, 0.0, 16.0, 16.0)
	var sardine = Fish.new(7, "Sardine", atlas)
	sardine.description = "A small, silver schooling fish that surges to the surface at dawn and dusk to feed on plankton."
	sardine.rarity = Game.Rarity.COMMON
	sardine.sell_price = 35.0
	sardine.power_needed = 0.0
	sardine.difficulty = Game.Difficulty.EASY
	sardine.category = Game.Category.FISH
	sardine.location = Game.Location.Crystalwater_Beach
	sardine.hour_start = 0.125
	sardine.hour_end = 0.417
	sardine.threshold = 10.0
	items.append(sardine)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(112.0, 0.0, 16.0, 16.0)
	var bream = Fish.new(8, "Bream", atlas)
	bream.description = "A flat, round fish with a cautious temperament. Feeds eagerly through the morning but disappears into the shade by noon."
	bream.rarity = Game.Rarity.UNCOMMON
	bream.sell_price = 60.0
	bream.power_needed = 0.0
	bream.difficulty = Game.Difficulty.MEDIUM
	bream.location = Game.Location.Crystalwater_Beach
	bream.category = Game.Category.FISH
	bream.hour_start = 0.167
	bream.hour_end = 0.625
	bream.threshold = 50.0
	items.append(bream)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(128.0, 0.0, 16.0, 16.0)
	var bluefish = Fish.new(9, "Bluefish", atlas)
	bluefish.description = "A fast, aggressive predator with a vicious bite. Comes alive in the late afternoon and tears through the water well into the night."
	bluefish.sell_price = 80.0
	bluefish.rarity = Game.Rarity.RARE
	bluefish.power_needed = 1.0
	bluefish.difficulty = Game.Difficulty.MEDIUM
	bluefish.location = Game.Location.Crystalwater_Beach
	bluefish.category = Game.Category.FISH
	bluefish.hour_start = 0.583
	bluefish.hour_end = 0.125
	bluefish.threshold = 200.0
	items.append(bluefish)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(144.0, 0.0, 16.0, 16.0)
	var carp = Fish.new(10, "Carp", atlas)
	carp.description = "A large, bottom-feeding fish that slowly grazes through murky water. Patient and elusive, it feeds throughout the day but is most sluggish in harsh light."
	carp.sell_price = 65.0
	carp.rarity = Game.Rarity.UNCOMMON
	carp.difficulty = Game.Difficulty.MEDIUM
	carp.location = Game.Location.Crystalwater_Beach
	carp.category = Game.Category.FISH
	carp.hour_start = 0.167
	carp.hour_end = 0.708
	carp.threshold = 20.0
	items.append(carp)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(160.0, 0.0, 16.0, 16.0)
	var eel = Fish.new(11, "Eel", atlas)
	eel.description = "A slippery, snake-like creature that hides in the mud and weeds. Almost exclusively a creature of the night."
	eel.sell_price = 100.0
	eel.rarity = Game.Rarity.RARE
	eel.difficulty = Game.Difficulty.HARD
	eel.location = Game.Location.Crystalwater_Beach
	eel.category = Game.Category.FISH
	eel.hour_start = 0.750
	eel.hour_end = 0.292
	eel.threshold = 200.0
	items.append(eel)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(176.0, 0.0, 16.0, 16.0)
	var goldfish = Fish.new(12, "Goldfish", atlas)
	goldfish.description = "A small, ornamental fish that somehow ended up in the wild. Docile and easy to catch at any hour."
	goldfish.sell_price = 40.0
	goldfish.rarity = Game.Rarity.COMMON
	goldfish.difficulty = Game.Difficulty.EASY
	goldfish.location = Game.Location.Crystalwater_Beach
	goldfish.category = Game.Category.FISH
	goldfish.hour_start = 0.0
	goldfish.hour_end = 0.0
	goldfish.threshold = 2.0
	items.append(goldfish)
