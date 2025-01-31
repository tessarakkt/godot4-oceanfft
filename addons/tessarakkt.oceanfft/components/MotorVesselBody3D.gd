@tool
@icon("res://addons/tessarakkt.oceanfft/icons/MotorVesselBody3D.svg")
extends BuoyancyBody3D
class_name MotorVesselBody3D
## Physics Body which is moved by 3D physics simulation, and interacts with
## buoyancy provided by an Ocean3D. Can be moved around with a simple single
## propeller/rudder configuration.


@export var thrust_power_main := 10.0
@export var max_rudder_force := 10.0


@onready var propeller:Marker3D = $Propeller
@onready var rudder:Marker3D = $Propeller


func _process(delta:float) -> void:
	if not environment or Engine.is_editor_hint():
		return
	
	if environment.get_wave_height(propeller.global_position) > propeller.global_position.y:
		var prop_horizontal := -global_transform.basis.z
		prop_horizontal.y = 0.0
		prop_horizontal = prop_horizontal.normalized()
		var prop_dot := prop_horizontal.dot(-global_transform.basis.z)
		
		if Input.is_action_pressed("ship_thrust_main_forwards"):
			apply_force(-global_transform.basis.z * thrust_power_main * prop_dot, propeller.global_position - global_position)
		elif Input.is_action_pressed("ship_thrust_main_backwards"):
			apply_force(global_transform.basis.z * thrust_power_main * prop_dot, propeller.global_position - global_position)
	
	if environment.get_wave_height(rudder.global_position) > rudder.global_position.y:
		if Input.is_action_pressed("ship_steering_main_left"):
			apply_force(global_transform.basis.x * max_rudder_force, rudder.global_position - global_position)
		elif Input.is_action_pressed("ship_steering_main_right"):
			apply_force(-global_transform.basis.x * max_rudder_force, rudder.global_position - global_position)
