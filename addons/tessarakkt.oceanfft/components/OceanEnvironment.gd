@icon("res://addons/tessarakkt.oceanfft/icons/OceanEnvironment.svg")
extends WorldEnvironment
class_name OceanEnvironment


@export var ocean:Ocean3D
@export var sun_light:DirectionalLight3D
@export var sky_light:DirectionalLight3D

@export_group("Surfaced Environment Settings")

@export var surfaced_fog_color := Color(0.34901961684227, 0.60784316062927, 0.8901960849762)
@export var surfaced_fog_density := 0.0001
@export var surfaced_fog_sky_affect := 0.0

@export_group("Underwater Environment Settings")

@export var underwater_fog_color := Color(0.12549020349979, 0.26274511218071, 0.44705882668495)
@export var underwater_fog_density := 0.015
@export var underwater_fog_sky_affect := 1.0


func _process(_delta):
	var camera := get_viewport().get_camera_3d()
	
	if ocean.get_wave_height(camera.global_position, 2) > camera.global_position.y:
		go_under_water()
	else:
		go_above_water()


func go_under_water() -> void:
	sky_light.visible = true
	sun_light.light_energy = 0.75
	
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = true
	
	ocean.material.set_shader_parameter("normal_factor", -1.0)
	ocean.material.set_shader_parameter("refraction_distance_power", 1.0)


func go_above_water() -> void:
	sky_light.visible = false
	sun_light.light_energy = 0.5
	
	environment.fog_enabled = true
	environment.volumetric_fog_enabled = false
	
	ocean.material.set_shader_parameter("normal_factor", 1.0)
	ocean.material.set_shader_parameter("refraction_distance_power", 1.55)
