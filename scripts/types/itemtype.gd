extends Object
class_name ItemType

var name: String
var id: int
var description: String
var rarity: Game.Rarity = Game.Rarity.COMMON
var texture: Texture

var single_purchase: bool = false
var purchasable: bool = false
var price: float = 0.0
var sell_price: float = 0.0
var category: Game.Category

func _init(id: int, name: String, texture: Texture) -> void:
	self.id = id
	self.name = name
	self.texture = texture

func _to_string() -> String:
	return name + " (" + str(id) + ")"
