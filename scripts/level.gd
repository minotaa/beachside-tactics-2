extends Node2D

func _ready() -> void:
	Network.player_joined.connect(player_joined)
	Network.player_quit.connect(player_quit)
	if not multiplayer.has_multiplayer_peer():
		spawn_player(1)
	elif multiplayer.is_server():
		spawn_player(1)
	else:
		# Client spawns their own player when they load in
		spawn_player(multiplayer.get_unique_id())

func _player_joined(id: int) -> void:
	print("[server] Player joined with ID " + str(id))
	await get_tree().create_timer(1.0).timeout
	spawn_player(id)
	if multiplayer.is_server():
		sync_players.rpc_id(id)

@rpc("authority", "call_remote", "reliable")
func sync_players() -> void:
	await get_tree().process_frame
	for player in Network.players:
		if player["id"] != multiplayer.get_unique_id():
			spawn_player(player["id"])

func spawn_player(id: int) -> void:
	var p = preload("res://scenes/player.tscn").instantiate()
	p.name = str(id)
	call_deferred("add_child", p, true)

func player_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("Player (", id, ") joined.")
	spawn_player(id)

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
