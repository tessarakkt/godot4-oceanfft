@tool
extends Node3D
class_name OceanSurface3D
## Base OceanSurface3D class. Has no rendering.

@export var ocean: Ocean3D:
	set(value):
		ocean = value
		_on_set_ocean()
		ocean_changed.emit()

signal ocean_changed

func _enter_tree():
	if get_parent() is Ocean3D:
		ocean = get_parent()

func _on_set_ocean() -> void:
	pass