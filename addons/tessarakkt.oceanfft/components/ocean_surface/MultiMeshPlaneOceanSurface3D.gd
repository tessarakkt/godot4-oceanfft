@tool
extends OceanSurface3DBase
class_name MultiMeshPlaneOceanSurface3D

@export var instance_counts : Vector2 = Vector2.ONE * 50:
	set(value):
		instance_counts = value
		update_mesh_instances()

@export_category("Instance Settings")
@export var instance_size := Vector2(256, 256):
	set(value):
		instance_size = value
		mesh.size = value
		update_mesh_instances()
@export var instance_subdivisions := Vector2(64, 64):
	set(value):
		instance_subdivisions = value
		mesh.subdivide_width = instance_subdivisions.x
		mesh.subdivide_depth = instance_subdivisions.y

var mesh := PlaneMesh.new()
var multimesh := MultiMesh.new()
var multimesh_instance : MultiMeshInstance3D

func _init():
	if !multimesh_instance:
		multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = multimesh
		multimesh.mesh = mesh
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = 1000000
		multimesh.visible_instance_count = 0
		multimesh_instance.material_override = null
		add_child(multimesh_instance)

func _on_set_ocean() -> void:
	if !ocean:
		multimesh_instance.visible = false
		return
	multimesh_instance.material_override = ocean.material
	mesh.size = Vector2.ONE * ocean.horizontal_dimension
	mesh.subdivide_width = instance_subdivisions.x
	mesh.subdivide_depth = instance_subdivisions.y
	multimesh_instance.visible = true
	update_mesh_instances()

func update_mesh_instances() -> void:
	var rows = instance_counts.x
	var columns = instance_counts.y

	# update mesh
	mesh.size = instance_size
	# update instance transforms
	multimesh.visible_instance_count = rows * columns
	var i := 0
	var offset = -Vector3((rows / 2.0) - 0.5, 0, (columns / 2.0) - 0.5) * ocean.horizontal_dimension
	var basis_position = position + offset
	for x in rows:
		for z in columns:
			var transform := Transform3D()
			transform.origin = basis_position + Vector3(x * ocean.horizontal_dimension, 0,  z * ocean.horizontal_dimension)
			multimesh.set_instance_transform(i, transform)
			i += 1
