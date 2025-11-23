extends Control

func _ready() -> void:
	var btn = $CenterContainer/VBoxContainer/StartButton
	if btn:
		btn.connect("pressed", Callable(self, "_on_start_button_pressed"))
		print("Title screen: Start button connected")
	else:
		push_error("Start button not found on title screen")
	var settings_btn = $CenterContainer/VBoxContainer/SettingsButton
	if settings_btn:
		settings_btn.connect("pressed", Callable(self, "_on_settings_button_pressed"))
	

func _on_start_button_pressed() -> void:
	print("Start pressed - changing to Stage1")
	var err = get_tree().change_scene_to_file("res://Stage1.tscn")
	if err != OK:
		push_error("Failed to change scene to Stage1.tscn: %s" % err)

func _on_settings_button_pressed() -> void:
	var err = get_tree().change_scene_to_file("res://settings_menu.tscn")
	if err != OK:
		push_error("Failed to change scene to settings_menu.tscn: %s" % err)
