extends WorldEnvironment


@onready var displacement_view:TextureRect = $CanvasLayer/Displacement
@onready var settings_view:PanelContainer = $CanvasLayer/PanelContainer
@onready var fps_view:Label = $CanvasLayer/FPS

@onready var ocean = $Ocean3D

@onready var camera = $Camera3D


func _ready() -> void:
	displacement_view.texture = ocean.get_waves_texture()


func _process(_delta:float) -> void:
	fps_view.text = "%.1f FPS" % [Engine.get_frames_per_second()]


func _input(event:InputEvent) -> void:
	if event.is_action_pressed("toggle_ocean_debug"):
		displacement_view.visible = not displacement_view.visible
		settings_view.visible = displacement_view.visible
		camera.motion_enabled = not displacement_view.visible
		
		if displacement_view.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_frameskip_value_changed(value:float) -> void:
	ocean.simulation_frameskip = value


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
	ocean.wave_speed = value


func _on_cull_enabled_toggled(button_pressed:bool) -> void:
	$QuadTree3D.pause_cull = not button_pressed
