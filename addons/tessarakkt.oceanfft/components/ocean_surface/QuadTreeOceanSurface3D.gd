@tool
extends OceanSurface3DBase
class_name QuadTreeOceanSurface3D

## Specifies the LOD level of the current quad. There will be X - 1 subquad
## levels nested below this quad.
@export_range(0, 1000000, 1) var lod_level := 2:
	set(value):
		lod_level = value
		quad_tree.lod_level = lod_level
		quad_tree.reinitialize()

## Horizontal size of the current quad.
@export_range(1.0, 65535.0) var quad_size := 1024.0:
	set(value):
		quad_size = value
		quad_tree.quad_size = quad_size
		quad_tree.reinitialize()

## Morph range for CDLOD geomorph between LOD levels.
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
		quad_tree.reinitialize()

var quad_tree : QuadTree3D

func _init():
	if !quad_tree:
		quad_tree = QuadTree3D.new()
		add_child(quad_tree)

func _on_set_ocean():
	quad_tree.material = ocean.material