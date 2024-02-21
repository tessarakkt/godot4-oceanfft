@tool
@icon("res://addons/tessarakkt.oceanfft/icons/QuadTree3D.svg")
extends Node3D
class_name QuadTree3D

@export var trigger_reinitialize: bool:
	set(value):
		reinitialize()

## Specifies the LOD level of the current quad. There will be X - 1 subquad
## levels nested below this quad.
@export_range(0, 1000000, 1) var lod_level := 2

## Horizontal size of the current quad.
@export_range(1.0, 65535.0) var quad_size := 1024.0

## Morph range for CDLOD geomorph between LOD levels.
@export_range(0.0, 1.0, 0.001) var morph_range := 0.15

## Vertex resolution of each of the quads in this tree.
@export_range(0, 32000, 1) var mesh_vertex_resolution := 256

## Ranges for each LOD level. Accessed as ranges[lod_level].
@export var ranges:Array[float] = [512.0, 1024.0, 2048.0]

## The visual shader to apply to the surface geometry.
@export var material: Material:
	set(value):
		material = value
		if mesh_instance:
			mesh_instance.material_override = material
		for quad in _subquads:
			quad.material = material
		if material and material is ShaderMaterial:
			## Set fade range start
			if material.get_shader_parameter("vertex_resolution"):
				material.set_shader_parameter("vertex_resolution", mesh_vertex_resolution)

## The camera this QuadTree3D is basing its LOD calculations on
@export var camera: Camera3D
var _camera : Camera3D:
	get:
		if camera:
			return camera
		return _get_camera()
		
## Whether the current quad is the root quad in the tree. Initializes all nested
## subquads on ready.
var is_root_quad := true

## If this is true, the LOD system will be paused in its current state.
var pause_cull := false

## Meshes for each LOD level.
var lod_meshes:Array[PlaneMesh] = []

## This quads mesh instance.
var mesh_instance:MeshInstance3D

var _visibility_detector:VisibleOnScreenNotifier3D
var _subquads:Array[QuadTree3D] = []
var _has_initialized := false

func _ready() -> void:
	var subquad_node
	
	if lod_meshes.is_empty():
		_create_lod_meshes()

	mesh_instance = MeshInstance3D.new()
	subquad_node = Node3D.new()
	_visibility_detector = VisibleOnScreenNotifier3D.new()
	add_child(subquad_node)
	add_child(mesh_instance)
	add_child(_visibility_detector)
	
	if Engine.is_editor_hint() and is_root_quad:
		mesh_instance.visible = true
	else:
		mesh_instance.visible = false
	mesh_instance.mesh = lod_meshes[lod_level]
	mesh_instance.material_override = material
	mesh_instance.set_instance_shader_parameter("patch_size", quad_size)
	mesh_instance.set_instance_shader_parameter("min_lod_morph_distance", ranges[lod_level] * 2 * (1.0 - morph_range))
	mesh_instance.set_instance_shader_parameter("max_lod_morph_distance", ranges[lod_level] * 2)
	
	_visibility_detector.aabb = AABB(Vector3(-quad_size * 0.75, -quad_size * 0.5, -quad_size * 0.75),
			Vector3(quad_size * 1.5, quad_size, quad_size * 1.5))
	mesh_instance.custom_aabb = _visibility_detector.aabb
	
	## If this is not the most detailed LOD level, initialize more detailed
	## children.
	if lod_level > 0:
		for offset in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			var offset_length:float = quad_size * 0.25
			var new_quad = QuadTree3D.new()
			new_quad.lod_level = lod_level - 1
			new_quad.quad_size = quad_size * 0.5
			new_quad.ranges = ranges
			new_quad.process_mode = PROCESS_MODE_DISABLED
			new_quad.position = offset * offset_length
			new_quad.morph_range = morph_range
			new_quad.lod_meshes = lod_meshes
			new_quad.is_root_quad = false
			new_quad.material = material
			new_quad.camera = _camera
			
			subquad_node.add_child(new_quad)
			_subquads.append(new_quad)

## Process mode is set to PROCESS_MODE_DISABLED for subquads, so only the root
## quad will run _process().
func _process(_delta:float) -> void:
	if not pause_cull and Engine.get_frames_drawn() % 2:
		lod_select(_camera.global_position)

## Select which meshes will be displayed at which LOD level. A return value of
## true marks the node as handled, and a value of false indicates the parent
## node must handle it.
## cam_pos is the camera/player position in global coordinates.
func lod_select(cam_pos:Vector3) -> bool:
	if Engine.is_editor_hint():
		return false
	## Beginning at the root node of lowest LOD, and working towards the most
	## detailed LOD 0.

	# if !Engine.is_editor_hint():
	# 	print("\nLOD SELECTOR")
	# 	print("lod selector cam pos", cam_pos)
	
	if not within_sphere(cam_pos, ranges[lod_level]):
		# print("not within sphere")
		## This quad is not within range of the selected LOD level, the parent
		## will need to display this at a lower detailed LOD. Return false to
		## mark the area as not handled.
		reset_visibility()
		return false
	
	if not _visibility_detector.is_on_screen():
		## This quad is not on screen. Do not make it visible, and return true
		## to mark the area as handled.
		mesh_instance.visible = false
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
			# print("within range of LOD level, but a more detailed child may be able to handle this")
			reset_visibility()
			
			## No children are within range of their LOD levels, make this quad
			## visible to handle the area.
			for subquad in _subquads:
				subquad.mesh_instance.visible = true
		
		else:
			## At least one more detailed children is within LOD range. Recurse
			## through them and select them if appropriate.
			for subquad in _subquads:
				subquad.mesh_instance.visible = false
				if not subquad.lod_select(cam_pos):
					subquad.mesh_instance.visible = true
		
		## The area has been handled.
		return true


## Reset this quad and all subquads to invisible.
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
	var cull_box := AABB(global_position + Vector3(-quad_size * 0.5, -10, -quad_size * 0.5),
			Vector3(quad_size, 20, quad_size))
	
	for i in range(3):
		if center[i] < cull_box.position[i]:
			dmin += pow(center[i] - cull_box.position[i], 2.0)
		
		elif center[i] > cull_box.end[i]:
			dmin += pow(center[i] - cull_box.end[i], 2.0)
	
	return dmin <= radius_squared

# More expensive than it needs to be but should only be called in-editor
func reinitialize():
	if !is_node_ready():
		return
	for child in get_children():
		child.queue_free()
		remove_child(child)
	_create_lod_meshes()
	_ready()

func _get_camera() -> Camera3D:
	var cam : Camera3D
	if Engine.is_editor_hint():
		cam = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	elif get_viewport():
		cam = get_viewport().get_camera_3d()
	if cam:
		material.set_shader_parameter("view_distance_max", cam.far)
	return cam

func _create_lod_meshes():
	print("clear lod meshes")
	lod_meshes.clear()
	## Initialize LOD meshes for each level
	var current_size = quad_size
	
	print("creating lod meshes")
	for i in range(lod_level + 1):
		var mesh := PlaneMesh.new()
		mesh.size = Vector2.ONE * current_size
		mesh.subdivide_depth = mesh_vertex_resolution - 1
		mesh.subdivide_width = mesh_vertex_resolution - 1
		
		lod_meshes.insert(0, mesh)
		current_size *= 0.5
	print(lod_meshes)
