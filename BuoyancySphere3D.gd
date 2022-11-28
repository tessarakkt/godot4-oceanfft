extends Marker3D
class_name BuoyancySphere3D


@export_range(0.0, 100.0) var radius := 1.0:
	set(new_radius):
		radius = new_radius
		gizmo_extents = new_radius
		_total_volume = 1.33333 * PI * pow(radius, 3.0)
@export_range(0, 10, 1) var height_sampling_steps := 3


var ocean:Ocean3D


var _total_volume := 0.0
var _velocity := Vector3.ZERO
@onready var _previous_pos := to_global(Vector3.ZERO)


func simulate_buoyancy(delta:float) -> float:
	var g:float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var global_pos := to_global(Vector3.ZERO)
	var wave_height:float = ocean.get_wave_height(global_pos, height_sampling_steps)
	var depth := global_pos.y - wave_height
	var buoyancy := 0.0
	
	_velocity = (global_pos - _previous_pos) * delta
	_previous_pos = global_pos
	
	if depth < radius:
		buoyancy = 5.0 * g * get_submerged_volume(wave_height) * -depth
	
	return buoyancy


func get_total_volume() -> float:
	return _total_volume


func get_non_submerged_volume(wave_height:float) -> float:
	var top = to_global(Vector3.ZERO).y + radius
	var non_submerged_radius = (top - wave_height) * 0.5
	
	return 1.33333 * PI * pow(non_submerged_radius, 3.0)


func get_submerged_volume(wave_height:float) -> float:
	return get_total_volume() - get_non_submerged_volume(wave_height)
