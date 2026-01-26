extends Node

var game_loaded: bool = false

func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"

func is_desktop() -> bool:
	return not is_mobile()
	
func _enter_tree() -> void:
	load_game()
	
func load_game() -> void:
	game_loaded = true
	if not FileAccess.file_exists("user://game.april"):
		return
	var save_file: FileAccess = FileAccess.open("user://game.april", FileAccess.READ)
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue
		var data = json.get_data()
	print("Loaded save data.")
		
func get_save_data() -> Dictionary:
	return {

	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game_loaded:
			save_game("went to background")

func save_game(reason: String) -> void:
	var save_file: FileAccess = FileAccess.open("user://save.april", FileAccess.WRITE)
	save_file.store_line(JSON.stringify(get_save_data()))
	print("Saved the game. " + "(" + reason + ")")
