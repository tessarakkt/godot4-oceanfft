extends Camera3D

var min_y := 20
var max_y := 6400

func _on_v_slider_value_changed(value:float):
	var log_value = value * value
	var scaled_value = log_value * max_y
	position.y = scaled_value + min_y
