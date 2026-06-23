extends Node2D

const BASE_CATCH_TIME = 1200.0

var location: Game.Location
var trap: Trap
var inventory = Inventory.new()
var bait_inventory = Inventory.new()
var timer = 0.0

signal trap_updated

func _ready() -> void:
	timer = BASE_CATCH_TIME

func _process(delta: float) -> void:
	var time_to_decrement = delta
	var speed_bonus = trap.fishing_speed
	if bait_inventory.total_size() > 0:
		speed_bonus += ((bait_inventory.get_item(0).type) as Bait).extra_fishing_speed * 0.5
	time_to_decrement += (sqrt(speed_bonus) * 3.5) * 0.001
	timer -= time_to_decrement
	$Sprite2D.position.y = 1.0 * sin(timer)
	if timer < 0.0:
		timer = BASE_CATCH_TIME
		if inventory.total_size() < trap.space:
			var fish = Catalog.get_fish(location, trap.fishing_power, true)
			inventory.add_item(ItemStack.new(fish, 1))
			if bait_inventory.total_size() > 0:
				var bait_stack = bait_inventory.get_item(0)
				bait_inventory.take_item(bait_stack.type, 1)
			trap_updated.emit()
	$InteractionMark.visible = false
	$InteractionMark/Fish.visible = false
	if inventory.total_size() >= trap.space:
		$InteractionMark.visible = true
		$InteractionMark/Fish.visible = true
