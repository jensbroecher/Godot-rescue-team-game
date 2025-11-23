extends Control

@onready var resolution_option: OptionButton = $CenterContainer/VBoxContainer/ResolutionRow/OptionButton
@onready var fullscreen_check: CheckBox = $CenterContainer/VBoxContainer/FullscreenRow/CheckBox
@onready var vsync_check: CheckBox = $CenterContainer/VBoxContainer/VsyncRow/CheckBox
@onready var apply_button: Button = $CenterContainer/VBoxContainer/Buttons/ApplyButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/Buttons/BackButton

func _ready() -> void:
	resolution_option.clear()
	for res: Vector2i in Settings.resolution_options:
		resolution_option.add_item(str(res.x) + " x " + str(res.y))
	var idx := 0
	for i in range(resolution_option.item_count):
		var res: Vector2i = Settings.resolution_options[i]
		if res.x == Settings.width and res.y == Settings.height:
			idx = i
	resolution_option.select(idx)
	fullscreen_check.button_pressed = Settings.fullscreen
	vsync_check.button_pressed = Settings.vsync
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	resolution_option.grab_focus()

func _on_apply_pressed() -> void:
	var sel_index := resolution_option.get_selected()
	if sel_index >= 0 and sel_index < Settings.resolution_options.size():
		var res: Vector2i = Settings.resolution_options[sel_index]
		Settings.width = res.x
		Settings.height = res.y
	Settings.fullscreen = fullscreen_check.button_pressed
	Settings.vsync = vsync_check.button_pressed
	Settings.save_settings()
	Settings.apply_settings()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://title_screen.tscn")
