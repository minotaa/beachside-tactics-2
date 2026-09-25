extends Node2D

var selected_character = "cat0"

func _on_play_pressed() -> void:
	var username = $UI/Main/Username.text
	print($UI/Main/Settings/Character/CheckButton.selected)
	await Network.join_server("10.10.20.2", username)
	# 10.10.20.2

func _connect_button_sfx(button: Button):
	button.mouse_entered.connect(func():
		Game.play_sfx("res://assets/sounds/click.wav", -2, false, false)
	)
	button.pressed.connect(func():
		Game.play_sfx("res://assets/sounds/click1.wav", -2, false, false)
	)

func _ready() -> void:
	for button in find_children("", "Button", true):
		if button is Button:
			_connect_button_sfx(button)
	for i in range($UI/Main/Settings/Character/CheckButton.item_count):
		if $UI/Main/Settings/Character/CheckButton.get_item_text(i) == Game.body_type:
			$UI/Main/Settings/Character/CheckButton.select(i)
	$"UI/Main/Settings/Close Shop/CheckButton".button_pressed = Game.close_shop_upon_sell
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

func _on_close_shop_button_toggled(toggled_on: bool) -> void:
	Game.close_shop_upon_sell = toggled_on

func _on_check_button_item_selected(index: int) -> void:
	Game.body_type = $UI/Main/Settings/Character/CheckButton.get_item_text($UI/Main/Settings/Character/CheckButton.selected)
