extends Camera3D


@export_range(0.0, 1000.0) var speed := 25.0
@export_range(0.0, 1000.0) var sprint_speed := 50.0
@export_range(0.0, 1.0) var camera_sensitivity := 0.1
@export_range(1.0, 15.0) var zoom_speed := 5.0
@export_range(1.0, 90.0) var zoom_fov := 25.0

@export var reflection_probe:ReflectionProbe
@export var world:WorldEnvironment
@export var ocean:Ocean3D
@export var sun_light:DirectionalLight3D
@export var sky_light:DirectionalLight3D

@export var surfaced_fog_color := Color(0.34901961684227, 0.60784316062927, 0.8901960849762)
@export var surfaced_fog_density := 0.0001
@export var surfaced_fog_sky_affect := 0.0
@export var surfaced_ocean_metallic := 0.1

@export var underwater_fog_color := Color(0.12549020349979, 0.26274511218071, 0.44705882668495)
@export var underwater_fog_density := 0.015
@export var underwater_fog_sky_affect := 1.0
@export var underwater_ocean_metallic := 0.05


var camera_motion := Vector2.ZERO
var motion_enabled := false
var zoom_factor := 0.0


func _process(delta:float) -> void:
	var motion := Vector3.ZERO
	
	if motion_enabled:
		if Input.is_action_pressed("free_cam_forward"):
			motion -= Vector3(basis.z.x, 0.0, basis.z.z).normalized()
	
		if Input.is_action_pressed("free_cam_backward"):
			motion += Vector3(basis.z.x, 0.0, basis.z.z).normalized()
	
		if Input.is_action_pressed("free_cam_left"):
			motion -= Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	
		if Input.is_action_pressed("free_cam_right"):
			motion += Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	
		if Input.is_action_pressed("free_cam_down"):
			motion += Vector3.DOWN
		
		if Input.is_action_pressed("free_cam_up"):
			motion += Vector3.UP
	
		motion = motion.normalized()
	
		if Input.is_action_pressed("free_cam_speed"):
			motion *= sprint_speed
		else:
			motion *= speed
		
		if Input.is_action_pressed("free_cam_zoom"):
			zoom_factor = clamp(zoom_factor + delta * zoom_speed, 0.0, 1.0)
		
		else:
			zoom_factor = clamp(zoom_factor - delta * zoom_speed, 0.0, 1.0)
		
		fov = lerp(75.0, zoom_fov, zoom_factor)
		
		if not motion.is_zero_approx():
			position += motion * delta
			reflection_probe.position = position
	
		rotate(Vector3.UP, camera_motion.x * -camera_sensitivity * delta)
		rotate(basis.x, camera_motion.y * -camera_sensitivity * delta)
	
		camera_motion = Vector2.ZERO
	
	if ocean.get_wave_height(global_position, 2) > global_position.y:
		go_under_water()

	else:
		go_above_water()


func _input(event:InputEvent) -> void:
	if motion_enabled and event is InputEventMouseMotion:
		camera_motion += event.relative


func go_under_water() -> void:
	world.environment.fog_enabled = false
	world.environment.volumetric_fog_enabled = true
	ocean._material.set_shader_parameter("normal_factor", -1.0)
	ocean._material.set_shader_parameter("refraction_distance_power", 1.0)
	ocean._material.set_shader_parameter("metallic_strength", underwater_ocean_metallic)
	sky_light.visible = true
	sun_light.light_energy = 0.75


func go_above_water() -> void:
	world.environment.fog_enabled = true
	world.environment.volumetric_fog_enabled = false
	ocean._material.set_shader_parameter("normal_factor", 1.0)
	ocean._material.set_shader_parameter("refraction_distance_power", 1.55)
	ocean._material.set_shader_parameter("metallic_strength", surfaced_ocean_metallic)
	sky_light.visible = false
	sun_light.light_energy = 0.5
