extends Node2D

var _spawning: Dictionary = {}
var awaiting_request: bool = false

func _ready() -> void:
	Network.player_joined.connect(player_joined)
	Network.player_quit.connect(player_quit)
	Network.update_players.connect(player_update)
	if not multiplayer.has_multiplayer_peer():
		spawn_player(1)
	for player in Network.players:
		spawn_player(player["id"])

@rpc("authority", "call_local", "reliable")
func send_time(time: float) -> void:
	Game.time = time
		
func player_joined(id) -> void:
	spawn_player(id)
	send_time.rpc(Game.time)

func player_quit(id) -> void:
	for child in get_children():
		if child.name == str(id):
			child.call_deferred("queue_free")
	
func player_update(players) -> void:
	pass
	
func spawn_player(id: int) -> void:
	if has_node(str(id)) or _spawning.has(id):
		print("Skipping duplicate spawn for ", id)
		return
	_spawning[id] = true
	var p = preload("res://scenes/player.tscn").instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	add_child.call_deferred(p)
	await get_tree().process_frame
	_spawning.erase(id)

func _process(_delta: float) -> void:
	$CanvasModulate.color = Game.get_sky_color()
