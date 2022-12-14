extends Marker3D
class_name BuoyancySphere3D


@export_range(0.0, 100.0) var radius := 1.0:
	set(new_radius):
		radius = new_radius
		gizmo_extents = new_radius
		_total_volume = 1.33333 * PI * pow(radius, 3.0)
@export_range(0, 10, 1) var height_sampling_steps := 3
@export_range(0, 10, 1) var max_cascade := 1


var ocean:Ocean3D


var _total_volume := 0.0


## Get the wave height at this buoyancy sphere's location.
func get_wave_height() -> float:
	return ocean.get_wave_height(global_position, max_cascade, height_sampling_steps)


## Get the total volume of this buoyancy sphere.
func get_total_volume() -> float:
	return _total_volume


## Get the approximated non-submerged volume of this buoyancy sphere.
func get_non_submerged_volume() -> float:
	var top = global_position.y + radius
	var non_submerged_radius = (top - get_wave_height()) * 0.5
	
	return clamp(1.33333 * PI * pow(non_submerged_radius, 3.0), 0.0, _total_volume)


## Get the approximated submerged volume of this buoyancy sphere.
func get_submerged_volume() -> float:
	return get_total_volume() - get_non_submerged_volume()
