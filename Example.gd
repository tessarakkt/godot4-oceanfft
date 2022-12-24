extends WorldEnvironment


@onready var displacement_cascade0_view:TextureRect = $CanvasLayer/Displacement_cascade0
@onready var displacement_cascade1_view:TextureRect = $CanvasLayer/Displacement_cascade1
@onready var displacement_cascade2_view:TextureRect = $CanvasLayer/Displacement_cascade2
@onready var settings_view:PanelContainer = $CanvasLayer/PanelContainer
@onready var fps_view:Label = $CanvasLayer/FPS

@onready var ocean = $Ocean3D

@onready var camera = $Camera3D


func _ready() -> void:
	displacement_cascade0_view.texture = ocean.get_waves_texture(0)
	displacement_cascade1_view.texture = ocean.get_waves_texture(1)
	displacement_cascade2_view.texture = ocean.get_waves_texture(2)


func _process(_delta:float) -> void:
	fps_view.text = "%.1f FPS" % [Engine.get_frames_per_second()]


func _input(event:InputEvent) -> void:
	if event.is_action_pressed("toggle_ocean_debug"):
		displacement_cascade0_view.visible = not displacement_cascade0_view.visible
		displacement_cascade1_view.visible = displacement_cascade0_view.visible
		displacement_cascade2_view.visible = displacement_cascade0_view.visible
		settings_view.visible = displacement_cascade0_view.visible
		camera.motion_enabled = not displacement_cascade0_view.visible
		
		if displacement_cascade0_view.visible:
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


func _on_planetary_curve_value_changed(value:float) -> void:
	$QuadTree3D.planetary_curve_strength = value * 0.0001
