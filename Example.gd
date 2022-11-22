extends WorldEnvironment


@onready var canvas_layer:CanvasLayer = $CanvasLayer
@onready var displacement_view:TextureRect = $CanvasLayer/Displacement
@onready var normal_view:TextureRect = $CanvasLayer/Normal

@onready var ocean = $Ocean


func _ready() -> void:
	displacement_view.texture = ocean.get_waves_texture()
	normal_view.texture = ocean.get_normal_map_texture()


func _input(event:InputEvent) -> void:
	if event.is_action_pressed("toggle_ocean_debug"):
		canvas_layer.visible = not canvas_layer.visible


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
