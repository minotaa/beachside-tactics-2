extends ItemType
class_name Upgrade

var max_level: int = 0
var data: Dictionary = {}
var get_benefits: Callable = func(level: int):
	return "Nothing: +1"
