@tool
extends Node3D
class_name OceanSurfaceRenderer3D

@export var ocean: Ocean3D:
	set(value):
		ocean = value
		if renderer:
			renderer.ocean = value

enum RenderingMode {
	SIMPLE_PLANE,
	MULTI_MESH
}
@export var rendering_mode : RenderingMode = RenderingMode.SIMPLE_PLANE:
	set(value):
		rendering_mode = value
		if is_instance_valid(renderer):
			renderer.queue_free()
		renderer = _rendering_modes[rendering_mode].new()
		renderer.ocean = ocean
		add_child(renderer)

@export var settings: Resource:
	get:
		if renderer:
			return renderer.settings
		return null

# TODO editor script with dropdown triggered by what's available
var _rendering_modes := {
	RenderingMode.SIMPLE_PLANE: SimplePlaneRenderer,
	RenderingMode.MULTI_MESH: MultiMeshRenderer
}

var renderer : BaseOceanRenderer = null:
	set(value):
		renderer = value
		renderer.ocean = ocean

func _ready():
	# TODO just for testing to make sure renderers are well behaved
	if get_child_count() > 0:
		push_warning("OceanRenderer has children in _ready(): ", get_children())
	renderer = _rendering_modes[rendering_mode].new()
	renderer.ocean = ocean
	add_child(renderer)

func _enter_tree():
	if get_parent() is Ocean3D:
		ocean = get_parent()

class BaseOceanRenderer extends Node3D:
	var material: Material
	var ocean: Ocean3D:
		set(value):
			ocean = value
			_on_set_ocean()
	var settings: Resource:
		set(value):
			settings = value
			settings.changed.connect(_on_settings_changed)
	
	func _init() -> void:
		if !is_available():
			push_warning("OceanRenderingMode not available")

	func _on_set_ocean():
		if ocean:
			material = ocean.material
		else:
			material = null

	func _on_settings_changed():
		pass
	
	func is_available() -> bool:
		return false
	
class SimplePlaneRenderer extends BaseOceanRenderer:
	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()

	func _init():
		settings = mesh
		mesh_instance.mesh = mesh
		mesh_instance.material_override = null
		add_child(mesh_instance)

	func _on_set_ocean():
		super()
		if !ocean:
			mesh_instance.visible = false
			return
		mesh_instance.material_override = ocean.material
		mesh.size = Vector2.ONE * ocean.horizontal_dimension
		mesh.subdivide_width = ocean.horizontal_dimension
		mesh.subdivide_depth = ocean.horizontal_dimension
		mesh_instance.visible = true
	
	func is_available() -> bool:
		return true

class MultiMeshRenderer extends BaseOceanRenderer:
	var multimesh_instance := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	var mesh := PlaneMesh.new()

	func _init():
		settings = MultiMeshRenderer.Settings.new()
		multimesh_instance.multimesh = multimesh
		multimesh.mesh = mesh
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = 1000
		multimesh.visible_instance_count = 0
		multimesh_instance.material_override = null
		add_child(multimesh_instance)

	func _on_set_ocean() -> void:
		super()
		if !ocean:
			multimesh_instance.visible = false
			return
		multimesh_instance.material_override = ocean.material
		mesh.size = Vector2.ONE * ocean.horizontal_dimension
		mesh.subdivide_width = ocean.horizontal_dimension
		mesh.subdivide_depth = ocean.horizontal_dimension
		multimesh_instance.visible = true
		update_mesh_instances()
	
	func update_mesh_instances() -> void:
		multimesh.visible_instance_count = settings.x_count * settings.z_count
		var i := 0
		var offset = -Vector3((settings.x_count / 2.0) - 0.5, 0, (settings.z_count / 2.0) - 0.5) * ocean.horizontal_dimension
		var basis_position = position + offset
		for x in settings.x_count:
			for z in settings.z_count:
				var transform := Transform3D()
				transform.origin = basis_position + Vector3(x * ocean.horizontal_dimension, 0,  z * ocean.horizontal_dimension)
				multimesh.set_instance_transform(i, transform)
				i += 1
	
	func _on_settings_changed() -> void:
		update_mesh_instances()
		
	func is_available() -> bool:
		return true
	
	class Settings extends Resource:
		@export var x_count := 4:
			set(value):
				x_count = value
				emit_changed()
		@export var z_count := 4:
			set(value):
				z_count = value
				emit_changed()