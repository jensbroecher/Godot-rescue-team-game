extends RigidBody3D

var water_level: float = 0.0
var fire_particles: GPUParticles3D = null
var in_water: bool = false

func _physics_process(delta: float) -> void:
	if !in_water and global_position.y < water_level:
		_enter_water()

func _enter_water() -> void:
	in_water = true
	linear_damp = 10.0 # High drag in water
	angular_damp = 10.0
	gravity_scale = 0.1 # Sinking slowly
	
	if fire_particles:
		fire_particles.emitting = false
