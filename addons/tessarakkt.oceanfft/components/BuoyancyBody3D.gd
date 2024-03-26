@tool
@icon("res://addons/tessarakkt.oceanfft/icons/BuoyancyBody3D.svg")
extends RigidBody3D
class_name BuoyancyBody3D
## Physics Body which is moved by 3D physics simulation, and interacts with
## buoyancy provided by an Ocean3D.

## Buoyancy force multiplier applied to all buoyancy probes.
@export var buoyancy_multiplier := 1.0

## Fudge factor; rather than take the depth linearly as in real buoyancy, raise
## the depth to this power first. It can be disabled by setting this to 1.0.
@export_range(0.5, 10.0, 0.001) var buoyancy_power := 1.5

## The ocean that provides this bodies buoyancy.
@export var ocean:Ocean3D

@export var submerged_drag_linear := 0.05
@export var submerged_drag_angular := 0.1


## True if the body has at least one probe underwater.
var submerged := false
## Number of probes that are currently underwater.
var submerged_probes := 0


# Probes currently used in calculating this body's buoyancy
var _buoyancy_probes:Array[BuoyancyProbe3D] = []
# Used to only display the warning that the ocean is null once
var _displayed_null_ocean_warning := false


func _physics_process(delta:float) -> void:
	if Engine.is_editor_hint():
		return
	if !ocean:
		if !_displayed_null_ocean_warning:
			push_warning("Property 'ocean' is null")
			_displayed_null_ocean_warning = true
		return

	var gv:Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	submerged_probes = 0
	submerged = false
	
	## Iterate through all buoyancy probes, calculate each ones buoyancy force,
	## and apply it at the appropriate offset.
	for probe in _buoyancy_probes:
		var depth:float = clamp((probe.global_position.y - ocean.get_wave_height(probe.global_position)), -10000.0, 0.0)
		var buoyancy = pow(abs(depth), buoyancy_power)
		
		if depth < 0.0:
			submerged = true
			submerged_probes += 1
			var multiplier := buoyancy_multiplier * probe.buoyancy_multiplier
			var force:Vector3 = -gv * buoyancy * multiplier * delta
			apply_force(force, probe.global_position - global_position)
	
#	linear_damp = submerged_drag_linear * (submerged_probes / _buoyancy_probes.size())
#	angular_damp = submerged_drag_angular * (submerged_probes / _buoyancy_probes.size())

func _integrate_forces(state):
	if submerged:
		linear_velocity *= 1.0 - submerged_drag_linear
		angular_velocity *= 1.0 - submerged_drag_angular

## Adds a BuoyancyProbe3D to this body's buoyancy calculation.
func add_probe(probe: BuoyancyProbe3D):
	_buoyancy_probes.append(probe)
	probe.ocean = ocean

## Removes a BuoyancyProbe3D to this body's buoyancy calculation.
func remove_probe(probe: BuoyancyProbe3D):
	var index := _buoyancy_probes.find(probe)
	if index >= 0:
		_buoyancy_probes.remove_at(index)

func _get_configuration_warnings():
	const _NO_PROBE_CONFIGURATION_WARNING :=\
		"This node has no BuoyancyProbes so it cannot interact with an Ocean.
		Consider adding a BuoyancyProbe3D as a child."

	if _buoyancy_probes.is_empty():
		return [_NO_PROBE_CONFIGURATION_WARNING]
