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
@export var environment:OceanEnvironment

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
	
	if !environment:
		if !_displayed_null_ocean_warning:
			push_warning("This BuoyancyBody3D is not a descendant of an OceanEnvironment")
			_displayed_null_ocean_warning = true
		return

	var gv:Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	submerged_probes = 0
	submerged = false
	
	## Iterate through all buoyancy probes, calculate each ones buoyancy force,
	## and apply it at the appropriate offset.
	for probe in _buoyancy_probes:
		var depth:float = clamp((probe.global_position.y - environment.get_wave_height(probe.global_position, probe.max_cascade, probe.height_sampling_steps)), -10000.0, 0.0)
		var buoyancy = pow(abs(depth), buoyancy_power)
		
		if depth < 0.0:
			submerged = true
			submerged_probes += 1
			var multiplier := buoyancy_multiplier * probe.buoyancy_multiplier
			var force:Vector3 = -gv * buoyancy * multiplier * delta
			apply_force(force, probe.global_position - global_position)
	
#	linear_damp = submerged_drag_linear * (submerged_probes / _buoyancy_probes.size())
#	angular_damp = submerged_drag_angular * (submerged_probes / _buoyancy_probes.size())


func _integrate_forces(state:PhysicsDirectBodyState3D) -> void:
	if submerged:
		linear_velocity *= 1.0 - submerged_drag_linear
		angular_velocity *= 1.0 - submerged_drag_angular


func _enter_tree() -> void:
	_add_ocean_environment_ancestor()


func _exit_tree() -> void:
	environment = null


func _add_ocean_environment_ancestor() -> void:
	var parent := get_parent()
	while parent:
		if parent is OceanEnvironment:
			environment = parent
			return
		parent = parent.get_parent()
	environment = null


## Adds a BuoyancyProbe3D to this body's buoyancy calculation.
func add_probe(probe:BuoyancyProbe3D) -> void:
	_buoyancy_probes.append(probe)


## Removes a BuoyancyProbe3D to this body's buoyancy calculation.
func remove_probe(probe:BuoyancyProbe3D) -> void:
	var index := _buoyancy_probes.find(probe)
	if index >= 0:
		_buoyancy_probes.remove_at(index)


func _get_configuration_warnings() -> PackedStringArray:
	var result:PackedStringArray = []
	
	if _buoyancy_probes.is_empty():
		result.push_back("This node has no BuoyancyProbes so it cannot interact with an Ocean.
		Consider adding a BuoyancyProbe3D as a child.")
	
	return result
