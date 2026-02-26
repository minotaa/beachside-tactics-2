extends Node

var dev_mode: bool = false
var eos_is_initialized: bool = false

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
