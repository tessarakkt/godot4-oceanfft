@icon("res://addons/tessarakkt.oceanfft/icons/BuoyancyProbe3D.svg")
extends Marker3D
class_name BuoyancyProbe3D
## Buoyancy probe used by BuoyancyBody3D to approximate an objects buoyancy.
##
## This is used as a wave height sampler by BuoyancyBody3D in order to do
## buoyancy calculations. It has no effect on its own, and must be added to a
## buoyancy body in order to provide an effect. This could also be used as a
## generic wave height sampler.

## The buoyancy multipler that applies to this probe only.
@export_range(0.0, 100.0) var buoyancy_multiplier := 1.0

## The height sampling steps used when sampling the wave height textures. This
## is used to correct for the horizontal displacement that the waves include.
@export_range(0, 10, 1) var height_sampling_steps := 2

## The highest index displacement cascade the wave height will be sampled from.
## lower numbers can be used to filter out smaller waves from a probes height
## sample. Useful for making a large object disregard small waves and only
## respond to larger swell waves.
@export_range(0, 2, 1) var max_cascade := 1


## The ocean simulation that will be sampled for wave height. If this is a child
## of a BuoyancyBody3D's BuoyancyProbes container node when
## BuoyancyBody3D._ready() is called, the bodies assigned ocean will be assigned
## to this probe. If the probe is added to the body after _ready(), the ocean
## will need to be manually assigned.
var ocean:Ocean3D


## Get the wave height at this buoyancy probes's location.
func get_wave_height() -> float:
	return ocean.get_wave_height(global_position, max_cascade, height_sampling_steps)
