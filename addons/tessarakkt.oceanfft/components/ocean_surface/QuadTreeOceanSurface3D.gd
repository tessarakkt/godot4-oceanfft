@tool
extends OceanSurface3DBase
class_name QuadTreeOceanSurface3D

## Horizontal size of the current quad.
@export_range(1.0, 65535.0) var quad_size := 1024.0:
	set(value):
		quad_size = value
		quad_tree.quad_size = quad_size
		quad_tree.reinitialize()

## Morph range for CDLOD geomorph between LOD levels.
# TODO not used?
@export_range(0.0, 1.0, 0.001) var morph_range := 0.15:
	set(value):
		morph_range = value
		quad_tree.morph_range = morph_range
		quad_tree.reinitialize()

## Vertex resolution of each of the quads in this tree.
@export_range(0, 32000, 1) var mesh_vertex_resolution := 256:
	set(value):
		mesh_vertex_resolution = value
		quad_tree.mesh_vertex_resolution = mesh_vertex_resolution
		quad_tree.reinitialize()

## Ranges for each LOD level. Accessed as ranges[lod_level].
@export var ranges:Array[float] = [512.0, 1024.0, 2048.0]:
	set(value):
		ranges = value
		quad_tree.ranges = ranges
		quad_tree.lod_level = ranges.size() - 1
		quad_tree.reinitialize()

var quad_tree : QuadTree3D

func _init():
	if !quad_tree:
		quad_tree = QuadTree3D.new()
		add_child(quad_tree)

func _on_set_ocean():
	quad_tree.material = ocean.material