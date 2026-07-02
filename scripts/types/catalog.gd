extends Node

func get_rarity_weight(rarity: Game.Rarity) -> float:
	match rarity:
		Game.Rarity.COMMON:
			return 3000.0
		Game.Rarity.UNCOMMON:
			return 500.0
		Game.Rarity.RARE:
			return 100.0
		Game.Rarity.EPIC:
			return 25.0
		Game.Rarity.LEGENDARY:
			return 5.0
	return 100.0  # fallback

func get_fish_drop(location: Game.Location, rod_power: int) -> ItemType:
	# 10% chance to get junk instead of fish
	if randf() > 0.9 - Game.get_junk_chance():
		return get_junk(location, rod_power)
	else:
		return get_fish(location, rod_power)

func get_fish(location: Game.Location, rod_power: int, trap: bool = false) -> Fish:
	var catchable_fish = []
	var current_time := Game.time / Game.TIME_IN_DAY

	for item in items:
		if item is Fish:
			if item.location == location and rod_power >= item.power_needed and (trap or not item.trap_only):
				catchable_fish.append(item)

	if catchable_fish.is_empty():
		return null

	var total_weight = 0.0
	for fish in catchable_fish:
		total_weight += _get_weighted_rarity(fish, current_time)

	var random_value = randf() * total_weight
	var current_weight = 0.0
	catchable_fish.shuffle()

	for fish in catchable_fish:
		current_weight += _get_weighted_rarity(fish, current_time)
		if random_value < current_weight:
			return fish

	return null

func _get_weighted_rarity(fish: Fish, current_time: float) -> float:
	var base = get_rarity_weight(fish.rarity)
	if fish.hour_start == fish.hour_end:
		return base
	var in_peak: bool
	if fish.hour_start < fish.hour_end:
		in_peak = current_time >= fish.hour_start and current_time < fish.hour_end
	else:
		in_peak = current_time >= fish.hour_start or current_time < fish.hour_end
	return base * (2.0 if in_peak else 0.25)

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
	var basic_fishing_rod = FishingRod.new(0, "Flimsy Fishing Rod", atlas)
	basic_fishing_rod.fishing_power = 1.0
	basic_fishing_rod.description = "The most basic fishing rod ever. You couldn't get more boring than this."
	basic_fishing_rod.purchase_limit = 1
	basic_fishing_rod.purchasable = true
	basic_fishing_rod.shoddy = true
	basic_fishing_rod.rarity = Game.Rarity.COMMON
	basic_fishing_rod.category = Game.Category.RODS
	basic_fishing_rod.junk_chance = 0.0
	basic_fishing_rod.price = 100.0
	basic_fishing_rod.sell_price = 10.0
	basic_fishing_rod.baitable = false
	basic_fishing_rod.data = { 
		"extra_stats": {
			"Baitable": "No",
			"Rod Power": "+1",
			"Extra Junk Chance": "+0"
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
	minnow.threshold = 5.0
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
	goldfish.threshold = 5.0
	items.append(goldfish)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/items.png")
	atlas.region = Rect2(16.0, 0.0, 16.0, 16.0)
	var bamboo_fishing_rod = FishingRod.new(13, "Bamboo Fishing Rod", atlas)
	bamboo_fishing_rod.fishing_power = 5.0
	bamboo_fishing_rod.description = "A rod of delicate, but crude and simplistic construction, much more better than that Flimsy Fishing Rod."
	bamboo_fishing_rod.purchase_limit = 1
	bamboo_fishing_rod.purchasable = true
	bamboo_fishing_rod.rarity = Game.Rarity.COMMON
	bamboo_fishing_rod.category = Game.Category.RODS
	bamboo_fishing_rod.junk_chance = 10.0
	bamboo_fishing_rod.price = 500.0
	bamboo_fishing_rod.sell_price = 10.0
	bamboo_fishing_rod.baitable = false
	bamboo_fishing_rod.shoddy = true
	bamboo_fishing_rod.data = { 
		"extra_stats": {
			"Baitable": "No",
			"Rod Power": "+5",
			"Extra Junk Chance": "+10"
		}
	}
	items.append(bamboo_fishing_rod)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/items.png")
	atlas.region = Rect2(32.0, 0.0, 16.0, 16.0)
	var decent_fishing_rod = FishingRod.new(14, "Decent Fishing Rod", atlas)
	decent_fishing_rod.fishing_power = 12.5
	decent_fishing_rod.description = "A fishing rod of decent construction, has a grip and can also attach bait!"
	decent_fishing_rod.purchase_limit = 1
	decent_fishing_rod.purchasable = true
	decent_fishing_rod.rarity = Game.Rarity.UNCOMMON
	decent_fishing_rod.category = Game.Category.RODS
	decent_fishing_rod.junk_chance = 20.0
	decent_fishing_rod.price = 2000.0
	decent_fishing_rod.sell_price = 125.0
	decent_fishing_rod.baitable = true
	decent_fishing_rod.shoddy = false
	decent_fishing_rod.data = { 
		"extra_stats": {
			"Baitable": "Yes",
			"Rod Power": "+12.5",
			"Extra Junk Chance": "+20"
		}
	}
	items.append(decent_fishing_rod)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/bait.png")
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	var worms = Bait.new(15, "Worms", atlas)
	worms.category = Game.Category.BAIT
	worms.rarity = Game.Rarity.COMMON
	worms.purchasable = true
	worms.extra_fishing_speed = 25.0
	worms.extra_quick_bite = 0.0
	worms.description = "A common and effective bait used to attract a variety of fish."
	worms.price = 10.0
	worms.data = { 
		"extra_stats": {
			"Fishing Speed": "+25",
			"Quick Bite": "+0"
		}
	}
	items.append(worms)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(192.0, 0.0, 16.0, 16.0)
	var anchovy = Fish.new(16, "Anchovy", atlas)
	anchovy.description = "A tiny, glittering fish that moves in dense schools near the surface. Out in force whenever the sun's up, vanishes the moment it sets."
	anchovy.sell_price = 12.0
	anchovy.rarity = Game.Rarity.COMMON
	anchovy.difficulty = Game.Difficulty.EASY
	anchovy.location = Game.Location.Crystalwater_Beach
	anchovy.category = Game.Category.FISH
	anchovy.hour_start = 0.25
	anchovy.hour_end = 0.75
	anchovy.threshold = 5.0
	anchovy.power_needed = 0.0
	items.append(anchovy)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(208.0, 0.0, 16.0, 16.0)
	var mullet = Fish.new(17, "Mullet", atlas)
	mullet.description = "A plain, sturdy fish that grazes along the bottom no matter the hour. Not exciting, but always there when you need it."
	mullet.sell_price = 18.0
	mullet.rarity = Game.Rarity.COMMON
	mullet.difficulty = Game.Difficulty.EASY
	mullet.location = Game.Location.Crystalwater_Beach
	mullet.category = Game.Category.FISH
	mullet.hour_start = 0.0
	mullet.hour_end = 0.0
	mullet.power_needed = 0.0
	mullet.threshold = 8.0
	items.append(mullet)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(224.0, 0.0, 16.0, 16.0)
	var flounder = Fish.new(18, "Flounder", atlas)
	flounder.description = "A flat, camouflaged fish that lies still against the seabed. Most active in the cool hours just after sunrise."
	flounder.sell_price = 55.0
	flounder.rarity = Game.Rarity.UNCOMMON
	flounder.difficulty = Game.Difficulty.MEDIUM
	flounder.category = Game.Category.FISH
	flounder.location = Game.Location.Crystalwater_Beach
	flounder.hour_start = 0.125
	flounder.hour_end = 0.417
	flounder.power_needed = 0.0
	flounder.threshold = 40.0
	items.append(flounder)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(240.0, 0.0, 16.0, 16.0)
	var mackerel = Fish.new(19, "Mackerel", atlas)
	mackerel.description = "A streamlined fish that travels in fast-moving schools through open water. Bites hardest as the afternoon stretches into evening."
	mackerel.sell_price = 50.0
	mackerel.rarity = Game.Rarity.UNCOMMON
	mackerel.difficulty = Game.Difficulty.MEDIUM
	mackerel.category = Game.Category.FISH
	mackerel.location = Game.Location.Crystalwater_Beach
	mackerel.hour_start = 0.5 
	mackerel.hour_end = 0.833
	mackerel.power_needed = 0.0
	mackerel.threshold = 35.0
	items.append(mackerel)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(0.0, 16.0, 16.0, 16.0)
	var perch = Fish.new(20, "Perch", atlas)
	perch.description = "A modest fish with a taste for calmer waters. Feeds steadily from sunrise through midday before settling down."
	perch.sell_price = 45.0
	perch.rarity = Game.Rarity.UNCOMMON
	perch.difficulty = Game.Difficulty.MEDIUM
	perch.category = Game.Category.FISH
	perch.location = Game.Location.Crystalwater_Beach
	perch.hour_start = 0.167
	perch.hour_end = 0.5
	perch.power_needed = 0.0
	perch.threshold = 30.0
	items.append(perch)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(16.0, 16.0, 16.0, 16.0)
	var swordfish = Fish.new(21, "Swordfish", atlas)
	swordfish.description = "A powerful, long-billed predator that cuts through the water with surprising speed. Only surfaces when the sun is at its highest."
	swordfish.sell_price = 150.0
	swordfish.rarity = Game.Rarity.RARE
	swordfish.difficulty = Game.Difficulty.HARD
	swordfish.category = Game.Category.FISH
	swordfish.location = Game.Location.Crystalwater_Beach
	swordfish.hour_start = 0.375 
	swordfish.hour_end = 0.625
	swordfish.power_needed = 5.0
	swordfish.threshold = 150.0
	items.append(swordfish)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(32.0, 16.0, 16.0, 16.0)
	var tuna = Fish.new(22, "Tuna", atlas)
	tuna.description = "A muscular, relentless swimmer built for distance and speed. Most active as daylight fades into night."
	tuna.sell_price = 175.0
	tuna.rarity = Game.Rarity.RARE
	tuna.difficulty = Game.Difficulty.HARD
	tuna.category = Game.Category.FISH
	tuna.location = Game.Location.Crystalwater_Beach
	tuna.hour_start = 0.625
	tuna.hour_end = 0.125
	tuna.power_needed = 5.0
	tuna.threshold = 175.0
	items.append(tuna)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(48.0, 16.0, 16.0, 16.0)
	var barracuda = Fish.new(23, "Barracuda", atlas)
	barracuda.description = "A sleek, razor-toothed hunter with a nasty temper. Patrols the dark waters at night and won't go down without a fight."
	barracuda.sell_price = 300.0
	barracuda.rarity = Game.Rarity.EPIC
	barracuda.difficulty = Game.Difficulty.HARD
	barracuda.location = Game.Location.Crystalwater_Beach
	barracuda.hour_start = 0.75
	barracuda.hour_end = 0.208
	barracuda.category = Game.Category.FISH
	barracuda.power_needed = 12.0
	barracuda.threshold = 300.0
	items.append(barracuda)
	
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/traps.png")
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	var common_trap = Trap.new(24, "Common Trap", atlas)
	common_trap.description = "A common flimsy fish trap for catching fish. Refill it with bait automatically to keep catching fish!"
	common_trap.fishing_power = 12.0
	common_trap.fishing_speed = 2.0
	common_trap.space = 3
	common_trap.bait_storage = 8
	common_trap.purchase_limit = 10
	common_trap.purchasable = true
	common_trap.rarity = Game.Rarity.COMMON
	common_trap.category = Game.Category.TRAPS
	common_trap.price = 2500
	common_trap.sell_price = 250.0
	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/submerged-traps.png")
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	common_trap.submerged_texture = atlas
	common_trap.data = { 
		"extra_stats": {
			"Space": "3",
			"Rod Power": "12.5",
			"Bait Storage": "+12",
			"Fishing Speed": "2"
		}
	}
	items.append(common_trap)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/bait.png")
	atlas.region = Rect2(16.0, 0.0, 16.0, 16.0)
	var snails = Bait.new(25, "Snails", atlas)
	snails.category = Game.Category.BAIT
	snails.rarity = Game.Rarity.COMMON
	snails.purchasable = true
	snails.extra_fishing_speed = 100.0
	snails.extra_quick_bite = 5.0
	snails.description = "A garden-variety mollusk. Helpful for attracting a larger variety of fish."
	snails.price = 100.0
	snails.data = { 
		"extra_stats": {
			"Fishing Speed": "+100",
			"Quick Bite": "+5"
		}
	}
	items.append(snails)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/bait.png")
	atlas.region = Rect2(32.0, 0.0, 16.0, 16.0)
	var peanuts = Bait.new(26, "Peanuts", atlas)
	peanuts.category = Game.Category.BAIT
	peanuts.rarity = Game.Rarity.COMMON
	peanuts.purchasable = true
	peanuts.extra_fishing_speed = 200.0
	peanuts.extra_quick_bite = 15.0
	peanuts.description = "The return. Dense, oily, and crunchy. Fish love this stuff."
	peanuts.price = 300.0
	peanuts.data = { 
		"extra_stats": {
			"Fishing Speed": "+200",
			"Quick Bite": "+15"
		}
	}
	items.append(peanuts)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/items.png")
	atlas.region = Rect2(48.0, 0.0, 16.0, 16.0)
	var turtle_fishing_rod = FishingRod.new(27, "Turtle Rod", atlas)
	turtle_fishing_rod.fishing_power = 100.0
	turtle_fishing_rod.description = "Shelly's old fishing rod, designed with turtle coloring."
	turtle_fishing_rod.purchase_limit = 1
	turtle_fishing_rod.purchasable = true
	turtle_fishing_rod.rarity = Game.Rarity.UNCOMMON
	turtle_fishing_rod.category = Game.Category.RODS
	turtle_fishing_rod.junk_chance = 25.0
	turtle_fishing_rod.price = 5000.0
	turtle_fishing_rod.sell_price = 125.0
	turtle_fishing_rod.baitable = true
	turtle_fishing_rod.shoddy = false
	turtle_fishing_rod.data = { 
		"extra_stats": {
			"Baitable": "Yes",
			"Rod Power": "+100",
			"Extra Junk Chance": "+25",
			"Turtle": "Yes"
		}
	}
	items.append(turtle_fishing_rod)

	atlas = AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/fish.png")
	atlas.region = Rect2(64.0, 16.0, 16.0, 16.0)
	var shrimp = Fish.new(28, "Shrimp", atlas)
	shrimp.description = "A tiny little bottom feeder. A well known delicacy for its rich taste."
	shrimp.sell_price = 200.0
	shrimp.rarity = Game.Rarity.UNCOMMON
	shrimp.difficulty = Game.Difficulty.INSANE
	shrimp.trap_only = true
	shrimp.location = Game.Location.Crystalwater_Beach
	shrimp.hour_start = 0.0
	shrimp.hour_end = 0.0
	shrimp.category = Game.Category.FISH
	shrimp.power_needed = 0.0
	shrimp.threshold = 0.0
	items.append(shrimp)
