extends Node2D

func _on_play_pressed() -> void:
	var res = await Network.host_server(6466)
	if not res:
		await Network.join_server("localhost", "miboba")
	else:
		Game.start_game()
