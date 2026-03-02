extends Node2D

func _ready() -> void:
	Network.player_joined.connect(player_joined)
	Network.player_quit.connect(player_quit)

func player_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("Player (", id, ") joined.")
	await get_tree().create_timer(2.0).timeout
	print(Network.players)

func player_quit(id) -> void:
	if not multiplayer.is_server():
		return

	print("[" + str(multiplayer.multiplayer_peer.get_unique_id()) + "] Removing " + str(id) + " from the game")
	for child in get_children():
		if child.name == str(id):
			child.call_deferred("queue_free")

func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	$CanvasModulate.color = Game.get_sky_color()
