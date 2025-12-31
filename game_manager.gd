extends Node3D

var helicopter: CharacterBody3D
var ship_landing_area: Area3D
var game_over_panel: Control
var fuel_bar: ProgressBar
var fuel_label: Label
var restart_button: Button
var menu_button: Button

var ocean: MeshInstance3D
var cloud_plane: MeshInstance3D
var mission_warning_panel: Control

var score: int = 0
var score_label: Label
var altitude_label: Label

func _ready() -> void:
	helicopter = get_node_or_null("helicopter")
	if helicopter == null:
		var root := self
		helicopter = root.find_child("helicopter", true, false)
	# ship node is not needed directly; we use the LandingArea under Ship for detection
	game_over_panel = $UI/GameOverPanel
	game_over_panel = $UI/GameOverPanel
	fuel_bar = $UI/FuelBar/ProgressBar
	fuel_label = $UI/FuelBar/FuelLabel
	
	# UI Setup - Fuel Gauge
	if fuel_bar:
		fuel_bar.show_percentage = false
	if fuel_label and fuel_bar:
		# Ensure label is on top of bar visually by reparenting if needed
		if fuel_label.get_parent() != fuel_bar:
			fuel_label.reparent(fuel_bar)
			
		# Reset position and set size to match parent
		fuel_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Force alignment
		fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fuel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fuel_label.position = Vector2.ZERO
		fuel_label.size = fuel_bar.size # Explicitly check size
			
	# UI Setup - Altitude Label
	altitude_label = Label.new()
	$UI/FuelBar.add_child(altitude_label)
	# Shift text further right to prevent overlap. Bar width is 200.
	altitude_label.position = Vector2(230, 28) 
	altitude_label.text = "ALT: 0"
	
	restart_button = $UI/GameOverPanel/CenterContainer/VBoxContainer/RestartButton
	menu_button = $UI/GameOverPanel/CenterContainer/VBoxContainer/MenuButton
	menu_button = $UI/GameOverPanel/CenterContainer/VBoxContainer/MenuButton
	mission_warning_panel = $UI/MissionWarning
	score_label = $UI/ScoreLabel
	update_score_ui()
	
	if helicopter != null:
		helicopter.fuel_changed.connect(_on_fuel_changed)
		helicopter.helicopter_crashed.connect(_on_helicopter_crashed)
		helicopter.mission_area_warning.connect(_on_mission_warning)
	
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# Set up ship landing detection (Area3D under Ship)
	ship_landing_area = $Ship/LandingArea
	if ship_landing_area:
		ship_landing_area.body_entered.connect(_on_ship_body_entered)
		# FIXED: Don't force position reset so we can move it in editor
		# var target_pos := ship_landing_area.global_transform.origin
		# if helicopter != null:
		# 	helicopter.global_transform = Transform3D(helicopter.global_transform.basis, target_pos)
		# 	helicopter.velocity = Vector3(0, -2.0, 0)
		# 	if helicopter.has_method("align_to_ground"):
		# 		helicopter.align_to_ground(20.0)
		# 	if helicopter.has_method("set_mission_start"):
		# 		helicopter.set_mission_start(helicopter.global_position)
		if helicopter != null and helicopter.has_method("set_mission_start"):
			helicopter.set_mission_start(helicopter.global_position)

	_setup_collision_for_named_nodes()

	_setup_collision_for_named_nodes()
	
	ocean = $Ocean if has_node("Ocean") else null
	# Note: We do not set initial instance parameters here because we will use strict material parameters in _process
	
	cloud_plane = get_node_or_null("CloudPlane")
	
	cloud_plane = get_node_or_null("CloudPlane")
	if cloud_plane == null:
		# Try looking in root just in case, though it should be a sibling in the scene usually
		cloud_plane = get_parent().find_child("CloudPlane", true, false)

func _process(delta: float) -> void:
	if helicopter != null:
		# Altitude Fading Logic
		var alt: float = helicopter.global_position.y
		var fade_start: float = 250.0
		var fade_end: float = 350.0
		var fade: float = 1.0 - clamp((alt - fade_start) / (fade_end - fade_start), 0.0, 1.0)
		
		if altitude_label:
			altitude_label.text = "ALT: %d" % int(alt)
		
		# Fade Ocean
		if ocean != null:
			var mat = ocean.get_active_material(0) as ShaderMaterial
			if mat:
				# surface_alpha handled visibility but let's be more aggressive
				mat.set_shader_parameter("surface_alpha", 0.5 * fade)
			
				# Transparency: 0.0=Opaque, 1.0=Fully Transparent (Invisible)
				var base_transparency = 0.05 
				var target_transparency = 1.0 - (1.0 - base_transparency) * fade
				mat.set_shader_parameter("transparency", target_transparency)
			
		# Fade Clouds
		if cloud_plane != null and cloud_plane.get_surface_override_material(0) != null:
			var mat: ShaderMaterial = cloud_plane.get_surface_override_material(0) as ShaderMaterial
			var base_color: Color = Color(0.9, 0.9, 0.9, 1.0) # Default whiteish
			var new_color: Color = base_color
			new_color.a = fade
			mat.set_shader_parameter("cloud_color", new_color)

		var grounded := helicopter.is_on_floor() or _helicopter_is_grounded_proximity(0.6)
		if grounded:
			# Refuel if we are on the ship (checking collision name)
			# The ship static body is named "dcol_Ship_Collision" or similar
			for i in range(helicopter.get_slide_collision_count()):
				var col = helicopter.get_slide_collision(i)
				var collider = col.get_collider()
				if collider and (collider.name.find("Ship") != -1 or collider.name.find("Carrier") != -1 or collider.name.find("dcol_") != -1):
					helicopter.refuel()
					break


func _on_fuel_changed(fuel: float, max_fuel: float) -> void:
	if fuel_bar:
		fuel_bar.value = (fuel / max_fuel) * 100.0
	if fuel_label:
		fuel_label.text = "FUEL %d%%" % int((fuel / max_fuel) * 100)

func _on_helicopter_crashed() -> void:
	game_over_panel.visible = true
	restart_button.grab_focus()
	# Do not pause the whole tree so UI buttons remain interactive
	# Helicopter itself is stopped by its own `is_crashed` flag

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://title_screen.tscn")

func _on_ship_body_entered(body: Node3D) -> void:
	if body == helicopter:
		if helicopter.is_on_floor() or _helicopter_is_grounded_proximity(0.5):
			helicopter.refuel()

func _on_mission_warning(active: bool) -> void:
	if mission_warning_panel:
		mission_warning_panel.visible = active

func add_score(amount: int) -> void:
	score += amount
	update_score_ui()

func update_score_ui() -> void:
	if score_label:
		score_label.text = "RESCUED: %d" % score



func _setup_collision_for_named_nodes() -> void:
	var to_process: Array[Node] = []
	var stack: Array[Node] = [self]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c.name.find("col_") != -1 or c.name.find("scol_") != -1 or c.name.find("sscol_") != -1 or c.name.find("dcol_") != -1:
				to_process.append(c)
	for src in to_process:
		var nm := String(src.name)
		if nm.find("sscol_") != -1:
			_build_box_static_collision_from_node(src)
		elif nm.find("scol_") != -1:
			_build_simple_static_collision_from_node(src)
		elif nm.find("dcol_") != -1:
			# FIXED: Use optimized deck generation (custom script)
			_build_deck_static_collision_from_node(src)
		else:
			_build_static_collision_from_node(src)

func _build_static_collision_from_node(source: Node) -> void:
	var parent := source.get_parent()
	if parent == null:
		return
	var sb_name := String(source.name) + "_Collision"
	var existing := parent.find_child(sb_name, false, false)
	if existing != null:
		return
	var static_body := StaticBody3D.new()
	static_body.name = sb_name
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	parent.add_child(static_body)
	static_body.global_transform = (source as Node3D).global_transform if source is Node3D else Transform3D.IDENTITY
	var meshes: Array[MeshInstance3D] = []
	var q: Array[Node] = [source]
	while q.size() > 0:
		var cur: Node = q.pop_back()
		if cur is MeshInstance3D:
			meshes.append(cur)
		for ch in cur.get_children():
			q.append(ch)
	for mi in meshes:
		if mi.mesh == null:
			continue
		var shape: Shape3D = mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var collider := CollisionShape3D.new()
		collider.shape = shape
		static_body.add_child(collider)
		collider.transform = static_body.global_transform.affine_inverse() * mi.global_transform

func _build_simple_static_collision_from_node(source: Node) -> void:
	var parent := source.get_parent()
	if parent == null:
		return
	var sb_name := String(source.name) + "_Collision"
	var existing := parent.find_child(sb_name, false, false)
	if existing != null:
		return
	var static_body := StaticBody3D.new()
	static_body.name = sb_name
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	parent.add_child(static_body)
	static_body.global_transform = (source as Node3D).global_transform if source is Node3D else Transform3D.IDENTITY
	var meshes: Array[MeshInstance3D] = []
	var q: Array[Node] = [source]
	while q.size() > 0:
		var cur: Node = q.pop_back()
		if cur is MeshInstance3D:
			meshes.append(cur)
		for ch in cur.get_children():
			q.append(ch)
	for mi in meshes:
		if mi.mesh == null:
			continue
		var shape: Shape3D = mi.mesh.create_convex_shape()
		if shape == null:
			continue
		var collider := CollisionShape3D.new()
		collider.shape = shape
		static_body.add_child(collider)
		collider.transform = static_body.global_transform.affine_inverse() * mi.global_transform

func _build_box_static_collision_from_node(source: Node) -> void:
	var parent := source.get_parent()
	if parent == null:
		return
	var sb_name := String(source.name) + "_Collision"
	var existing := parent.find_child(sb_name, false, false)
	if existing != null:
		return
	var static_body := StaticBody3D.new()
	static_body.name = sb_name
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	parent.add_child(static_body)
	static_body.global_transform = (source as Node3D).global_transform if source is Node3D else Transform3D.IDENTITY
	var meshes: Array[MeshInstance3D] = []
	var q: Array[Node] = [source]
	while q.size() > 0:
		var cur: Node = q.pop_back()
		if cur is MeshInstance3D:
			meshes.append(cur)
		for ch in cur.get_children():
			q.append(ch)
	for mi in meshes:
		if mi.mesh == null:
			continue
		var local_aabb: AABB = mi.get_aabb()
		var local_center: Vector3 = local_aabb.position + local_aabb.size * 0.5
		var box := BoxShape3D.new()
		box.size = local_aabb.size
		var collider := CollisionShape3D.new()
		collider.shape = box
		static_body.add_child(collider)
		var world_xf: Transform3D = mi.global_transform * Transform3D(Basis.IDENTITY, local_center)
		collider.transform = static_body.global_transform.affine_inverse() * world_xf
func _build_deck_static_collision_from_node(source: Node) -> void:
	var parent := source.get_parent()
	if parent == null:
		return
	var sb_name := String(source.name) + "_Collision"
	var existing := parent.find_child(sb_name, false, false)
	if existing != null:
		return
	var static_body := StaticBody3D.new()
	static_body.name = sb_name
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	parent.add_child(static_body)
	static_body.global_transform = (source as Node3D).global_transform if source is Node3D else Transform3D.IDENTITY
	var meshes: Array[MeshInstance3D] = []
	var q: Array[Node] = [source]
	while q.size() > 0:
		var cur: Node = q.pop_back()
		if cur is MeshInstance3D:
			meshes.append(cur)
		for ch in cur.get_children():
			q.append(ch)
	var faces_deck := PackedVector3Array()
	var faces_wall := PackedVector3Array()
	var inv := static_body.global_transform.affine_inverse()
	var up_thresh := 0.6
	var wall_thresh := 0.3
	for mi in meshes:
		if mi.mesh == null:
			continue
		var sc := mi.mesh.get_surface_count()
		for s in range(sc):
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.size() > 0:
				for i in range(0, idx.size(), 3):
					var a: Vector3 = verts[idx[i]]
					var b: Vector3 = verts[idx[i+1]]
					var c: Vector3 = verts[idx[i+2]]

					# FIXED: Use global coordinates for robust Up direction check
					var wa := mi.global_transform * a
					var wb := mi.global_transform * b
					var wc := mi.global_transform * c
					var n := (wb - wa).cross(wc - wa).normalized()
					var updot := n.dot(Vector3.UP)
					
					# Transform back to local space for the collision shape storage
					var la := inv * wa
					var lb := inv * wb
					var lc := inv * wc
					
					# Relaxed threshold: Capture ANY horizontal-ish surface (Floor OR Ceiling)
					# This handles inverted winding orders and slopes, while excluding vertical walls (optimization)
					if abs(updot) > wall_thresh:
						faces_deck.append_array([la, lb, lc])
					else:
						# It's a wall (vertical)
						faces_wall.append_array([la, lb, lc])
			else:
				for i in range(0, verts.size(), 3):
					var a2: Vector3 = verts[i]
					var b2: Vector3 = verts[i+1]
					var c2: Vector3 = verts[i+2]
					
					var wa2 := mi.global_transform * a2
					var wb2 := mi.global_transform * b2
					var wc2 := mi.global_transform * c2
					var n2 := (wb2 - wa2).cross(wc2 - wa2).normalized()
					var updot2 := n2.dot(Vector3.UP)
					
					var la2 := inv * wa2
					var lb2 := inv * wb2
					var lc2 := inv * wc2
					
					if abs(updot2) > wall_thresh:
						faces_deck.append_array([la2, lb2, lc2])
					else:
						faces_wall.append_array([la2, lb2, lc2])
	if faces_deck.size() > 0:
		var shape := ConcavePolygonShape3D.new()
		shape.data = faces_deck
		var collider := CollisionShape3D.new()
		collider.shape = shape
		static_body.add_child(collider)
	if faces_wall.size() > 0:
		var shape2 := ConcavePolygonShape3D.new()
		shape2.data = faces_wall
		var collider2 := CollisionShape3D.new()
		collider2.shape = shape2
		static_body.add_child(collider2)
func _helicopter_is_grounded_proximity(dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	var from := helicopter.global_position
	var to := helicopter.global_position + Vector3(0, -dist, 0)
	var params := PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = [helicopter]
	var res := space.intersect_ray(params)
	return res.size() > 0
