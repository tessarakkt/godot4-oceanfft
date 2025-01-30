extends Camera3D


@export_range(0.0, 1000.0) var speed := 25.0
@export_range(0.0, 1000.0) var sprint_speed := 50.0
@export_range(0.0, 1.0) var camera_sensitivity := 0.1
@export_range(1.0, 15.0) var zoom_speed := 5.0
@export_range(1.0, 90.0) var zoom_fov := 25.0

@export var reflection_probe:ReflectionProbe


var camera_motion := Vector2.ZERO
var motion_enabled := false
var zoom_factor := 0.0


func _process(delta:float) -> void:
	var motion := Vector3.ZERO
	
	if motion_enabled and current:
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
		basis = basis.orthonormalized()
	
		camera_motion = Vector2.ZERO


func _input(event:InputEvent) -> void:
	if motion_enabled and current and event is InputEventMouseMotion:
		camera_motion += event.relative
