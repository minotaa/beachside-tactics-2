extends Node

var dev_mode: bool = false

func _ready() -> void:
	var arguments = OS.get_cmdline_args()
	for arg in arguments:
		if arg == "--dev":
			dev_mode = true
			print("Dev mode detected.")
			HLog.log_level = HLog.LogLevel.DEBUG

	var init_opts = EOS.Platform.InitializeOptions.new()
	init_opts.product_name = "Beachside Tactics 2"
	init_opts.product_version = ProjectSettings.get_setting("application/config/version")
	
