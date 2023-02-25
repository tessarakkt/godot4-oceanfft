@icon("res://addons/tessarakkt.oceanfft/icons/BuoyancyBody3D.svg")
extends RigidBody3D
class_name BuoyancyBody3D


@export var buoyancy_multiplier := 1.0
@export_range(0.5, 10.0, 0.001) var buoyancy_power := 1.5
@export var ocean:Ocean3D


var _buoyancy_probes:Array[BuoyancyProbe3D] = []


func _ready() -> void:
	for probe in $BuoyancyProbes.get_children():
		_buoyancy_probes.append(probe)
		probe.ocean = ocean


func _physics_process(delta:float) -> void:
	var gv:Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	
	for probe in _buoyancy_probes:
		var depth:float = clamp((probe.global_position.y - ocean.get_wave_height(probe.global_position)), -10000.0, 0.0)
		var buoyancy = pow(abs(depth), buoyancy_power)
		
		if depth < 0.0:
			var old_y := probe.position.y
			probe.position.y = 0.0
			apply_force(buoyancy * -gv * buoyancy_multiplier * delta, probe.global_position - global_position)
			probe.position.y = old_y
