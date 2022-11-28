extends RigidBody3D
class_name BuoyancyBody3D


@export_range(0.00001, 10.0) var buoyancy_multiplier := 1.0


var buoyancy_spheres:Array[BuoyancySphere3D] = []


func _ready() -> void:
	var ocean := get_ocean()
	
	for sphere in $BuoyancySpheres.get_children():
		buoyancy_spheres.append(sphere)
		sphere.ocean = ocean


func _physics_process(delta:float) -> void:
	var gv:Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	var buoyancy := 0.0
	
	for sphere in buoyancy_spheres:
		buoyancy = sphere.simulate_buoyancy(delta) * buoyancy_multiplier * delta
		apply_force(buoyancy * -gv, sphere.position)


## Return the Ocean3D object used for buoyancy calculations.
## Return null if no ocean is found.
func get_ocean() -> Ocean3D:
	var oceans = get_tree().get_nodes_in_group("ocean")
	
	if oceans.size() > 0 and oceans[0] is Ocean3D:
		return oceans[0]
	
	return null
