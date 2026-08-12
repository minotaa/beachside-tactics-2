extends Node

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("Removing Main Menu...")
		get_node("Main Menu").queue_free()
		var arguments = OS.get_cmdline_args()
		for arg in arguments:
			if arg.split("=")[0] == "--port":
				Network.PORT = arg.split("=")[1].to_int()
				print("Changed port to " + str(Network.PORT) + ".")
		print("Attempting to start a server now...")
		var res = await Network.host_server(Network.PORT)
		if not res:
			print("For some reason, couldn't start a server.")
		else:
			print("Started a server with port " + str(Network.PORT))
