@tool
extends CanvasItem

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		visible = false
	else:
		visible = true
