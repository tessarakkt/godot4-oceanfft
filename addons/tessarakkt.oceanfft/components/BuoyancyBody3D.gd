extends RigidBody3D
class_name BuoyancyBody3D


@export var buoyancy_multiplier := 1.0


var buoyancy_probes:Array[BuoyancyProbe3D] = []
var ocean:Ocean3D


func _ready() -> void:
	ocean = get_ocean()
	
	for probe in $BuoyancyProbes.get_children():
		buoyancy_probes.append(probe)
		probe.ocean = ocean


func _physics_process(delta:float) -> void:
	var gv:Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	
	for probe in buoyancy_probes:
		var depth:float = clamp((probe.global_position.y - ocean.get_wave_height(probe.global_position)), -10000.0, 0.0)
		var buoyancy = pow(abs(depth), 1.5)
		
		if depth < 0.0:
			var old_y := probe.position.y
			probe.position.y = 0.0
			apply_force(buoyancy * -gv * buoyancy_multiplier * delta, probe.global_position - global_position)
			probe.position.y = old_y


## Return the Ocean3D object used for buoyancy calculations.
## Return null if no ocean is found.
## TODO: This is not a good way of doing this
func get_ocean() -> Ocean3D:
	var oceans = get_tree().get_nodes_in_group("ocean")
	
	if oceans.size() > 0 and oceans[0] is Ocean3D:
		return oceans[0]
	
	return null
