extends CharacterBody3D

@export var run_speed: float = 6.0
@export var walk_speed: float = 3.0
@export var rotation_speed: float = 5.0
@export var gravity: float = 9.8
@export var detection_radius: float = 30.0
@export var slow_radius: float = 10.0
@export var safe_drop_height: float = 4.0

var target: Node3D
var animation_player: AnimationPlayer
var picked_up: bool = false
var visuals: Node3D

enum State { IDLE, RUNNING, WALKING, FADING }
var current_state: State = State.IDLE

func _ready() -> void:
	visuals = get_node_or_null("Visuals")
	
	# Find helicopter
	if !target:
		target = get_tree().get_first_node_in_group("helicopter")
		if !target:
			target = get_node_or_null("/root/Stage1/helicopter")
	
	animation_player = get_node_or_null("Visuals/AnimationPlayer")
	if !animation_player and visuals:
		animation_player = visuals.get_node_or_null("AnimationPlayer")
	
	if animation_player:
		# Pick random idle
		var r = randf()
		if r < 0.5 and animation_player.has_animation("HumanArmature|Man_Idle"):
			_play_anim("HumanArmature|Man_Idle")
		elif animation_player.has_animation("HumanArmature|Man_Standing"):
			_play_anim("HumanArmature|Man_Standing")
		# Fallback to existing logic if needed, but we have the names now
		elif animation_player.has_animation("mixamo.com"):
			_play_anim("mixamo.com")

func _physics_process(delta: float) -> void:
	if picked_up:
		return

	# Apply Gravity
	if !is_on_floor():
		velocity.y -= gravity * delta

	if !target:
		move_and_slide()
		return
	
	var dist = global_position.distance_to(target.global_position)
	var vertical_dist = global_position.y - target.global_position.y
	var direction = (target.global_position - global_position)
	direction.y = 0 
	
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, delta * 10.0)
			velocity.z = move_toward(velocity.z, 0, delta * 10.0)
			if dist < detection_radius and vertical_dist < safe_drop_height:
				current_state = State.RUNNING
				_play_anim("HumanArmature|Man_Run")
				
		State.RUNNING:
			if vertical_dist > safe_drop_height:
				current_state = State.IDLE
				_play_anim("HumanArmature|Man_Idle")
			elif dist < slow_radius:
				current_state = State.WALKING
				_play_anim("HumanArmature|Man_Walk")
			_move_towards_target(direction, run_speed, delta)
			
		State.WALKING:
			if vertical_dist > safe_drop_height:
				current_state = State.IDLE
				_play_anim("HumanArmature|Man_Idle")
			elif dist > slow_radius + 2.0: # Hysteresis
				current_state = State.RUNNING
				_play_anim("HumanArmature|Man_Run")
			_move_towards_target(direction, walk_speed, delta)
			
	move_and_slide()

func _move_towards_target(direction: Vector3, speed: float, delta: float) -> void:
	if direction.length() > 0.1:
		var dir_norm = direction.normalized()
		velocity.x = dir_norm.x * speed
		velocity.z = dir_norm.z * speed
		
		# Rotate towards target
		var target_look = global_position + direction
		look_at(target_look, Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0

func _play_anim(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		# Don't restart if already playing
		if animation_player.current_animation == anim_name:
			return
		animation_player.play(anim_name)
		animation_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

func _on_pickup_area_entered(body: Node3D) -> void:
	if picked_up:
		return
		
	# Check if it's the helicopter
	if body.name == "helicopter" or body.is_in_group("helicopter"):
		_pickup()

func _pickup() -> void:
	if picked_up:
		return
	picked_up = true
	current_state = State.FADING
	
	# Add score
	var gm = get_node_or_null("/root/Stage1")
	if gm and gm.has_method("add_score"):
		gm.add_score(1)
		
	# Fade out logic
	var tween = create_tween()
	# We need to fade visual children. 
	# A generic way is to modulate if possible, or opacity if materials support it.
	# Sprite3D has opacity/modulate. MeshInstance3D needs material tweaks.
	# Since these are likely standard materials from FBX, we might not have 'transparency' set to alpha.
	# A simple hack for standard materials is shrinking scale to 0.
	
	if visuals:
		tween.tween_property(visuals, "scale", Vector3.ZERO, 1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
		
	tween.finished.connect(queue_free)
