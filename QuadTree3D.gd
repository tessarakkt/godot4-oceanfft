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
		return _visibility_detector.aabb
	set(new_aabb):
		_visibility_detector.aabb = AABB(
				global_position + new_aabb.position,
				new_aabb.size)

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
	cull_box = AABB(Vector3(-quad_size * 0.8, -128.0, -quad_size * 0.8),
			Vector3(quad_size * 1.6, 256.0, quad_size * 1.6))
	
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
#		var offset:Vector3 = global_position - _camera.global_position.snapped(Vector3(512.0, 0.0, 512.0))
#		offset.y = 0.0
#		if not offset.is_zero_approx():
#			shift(offset)
		
		reset_visibility()
		lod_select(_camera)


## Select which meshes will be displayed at which LOD level. A return value of
## true marks the node as handled, and a value of false indicates the parent
## node must handle it.
func lod_select(cam:Camera3D) -> bool:
	## Beginning at the root node of lowest LOD, and working towards the most
	## detailed LOD 0.
	
	if not within_sphere(cam.global_position, ranges[lod_level]):
		## This node is not within range of the selected LOD level, the parent
		## will need to display this at a lower detailed LOD.
		return false
	
	if not _visibility_detector.is_on_screen() and not cull_box.has_point(cam.global_position):
		## This node is not on screen, and the camera is not within its cell. Do
		## not make it visible, and mark it as handled.
		#mesh.mesh = high_lod_mesh
		#mesh.visible = true
		return true
	
	if lod_level == 0:
		## Within range of selected LOD level, and at lowest LOD, there are no
		## more detailed children to render this. Make it visible.
		mesh.mesh = high_lod_mesh
		mesh.visible = true
		return true
	
	else:
		## Within range of selected LOD level, but there are more detailed
		## children that may be able to display this.
		if not within_sphere(cam.global_position, ranges[lod_level - 1]):
			## No children are within range of their LOD levels, handle the
			## entire node here.
			mesh.mesh = high_lod_mesh
			mesh.visible = true
		
		else:
			## Some more detailed children are within their LOD range. Recurse
			## through them and select them.
			for subquad in _subquads:
				if not subquad.lod_select(cam):
					## If a child node is out of its LOD range, we need to cover
					## it with a lower LOD.
					subquad.mesh.mesh = low_lod_mesh
					subquad.visible = true
					subquad.position.y += 32
		
		return true


## Reset all quads to a certain visibility, defaults to false.
func reset_visibility(to:bool = false) -> void:
	mesh.visible = to
	
	for subquad in _subquads:
		subquad.reset_visibility(to)
		subquad.position.y = 0


## Shift the plane horizontally. Intended for following the player position.
## This should be used rather than adjusting position directly, as this will
## properly adjust the AABB cull boxes of this and child quads. Y coordinate
## should be set to 0 offset is used as global coordinates.
func shift(offset:Vector3, is_root_quad:bool = true) -> void:
	cull_box.position += offset
	
	if is_root_quad:
		global_position += offset
	
	for subquad in _subquads:
		subquad.shift(offset, false)


## Returns true if this quads cull_box AABB intersects with a sphere with the
## specified radius and center point.
func within_sphere(center:Vector3, radius:float) -> bool:
	var vector:Vector3 = (cull_box.get_center() - center).normalized()
	
	if cull_box.intersects_segment(center, center + vector * radius):
		return true
	
	for i in range(8):
		if (cull_box.get_endpoint(i) - center).length() < radius:
			return true
	
	return false
