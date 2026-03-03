extends Node2D

var _spawning: Dictionary = {}

func _ready() -> void:
	Network.player_joined.connect(player_joined)
	Network.player_quit.connect(player_quit)
	Network.update_players.connect(player_update)
	if not multiplayer.has_multiplayer_peer():
		spawn_player(1)
	elif multiplayer.is_server():
		spawn_player(1)
	# Clients do NOTHING here — server will spawn them via player_joined signal

func player_update(_players) -> void:
	pass

func player_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("Player (", id, ") joined.")
	spawn_player(id)  # Spawn on server
	# Tell ALL clients (including the new one) about every currently spawned player
	var all_ids: Array = []
	for child in get_children():
		var pid = child.name.to_int()
		if pid != 0:
			all_ids.append(pid)
	print("Telling all clients to spawn: ", all_ids)
	sync_existing_players.rpc(all_ids)  # Broadcast to everyone

@rpc("authority", "call_remote", "reliable")
func sync_existing_players(ids: Array) -> void:
	print("sync_existing_players called, my id: ", multiplayer.get_unique_id(), " ids: ", ids)
	for id in ids:
		if id != multiplayer.get_unique_id():
			spawn_player(id)

func spawn_player(id: int) -> void:
	if has_node(str(id)) or _spawning.has(id):
		print("Skipping duplicate spawn for ", id)
		return
	_spawning[id] = true
	var p = preload("res://scenes/player.tscn").instantiate()
	p.name = str(id)
	add_child.call_deferred(p)
	await get_tree().process_frame
	_spawning.erase(id)

func player_quit(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[" + str(multiplayer.multiplayer_peer.get_unique_id()) + "] Removing " + str(id) + " from the game")
	for child in get_children():
		if child.name == str(id):
			child.call_deferred("queue_free")
	remove_player.rpc(id)

@rpc("authority", "call_remote", "reliable")
func remove_player(id: int) -> void:
	for child in get_children():
		if child.name == str(id):
			child.call_deferred("queue_free")

func _process(_delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	$CanvasModulate.color = Game.get_sky_color()
