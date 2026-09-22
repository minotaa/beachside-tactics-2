extends Node2D

const RARITY_LIFETIMES := {
	Game.Rarity.COMMON: 16.0,
	Game.Rarity.UNCOMMON: 12.0,
	Game.Rarity.RARE: 9.0,
	Game.Rarity.EPIC: 6.5,
	Game.Rarity.LEGENDARY: 4.5,
}

@export var lifetime: float = 12.0
@export var min_scale: float = 0.4

var assigned_item: ItemType
var _age: float = 0.0

func _ready() -> void:
	if assigned_item:
		_apply_rarity_visuals(assigned_item)

func set_item(item: ItemType) -> void:
	assigned_item = item
	lifetime = RARITY_LIFETIMES.get(item.rarity, 12.0)
	if is_inside_tree():
		_apply_rarity_visuals(item)

func _apply_rarity_visuals(item: ItemType) -> void:
	var rarity_name = Game.Rarity.find_key(item.rarity).to_lower()
	$GPUParticles2D.texture = load("res://assets/sprites/caught-fish-" + rarity_name + ".png")
	$GPUParticles2D.restart()

func _process(delta: float) -> void:
	_age += delta
	var t = clamp(_age / lifetime, 0.0, 1.0)
	$Sprite2D.scale = Vector2(1.5, 1.5).lerp(Vector2(1.5, 1.5) * min_scale, t)
	$Sprite2D.modulate.a = 1.0 - t
	$GPUParticles2D.modulate.a = 1.0 - t
	if t >= 1.0:
		queue_free()
