extends Level

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		body.do_slight_glitch()
