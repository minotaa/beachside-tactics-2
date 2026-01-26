extends Object
class_name ItemStack

var amount: int = 0
var type: ItemType
var data = {}

func _to_string() -> String:
	# add a dev mode option
	return str(amount) + "x " + type.name #+ " " + str(data) 

func _init(itemType: ItemType, amt: int = 1) -> void:
	amount = amt
	type = itemType
