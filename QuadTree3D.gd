extends Node3D
class_name QuadTree3D


@export_range(0, 1000000, 1) var lod_level := 2
@export_range(1.0, 65535.0) var quad_size := 1024.0
@export_range(0.0, 1.0) var morph_range := 0.15
@export_range(0.0, 0.001) var planetary_curve_strength := 0.000001:
	set(new_planetary_curve_strength):
		planetary_curve_strength = new_planetary_curve_strength
		material.set_shader_parameter("planetary_curve_strength", planetary_curve_strength)
@export_range(0, 32000, 1) var mesh_vertex_resolution := 512
@export var ranges:Array[float] = [512.0, 1024.0, 2048.0]
@export_node_path(Camera3D) var camera


## Will hold this resource loaded so as to instantiate subquads
## This can't currently be preloaded due to an engine bug
## https://github.com/godotengine/godot/issues/70985
var Quad


var pause_cull := false
var cull_box:AABB
var lod_meshes:Array[PlaneMesh] = []
var material:ShaderMaterial:
	get:
		return mesh_instance.material_override
	set(new_material):
		mesh_instance.material_override = new_material


var _subquads:Array[QuadTree3D] = []
var _camera:Camera3D


@onready var mesh_instance:MeshInstance3D = $MeshInstance3D
@onready var _visibility_detector:VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D


func _ready() -> void:
	## If the camera NodePath is set, then this is the top level quad
	if camera != null:
		## This is the camera that culling will be based on.
		_camera = get_node(camera)
		
		## Load self to instantiate subquads with
		## This can't currently be preloaded due to an engine bug
		## https://github.com/godotengine/godot/issues/70985
		Quad = load("res://QuadTree3D.tscn")
		
		## Set max view distance and fade range start
		material.set_shader_parameter("view_distance_max", _camera.far)
		material.set_shader_parameter("view_fade_start", 0.005)
		
		## Initialize LOD meshes for each level
		var current_size = quad_size
		
		for i in range(lod_level + 1):
			var mesh := PlaneMesh.new()
			mesh.size = Vector2.ONE * current_size
			mesh.subdivide_depth = mesh_vertex_resolution - 1
			mesh.subdivide_width = mesh_vertex_resolution - 1
			
			lod_meshes.insert(0, mesh)
			current_size *= 0.5
	
	var offset_length:float = quad_size * 0.25
	
	mesh_instance.mesh = lod_meshes[lod_level]
	mesh_instance.set_instance_shader_parameter("vertex_resolution", float(mesh_vertex_resolution))
	mesh_instance.set_instance_shader_parameter("patch_size", quad_size)
	mesh_instance.set_instance_shader_parameter("min_lod_morph_distance", ranges[lod_level] * 2 * (1.0 - morph_range))
	mesh_instance.set_instance_shader_parameter("max_lod_morph_distance", ranges[lod_level] * 2)
	
	_visibility_detector.aabb = AABB(Vector3(-quad_size * 0.75, -quad_size * 0.5, -quad_size * 0.75),
			Vector3(quad_size * 1.5, quad_size, quad_size * 1.5))
	mesh_instance.custom_aabb = _visibility_detector.aabb
	cull_box = AABB(global_position + Vector3(-quad_size * 0.5, -10, -quad_size * 0.5),
			Vector3(quad_size, 20, quad_size))
	
	## If this is not the most detailed LOD level, initialize more detailed
	## children.
	if lod_level > 0:
		for offset in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			var new_quad = Quad.instantiate()
			new_quad.lod_level = lod_level - 1
			new_quad.quad_size = quad_size * 0.5
			new_quad.ranges = ranges
			new_quad.process_mode = PROCESS_MODE_DISABLED
			new_quad.position = offset * offset_length
			new_quad.mesh_vertex_resolution = mesh_vertex_resolution
			new_quad.morph_range = morph_range
			new_quad.Quad = Quad
			new_quad.lod_meshes = lod_meshes
			
			$SubQuads.add_child(new_quad)
			_subquads.append(new_quad)


## Process mode is set to PROCESS_MODE_DISABLED for subquads, so only the root
## quad will run _process().
func _process(_delta:float) -> void:
	if not pause_cull:
		reset_visibility()
		lod_select(_camera.global_position)


## Select which meshes will be displayed at which LOD level. A return value of
## true marks the node as handled, and a value of false indicates the parent
## node must handle it.
## cam_pos is the camera/player position in global coordinates.
func lod_select(cam_pos:Vector3) -> bool:
	## Beginning at the root node of lowest LOD, and working towards the most
	## detailed LOD 0.
	
	if not within_sphere(cam_pos, ranges[lod_level]):
		## This quad is not within range of the selected LOD level, the parent
		## will need to display this at a lower detailed LOD. Return false to
		## mark the area as not handled.
		return false
	
	if not _visibility_detector.is_on_screen():
		## This quad is not on screen. Do not make it visible, and return true
		## to mark the area as handled.
		return true
	
	if lod_level == 0:
		## Within range of selected LOD level, and at highest detailed LOD,
		## there are no more detailed children to render this. Make this quad
		## visible. Return true to mark the area handled.
		mesh_instance.visible = true
		return true
	
	else:
		## Within range of selected LOD level, but there are more detailed
		## children that may be able to display this. Check if any are within
		## their LOD range.
		if not within_sphere(cam_pos, ranges[lod_level - 1]):
			## No children are within range of their LOD levels, make this quad
			## visible to handle the area.
			for subquad in _subquads:
				subquad.mesh_instance.visible = true
		
		else:
			## At least one more detailed children is within LOD range. Recurse
			## through them and select them if appropriate.
			for subquad in _subquads:
				if not subquad.lod_select(cam_pos):
					subquad.mesh_instance.visible = true
		
		## The area has been handled.
		return true


## Reset all quads to invisible.
func reset_visibility() -> void:
	if mesh_instance.visible:
		## If this quad is visible, no children should be visible.
		mesh_instance.visible = false
	
	else:
		## If this quad is not visible, there are likely children displaying it.
		for subquad in _subquads:
			subquad.reset_visibility()


## Returns true if this quads cull_box AABB intersects with a sphere with the
## specified radius and center point.
func within_sphere(center:Vector3, radius:float) -> bool:
	var radius_squared := radius * radius
	var dmin := 0.0
	
	for i in range(3):
		if center[i] < cull_box.position[i]:
			dmin += pow(center[i] - cull_box.position[i], 2.0)
		
		elif center[i] > cull_box.end[i]:
			dmin += pow(center[i] - cull_box.end[i], 2.0)
	
	return dmin <= radius_squared
