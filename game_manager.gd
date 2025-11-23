extends Node3D

var helicopter: CharacterBody3D
var ship_landing_area: Area3D
var game_over_panel: Control
var fuel_bar: ProgressBar
var restart_button: Button
var menu_button: Button
var ocean: MeshInstance3D

func _ready() -> void:
	helicopter = get_node_or_null("helicopter")
	if helicopter == null:
		var root := self
		helicopter = root.find_child("helicopter", true, false)
	# ship node is not needed directly; we use the LandingArea under Ship for detection
	game_over_panel = $UI/GameOverPanel
	fuel_bar = $UI/FuelBar/ProgressBar
	restart_button = $UI/GameOverPanel/CenterContainer/VBoxContainer/RestartButton
	menu_button = $UI/GameOverPanel/CenterContainer/VBoxContainer/MenuButton
	
	if helicopter != null:
		helicopter.fuel_changed.connect(_on_fuel_changed)
		helicopter.helicopter_crashed.connect(_on_helicopter_crashed)
	
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# Set up ship landing detection (Area3D under Ship)
	ship_landing_area = $Ship/LandingArea
	if ship_landing_area:
		ship_landing_area.body_entered.connect(_on_ship_body_entered)
		var target_pos := ship_landing_area.global_transform.origin
		if helicopter != null:
			helicopter.global_transform = Transform3D(helicopter.global_transform.basis, target_pos)
			helicopter.velocity = Vector3(0, -2.0, 0)
			if helicopter.has_method("align_to_ground"):
				helicopter.align_to_ground(20.0)

	_setup_collision_for_named_nodes()

	ocean = $Ocean if has_node("Ocean") else null
	if ocean != null:
		var mat := ocean.get_active_material(0)
		if mat is ShaderMaterial:
			ocean.set_instance_shader_parameter("transparency", 0.95)
			ocean.set_instance_shader_parameter("transparency_tint", 0.7)
			ocean.set_instance_shader_parameter("surface_alpha", 0.5)
			ocean.set_instance_shader_parameter("ssr_mix_strength", 0.0)
			ocean.set_instance_shader_parameter("roughness", 1.0)
			ocean.set_instance_shader_parameter("metallic", 0.0)
			ocean.set_instance_shader_parameter("ssr_screen_border_fadeout", 0.0)
			ocean.set_instance_shader_parameter("border_scale", 0.0)
			ocean.set_instance_shader_parameter("wave_height_scale", 0.15)
			ocean.set_instance_shader_parameter("wave_time_scale_a", 0.02)
			ocean.set_instance_shader_parameter("wave_time_scale_b", 0.02)
			ocean.set_instance_shader_parameter("wave_noise_scale_a", 18.0)
			ocean.set_instance_shader_parameter("wave_noise_scale_b", 18.0)

func _process(delta: float) -> void:
	if ship_landing_area != null and helicopter != null:
		var grounded := helicopter.is_on_floor() or _helicopter_is_grounded_proximity(0.6)
		if grounded:
			if ship_landing_area.overlaps_body(helicopter):
				helicopter.refuel()


func _on_fuel_changed(fuel: float, max_fuel: float) -> void:
	fuel_bar.value = (fuel / max_fuel) * 100.0

func _on_helicopter_crashed() -> void:
	game_over_panel.visible = true
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
					var wa := (mi.global_transform.basis * a) + mi.global_transform.origin
					var wb := (mi.global_transform.basis * b) + mi.global_transform.origin
					var wc := (mi.global_transform.basis * c) + mi.global_transform.origin
					var n := (wb - wa).cross(wc - wa).normalized()
					var updot := n.dot(Vector3.UP)
					var la := (inv.basis * wa) + inv.origin
					var lb := (inv.basis * wb) + inv.origin
					var lc := (inv.basis * wc) + inv.origin
					if updot > up_thresh:
						faces_deck.append_array([la, lb, lc, lc, lb, la])
					elif abs(updot) < wall_thresh:
						faces_wall.append_array([la, lb, lc, lc, lb, la])
			else:
				for i in range(0, verts.size(), 3):
					var a2: Vector3 = verts[i]
					var b2: Vector3 = verts[i+1]
					var c2: Vector3 = verts[i+2]
					var wa2 := (mi.global_transform.basis * a2) + mi.global_transform.origin
					var wb2 := (mi.global_transform.basis * b2) + mi.global_transform.origin
					var wc2 := (mi.global_transform.basis * c2) + mi.global_transform.origin
					var n2 := (wb2 - wa2).cross(wc2 - wa2).normalized()
					var updot2 := n2.dot(Vector3.UP)
					var la2 := (inv.basis * wa2) + inv.origin
					var lb2 := (inv.basis * wb2) + inv.origin
					var lc2 := (inv.basis * wc2) + inv.origin
					if updot2 > up_thresh:
						faces_deck.append_array([la2, lb2, lc2, lc2, lb2, la2])
					elif abs(updot2) < wall_thresh:
						faces_wall.append_array([la2, lb2, lc2, lc2, lb2, la2])
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
