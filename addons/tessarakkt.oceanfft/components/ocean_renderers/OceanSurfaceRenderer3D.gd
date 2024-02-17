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
	MULTI_PLANE
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
	RenderingMode.MULTI_PLANE: MultiMeshPlaneGridRenderer
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
		settings = Settings.new()
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
	
	func _on_settings_changed() -> void:
		mesh.subdivide_width = settings.subdivisions.x
		mesh.subdivide_depth = settings.subdivisions.y
		mesh.size = settings.size

	class Settings extends Resource:
		@export var size := Vector2(256, 256):
			set(value):
				size = value
				emit_changed()
		@export var subdivisions := Vector2(256, 256):
			set(value):
				subdivisions = value
				emit_changed()

class MultiMeshPlaneGridRenderer extends BaseOceanRenderer:
	var multimesh_instance := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	var mesh := PlaneMesh.new()

	func _init():
		settings = MultiMeshPlaneGridRenderer.Settings.new()
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
		# update mesh
		mesh.size = settings.instance_size
		mesh.subdivide_width = settings.instance_subdivisions.x
		mesh.subdivide_depth = settings.instance_subdivisions.y
		# update instance transforms
		multimesh.visible_instance_count = settings.rows * settings.columns
		var i := 0
		var offset = -Vector3((settings.rows / 2.0) - 0.5, 0, (settings.columns / 2.0) - 0.5) * ocean.horizontal_dimension
		var basis_position = position + offset
		for x in settings.rows:
			for z in settings.columns:
				var transform := Transform3D()
				transform.origin = basis_position + Vector3(x * ocean.horizontal_dimension, 0,  z * ocean.horizontal_dimension)
				multimesh.set_instance_transform(i, transform)
				i += 1
	
	func _on_settings_changed() -> void:
		update_mesh_instances()
		
	func is_available() -> bool:
		return true
	
	class Settings extends Resource:
		@export_category("Mesh Instance Settings")
		@export var instance_size := Vector2(256, 256):
			set(value):
				instance_size = value
				emit_changed()
		@export var instance_subdivisions := Vector2(256, 256):
			set(value):
				instance_subdivisions = value
				emit_changed()
		@export_category("Grid Settings")
		@export var rows := 4:
			set(value):
				rows = value
				emit_changed()
		@export var columns := 4:
			set(value):
				columns = value
				emit_changed()