@tool
extends Node3D
class_name OceanSurface3D
## Base OceanSurface3D class. Has no rendering.

enum InfiniteMode {
	OFF,
	PROCESS,
	PHYSICS_PROCESS,
}

@export var infinite_mode: InfiniteMode

@export var ocean: Ocean3D:
	set(value):
		ocean = value
		_on_set_ocean()
		ocean_changed.emit()

signal ocean_changed

func _enter_tree():
	if get_parent() is Ocean3D:
		ocean = get_parent()

## Override this to implement rendering in subclasses
func _on_set_ocean() -> void:
	pass

func _process(delta: float):
	if infinite_mode == InfiniteMode.PROCESS:
		call_deferred("_position_at_camera_xz")

func _physics_process(delta: float):
	if infinite_mode == InfiniteMode.PHYSICS_PROCESS:
		call_deferred("_position_at_camera_xz")

func _position_at_camera_xz():
	if ocean.camera:
		position.x = ocean.camera.position.x
		position.z = ocean.camera.position.z