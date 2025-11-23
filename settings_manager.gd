extends Node

var resolution_options: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
var width: int = 1280
var height: int = 720
var fullscreen: bool = false
var vsync: bool = true

func _ready() -> void:
	load_settings()
	apply_settings()

func apply_settings() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(width, height))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "width", width)
	cfg.set_value("video", "height", height)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.save("user://settings.cfg")

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://settings.cfg")
	if err == OK:
		width = int(cfg.get_value("video", "width", width))
		height = int(cfg.get_value("video", "height", height))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		vsync = bool(cfg.get_value("video", "vsync", vsync))
