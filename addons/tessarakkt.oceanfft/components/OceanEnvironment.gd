@icon("res://addons/tessarakkt.oceanfft/icons/OceanEnvironment.svg")
extends WorldEnvironment
class_name OceanEnvironment
## Manages environment settings, including above water/under water transitions
## for a scene containing an Ocean3D.


## The ocean simulation this environment is based on.
@export var ocean:Ocean3D

## The environments sun light. This should be angled to align with to shine in
## the desired direction of the sunlight. Used above and under water.
@export var sun_light:DirectionalLight3D

## The environments sky light. This should be pointed downwards (aligned to -Y).
## This is used under water to illuminate the environmental volumetric fog near
## the surface, and darker as depth increases. It is disabled above water, and
## the environments sky is used for sky lighting above water.
@export var sky_light:DirectionalLight3D


@export_group("Surfaced Environment Settings")

## Color used for environments non-volumetric fog when above water.
@export var surfaced_fog_color := Color(0.34901961684227, 0.60784316062927, 0.8901960849762)

## Density used for environments non-volumetric fog when above water.
@export var surfaced_fog_density := 0.0001

## Sky Affect used for environments non-volumetric fog when above water.
@export var surfaced_fog_sky_affect := 0.0

## Particle emitter for ambient wave splashes. Only emits particles when above
## water, disabled under water. Setting this is optional.
@export var splash_particles:GPUParticles3D

## Particle sub emitter for making ambient wave splashes bigger. Only emits as
## secondary emission to splash_particles emissions. Setting this is optional.
@export var splash_sub_particles:GPUParticles3D


@export_group("Underwater Environment Settings")

## Color used for environments volumetric fog when under water.
@export var underwater_fog_color := Color(0.12549020349979, 0.26274511218071, 0.44705882668495)

## Density used for environments volumetric fog when under water.
@export var underwater_fog_density := 0.015

## Sky Affect used for environments volumetric fog when under water.
@export var underwater_fog_sky_affect := 1.0

## Particle emitter for underwater particles (marine snow). Only emits particles
## when under water, disabled above water. To disable this effect, simply do not
## set a particle emitter here.
@export var underwater_particles:GPUParticles3D


## True if the camera has transitioned to above water. False if the camera has
## transitioned to below water.
var player_is_surfaced := false


func _ready():
	var camera := get_viewport().get_camera_3d()
	
	if splash_particles != null:
		splash_particles.process_material.set_shader_parameter("view_distance_max", camera.far)
		splash_particles.process_material.set_shader_parameter("wind_uv_offset", ocean.wind_uv_offset)
		splash_particles.process_material.set_shader_parameter("cascade_uv_scales", ocean.cascade_scales)
		splash_particles.process_material.set_shader_parameter("cascade_displacements", ocean.get_all_waves_textures())
		splash_particles.process_material.set_shader_parameter("uv_scale", ocean._uv_scale)
		
		if splash_sub_particles != null:
			splash_sub_particles.process_material.set_shader_parameter("view_distance_max", camera.far)
			splash_sub_particles.process_material.set_shader_parameter("wind_uv_offset", ocean.wind_uv_offset)
			splash_sub_particles.process_material.set_shader_parameter("cascade_uv_scales", ocean.cascade_scales)
			splash_sub_particles.process_material.set_shader_parameter("cascade_displacements", ocean.get_all_waves_textures())
			splash_sub_particles.process_material.set_shader_parameter("uv_scale", ocean._uv_scale)


func _process(_delta):
	var camera := get_viewport().get_camera_3d()
	
	if ocean.get_wave_height(camera.global_position, 2) > camera.global_position.y:
		if player_is_surfaced:
			go_under_water()
	else:
		if not player_is_surfaced:
			go_above_water()
	
	if splash_particles != null:
		splash_particles.process_material.set_shader_parameter("wind_uv_offset", ocean.wind_uv_offset)
		splash_particles.process_material.set_shader_parameter("camera_position_world", camera.global_position)
		splash_particles.global_position = camera.global_position + (-camera.global_transform.basis.z * 300.0)
		
		if splash_sub_particles != null:
			splash_sub_particles.process_material.set_shader_parameter("wind_uv_offset", ocean.wind_uv_offset)
			splash_sub_particles.process_material.set_shader_parameter("camera_position_world", camera.global_position)
	
	if underwater_particles != null:
		underwater_particles.global_position = camera.global_position


## Transition to under water environment settings.
func go_under_water() -> void:
	player_is_surfaced = false
	
	if sky_light:
		sky_light.visible = true
	if sun_light:
		sun_light.light_energy = 0.75
	
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = true
	
	ocean.material.set_shader_parameter("normal_factor", -1.0)
	ocean.material.set_shader_parameter("refraction_distance_power", 1.0)
	
	if splash_particles != null:
		splash_particles.restart()
		splash_particles.emitting = false
		
		if splash_sub_particles != null:
			splash_sub_particles.restart()
	
	if underwater_particles != null:
		underwater_particles.emitting = true


## Transition to above water environment settings.
func go_above_water() -> void:
	player_is_surfaced = true
	
	if sky_light:
		sky_light.visible = false
	if sun_light:
		sun_light.light_energy = 0.5
	
	environment.fog_enabled = true
	environment.volumetric_fog_enabled = false
	
	ocean.material.set_shader_parameter("normal_factor", 1.0)
	ocean.material.set_shader_parameter("refraction_distance_power", 1.55)
	
	if splash_particles != null:
		splash_particles.emitting = true
	
	if underwater_particles != null:
		underwater_particles.restart()
		underwater_particles.emitting = false
