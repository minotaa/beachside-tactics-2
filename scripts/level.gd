extends Node2D

func _process(delta: float) -> void:
	$CanvasModulate.color = Game.get_sky_color()
