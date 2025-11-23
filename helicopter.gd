extends CharacterBody3D

@export var move_speed: float = 16.0
@export var lift_speed: float = 8.0
@export var turn_speed: float = 1.5
@export var fuel_drain_rate: float = 0.5
@export var max_fuel: float = 100.0
@export var acceleration: float = 6.0
@export var deceleration: float = 8.0
@export var lift_acceleration: float = 6.0
@export var tilt_max_degrees: float = 12.0
@export var tilt_speed: float = 6.0
@export var max_altitude: float = 120.0
@export var wobble_amplitude_deg: float = 1.0
@export var wobble_frequency: float = 1.2
@export var bob_amplitude: float = 0.2
@export var bob_frequency: float = 0.8
@export var sustained_speed_multiplier_max: float = 2.0
@export var sustained_accel_rate: float = 0.4
@export var sustained_decay_rate: float = 0.7
@export var strafe_lean_degrees: float = 8.0
@export var airborne_wobble_min_height: float = 2.0
@export var airborne_wobble_multiplier: float = 1.8
@export var ground_wobble_multiplier: float = 0.0
@export var rotor_spinup_rate: float = 0.8
@export var rotor_spindown_rate: float = 0.8
@export var min_takeoff_rotor_speed: float = 0.8
@export var rotor_rotation_rate: float = 25.0
@export var landed_back_tilt_degrees: float = 3.0
@export var water_level: float = 0.0
@export var water_crash_margin: float = -0.2
@export var use_precise_collision: bool = false
@export var simple_collider_scale: Vector3 = Vector3(0.9, 0.75, 0.9)
@export var simple_collider_center_offset: Vector3 = Vector3(0.0, 0.08, 0.0)
@export var auto_align_on_ready: bool = true
@export var landing_clearance: float = 0.07
@export var grounded_clearance: float = 0.02
@export var grounded_clearance_scale: float = 0.05
@export var explosion_scene: PackedScene
@export var enable_downwash: bool = false
@export var enable_rotor_disc_blur: bool = false

var current_fuel: float = 0.0
var is_crashed: bool = false
var crashed_falling: bool = false
var crash_timer: float = 0.0
@export var crash_delay: float = 2.0
@export var gravity: float = 9.8
@export var disable_collisions_during_crash: bool = true
var collisions_disabled_after_crash: bool = false
var crash_flip_duration: float = 0.8
var crash_spin_rate: float = 4.0
var crash_flip_axis: Vector3 = Vector3(0, 0, 1)
var wobble_time: float = 0.0
var sustained_accum: float = 0.0
var last_move_dir: Vector2 = Vector2.ZERO
var rotor_speed: float = 0.0
var rotor_nodes: Array[Node3D] = []
var prev_rotor_speed: float = 0.0
var sfx_flying: AudioStreamPlayer3D
var sfx_start: AudioStreamPlayer3D
var start_ready: bool = false
var precise_collision_built: bool = false
var engines_on: bool = false
var start_sequence_in_progress: bool = false
var rotor_blur_nodes: Array[MeshInstance3D] = []
var downwash_nodes: Array[GPUParticles3D] = []
var in_safe_zone: bool = false
var sfx_crashes: Array[AudioStreamPlayer3D] = []
var sfx_watercrash: AudioStreamPlayer3D
var explosion_fx: GPUParticles3D
var splash_fx: GPUParticles3D
var fountain_fx: GPUParticles3D
var simple_box_size: Vector3 = Vector3.ZERO
var simple_box_center: Vector3 = Vector3.ZERO
var was_grounded: bool = false
var aligned_this_grounding: bool = false

signal fuel_changed(fuel: float, max_fuel: float)
signal helicopter_crashed

func _ready() -> void:
	current_fuel = max_fuel
	emit_signal("fuel_changed", current_fuel, max_fuel)
	randomize()
	rotor_nodes = _find_rotor_nodes()
	var dw1: GPUParticles3D = get_node_or_null("Rotor/Downwash")
	var dw2: GPUParticles3D = get_node_or_null("Rotor2/Downwash")
	if dw1:
		downwash_nodes.append(dw1)
	if dw2:
		downwash_nodes.append(dw2)
	safe_margin = 0.06
	floor_snap_length = 0.25
	rotor_speed = 0.0
	prev_rotor_speed = 0.0
	engines_on = false
	velocity.y = -0.5
	max_slides = 1
	if use_precise_collision:
		_build_precise_collision()
	else:
		_build_simple_body_collision()
	precise_collision_built = true
	if auto_align_on_ready and !use_precise_collision:
		_align_to_ground(20.0)
	sfx_flying = get_node_or_null("SFX_Flying")
	sfx_start = get_node_or_null("SFX_Start")
	sfx_watercrash = get_node_or_null("SFX_WaterCrash")
	var sc1: AudioStreamPlayer3D = get_node_or_null("SFX_Crash1")
	var sc2: AudioStreamPlayer3D = get_node_or_null("SFX_Crash2")
	var sc3: AudioStreamPlayer3D = get_node_or_null("SFX_Crash3")
	if sc1:
		sfx_crashes.append(sc1)
	if sc2:
		sfx_crashes.append(sc2)
	if sc3:
		sfx_crashes.append(sc3)
	for c in sfx_crashes:
		c.unit_size = 1.0
		c.bus = "Master"
	if sfx_watercrash:
		sfx_watercrash.unit_size = 1.0
		sfx_watercrash.bus = "Master"
		if sfx_flying and sfx_flying.stream:
			if sfx_flying.stream is AudioStreamMP3:
				(sfx_flying.stream as AudioStreamMP3).loop = true
			sfx_flying.volume_db = -6.0
			sfx_flying.stop()
	if sfx_start and sfx_start.stream:
		sfx_start.volume_db = -6.0
		sfx_start.stop()
	explosion_fx = get_node_or_null("ExplosionParticles")
	splash_fx = get_node_or_null("WaterSplash")
	fountain_fx = get_node_or_null("WaterFountain")

func _physics_process(delta: float) -> void:
	# If we are in the falling crash sequence, apply gravity and count down
	if crashed_falling:
		crash_timer += delta
		velocity.y -= gravity * delta
		move_and_slide()
		if disable_collisions_during_crash and !collisions_disabled_after_crash and crash_timer > 0.05:
			collision_layer = 0
			collision_mask = 0
			collisions_disabled_after_crash = true
		if crash_timer < crash_flip_duration:
			rotate(crash_flip_axis, crash_spin_rate * delta)
		if crash_timer >= crash_delay:
			# finish crash
			crashed_falling = false
			is_crashed = true
			emit_signal("helicopter_crashed")
		return

	if is_crashed:
		return


	wobble_time += delta

	# crash when entering water regardless of safe zone
	if !crashed_falling and global_position.y <= water_level + water_crash_margin:
		start_crash()
		return

	var grounded: bool = is_on_floor() or _is_ground_close(1.0)
	var joy_y_debug = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var joy_trigger_debug = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	
	# Refined input check - Trigger only for lift
	var wants_spin: bool = (
		Input.is_key_pressed(KEY_Q) or 
		Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.05 or
		Input.get_joy_axis(1, JOY_AXIS_TRIGGER_RIGHT) > 0.05
	)

	# Force print every frame to ensure visibility if something is wrong
	# print("DEBUG: Spin:", wants_spin, " TrigR:", joy_trigger_debug, " JoyY:", joy_y_debug)

	var rotor_target: float = 0.0
	if start_sequence_in_progress:
		rotor_target = 1.0
	elif engines_on:
		rotor_target = 1.0
	if grounded and !wants_spin and !start_sequence_in_progress:
		rotor_target = 0.0
	var rate: float = rotor_spinup_rate if rotor_target > rotor_speed else rotor_spindown_rate
	rotor_speed = move_toward(rotor_speed, rotor_target, rate * delta)
	if rotor_blur_nodes.size() > 0:
		var blur: float = clamp((rotor_speed - 0.6) / 0.4, 0.0, 1.0)
		for rb in rotor_blur_nodes:
			if !enable_rotor_disc_blur:
				rb.visible = false
				continue
			if rb and rb.material_override:
				rb.material_override.set_shader_parameter("blur_strength", blur)
			rb.visible = blur > 0.01
	
	# Start sequence logic
	if wants_spin and !engines_on and !start_sequence_in_progress:
		# print("STARTING ENGINES!")
		start_ready = false
		start_sequence_in_progress = true
		if sfx_start:
			sfx_start.stop()
			sfx_start.volume_db = 100.0
			sfx_start.play()
		var t = get_tree().create_timer(2.0)
		t.timeout.connect(_on_start_ready)
	var airborne := (!grounded) and (rotor_speed >= min_takeoff_rotor_speed)
	if sfx_flying:
		if airborne and start_ready and !sfx_flying.playing:
			sfx_flying.stop()
			sfx_flying.volume_db = 100.0
			sfx_flying.play()
			var tw_in = create_tween()
			tw_in.tween_property(sfx_flying, "volume_db", 100.0, 0.8)
			if sfx_start and sfx_start.playing:
				var tw_out = create_tween()
				tw_out.tween_property(sfx_start, "volume_db", -60.0, 0.8).finished.connect(_on_stop_start_sound)
		if (!airborne) and sfx_flying.playing:
			var tw_out2 = create_tween()
			tw_out2.tween_property(sfx_flying, "volume_db", -60.0, 1.2).finished.connect(_on_stop_flying_sound)
	prev_rotor_speed = rotor_speed
	if grounded and engines_on and !wants_spin and rotor_speed < 0.3:
		engines_on = false
		start_ready = false
		start_sequence_in_progress = false
		start_ready = false
	if rotor_rotation_rate > 0.0 and rotor_nodes.size() > 0:
		for rn in rotor_nodes:
			if rn != null:
				rn.rotate_y(rotor_rotation_rate * rotor_speed * delta)
	if enable_downwash and downwash_nodes.size() > 0:
		var near_ground := _is_ground_close(4.0)
		for dwn in downwash_nodes:
			if dwn == null:
				continue
			dwn.emitting = rotor_speed >= 0.6
			var ppm := dwn.process_material as ParticleProcessMaterial
			if ppm != null:
				var gstr := 4.0 + rotor_speed * 6.0
				var mult := 1.5 if near_ground else 1.0
				ppm.gravity = Vector3(0, -gstr * mult, 0)
				ppm.initial_velocity_min = 0.6 * rotor_speed
				ppm.initial_velocity_max = 1.2 * rotor_speed

	# Drain fuel only when engines running
	if engines_on and rotor_speed > min_takeoff_rotor_speed * 0.5:
		current_fuel -= fuel_drain_rate * delta
	if current_fuel < 0.0:
		current_fuel = 0.0
	emit_signal("fuel_changed", current_fuel, max_fuel)

	if current_fuel <= 0.0:
		start_crash()
		return

	var forward = -transform.basis.z.normalized()
	var horizontal_forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var right = transform.basis.x.normalized()
	var horizontal_right = Vector3(right.x, 0.0, right.z).normalized()
	var input_velocity: Vector3 = Vector3.ZERO

	# Keyboard Input
	if Input.is_key_pressed(KEY_W):
		input_velocity += horizontal_forward * move_speed
	if Input.is_key_pressed(KEY_S):
		input_velocity -= horizontal_forward * move_speed

	if Input.is_key_pressed(KEY_Q):
		if rotor_speed >= min_takeoff_rotor_speed:
			input_velocity.y += lift_speed
	if Input.is_key_pressed(KEY_E):
		input_velocity.y -= lift_speed

	if Input.is_key_pressed(KEY_SHIFT):
		if Input.is_key_pressed(KEY_A):
			input_velocity += -horizontal_right * move_speed
		if Input.is_key_pressed(KEY_D):
			input_velocity += horizontal_right * move_speed

	# Controller Input
	var deadzone: float = 0.2
	
	# Left Stick: Movement (Forward/Back/Left/Right)
	var joy_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var joy_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	
	if abs(joy_y) > deadzone:
		# Invert Y because negative axis is usually up/forward
		input_velocity += horizontal_forward * move_speed * -joy_y
		
	if abs(joy_x) > deadzone:
		input_velocity += horizontal_right * move_speed * joy_x

	# Triggers: Lift
	var trigger_right = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	var trigger_left = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	
	if trigger_right > deadzone:
		if rotor_speed >= min_takeoff_rotor_speed:
			input_velocity.y += lift_speed * trigger_right
			
	if trigger_left > deadzone:
		input_velocity.y -= lift_speed * trigger_left

	var wobble_active := engines_on && (!grounded) && (global_position.y >= airborne_wobble_min_height)
	var wobble_scale: float = airborne_wobble_multiplier if wobble_active else 0.0
	input_velocity.y += sin(wobble_time * bob_frequency) * (bob_amplitude * wobble_scale)
	if grounded and !wants_spin:
		input_velocity.y = max(input_velocity.y, 0.0)

	var hv2: Vector2 = Vector2(input_velocity.x, input_velocity.z)
	var hv_len: float = hv2.length()
	if hv_len > 0.0:
		var dir: Vector2 = hv2 / hv_len
		var dotp: float = 1.0 if last_move_dir == Vector2.ZERO else clamp(dir.dot(last_move_dir), -1.0, 1.0)
		if dotp > 0.85:
			sustained_accum = clamp(sustained_accum + sustained_accel_rate * delta, 0.0, sustained_speed_multiplier_max - 1.0)
		else:
			sustained_accum = max(sustained_accum - sustained_decay_rate * delta, 0.0)
		last_move_dir = dir
	else:
		sustained_accum = max(sustained_accum - sustained_decay_rate * delta, 0.0)

	var speed_mult: float = 1.0 + sustained_accum
	input_velocity.x *= speed_mult
	input_velocity.z *= speed_mult

	if global_position.y >= max_altitude:
		input_velocity.y = min(input_velocity.y, 0.0)

	var accel_factor = acceleration if input_velocity.length() > 0.0 else deceleration
	
	# Apply gravity if not grounded (and not in special crash sequence)
	if !grounded:
		velocity.y -= gravity * delta
	
	# Restrict horizontal movement if airborne and rotors are not spinning fast enough
	if !grounded and rotor_speed < min_takeoff_rotor_speed:
		input_velocity.x = 0
		input_velocity.z = 0
		
	velocity.x = lerp(velocity.x, input_velocity.x, accel_factor * delta)
	velocity.z = lerp(velocity.z, input_velocity.z, accel_factor * delta)
	
	# Lift logic
	if rotor_speed >= min_takeoff_rotor_speed:
		velocity.y = lerp(velocity.y, input_velocity.y, lift_acceleration * delta)
	
	if grounded and !wants_spin:
		velocity.y = move_toward(velocity.y, 0.0, lift_acceleration * 2.0 * delta)
	move_and_slide()
	if grounded and !wants_spin:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * 2.0 * delta)
	if !is_crashed and precise_collision_built:
		var slide_count := get_slide_collision_count()
		for i in range(slide_count):
			var col := get_slide_collision(i)
			var n := col.get_normal()
			var is_floor := n.dot(Vector3.UP) > 0.7
			if !in_safe_zone and !is_floor:
				start_crash()
				break

	if !Input.is_key_pressed(KEY_SHIFT):
		var rot: float = 0.0
		if Input.is_key_pressed(KEY_A):
			rot += turn_speed * delta
		if Input.is_key_pressed(KEY_D):
			rot -= turn_speed * delta
			
		# Controller Right Stick: Rotation
		var joy_rx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		if abs(joy_rx) > 0.2: # Deadzone
			rot -= turn_speed * delta * joy_rx * 2.0 # Multiplier for sensitivity
			
		if rot != 0.0:
			rotate_y(rot)

	var speed_factor = clamp(Vector3(velocity.x, 0.0, velocity.z).dot(horizontal_forward) / move_speed, -1.0, 1.0)
	var desired_tilt = 0.0 if grounded else (-tilt_max_degrees * speed_factor + sin(wobble_time * wobble_frequency) * (wobble_amplitude_deg * wobble_scale))
	rotation_degrees.x = lerp(rotation_degrees.x, desired_tilt, tilt_speed * delta)

	var lateral_factor = clamp(Vector3(velocity.x, 0.0, velocity.z).dot(horizontal_right) / move_speed, -1.0, 1.0)
	var lean_factor = lateral_factor if Input.is_key_pressed(KEY_SHIFT) else 0.0
	var desired_roll = (-strafe_lean_degrees * lean_factor) + (sin(wobble_time * wobble_frequency * 1.5) * (wobble_amplitude_deg * wobble_scale) * 0.6)
	rotation_degrees.z = lerp(rotation_degrees.z, desired_roll, tilt_speed * delta)
	if global_position.y > max_altitude:
		global_position.y = max_altitude
		if velocity.y > 0.0:
			velocity.y = 0.0
	if grounded:
		if !use_precise_collision and !wants_spin:
			_align_to_ground_soft(2.0, 0.35)
		was_grounded = true
	else:
		was_grounded = false
		aligned_this_grounding = false

func refuel() -> void:
	current_fuel = max_fuel
	emit_signal("fuel_changed", current_fuel, max_fuel)

func enter_safe_zone() -> void:
	in_safe_zone = true

func exit_safe_zone() -> void:
	in_safe_zone = false

func start_crash() -> void:
	# Begin falling sequence before final crash
	if crashed_falling or is_crashed:
		return
	# stop any ongoing rotor/start sounds
	if sfx_flying and sfx_flying.playing:
		sfx_flying.stop()
	if sfx_start and sfx_start.playing:
		sfx_start.stop()
	var at_water: bool = global_position.y < water_level + 0.2
	var epos: Vector3 = global_position + Vector3(0, 0.5, 0)
	var p_init := get_parent()
	if p_init:
		var aps_init := AudioStreamPlayer3D.new()
		aps_init.unit_size = 1.0
		aps_init.bus = "Master"
		aps_init.volume_db = 12.0
		p_init.add_child(aps_init)
		aps_init.global_transform = Transform3D(Basis.IDENTITY, epos)
		var st_path := "res://WaterCrash.mp3" if at_water else ("res://Crash%d.mp3" % (1 + int(randi() % 3)))
		var st_init := load(st_path)
		if st_init is AudioStream:
			aps_init.stream = st_init
			aps_init.play()
		var tf_init = get_tree().create_timer(3.0)
		tf_init.timeout.connect(_on_free_explosion.bind(aps_init))
		if at_water:
			if sfx_watercrash and sfx_watercrash.stream:
				sfx_watercrash.stop()
				sfx_watercrash.volume_db = -60.0
				sfx_watercrash.play()
			if splash_fx:
				splash_fx.global_position = Vector3(global_position.x, water_level, global_position.z)
				splash_fx.emitting = true
			if fountain_fx:
				fountain_fx.global_position = Vector3(global_position.x, water_level, global_position.z)
				fountain_fx.emitting = true
			epos = Vector3(global_position.x, water_level, global_position.z)
		else:
			if sfx_crashes.size() > 0:
				var idx: int = int(randi() % sfx_crashes.size())
				var player := sfx_crashes[idx]
				if player and player.stream:
					player.stop()
					player.volume_db = -60.0
					player.play()
		if explosion_scene != null:
			var inst := explosion_scene.instantiate()
			var p := get_parent()
			if p:
				p.add_child(inst)
				if inst is Node3D:
					var n3 := inst as Node3D
					n3.global_transform = Transform3D(Basis.IDENTITY, epos)
					n3.scale = Vector3(80, 80, 80)
			var t = get_tree().create_timer(3.0)
			t.timeout.connect(_on_free_explosion.bind(inst))
	# begin falling with flip and jolt
	crashed_falling = true
	crash_timer = 0.0
	collisions_disabled_after_crash = false
	if velocity.y > 0:
		velocity.y = 0
	var jx: float = randf() * 6.0 - 3.0
	var jz: float = randf() * 6.0 - 3.0
	velocity.x = jx
	velocity.y = 8.0
	velocity.z = jz
	crash_flip_axis = Vector3(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
	crash_spin_rate = abs(crash_spin_rate) * (-1.0 if randf() < 0.5 else 1.0)

func crash() -> void:
	# immediate crash (fallback)
	is_crashed = true
	emit_signal("helicopter_crashed")

func _on_start_ready() -> void:
	start_ready = true
	engines_on = true
	start_sequence_in_progress = false
	if sfx_start and sfx_start.playing:
		var tw = create_tween()
		tw.tween_property(sfx_start, "volume_db", -60.0, 0.4).finished.connect(_on_stop_start_sound)

func _build_precise_collision() -> void:
	var body := get_node_or_null("Heli Body")
	if body != null:
		_build_collision_for_node(body as Node3D, self)

func _build_collision_for_node(root_node: Node3D, attach_node: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root_node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes.append(n)
		for ch in n.get_children():
			stack.append(ch)
	for mi in meshes:
		if mi.mesh == null:
			continue
		var shape: Shape3D = mi.mesh.create_convex_shape()
		if shape == null:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		attach_node.add_child(cs)
		cs.transform = attach_node.global_transform.affine_inverse() * mi.global_transform

func _build_simple_body_collision() -> void:
	var body := get_node_or_null("Heli Body")
	if body == null:
		return
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [body]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes.append(n)
		for ch in n.get_children():
			stack.append(ch)
	var has_bounds := false
	var global_bounds := AABB()
	for mi in meshes:
		if mi.mesh == null:
			continue
		var local_aabb: AABB = mi.get_aabb()
		var p: Vector3 = local_aabb.position
		var s: Vector3 = local_aabb.size
		var xf: Transform3D = mi.global_transform
		var corners: Array[Vector3] = [
			p,
			p + Vector3(s.x, 0, 0),
			p + Vector3(0, s.y, 0),
			p + Vector3(0, 0, s.z),
			p + Vector3(s.x, s.y, 0),
			p + Vector3(s.x, 0, s.z),
			p + Vector3(0, s.y, s.z),
			p + s
		]
		var wp0: Vector3 = (xf.basis * corners[0]) + xf.origin
		var min_v: Vector3 = wp0
		var max_v: Vector3 = wp0
		for c in corners:
			var wc: Vector3 = (xf.basis * c) + xf.origin
			min_v = Vector3(min(min_v.x, wc.x), min(min_v.y, wc.y), min(min_v.z, wc.z))
			max_v = Vector3(max(max_v.x, wc.x), max(max_v.y, wc.y), max(max_v.z, wc.z))
		var world_aabb: AABB = AABB(min_v, max_v - min_v)
		if !has_bounds:
			global_bounds = world_aabb
			has_bounds = true
		else:
			global_bounds = global_bounds.merge(world_aabb)
	if !has_bounds:
		return
	var box := BoxShape3D.new()
	var scaled_size: Vector3 = Vector3(
		global_bounds.size.x * simple_collider_scale.x,
		global_bounds.size.y * simple_collider_scale.y,
		global_bounds.size.z * simple_collider_scale.z
	)
	box.size = scaled_size
	var cs := CollisionShape3D.new()
	cs.shape = box
	add_child(cs)
	var center := global_bounds.position + global_bounds.size * 0.5 + Vector3(
		global_bounds.size.x * simple_collider_center_offset.x,
		global_bounds.size.y * simple_collider_center_offset.y,
		global_bounds.size.z * simple_collider_center_offset.z
	)
	cs.transform = global_transform.affine_inverse() * Transform3D(Basis.IDENTITY, center)
	simple_box_size = scaled_size
	simple_box_center = cs.transform.origin

func _on_rotor_body_entered(body: Node) -> void:
	if is_crashed:
		return
	if body == self:
		return
	if rotor_speed > 0.2:
		start_crash()

func _is_ground_close(dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := global_position + Vector3(0, -dist, 0)
	var params := PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = [self]
	var res := space.intersect_ray(params)
	return res.size() > 0

func _align_to_ground(max_cast: float) -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var to := global_position + Vector3(0, -max_cast, 0)
	var params := PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = [self]
	var res := space.intersect_ray(params)
	if res.has("position") and simple_box_size != Vector3.ZERO:
		var hit_y := (res["position"] as Vector3).y
		var bottom_local_y := simple_box_center.y - simple_box_size.y * 0.5
		var desired_y := hit_y - bottom_local_y + landing_clearance + grounded_clearance + (simple_box_size.y * grounded_clearance_scale)
		global_position.y = desired_y
		velocity.y = 0.0

func _align_to_ground_soft(max_cast: float, alpha: float) -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var to := global_position + Vector3(0, -max_cast, 0)
	var params := PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = [self]
	var res := space.intersect_ray(params)
	if res.has("position") and simple_box_size != Vector3.ZERO:
		var hit_y := (res["position"] as Vector3).y
		var bottom_local_y := simple_box_center.y - simple_box_size.y * 0.5
		var desired_y := hit_y - bottom_local_y + landing_clearance + grounded_clearance + (simple_box_size.y * grounded_clearance_scale)
		var t: float = clampf(alpha, 0.0, 1.0)
		global_position.y = lerp(global_position.y, desired_y, t)

func align_to_ground(max_cast: float) -> void:
	_align_to_ground(max_cast)

func _on_stop_start_sound() -> void:
	if sfx_start and sfx_start.playing:
		sfx_start.stop()

func _on_stop_flying_sound() -> void:
	if sfx_flying and sfx_flying.playing:
		sfx_flying.stop()

func _find_rotor_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var candidates: Array[Node] = []
	for c in get_children():
		candidates.append(c)
	for c in candidates:
		if c is Node3D:
			var n := String(c.name).to_lower()
			if n.contains("rotor"):
				result.append(c as Node3D)
	rotor_blur_nodes.clear()
	var rb1: MeshInstance3D = get_node_or_null("Rotor/RotorBlur")
	var rb2: MeshInstance3D = get_node_or_null("Rotor2/RotorBlur")
	if rb1:
		rotor_blur_nodes.append(rb1)
	if rb2:
		rotor_blur_nodes.append(rb2)
	for rb in rotor_blur_nodes:
		rb.visible = false
	return result
func _on_free_explosion(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()
