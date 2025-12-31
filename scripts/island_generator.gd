@tool
extends StaticBody3D

@export var grass_texture: Texture2D
@export var ground_texture: Texture2D
@export var sand_texture: Texture2D
@export var radius: float = 200.0:
	set(value):
		radius = value
		if is_inside_tree(): generate_island()
@export var height: float = 25.0:
	set(value):
		height = value
		if is_inside_tree(): generate_island()
@export var noise_scale: float = 0.04:
	set(value):
		noise_scale = value
		if is_inside_tree(): generate_island()
@export var noise_height: float = 15.0:
	set(value):
		noise_height = value
		if is_inside_tree(): generate_island()
@export var resolution: int = 128:
	set(value):
		resolution = value
		if is_inside_tree(): generate_island()
@export var seed_value: int = 0:
	set(value):
		seed_value = value
		if is_inside_tree(): generate_island()
@export var blend_distance: float = 8.0:
	set(value):
		blend_distance = value
		if is_inside_tree(): generate_island()
@export var texture_scale: float = 0.02:
	set(value):
		texture_scale = value
		if material: material.set_shader_parameter("texture_scale", texture_scale)
		# No need to regenerate mesh for texture scale, just shader param
@export var texture_blur: float = 5.0:
	set(value):
		texture_blur = value
		if material: material.set_shader_parameter("texture_blur", texture_blur)

@export var underwater_depth: float = 80.0:
	set(value):
		underwater_depth = value
		if is_inside_tree(): generate_island()


@export var force_update: bool = false:
	set(value):
		force_update = false # Always reset to false to act as a button
		if is_inside_tree():
			print("IslandGenerator: Force update triggered")
			generate_island()

var material: ShaderMaterial

func _ready():
	print("IslandGenerator: _ready called")
	# Load default textures if not set
	if grass_texture == null and FileAccess.file_exists("res://textures/grass-texture.jpg"):
		grass_texture = load("res://textures/grass-texture.jpg")
	if ground_texture == null and FileAccess.file_exists("res://textures/ground-texture.jpg"):
		ground_texture = load("res://textures/ground-texture.jpg")
	if sand_texture == null and FileAccess.file_exists("res://textures/sand-texture.jpg"):
		sand_texture = load("res://textures/sand-texture.jpg")
		
	# Setup material
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/island_terrain.gdshader")
	if grass_texture: material.set_shader_parameter("grass_texture", grass_texture)
	if ground_texture: material.set_shader_parameter("ground_texture", ground_texture)
	if sand_texture: material.set_shader_parameter("sand_texture", sand_texture)
	material.set_shader_parameter("texture_scale", texture_scale)
	material.set_shader_parameter("texture_blur", texture_blur)
	
	generate_island()
	
	# Hide flat area markers in game
	if not Engine.is_editor_hint():
		for child in get_children():
			if child is MeshInstance3D and child.name != "GeneratedMesh":
				child.hide()
	
	# Make sure the generated mesh is visible in editor
	if Engine.is_editor_hint():
		var mesh_node = get_node_or_null("GeneratedMesh")
		if mesh_node:
			mesh_node.visible = true
			# We don't change owner here, as it is dynamically generated.
			# But we need to make sure it's not hidden.

func generate_island():
	print("IslandGenerator: Generating island...")
	# Ensure material exists (lazy init in case _ready hasn't run or cleared)
	if material == null:
		# Try to load defaults again or just wait for _ready?
		# Better to initialize it here if missing.
		material = ShaderMaterial.new()
		if ResourceLoader.exists("res://shaders/island_terrain.gdshader"):
			material.shader = load("res://shaders/island_terrain.gdshader")
		
		if grass_texture == null and FileAccess.file_exists("res://textures/grass-texture.jpg"):
			grass_texture = load("res://textures/grass-texture.jpg")
		if ground_texture == null and FileAccess.file_exists("res://textures/ground-texture.jpg"):
			ground_texture = load("res://textures/ground-texture.jpg")
		if sand_texture == null and FileAccess.file_exists("res://textures/sand-texture.jpg"):
			sand_texture = load("res://textures/sand-texture.jpg")
			
		if grass_texture: material.set_shader_parameter("grass_texture", grass_texture)
		if ground_texture: material.set_shader_parameter("ground_texture", ground_texture)
		if sand_texture: material.set_shader_parameter("sand_texture", sand_texture)
		material.set_shader_parameter("texture_scale", texture_scale)
		material.set_shader_parameter("texture_blur", texture_blur)

	# Clear generated children immediately to avoid conflicts
	for child in get_children():
		if child.name == "GeneratedMesh" or child.name == "GeneratedCollision":
			# Use free() instead of queue_free() in editor to ensure immediate removal
			# This prevents "pending delete" nodes from conflicting with new ones
			child.free()
	
	# Find flat areas (MeshInstance3D children that are not the generated mesh)
	var flat_areas = []
	for child in get_children():
		if child is MeshInstance3D and child.name != "GeneratedMesh":
			flat_areas.append(child)
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = noise_scale
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	
	# Generate vertices
	var step = (radius * 2.5) / resolution
	var offset = Vector2(-radius * 1.25, -radius * 1.25)
	
	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var pos_x = offset.x + x * step
			var pos_z = offset.y + z * step
			
			var dist = Vector2(pos_x, pos_z).length()
			
			# Organic shape distortion
			var angle = atan2(pos_z, pos_x)
			var radius_distortion = noise.get_noise_2d(cos(angle) * 50, sin(angle) * 50) * (radius * 0.3)
			var effective_radius = radius + radius_distortion
			
			var y = 0.0
			var uv = Vector2(float(x)/resolution, float(z)/resolution)
			
			# Base height from noise
			var h_noise = noise.get_noise_2d(pos_x, pos_z)
			
			# Falloff
			var falloff = 1.0 - smoothstep(effective_radius * 0.4, effective_radius, dist)
			
			# Natural height
			var h_natural = (height * 0.5 + h_noise * noise_height) * falloff
			
			# Steep underwater drop
			# We want it to go very deep quickly at the edges
			var border_factor = 1.0 - falloff
			h_natural -= underwater_depth * pow(border_factor, 2.0) # Quadratic drop to specified depth
			
			# Apply flattening
			var final_h = h_natural
			var blend_factor = 0.0 # 0 = grass, 1 = ground
			
			# Check against all flat areas
			for area in flat_areas:
				# Transform point to local space of the area
				var point_global = to_global(Vector3(pos_x, 0, pos_z))
				var point_local = area.to_local(point_global)
				
				# Get bounds (assuming BoxMesh or similar centered mesh)
				var aabb = area.get_aabb()
				# We work in local space, so we use the unscaled AABB size
				# The scale is handled by to_local()
				
				var p = Vector2(point_local.x, point_local.z)
				var center = Vector2(aabb.position.x + aabb.size.x/2.0, aabb.position.z + aabb.size.z/2.0)
				var b = Vector2(aabb.size.x/2.0, aabb.size.z/2.0)
				
				var d_vec = (p - center).abs() - b
				
				# If we are using a BoxMesh, get_aabb returns the unscaled size.
				# However, to_local transforms the point into the child's local space.
				# If the child is scaled (e.g. scale = (10, 1, 10)), to_local will NOT apply that scale to the input point inverse.
				# Wait, to_local(global_point) = transform.affine_inverse() * global_point
				# This includes the inverse scale.
				# So if the box is scaled up by 10, the point in local space will be scaled down by 10.
				# And the AABB is unscaled (e.g. 1x1x1).
				# So checking if point is inside AABB is correct logic for "is point inside the transformed box".
				
				# The issue might be that aabb.position is usually (-size/2, -size/2, -size/2).
				# So center should be 0,0,0 usually.
				
				# Let's debug the "flattened whole island" issue.
				# If the box is at 0,0,0 and huge, it flattens everything.
				# But if the user added a small box, maybe there's a logic error.
				
				# One possibility: The SDF calculation is wrong or the blend distance is huge relative to local space?
				# If the node is scaled, the blend distance (8.0 world units) is not scaled into local space.
				# But we are doing SDF in local space!
				# So we need to compare SDF against blend_distance converted to local space?
				# OR we should do SDF in world space.
				
				# Let's try world space SDF. It's often easier.
				# We need the box bounds in world space.
				# For an AABB box (axis aligned), we can just take the global position and scaled size?
				# But the box might be rotated.
				
				# Let's stick to local space but fix the distance comparison.
				# If the box has scale (100, 1, 100), 1 unit in local space is 100 units in world space?
				# No. 
				# Transform: Local * Scale = World (simplified).
				# World / Scale = Local.
				# So if Scale=100, World=100 -> Local=1.
				# So a blend distance of 8.0 (World) becomes 0.08 in Local space.
				
				# We need to scale the blend_distance into local space to make the smoothstep work correctly?
				# Or better: Convert the SDF distance back to world space before smoothstep.
				
				# Approximation: Multiply local distance by max scale component?
				var local_scale_xz = Vector2(area.scale.x, area.scale.z)
				# Let's just assume uniform scale for simplicity or take max.
				var scale_factor = max(area.scale.x, area.scale.z)
				
				# Calculate SDF in local space
				var q = (p - center).abs() - b
				var sdf_local = Vector2(max(q.x, 0.0), max(q.y, 0.0)).length() + min(max(q.x, q.y), 0.0)
				
				# Convert SDF to approx world distance
				var sdf_world = sdf_local * scale_factor
				
				# Target height is the box's local Y position (since box is child of island)
				var target_h = area.position.y
				
				var weight = 1.0 - smoothstep(-blend_distance, blend_distance, sdf_world)
				
				if weight > 0.0:
					# Blend height
					final_h = lerp(final_h, target_h, weight)
					# Blend texture (additively? or max?)
					blend_factor = max(blend_factor, weight)
			
			# Alpha fade based on falloff (1.0 at center, 0.0 at edges)
			# We want it to be fully opaque on the island, and fade out as it goes deep
			var alpha = smoothstep(0.0, 0.4, falloff)
			
			# Sand blending logic
			# Beach zone: from slightly below water to slightly above
			# Adjust these values based on taste.
			# Let's say beach starts at -5.0 and ends at +3.0
			# We want full sand around 0.0, fading to grass/ground higher up and sand/underwater lower down.
			var sand_start_h = -6.0
			var sand_peak_h = 1.0
			var sand_end_h = 4.0
			
			var sand_factor = 0.0
			if final_h > sand_start_h and final_h < sand_end_h:
				if final_h < sand_peak_h:
					# Fade in from water
					sand_factor = smoothstep(sand_start_h, sand_peak_h, final_h)
				else:
					# Fade out to land
					sand_factor = 1.0 - smoothstep(sand_peak_h, sand_end_h, final_h)
					
			# Also blend sand based on flatness? Maybe later. Height is good for beaches.
			
			# Encode: R=Ground Blend, G=Sand Blend, B=Unused, A=Alpha
			st.set_color(Color(blend_factor, sand_factor, 0, alpha))
			st.set_uv(uv)
			st.set_normal(Vector3(0, 1, 0))
			st.add_vertex(Vector3(pos_x, final_h, pos_z))
	
	# Generate indices
	for z in range(resolution):
		for x in range(resolution):
			var top_left = z * (resolution + 1) + x
			var top_right = top_left + 1
			var bottom_left = (z + 1) * (resolution + 1) + x
			var bottom_right = bottom_left + 1
			
			st.add_index(top_left)
			st.add_index(bottom_right)
			st.add_index(bottom_left)
			
			st.add_index(top_left)
			st.add_index(top_right)
			st.add_index(bottom_right)
	
	st.generate_normals()
	st.generate_tangents()
	
	var mesh = st.commit()
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.name = "GeneratedMesh"
	add_child(mesh_instance)
	print("IslandGenerator: Mesh created with ", mesh.get_faces().size(), " faces")
	
	# Set owner in editor so it shows in Scene Tree (helps debugging/visibility)
	if Engine.is_editor_hint() and get_tree():
		var root = get_tree().edited_scene_root
		if root:
			mesh_instance.owner = root

	# Ensure visibility (force update)
	mesh_instance.visible = true

	# Collision
	var col_shape = CollisionShape3D.new()
	col_shape.name = "GeneratedCollision"
	col_shape.shape = mesh.create_trimesh_shape()
	add_child(col_shape)
	
	if Engine.is_editor_hint() and get_tree():
		var root = get_tree().edited_scene_root
		if root:
			col_shape.owner = root
