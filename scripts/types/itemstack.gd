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

func to_data() -> Dictionary:
	return {
		"id": type.id,
		"amount": amount,
		"data": data
	}

static func from_data(net_data: Dictionary) -> ItemStack:
	var stack = ItemStack.new(Catalog.get_item(net_data["id"]), net_data["amount"])
	stack.data = net_data.get("data", {})
	return stack
