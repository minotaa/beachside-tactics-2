extends Object
class_name Inventory

var list = []

func total_size() -> int:
	var size = 0
	for item in list:
		size += item.amount
	return size

func get_item(index: int) -> ItemStack:
	return list[index]

func get_item_stack(item: ItemType) -> ItemStack:
	for i in list:
		if i.type.id == item.id:
			return i
	return null

func add_item(item: ItemStack) -> void:
	for i in list: # Checks for existing items.
		if i.type.id == item.type.id:
			var prev = list[list.find(i)]
			prev.amount += item.amount
			return
	list.append(item)

func has_item(item: ItemType) -> bool:
	for i in list:
		if i.type.id == item.id:
			return true
	return false

func take_item(item: ItemType, amount: int) -> void:
	for i in list:
		if i.type.id == item.id:
			i.amount -= amount
			if i.amount == 0:
				list.erase(i)

func set_list_from_save(_list: Array):
	for value in _list:
		var item = ItemStack.new(Catalog.get_by_id(value.id), value.amount)
		if value.has("data"):
			item.data = value["data"]
		list.append(item)

func to_list() -> Array:
	var _list = []
	for value in list:
		if value.data.is_empty():
			_list.append({
				"id": (((value as ItemStack).type) as ItemType).id,
				"amount": (value as ItemStack).amount
			})
		else:
			_list.append({
				"id": (((value as ItemStack).type) as ItemType).id,
				"amount": (value as ItemStack).amount,
				"data": (value as ItemStack).data
			})
	return _list

func remove_item(item: ItemStack) -> void:
	list.erase(item)
	
	
