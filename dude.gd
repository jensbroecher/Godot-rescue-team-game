extends Sprite3D

@export var move_speed: float = 4.0
@export var approach_distance: float = 5.0
@export var helicopter_path: NodePath = "../helicopter"
@export var walking_texture: Texture2D

var helicopter: Node3D
var idle_texture: Texture2D

func _ready() -> void:
	if has_node(helicopter_path):
		helicopter = get_node(helicopter_path)
	idle_texture = texture

func _process(delta: float) -> void:
	if !helicopter:
		return
		
	# Check if helicopter is grounded
	var is_grounded = false
	if helicopter.get("was_grounded") != null:
		is_grounded = helicopter.was_grounded
	
	if is_grounded:
		var target_pos = helicopter.global_position
		var my_pos = global_position
		
		# Ignore Y difference for distance check and movement direction
		var dist_vector = Vector3(target_pos.x - my_pos.x, 0, target_pos.z - my_pos.z)
		var dist = dist_vector.length()
		
		if dist > approach_distance:
			var dir = dist_vector.normalized()
			global_position += dir * move_speed * delta
			
			if walking_texture:
				texture = walking_texture
			
			# Flip based on direction (assuming right-facing sprite)
			# If moving left (negative X relative to camera or world?), let's just check X movement
			# Actually, billboard mode makes this tricky. 
			# If billboard is enabled, the sprite always faces the camera.
			# flip_h will flip it horizontally relative to the camera view.
			# If we move "right" on screen, we want it facing right.
			
			# Simple check: if moving in positive X, face right? 
			# It depends on camera angle. But usually:
			# If the sprite is designed facing right:
			flip_h = dir.x < 0
		else:
			texture = idle_texture
	else:
		texture = idle_texture
