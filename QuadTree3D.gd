extends Node3D
class_name QuadTree3D


@export_range(0, 1000000, 1) var lod_level := 2
@export_range(1.0, 8192.0) var quad_size := 1024.0
@export_range(1.0, 8192.0) var mesh_size := 256.0
@export var high_lod_mesh:Mesh
@export var low_lod_mesh:Mesh
@export var ranges:Array[float] = [512.0, 1024.0, 2048.0]
@export_node_path(Camera3D) var camera


var pause_cull := false
var cull_box:AABB:
	get:
		return AABB(
				global_position + _visibility_detector.aabb.position,
				_visibility_detector.aabb.size)
	set(new_aabb):
		_visibility_detector.aabb = new_aabb

var mesh:MeshInstance3D
var material:ShaderMaterial:
	get:
		return mesh.material_override
	set(new_material):
		mesh.material_override = new_material


var _subquads:Array[QuadTree3D] = []
var _camera:Camera3D


@onready var _visibility_detector:VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D


func _ready() -> void:
	## For some reason this doesn't work as a preload()? I'm probably doing
	## something wrong... It's not enough of a problem to care right now.
	var quad = load("res://QuadTree3D.tscn")
	var offset_length:float = quad_size * 0.25
	
	mesh = $MeshInstance3D
	mesh.mesh = high_lod_mesh
	mesh.scale = Vector3.ONE * (quad_size / mesh_size)
	
	## If a NodePath to a Camera3D has been specified in the export, grab it.
	## This is the camera that culling will be based on.
	if camera != null:
		_camera = get_node(camera)
	
	## Initialized with size only, global position is added in the setter
	cull_box = AABB(Vector3(-quad_size * 0.5, -128.0, -quad_size * 0.5),
			Vector3(quad_size * 1.0, 256.0, quad_size * 1.0))
	
	## If this is not the most detailed LOD level, initialize more detailed
	## children.
	if lod_level > 0:
		for offset in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			var new_quad = quad.instantiate()
			new_quad.lod_level = lod_level - 1
			new_quad.quad_size = quad_size * 0.5
			new_quad.ranges = ranges
			new_quad.process_mode = PROCESS_MODE_DISABLED
			new_quad.position = offset * offset_length
			new_quad.high_lod_mesh = high_lod_mesh
			new_quad.low_lod_mesh = low_lod_mesh
			
			$SubQuads.add_child(new_quad)
			_subquads.append(new_quad)


## Process mode is set to PROCESS_MODE_DISABLED for subquads, so only the root
## quad will run _process().
func _process(_delta:float) -> void:
	if not pause_cull:
		var offset:Vector3 = _camera.global_position.snapped(Vector3(512.0, 0.0, 512.0))
		var frustrum_override := false
		offset.y = 0.0
		if not offset.is_equal_approx(global_position):
			global_position = offset
			frustrum_override = true
		
		reset_visibility()
		lod_select(_camera.global_position, frustrum_override)


## Select which meshes will be displayed at which LOD level. A return value of
## true marks the node as handled, and a value of false indicates the parent
## node must handle it.
## cam_pos is the camera/player position in global coordinates.
## frustrum_override, if true, forces all quads to be considered within the
## camera frustrum. If this is false, this will be determined by a
## VisibleOnScreenNotifier3D for each quad.
func lod_select(cam_pos:Vector3, frustrum_override:bool) -> bool:
	## Beginning at the root node of lowest LOD, and working towards the most
	## detailed LOD 0.
	
	if not within_sphere(cam_pos, ranges[lod_level]):
		## This quad is not within range of the selected LOD level, the parent
		## will need to display this at a lower detailed LOD. Return false to
		## mark the area as not handled.
		return false
	
	if not (_visibility_detector.is_on_screen() or frustrum_override):
		## This quad is not on screen. Do not make it visible, and return true
		## to mark the area as handled.
		return true
	
	if lod_level == 0:
		## Within range of selected LOD level, and at highest detailed LOD,
		## there are no more detailed children to render this. Make this quad
		## visible. Return true to mark the area handled.
		mesh.mesh = high_lod_mesh
		mesh.visible = true
		return true
	
	else:
		## Within range of selected LOD level, but there are more detailed
		## children that may be able to display this. Check if any are within
		## their LOD range.
		if not within_sphere(cam_pos, ranges[lod_level - 1]):
			## No children are within range of their LOD levels, make this quad
			## visible to handle the area.
			mesh.mesh = high_lod_mesh
			mesh.visible = true
		
		else:
			## At least one more detailed children is within LOD range. Recurse
			## through them and select them if appropriate.
			for subquad in _subquads:
				if not subquad.lod_select(cam_pos, frustrum_override):
					## If a child node is out of its LOD range, we need to force
					## it to display at a lower detailed LOD.
					subquad.mesh.mesh = low_lod_mesh
					subquad.mesh.visible = true
		
		## The area has been handled.
		return true


## Reset all quads to a certain visibility, defaults to false.
func reset_visibility(to:bool = false) -> void:
	mesh.visible = to
	
	for subquad in _subquads:
		subquad.reset_visibility(to)
		subquad.position.y = 0


## Returns true if this quads cull_box AABB intersects with a sphere with the
## specified radius and center point.
func within_sphere(center:Vector3, radius:float) -> bool:
	var vector:Vector3 = (cull_box.abs().get_center() - center).normalized()
	
	if cull_box.intersects_segment(center, center + (vector * radius)):
		return true
	
	return false
