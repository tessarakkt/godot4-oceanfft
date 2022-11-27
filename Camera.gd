extends Camera3D


@export_range(0.0, 1000.0) var speed := 25.0
@export_range(0.0, 1000.0) var sprint_speed := 50.0
@export_range(0.0, 1.0) var camera_sensitivity := 0.1


var camera_motion := Vector2.ZERO
var motion_enabled := false


func _process(delta:float) -> void:
	var motion := Vector3.ZERO
	
	if motion_enabled:
		if Input.is_action_pressed("free_cam_forward"):
			motion -= basis.z
	
		if Input.is_action_pressed("free_cam_backward"):
			motion += basis.z
	
		if Input.is_action_pressed("free_cam_left"):
			motion -= basis.x
	
		if Input.is_action_pressed("free_cam_right"):
			motion += basis.x
	
		motion = motion.normalized()
	
		if Input.is_action_pressed("free_cam_speed"):
			motion *= sprint_speed
		else:
			motion *= speed
	
		position += motion * delta
	
		rotate(Vector3.UP, camera_motion.x * -camera_sensitivity * delta)
		rotate(basis.x, camera_motion.y * -camera_sensitivity * delta)
	
		camera_motion = Vector2.ZERO


func _input(event:InputEvent) -> void:
	if motion_enabled and event is InputEventMouseMotion:
		camera_motion += event.relative
