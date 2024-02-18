@tool
extends OceanSurface3DBase
class_name PlaneMeshOceanSurface3D

@export var mesh_size : Vector2 = Vector2(256, 256):
	set(value):
		mesh_size = value
		plane_mesh.size = mesh_size

@export var subdivisions := Vector2(64, 64):
	set(value):
		subdivisions = value
		plane_mesh.subdivide_width = subdivisions.x
		plane_mesh.subdivide_depth = subdivisions.y

var plane_mesh := PlaneMesh.new()
var mesh_instance : MeshInstance3D

func _init():
	if !mesh_instance:
		plane_mesh.size = mesh_size
		mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = plane_mesh
		add_child(mesh_instance)

func _on_set_ocean():
	if !ocean:
		mesh_instance.visible = false
		return
	print(plane_mesh)
	print(mesh_instance)
	mesh_instance.material_override = ocean.material
	plane_mesh.subdivide_width = subdivisions.x
	plane_mesh.subdivide_depth = subdivisions.y
	plane_mesh.size = mesh_size
	mesh_instance.visible = true