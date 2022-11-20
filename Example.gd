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
