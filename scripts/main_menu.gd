extends Node2D

func _on_play_pressed() -> void:
	var res = await Network.host_server(6466)
	if not res:
		await Network.join_server("localhost", "miboba")
	else:
		Game.start_game()

func _ready() -> void:
	$UI/Main/Settings/Fullscreen/CheckButton.button_pressed = Game.fullscreen
	$UI/Main/Settings/SFX/Slider.value = Game.sfx_volume

func _on_sfx_value_changed(value: float) -> void:
	Game.sfx_volume = value
	if Game.sfx_volume <= 0.0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
		var db_value = lerp(-55.0, 0.0, Game.sfx_volume / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db_value)

func _on_sfx_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Game.play_sfx("res://assets/sounds/catch.ogg", 0.0)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	Game.fullscreen = toggled_on
	if Game.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
