extends CanvasLayer


@onready var displacement_cascade0_view:TextureRect = $Displacement_cascade0
@onready var displacement_cascade1_view:TextureRect = $Displacement_cascade1
@onready var displacement_cascade2_view:TextureRect = $Displacement_cascade2
@onready var settings_view:PanelContainer = $PanelContainer
@onready var fps_view:Label = $VBoxContainer/FPS
@onready var ocean_fps_view:Label = $VBoxContainer/OceanFPS


@export var ocean:Ocean3D
@export var free_camera:Camera3D
@export var player_camera:Camera3D


func _ready():
	displacement_cascade0_view.texture = ocean.get_waves_texture(0)
	displacement_cascade1_view.texture = ocean.get_waves_texture(1)
	displacement_cascade2_view.texture = ocean.get_waves_texture(2)


func _process(_delta):
	var fps := Engine.get_frames_per_second()
	
	fps_view.text = "%.1f Draw FPS" % [fps]
	ocean_fps_view.text = "%.1f Ocean TPS" % [fps / (ocean.simulation_frameskip + 1)]


func _input(event:InputEvent) -> void:
	if event.is_action_pressed("camera_mode_free") and free_camera != null:
		free_camera.make_current()
	
	if event.is_action_pressed("camera_mode_ship") and player_camera != null:
		player_camera.make_current()
	
	if event.is_action_pressed("toggle_ocean_debug"):
		displacement_cascade0_view.visible = not displacement_cascade0_view.visible
		displacement_cascade1_view.visible = displacement_cascade0_view.visible
		displacement_cascade2_view.visible = displacement_cascade0_view.visible
		settings_view.visible = displacement_cascade0_view.visible
		
		if displacement_cascade0_view.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	get_viewport().get_camera_3d().motion_enabled = not displacement_cascade0_view.visible


func _on_frameskip_value_changed(value:float) -> void:
	ocean.simulation_frameskip = int(value)


func _on_simulate_enabled_toggled(button_pressed:bool) -> void:
	ocean.simulation_enabled = button_pressed


func _on_speed_value_changed(value:float) -> void:
	ocean.time_scale = value


func _on_choppiness_value_changed(value:float) -> void:
	ocean.choppiness = value


func _on_wind_speed_value_changed(value:float) -> void:
	ocean.wave_vector = ocean.wave_vector.normalized() * value


func _on_wind_direction_value_changed(value:float) -> void:
	ocean.wind_direction_degrees = value


func _on_wave_speed_value_changed(value:float) -> void:
	ocean.wave_scroll_speed = -value


func _on_cull_enabled_toggled(button_pressed:bool) -> void:
	$"../QuadTree3D".pause_cull = not button_pressed


func _on_planetary_curve_value_changed(value:float) -> void:
	ocean.planetary_curve_strength = value * 0.0001


func _on_heightmap_sync_frameskip_value_changed(value: float) -> void:
	ocean.heightmap_sync_frameskip = int(value)
