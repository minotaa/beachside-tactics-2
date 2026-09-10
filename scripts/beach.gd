extends Level

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") and Game.get_player() != null and body == Game.get_player():
		body.do_slight_glitch()

func _on_void_music_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") and Game.get_player() != null and body == Game.get_player():
		Game.play_music("res://assets/sounds/VoidFishing.wav", -10)
		var sfx_idx := AudioServer.get_bus_index("SFX")
		var tween := create_tween()
		tween.tween_method(func(db): AudioServer.set_bus_volume_db(sfx_idx, db), AudioServer.get_bus_volume_db(sfx_idx), -15.0, 1.0)

func _on_void_music_body_exited(body: Node2D) -> void:
	Game.stop_music()
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var tween := create_tween()
	tween.tween_method(func(db): AudioServer.set_bus_volume_db(sfx_idx, db), AudioServer.get_bus_volume_db(sfx_idx), 0.0, 1.0)
