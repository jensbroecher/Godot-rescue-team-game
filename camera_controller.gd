extends Camera3D

@export var follow_distance: float = 10.5
@export var follow_height: float = 7.0
@export var follow_speed: float = 3.0
@export var isometric_angle: float = 45.0
@export var trailing_strength: float = 0.25
@export var max_trail_distance: float = 5.0

var target: Node3D
var target_position: Vector3

func _ready() -> void:
	target = get_parent().get_node("helicopter")
	if target == null:
		push_error("Helicopter not found!")
		return
	target_position = target.global_position

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var angle_rad = deg_to_rad(isometric_angle)
	var base_pos = target.global_position + Vector3(
		follow_distance * cos(angle_rad),
		follow_height,
		follow_distance * sin(angle_rad)
	)
	var trail_offset = Vector3.ZERO
	if target is CharacterBody3D:
		var t_vel = (target as CharacterBody3D).velocity
		trail_offset = -t_vel * trailing_strength
		if trail_offset.length() > max_trail_distance:
			trail_offset = trail_offset.normalized() * max_trail_distance
	var desired_pos = base_pos + trail_offset
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	look_at(target.global_position + Vector3(0, 2, 0), Vector3.UP)
