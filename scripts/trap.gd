extends Node2D

const BASE_CATCH_TIME = 1200.0

var location: Game.Location
var trap: Trap
var inventory = Inventory.new()
var bait_inventory = Inventory.new()
var timer = 0.0

func _ready() -> void:
	timer = BASE_CATCH_TIME

func _process(delta: float) -> void:
	var time_to_decrement = delta
	time_to_decrement += (sqrt(trap.fishing_speed) * 3.5) * 0.001
	if bait_inventory.total_size() > 0:
		time_to_decrement += (sqrt(((bait_inventory.get_item(0).type) as Bait).extra_fishing_speed) * 3.5) * 0.001
	print(delta)
	print(time_to_decrement)
	timer -= time_to_decrement
	if timer < 0.0:
		timer = BASE_CATCH_TIME
		if inventory.total_size() < trap.space:
			inventory.add_item(ItemStack.new(Catalog.get_fish(location, trap.fishing_power), 1))
	$InteractionMark.visible = false
	$InteractionMark/Fish.visible = false
	if inventory.total_size() >= trap.space:
		$InteractionMark.visible = true
		$InteractionMark/Fish.visible = true
