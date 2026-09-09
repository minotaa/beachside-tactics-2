extends Node2D
class_name Level

var canvas_modulate: CanvasModulate

func _ready() -> void:
	if get_node("CanvasModulate") != null:
		canvas_modulate = $CanvasModulate
		canvas_modulate.show()

func _process(_delta: float) -> void:
	if canvas_modulate:
		canvas_modulate.color = Game.get_sky_color()
