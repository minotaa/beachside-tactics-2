extends Node

var PORT: int = 6466
const DEFAULT_SERVER_IP: String = "127.0.0.1"
const MAX_PLAYERS: int = 9

var players = []
var player_name: String
var dev_mode: bool = false
var eos_is_initialized: bool = false

signal player_joined(peer_id)
signal update_players(players)
signal player_quit(peer_id)

func _ready() -> void:
	var arguments = OS.get_cmdline_args()
	for arg in arguments:
		if arg == "--dev":
			dev_mode = true
			print("Dev mode detected.")
			HLog.log_level = HLog.LogLevel.DEBUG
	if not dev_mode:
		HLog.log_level = HLog.LogLevel.OFF

	var init_opts = EOS.Platform.InitializeOptions.new()
	init_opts.product_name = "Beachside Tactics 2"
	init_opts.product_version = ProjectSettings.get_setting("application/config/version")
	
	var create_opts = EOS.Platform.CreateOptions.new()
	create_opts.product_id = "95e7c7c607d4454b9bf070c182046321"
	create_opts.sandbox_id = "07224f56fe8c47d6b77c95a4a2ad6c25"
	create_opts.deployment_id = "3b3aeaa4d41e4f7fa83da7a662ccbe03"
	create_opts.client_id = "xyza7891ILDMPf56HBdlWJq54FXe1W33"
	create_opts.client_secret = "GNyxFinWoIaDf3vSiKQZfjZSXSEkqltzGnHpcII2apM"

	# openssl rand -hex 64
	create_opts.encryption_key = "86b50e0ce5e8643fed3f15a1f2b521215afef6241e13c63435a673cd760390f62d987e5f257aa15ec5f891729312fe8d944c6230aaa9c7a14a713b324224d272"

	HAuth.auth_login_flags = EOS.Auth.LoginFlags.None

	# enable overlay on windows only for some reason??
	if OS.get_name() == "Windows":
		create_opts.flags = EOS.Platform.PlatformFlags.WindowsEnableOverlayOpengl

	# set up SDK
	var init_res := await HPlatform.initialize_async(init_opts)
	if not EOS.is_success(init_res):
		printerr("Failed to initialize EOS SDK: ", EOS.result_str(init_res))
		# TODO: consequences
		return
	
	var create_success := await HPlatform.create_platform_async(create_opts)
	if not create_success:
		printerr("Failed to create EOS Platform")
		# TODO: consequences
		return

	# Setup Logs from EOS
	HPlatform.log_msg.connect(_on_eos_log_msg)
	# This will control which logs you get from EOS SDK
	var log_res := HPlatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Verbose)
	if not EOS.is_success(log_res):
		printerr("Failed to set logging level")
		# TODO: consequences
		return

	HAuth.logged_in.connect(_on_eos_logged_in)
	HAuth.logged_in_connect.connect(_on_eos_logged_in)

	print("Logged into EOS.")
	eos_is_initialized = true

	HAuth.display_name_changed.connect(_eos_display_name_changed)

func _eos_display_name_changed():
	print("EOS Display Name has changed, it's now " + HAuth.display_name + ".")
	#Toast.add("Your username has been changed to: " + HAuth.display_name)

func _on_eos_logged_in():
	print("EOS logged in successfully: product_user_id=%s" % HAuth.product_user_id)

func _on_eos_log_msg(msg: EOS.Logging.LogMessage) -> void:
	print("SDK %s | %s" % [msg.category, msg.message])
	if msg.category == "[ERROR]":
		Toast.add(msg.message)

# conn funcs

func join_server(address: String, username: String = "Player") -> bool:
	if not username.is_valid_identifier():
		username = "Player"
	player_name = username
	if address == "localhost":
		address = "127.0.0.1"
	var split_address = address.split(":")
	var valid_address: String
	var port: int
	if split_address.size() == 1:
		valid_address = split_address[0]
		port = PORT
	elif split_address.size() > 2:
		print("Too many address segments")
		return false
	else:
		valid_address = split_address[0]
		port = split_address[1].to_int()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(valid_address, port)
	print("Connecting to " + valid_address + ":" + str(port))
	if error != OK:
		print("Error occurred while connecting: " + str(error))
		return false

	multiplayer.multiplayer_peer = peer
	multiplayer.server_disconnected.connect(server_disconnected)
	multiplayer.connection_failed.connect(connection_failed)

	# Wait a moment for connection to establish
	var ticks = 0
	var max_ticks = 50 # 5 seconds 
	while multiplayer.multiplayer_peer != null and (not multiplayer.multiplayer_peer.get_connection_status() == 2 or multiplayer.get_unique_id() == 1):
		if ticks >= max_ticks:
			Toast.add("Timed out.")
			print("Timed out, reached maximum ticks.")
			return false
		print("Stalling...")
		ticks += 1
		await get_tree().create_timer(0.1).timeout

	if multiplayer.multiplayer_peer == null:
		return false

	print("[" + str(multiplayer.get_unique_id()) + "] Connected to the server")
	return true
	
func host_server(port: int) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("Error while starting server: " + str(error))
		Toast.add("An error occurred while starting server.")
		return false

	print("Created server with IP " + DEFAULT_SERVER_IP + " on port " + str(PORT))
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_player_joined)
	multiplayer.peer_disconnected.connect(_player_quit)

	# Host joins as ID 1
	players.append({
		"id": 1,
		"username": player_name
	})
	update_players.emit(players)

	return true

# server funcs
@rpc("authority", "call_local", "reliable")
func broadcast_players(new_list: Array) -> void:
	players = new_list
	update_players.emit(players)

@rpc("authority", "call_local", "reliable")
func server_player_joined(id: int) -> void:
	print("[" + str(multiplayer.get_unique_id()) + "] [client] Player joined: " + str(id))
	player_joined.emit(id)

@rpc("authority", "call_local", "reliable")
func server_player_quit(id: int) -> void:
	print("[" + str(multiplayer.get_unique_id()) + "] [client] Player quit: " + str(id))
	player_quit.emit(id)
	

# client funcs
func _player_joined(id: int) -> void:
	print("[server] Player joined with ID " + str(id))
	server_player_joined.rpc(id)

func _player_quit(id: int) -> void:
	print("[server] Player quit with ID " + str(id))
	for player in players:
		if str(player["id"]) == str(id):
			Toast.add.rpc(player["username"] + " left the server!")
	players = players.filter(func(p): return p["id"] != id)
	broadcast_players.rpc(players)
	player_quit.emit(id)
	server_player_quit.rpc(id)

func server_disconnected() -> void:
	print("Disconnected from server")
	Toast.add("Disconnected from the server.")
	multiplayer.server_disconnected.disconnect(server_disconnected)
	multiplayer.connection_failed.disconnect(connection_failed)
		
func connection_failed() -> void:
	print("Connection failed")
	Toast.add("Connection failed.")
	multiplayer.server_disconnected.disconnect(server_disconnected)
	multiplayer.connection_failed.disconnect(connection_failed)
