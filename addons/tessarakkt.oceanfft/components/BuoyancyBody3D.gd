extends RigidBody3D
class_name BuoyancyBody3D


@export_range(0.00001, 10.0) var buoyancy_multiplier := 1.0


var buoyancy_spheres:Array[BuoyancySphere3D] = []
var ocean:Ocean3D


func _ready() -> void:
	ocean = get_ocean()
	
	for sphere in $BuoyancySpheres.get_children():
		buoyancy_spheres.append(sphere)
		sphere.ocean = ocean


func _physics_process(delta:float) -> void:
	var g:float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var gv:Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	
	## Get the submerged volume for each buoyancy sphere, and the total
	var total_submerged_volume := 0.0
	for sphere in buoyancy_spheres:
		var submerged_volume := sphere.get_submerged_volume()
		total_submerged_volume += submerged_volume
	
	## Get the weighted average of the positions based on individual submerged
	## volume and total submerged volume. This position will be center of
	## buoyancy (COB).
	var center_of_buoyancy := Vector3.ZERO
	for sphere in buoyancy_spheres:
		center_of_buoyancy += (sphere.global_position - global_position) * (sphere.get_submerged_volume() / total_submerged_volume)
	
	## Calculate the total force of buoyancy which will act at the COB
	var depth := global_position.y - ocean.get_wave_height(global_position)
	var buoyancy = 997.0 * g * total_submerged_volume * -depth
	
	## Apply the buoyancy force at the COB
	if depth < 0.0:
		apply_force(buoyancy * -gv * buoyancy_multiplier * delta, center_of_buoyancy)


## Return the Ocean3D object used for buoyancy calculations.
## Return null if no ocean is found.
## TODO: This is not a good way of doing this
func get_ocean() -> Ocean3D:
	var oceans = get_tree().get_nodes_in_group("ocean")
	
	if oceans.size() > 0 and oceans[0] is Ocean3D:
		return oceans[0]
	
	return null
