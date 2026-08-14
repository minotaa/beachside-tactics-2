extends Node2D

var trap: int
var float_timer: float = 0.0

signal trap_updated

func _process(delta: float) -> void:
	float_timer += delta
	$Sprite2D.texture = Catalog.get_item(trap).submerged_texture
	$Sprite2D.position.y = 1.0 * sin(float_timer)
	$InteractionMark.visible = false
	$InteractionMark/Fish.visible = false
	#if inventory.total_size() >= trap.space:
		#$InteractionMark.visible = true
		#$InteractionMark/Fish.visible = true
