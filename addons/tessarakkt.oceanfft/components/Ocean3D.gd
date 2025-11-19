@icon("res://addons/tessarakkt.oceanfft/icons/Ocean3D.svg")
extends Resource
class_name Ocean3D


const UNIFORM_SET := 0
const WORK_GROUP_DIM := 32
const GOLDEN_RATIO := 1.618033989


enum Binding {
	SETTINGS = 0,
	INITIAL_SPECTRUM = 20,
	SPECTRUM = 21,
	PING = 25,
	PONG = 26,
	INPUT = 27,
	OUTPUT = 28,
	DISPLACEMENT = 30,
}


enum FFTResolution {
	FFT_2x2 = 2,
	FFT_4x4 = 4,
	FFT_8x8 = 8,
	FFT_16x16 = 16,
	FFT_32x32 = 32,
	FFT_64x64 = 64,
	FFT_128x128 = 128,
	FFT_256x256 = 256,
	FFT_512x512 = 512,
	FFT_1024x1024 = 1024,
	FFT_2048x2048 = 2048,
}


## Whether _simulate() should be called by _process(). The simulation_frameskip
## setting will control whether this calls every frame, or skips frames. This
## does not affect the ability to call _simulate() directly, but it probably
## should be disabled if you are calling the simulation directly.
@export var simulation_enabled := true

## The vertex and shader that will use the generated displacement maps to deform
## the surface geometry and apply visual shading.
@export var material:ShaderMaterial = preload("res://addons/tessarakkt.oceanfft/Ocean.tres")

@export_group("Simulation Settings")

## Controls how many frames the _process() skips calling _simulate().
## For a smooth visual simulation, _simulate() should be called at least 30
## frames per second (FPS / (frameskip + 1) >= 30).
## Set to 0 to disable frame skip.
@export_range(0, 30, 1) var simulation_frameskip := 0

## Controls how frequently _process() requests a heightmap sync when calling
## _simulate(). This is used by the buoyancy system, high frameskip settings
## may cause floating objects to appear disconnected from the rendered waves.
## When used in conjunction with simulation_frameskip, this will only count
## frames where _simulate() was called by _process().
## Set to -1 to disable heightmap sync (breaks buoyancy).
## Set to 0 to disable heightmap sync frame skip.
@export_range(-1, 30, 1) var heightmap_sync_frameskip := 0

## The resolution to generate the displacement maps at via FFT in the compute
## shaders.
@export var fft_resolution:FFTResolution = FFTResolution.FFT_256x256:
	set(new_fft_resolution):
		fft_resolution = new_fft_resolution
		_is_initial_spectrum_changed = true

## The horizontal distance the ocean patch should be simulated for.
@export_range(0, 2048) var horizontal_dimension := 256:
	set(new_horizontal_dimension):
		horizontal_dimension = new_horizontal_dimension
		_is_initial_spectrum_changed = true

## The time scale for the simulation. Speeds up or slows down the waves.
@export_range(0.001, 5.0) var time_scale := 1.0

## The wave number ranges of the wave energy spectrum that each displacement
## cascade covers.
@export var cascade_ranges:Array[Vector2] = [Vector2(0.0, 0.03), Vector2(0.03, 0.15), Vector2(0.15, 1.0)]

## The UV scales applied to each displacement map cascade when applied to the
## surface geometry.
@export var cascade_scales:Array[float] = [GOLDEN_RATIO * 2.0, GOLDEN_RATIO, 0.5]


@export_group("Surface Deform Modifiers")

## Reduce the height of the ocean surface exponentially as distance from the
## camera increases. Simulates planetary curve.
@export_range(0.0, 0.001, 0.0000001) var planetary_curve_strength := 0.000001:
	set(new_planetary_curve_strength):
		planetary_curve_strength = new_planetary_curve_strength
		material.set_shader_parameter("planetary_curve_strength", planetary_curve_strength)

@export_subgroup("Amplitude Distance Fade")

## Amplitude scale applied to the ocean surface at amplitude_scale_fade_distance
## from the camera.
@export_range(0.0, 5.0, 0.01) var amplitude_scale_min := 0.25:
	set(new_amplitude_scale_min):
		amplitude_scale_min = new_amplitude_scale_min
		material.set_shader_parameter("amplitude_scale_min", amplitude_scale_min)

## Amplitude scale applied to the ocean surface near the camera.
@export_range(0.0, 5.0, 0.01) var amplitude_scale_max := 1.0:
	set(new_amplitude_scale_max):
		amplitude_scale_max = new_amplitude_scale_max
		material.set_shader_parameter("amplitude_scale_max", amplitude_scale_max)

## Linear interpolate between amplitude_scale_min at 0 units from camera, and
## amplitude_scale_max at amplitude_scale_fade_distance units from camera.
@export_range(0.0, 32000.0, 10.0) var amplitude_scale_fade_distance := 12000.0:
	set(new_amplitude_scale_fade_distance):
		amplitude_scale_fade_distance = new_amplitude_scale_fade_distance
		material.set_shader_parameter("amplitude_scale_fade_distance", amplitude_scale_fade_distance)

@export_subgroup("Domain Warp")

## Noise texture used to domain warp the displacement maps as they are applied
## to the surface.
@export var domain_warp_texture:NoiseTexture2D:
	set(new_domain_warp_texture):
		material.set_shader_parameter("domain_warp_texture", new_domain_warp_texture)
		domain_warp_texture = new_domain_warp_texture
		await new_domain_warp_texture.changed
		_domain_warp_image = new_domain_warp_texture.get_image()

## Controls how much distortion is applied to the displacement map domain warp
@export_range(0.0, 5000.0) var domain_warp_strength := 1500.0:
	set(new_domain_warp_strength):
		material.set_shader_parameter("domain_warp_strength", new_domain_warp_strength)
		domain_warp_strength = new_domain_warp_strength

## Controls how large the domain_warp_texture is stretched horizontally.
## Smaller numbers result in more horizontal stretching.
## To stretch the texture to cover X world units, set this value to 1.0 / X
@export_range(0.0, 1.0, 0.0000001) var domain_warp_uv_scale := 0.0000625:
	set(new_domain_warp_uv_scale):
		material.set_shader_parameter("domain_warp_uv_scale", new_domain_warp_uv_scale)
		domain_warp_uv_scale = new_domain_warp_uv_scale


@export_group("Weather Settings")

## Wave choppiness value. Higher values give waves sharper crests, but can cause
## wave geometry to fold in over itself.
@export_range(0.0, 10.0) var choppiness := 1.5:
	set(new_choppiness):
		choppiness = new_choppiness

## The wind direction.
@export_range(0.0, 360.0) var wind_direction_degrees := 0.0:
	set(new_wind_direction_degrees):
		wind_direction = deg_to_rad(new_wind_direction_degrees)

		wind_vector.x = cos(wind_direction)
		wind_vector.y = sin(wind_direction)
		
		wind_vector = wind_vector.normalized() * wind_speed
	get:
		return rad_to_deg(wind_direction)

## Controls how much the generated displacement maps are scrolled horizontally
## over time.
@export_range(-10.0, 10.0) var wave_scroll_speed := 0.0

## The speed of the wind passed to the wave simulation.
@export_range(0.0, 1000.0) var wind_speed := 15.0:
	set(new_wave_length):
		wind_vector = wind_vector.normalized() * new_wave_length
		wind_speed = new_wave_length


var initialized := false

## The "accumulated wind" that has blown, for wave scrolling from wind.
## Updated each frame by Ocean3D._process()
var wind_uv_offset := Vector2.ZERO

## The wind direction.
var wind_direction := 0.0

var wind_vector := Vector2(15.0, 0.0):
	set(new_wave_vector):
		wind_vector = new_wave_vector
		_is_initial_spectrum_changed = true


var _uv_scale := 0.00390625

var _rd:RenderingDevice = RenderingServer.get_rendering_device()

var _fmt_r32f := RDTextureFormat.new()
var _fmt_rgba32f := RDTextureFormat.new()

var _initial_spectrum_shader:RID
var _initial_spectrum_pipeline:RID
var _is_initial_spectrum_changed := true
var _initial_spectrum_settings_buffer_cascade:Array[RID] = []
var _initial_spectrum_settings_uniform_cascade:Array[RDUniform] = []
var _initial_spectrum_uniform_cascade:Array[RDUniform] = []
var _initial_spectrum_tex_cascade:Array[RID] = []

var _phase_shader:RID
var _phase_pipeline:RID
var _phase_settings_buffer:RID
var _phase_settings_uniform := RDUniform.new()
var _ping_uniform_cascade:Array[RDUniform] = []
var _pong_uniform_cascade:Array[RDUniform] = []
var _ping_image_cascade:Array[Image] = []
var _ping_tex_cascade:Array[RID] = []
var _pong_tex_cascade:Array[RID] = []

var _spectrum_shader:RID
var _spectrum_pipeline:RID
var _is_spectrum_changed := true
var _spectrum_settings_buffer:RID
var _spectrum_settings_uniform := RDUniform.new()
var _spectrum_uniform_cascade:Array[RDUniform] = []
var _spectrum_tex_cascade:Array[RID] = []

var _fft_horizontal_shader:RID
var _fft_horizontal_pipeline:RID
var _fft_vertical_shader:RID
var _fft_vertical_pipeline:RID
var _fft_settings_buffer:RID
var _fft_settings_uniform := RDUniform.new()
var _sub_pong_uniform := RDUniform.new()
var _sub_pong_tex:RID

var _waves_image_cascade:Array[Image] = []
var _waves_texture_cascade:Array[Texture2DRD] = []

var _is_ping_phase := true

var _frameskip := 0
var _heightmap_sync_frameskip := 0
var _accumulated_delta := 0.0

var _domain_warp_image:Image

var _rng := RandomNumberGenerator.new()


## Initialize the simulation
func initialize_simulation() -> void:
	_rng.randomize()
	RenderingServer.call_on_render_thread(_initialize_simulation)


## Simulate a single iteration of the ocean. Respects frameskip and simulation
## enabled settings.
func simulate(delta:float) -> void:
	assert(initialized, "Ocean3D not initialized")
	
	if simulation_enabled:
		_accumulated_delta += delta
		
		wind_uv_offset += Vector2(cos(wind_direction), sin(wind_direction)) * wave_scroll_speed * delta
		material.set_shader_parameter("wind_uv_offset", wind_uv_offset)
		
		if simulation_frameskip > 0:
			_frameskip += 1
			if _frameskip <= simulation_frameskip:
				return
			else:
				_frameskip = 0
		
		var sync_heightmap := heightmap_sync_frameskip != -1
		if heightmap_sync_frameskip > 0:
			_heightmap_sync_frameskip += 1
			if _heightmap_sync_frameskip <= heightmap_sync_frameskip:
				sync_heightmap = false
			else:
				sync_heightmap = true
				_heightmap_sync_frameskip = 0
		
		RenderingServer.call_on_render_thread(_simulate.bind(_accumulated_delta, sync_heightmap))
		_accumulated_delta = 0.0


## Simulate a single iteration of the ocean. Ignores frameskip and simulation
## enabled settings.
func force_simulate(delta:float, sync_heightmap:bool = false) -> void:
	RenderingServer.call_on_render_thread(_simulate.bind(delta, sync_heightmap))


## Convert a global position (on the horizontal XZ plane) to a pixel coordinate
## for sampling the wave displacement texture directly. The Y coordinate is
## ignored.
func global_to_pixel(camera:Camera3D, global_pos:Vector3, cascade:int, apply_domain_warp:bool = true) -> Vector2i:
	## The order of operations in this function is dependent on the order of
	## operations used in the vertex shader to rotate and scale the displacement
	## map before applying it. Make sure to check if the vertex shader should be
	## updated to account for any changes made here.
	
	assert(initialized, "Ocean3D not initialized")
	
	## Convert to UV coordinate
	## The visual shader uses the global XZ coordinates as UV
	var uv_pos := Vector2.ZERO
	uv_pos.x = global_pos.x
	uv_pos.y = global_pos.z
	
	## Apply domain warp
	if apply_domain_warp and _domain_warp_image != null:
		var linear_dist:float = (global_pos - camera.global_position).length()
		
		## Recursive call; note that it is called with the apply_domain_warp
		## parameter set to false to avoid infinite recursion.
		var base_pixel_pos := global_to_pixel(camera, global_pos, cascade, false)
		var domain_warp := Vector2(
				_domain_warp_image.get_pixelv(base_pixel_pos * domain_warp_uv_scale).r,
				_domain_warp_image.get_pixelv(-base_pixel_pos * domain_warp_uv_scale).r)
		domain_warp *= domain_warp_strength * (linear_dist / camera.far)
		uv_pos += domain_warp
	
	## Apply UV scale
	uv_pos *= _uv_scale
	uv_pos *= 1.0 / cascade_scales[cascade]
	
	## Offset by wind scrolling
	uv_pos += wind_uv_offset * cascade_scales[cascade]
	
	## Normalize values to 0.0-1.0
	uv_pos.x -= floorf(uv_pos.x)
	uv_pos.y -= floorf(uv_pos.y)
	
	## Convert to pixel coordinate
	var pixel_pos := Vector2i.ZERO
	pixel_pos.x = floor((fft_resolution - 1) * uv_pos.x)
	pixel_pos.y = floor((fft_resolution - 1) * uv_pos.y)
	
	return pixel_pos


## Query the wave height at a given location on the horizontal XZ plane. The Y
## coordinate is ignored, and global position in this context is the position
## relative to the oceans parent node. Since each pixel encodes both a vertical
## and horizontal displacement, we need to offset the horizontal displacement 
## and resample a few times to get an accurate height. The number of resample
## iterations is defined by steps parameter.
func get_wave_height(camera:Camera3D, global_pos:Vector3, max_cascade:int = 1, steps:int = 2) -> float:
	assert(initialized, "Ocean3D not initialized")
	
	var pixel:Color
	var xz_offset := Vector3.ZERO
	var total_height := 0.0
	var linear_dist := (global_pos - camera.global_position).length()
	
	## Wave Displacements
	for cascade in range(max_cascade):
		for i in range(steps):
			var pixel_pos := global_to_pixel(camera, global_pos - xz_offset, cascade)
			
			pixel = _waves_image_cascade[cascade].get_pixelv(pixel_pos)
			xz_offset.x += pixel.r
			xz_offset.z += pixel.b
		
		total_height += pixel.g
		xz_offset = Vector3.ZERO
	
	## Wave Amplitude Distance Fade
	var amplitude_fade_range:float = clamp(linear_dist, 0.0, amplitude_scale_fade_distance) / amplitude_scale_fade_distance
	total_height *= lerp(amplitude_scale_max, amplitude_scale_min, amplitude_fade_range)
	
	## Planetary Curve
	var curvation:float = planetary_curve_strength * (pow(global_pos.x - camera.global_position.x, 2.0) + pow(global_pos.y - camera.global_position.z, 2.0))
	total_height -= curvation;
	
	return total_height


## Get the wave displacement map of a single cascade as an Image.
## This returns the displacement map already cached on the CPU, it will not
## call _simulate(), or marshall additional data from the GPU.
func get_waves(cascade:int = 0) -> Image:
	assert(initialized, "Ocean3D not initialized")
	return _waves_image_cascade[cascade]


## Get the wave displacement map of a single cascade as a Texture2DRD.
func get_waves_texture(cascade:int = 0) -> Texture2DRD:
	assert(initialized, "Ocean3D not initialized")
	return _waves_texture_cascade[cascade]


## Get the wave displacement maps of all cascades as an Array of Images.
## This returns the displacement map already cached on the CPU, it will not
## call _simulate(), or marshall additional data from the GPU.
func get_all_waves() -> Array[Image]:
	assert(initialized, "Ocean3D not initialized")
	return _waves_image_cascade


## Get the wave displacement maps of all cascades as an Array of Texture2DRDs.
func get_all_waves_textures() -> Array[Texture2DRD]:
	assert(initialized, "Ocean3D not initialized")
	return _waves_texture_cascade


func _pack_initial_spectrum_settings(cascade:int) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension * cascade_scales[cascade]]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([cascade_ranges[cascade].x, cascade_ranges[cascade].y, wind_vector.x, wind_vector.y]).to_byte_array())
	return settings_bytes


func _pack_phase_settings(delta_time:float, cascade:int) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension * cascade_scales[cascade]]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([delta_time]).to_byte_array())
	return settings_bytes


func _pack_spectrum_settings(cascade:int) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([horizontal_dimension * cascade_scales[cascade]]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([choppiness, fft_resolution]).to_byte_array())
	return settings_bytes


func _pack_fft_settings(subseq_count:int) -> PackedByteArray:
	return PackedInt32Array([fft_resolution, subseq_count]).to_byte_array()


#### Render Thread Code
################################################################################
## All code below this point must be run on the main render thread via
## RenderingServer.call_on_render_thread().


## Initialize the ocean simulation. Compiles shaders, prepares texture and
## settings buffers.
## This must be called via RenderingServer.call_on_render_thread().
func _initialize_simulation() -> void:
	var shader_file:Resource
	var settings_bytes:PackedByteArray
	var initial_image_rf := Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RF)
	var initial_image_rgbaf := Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGBAF)
	
	#### Initialize RDTextureFormats
	############################################################################
	## These are initialized once and reused as needed.
	
	_fmt_r32f.width = fft_resolution
	_fmt_r32f.height = fft_resolution
	_fmt_r32f.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	_fmt_r32f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	_fmt_rgba32f.width = fft_resolution
	_fmt_rgba32f.height = fft_resolution
	_fmt_rgba32f.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	_fmt_rgba32f.usage_bits = _fmt_r32f.usage_bits
	
	#### Compile & Initialize Initial Spectrum Shader
	############################################################################
	## The Initial Spectrum texture is initialized empty. It will be generated
	## by the Initial Spectrum shader based on the wind, FFT resolution, and
	## horizontal dimension inputs. It will be static and constant for a given
	## set of inputs, and doesn't need to be recalculated per frame, only when
	## inputs change.
	
	## Compile Shader
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/InitialSpectrum.glsl")
	_initial_spectrum_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_initial_spectrum_pipeline = _rd.compute_pipeline_create(_initial_spectrum_shader)
	
	## Initialize cascaded FFTs
	_initial_spectrum_settings_buffer_cascade.resize(cascade_ranges.size())
	_initial_spectrum_settings_uniform_cascade.resize(cascade_ranges.size())
	_initial_spectrum_tex_cascade.resize(cascade_ranges.size())
	_initial_spectrum_uniform_cascade.resize(cascade_ranges.size())
	
	for i in cascade_ranges.size():
		## Initialize Settings Buffer
		settings_bytes = _pack_initial_spectrum_settings(i)
		_initial_spectrum_settings_buffer_cascade[i] = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
		_initial_spectrum_settings_uniform_cascade[i] = RDUniform.new()
		_initial_spectrum_settings_uniform_cascade[i].uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		_initial_spectrum_settings_uniform_cascade[i].binding = Binding.SETTINGS
		_initial_spectrum_settings_uniform_cascade[i].add_id(_initial_spectrum_settings_buffer_cascade[i])
	
		## Initialized empty, it will be generated on the first frame
		_initial_spectrum_tex_cascade[i] = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [initial_image_rf.get_data()])
		_initial_spectrum_uniform_cascade[i] = RDUniform.new()
		_initial_spectrum_uniform_cascade[i].uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		_initial_spectrum_uniform_cascade[i].binding = Binding.INITIAL_SPECTRUM
		_initial_spectrum_uniform_cascade[i].add_id(_initial_spectrum_tex_cascade[i])
	
	#### Compile & Initialize Phase Shader
	############################################################################
	## Applies time based flow to a crafted random data spectrum.
	
	## Compile Shader
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/Phase.glsl")
	_phase_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_phase_pipeline = _rd.compute_pipeline_create(_phase_shader)
	
	## Initialize cascade arrays
	_ping_uniform_cascade.resize(cascade_ranges.size())
	_pong_uniform_cascade.resize(cascade_ranges.size())
	_ping_image_cascade.resize(cascade_ranges.size())
	_ping_tex_cascade.resize(cascade_ranges.size())
	_pong_tex_cascade.resize(cascade_ranges.size())
	
	## Initialize Settings Buffer
	settings_bytes = _pack_phase_settings(0.0, 0)
	_phase_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_phase_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_phase_settings_uniform.binding = Binding.SETTINGS
	_phase_settings_uniform.add_id(_phase_settings_buffer)
	
	#### Initialize Ping Pong Buffer Textures
	############################################################################
	## These act as the input and output buffers for the Phase shader.
	##
	## They are a form of double buffer to work around the fact that due to
	## asynchronous execution, the shader can't safely read and write from the
	## same texture in the same execution.
	##
	## On even numbered frames (the "ping phase"), we read from the Ping buffer.
	## The output is written to the Pong buffer.
	## On odd numbered frames ("pong phase"), we do the opposite, we read from
	## Pong, and write to Ping.
	##
	## On first start up, Ping gets initialized with crafted random data.
	
	var ping_data:PackedFloat32Array = []
	
	## The Ping buffer must be initialized with this crafted randomized data
	for i in range(fft_resolution * fft_resolution):
		if ping_data.append(_rng.randf_range(0.0, 1.0) * 2.0 * PI):
			print("error generating initial ping data")
	
	for cascade in cascade_ranges.size():
		_ping_image_cascade[cascade] = Image.create_from_data(fft_resolution, fft_resolution, false, Image.FORMAT_RF, ping_data.to_byte_array())
		_ping_tex_cascade[cascade] = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [_ping_image_cascade[cascade].get_data()])
		_ping_uniform_cascade[cascade] = RDUniform.new()
		_ping_uniform_cascade[cascade].uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		_ping_uniform_cascade[cascade].binding = Binding.PING
		_ping_uniform_cascade[cascade].add_id(_ping_tex_cascade[cascade])
		
		## The Pong buffer is initialized empty; it will be generated as the output
		## of the first iteration of the Phase shader based on the Ping input
		_pong_tex_cascade[cascade] = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [initial_image_rf.get_data()])
		_pong_uniform_cascade[cascade] = RDUniform.new()
		_pong_uniform_cascade[cascade].uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		_pong_uniform_cascade[cascade].binding = Binding.PONG
		_pong_uniform_cascade[cascade].add_id(_pong_tex_cascade[cascade])
	
	#### Compile & Initialize Spectrum Shader
	############################################################################
	## Merges the weather parameters calculated in the Initial Spectrum with the
	## crafted time varying randomness calculated in Phase (and stored in the
	## Ping/Pong textures)
	
	## Compile Shader
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/Spectrum.glsl")
	_spectrum_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_spectrum_pipeline = _rd.compute_pipeline_create(_spectrum_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_spectrum_settings(0)
	_spectrum_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_spectrum_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_spectrum_settings_uniform.binding = Binding.SETTINGS
	_spectrum_settings_uniform.add_id(_spectrum_settings_buffer)
	
	_spectrum_tex_cascade.resize(cascade_ranges.size())
	_spectrum_uniform_cascade.resize(cascade_ranges.size())
	_waves_image_cascade.resize(cascade_ranges.size())
	_waves_texture_cascade.resize(cascade_ranges.size())
	
	for i in cascade_ranges.size():
		## Initialized empty, it will be generated each frame
		_spectrum_tex_cascade[i] = _rd.texture_create(_fmt_rgba32f, RDTextureView.new(), [initial_image_rgbaf.get_data()])
		_spectrum_uniform_cascade[i] = RDUniform.new()
		_spectrum_uniform_cascade[i].uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		_spectrum_uniform_cascade[i].binding = Binding.SPECTRUM
		_spectrum_uniform_cascade[i].add_id(_spectrum_tex_cascade[i])
		
		## Bind the displacement map cascade texture to the visual shader
		_waves_image_cascade[i] = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGBAF)
		_waves_texture_cascade[i] = Texture2DRD.new()
		_waves_texture_cascade[i].texture_rd_rid = _spectrum_tex_cascade[i]
	
	material.set_shader_parameter("cascade_displacements", _waves_texture_cascade)
	material.set_shader_parameter("cascade_uv_scales", cascade_scales)
	material.set_shader_parameter("uv_scale", _uv_scale)
	
	#### Compile & Initialize FFT Shaders
	############################################################################
	## Converts the result of the Spectrum shader into a usable displacement map.
	##
	## Uses the Spectrum texture and SubPong texture as ping pong buffers. The
	## resulting displacement map will be stored in the Specturm texture.
	
	## Compile Shaders
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/FFTHorizontal.glsl")
	_fft_horizontal_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_fft_horizontal_pipeline = _rd.compute_pipeline_create(_fft_horizontal_shader)
	
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/FFTVertical.glsl")
	_fft_vertical_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_fft_vertical_pipeline = _rd.compute_pipeline_create(_fft_vertical_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_fft_settings(0)
	_fft_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_fft_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_fft_settings_uniform.binding = Binding.SETTINGS
	_fft_settings_uniform.add_id(_fft_settings_buffer)
	
	## Initialize empty, will be calculated based on the Spectrum
	_sub_pong_tex = _rd.texture_create(_fmt_rgba32f, RDTextureView.new(), [initial_image_rgbaf.get_data()])
	_sub_pong_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_sub_pong_uniform.add_id(_sub_pong_tex)
	
	initialized = true


## Simulate a single iteration of the ocean. The resulting displacement map
## texture can be retrieved using the get_waves_texture() function, or as an
## Image via get_waves(). The texture is the same buffer in VRAM the compute
## shaders operate on. The image is stored in CPU RAM and is only updated when
## sync_heightmap is true.
## This must be called via RenderingServer.call_on_render_thread().
func _simulate(delta:float, sync_heightmap:bool) -> void:
	var uniform_set:RID
	var compute_list:int
	var settings_bytes:PackedByteArray
	
	#### Iterate & Execute Cascades
	############################################################################
	for cascade in cascade_ranges.size():
		
		#### Update Initial Spectrum
		########################################################################
		## Only executed on first frame, or if Wind, FFT Resolution, or
		## Horizontal Dimension inputs are changed, as the output is constant
		## for a given set of inputs. The Initial Spectrum is cached in VRAM. It
		## is not returned to CPU RAM.
	
		if _is_initial_spectrum_changed:
			## Update Settings Buffer
			settings_bytes = _pack_initial_spectrum_settings(cascade)
			if _rd.buffer_update(_initial_spectrum_settings_buffer_cascade[cascade], 0, settings_bytes.size(), settings_bytes) != OK:
				print("error updating initial spectrum settings buffer")
			
			## Build Uniform Set
			uniform_set = _rd.uniform_set_create([
					_initial_spectrum_settings_uniform_cascade[cascade],
					_initial_spectrum_uniform_cascade[cascade]], _initial_spectrum_shader, UNIFORM_SET)
			
			## Create Compute List
			compute_list = _rd.compute_list_begin()
			_rd.compute_list_bind_compute_pipeline(compute_list, _initial_spectrum_pipeline)
			_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
			@warning_ignore("integer_division")
			_rd.compute_list_dispatch(compute_list, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM, 1)
			_rd.compute_list_end()
			
			_rd.free_rid(uniform_set)
		
		## Prevent this from running again until the Wind, FFT Resolution, or
		## Horizontal Dimension inputs are changed. The condition ensures it
		## runs for all cascades.
		if cascade == cascade_ranges.size() - 1:
			_is_initial_spectrum_changed = false
	
		#### Execute Phase Shader; Updates Ping Pong Buffers
		########################################################################
		
		## Leave the textures in place in VRAM, and just switch the binding
		## points.
		if _is_ping_phase:
			_ping_uniform_cascade[cascade].binding = Binding.PING
			_pong_uniform_cascade[cascade].binding = Binding.PONG
		
		else:
			_ping_uniform_cascade[cascade].binding = Binding.PONG
			_pong_uniform_cascade[cascade].binding = Binding.PING
		
		## Update Settings Buffer
		settings_bytes = _pack_phase_settings(delta * time_scale, cascade)
		if _rd.buffer_update(_phase_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
			print("error updating phase settings buffer")
		
		## Build Uniform Set
		uniform_set = _rd.uniform_set_create([
				_phase_settings_uniform,
				_ping_uniform_cascade[cascade],
				_pong_uniform_cascade[cascade]], _phase_shader, UNIFORM_SET)
		
		## Create Compute List
		compute_list = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(compute_list, _phase_pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
		@warning_ignore("integer_division")
		_rd.compute_list_dispatch(compute_list, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM, 1)
		_rd.compute_list_end()
		
		_rd.free_rid(uniform_set)
	
		#### Execute Spectrum Shader Cascades
		########################################################################
		
		## Update Settings Buffer
		settings_bytes = _pack_spectrum_settings(cascade)
		if _rd.buffer_update(_spectrum_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
			print("error updating spectrum settings buffer")
		
		## Ensure the Spectrum texture binding is correct from previous frames.
		## It gets changed later on in _simulate().
		_spectrum_uniform_cascade[cascade].binding = Binding.SPECTRUM
		
		## Build Uniform Set
		uniform_set = _rd.uniform_set_create([
				_spectrum_settings_uniform,
				_initial_spectrum_uniform_cascade[cascade],
				_spectrum_uniform_cascade[cascade],
				_ping_uniform_cascade[cascade],
				_pong_uniform_cascade[cascade]], _spectrum_shader, UNIFORM_SET)
		
		## Create Compute List
		compute_list = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(compute_list, _spectrum_pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
		@warning_ignore("integer_division")
		_rd.compute_list_dispatch(compute_list, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM, 1)
		_rd.compute_list_end()
		
		_rd.free_rid(uniform_set)
	
		#### Execute Horizontal FFT Shader Cascades
		########################################################################
		
		var is_sub_ping_phase := true
		var p := 1
		while p < fft_resolution:
			## Leave the textures in place in VRAM, and just switch the binding
			## points.
			if is_sub_ping_phase:
				_spectrum_uniform_cascade[cascade].binding = Binding.INPUT
				_sub_pong_uniform.binding = Binding.OUTPUT
			
			else:
				_spectrum_uniform_cascade[cascade].binding = Binding.OUTPUT
				_sub_pong_uniform.binding = Binding.INPUT
			
			## Update Settings Buffer
			settings_bytes = _pack_fft_settings(p)
			if _rd.buffer_update(_fft_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
				print("error updating horizontal FFT settings buffer")
			
			## Build Uniform Set
			uniform_set = _rd.uniform_set_create([
					_fft_settings_uniform,
					_sub_pong_uniform,
					_spectrum_uniform_cascade[cascade]], _fft_horizontal_shader, UNIFORM_SET)
			
			## Create Compute List
			compute_list = _rd.compute_list_begin()
			_rd.compute_list_bind_compute_pipeline(compute_list, _fft_horizontal_pipeline)
			_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
			_rd.compute_list_dispatch(compute_list, fft_resolution, 1, 1)
			_rd.compute_list_end()
			
			_rd.free_rid(uniform_set)
			
			p <<= 1
			is_sub_ping_phase = not is_sub_ping_phase
		
		#### Execute Vertical FFT Shader Cascades
		########################################################################
		
		p = 1
		while p < fft_resolution:
			## Leave the textures in place in VRAM, and just switch the binding
			## points.
			if is_sub_ping_phase:
				_spectrum_uniform_cascade[cascade].binding = Binding.INPUT
				_sub_pong_uniform.binding = Binding.OUTPUT
			
			else:
				_spectrum_uniform_cascade[cascade].binding = Binding.OUTPUT
				_sub_pong_uniform.binding = Binding.INPUT
			
			## Update Settings Buffer
			settings_bytes = _pack_fft_settings(p)
			if _rd.buffer_update(_fft_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
				print("error updating vertical FFT settings buffer")
			
			## Build Uniform Set
			uniform_set = _rd.uniform_set_create([
					_fft_settings_uniform,
					_sub_pong_uniform,
					_spectrum_uniform_cascade[cascade]], _fft_vertical_shader, UNIFORM_SET)
			
			## Create Compute List
			compute_list = _rd.compute_list_begin()
			_rd.compute_list_bind_compute_pipeline(compute_list, _fft_vertical_pipeline)
			_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
			_rd.compute_list_dispatch(compute_list, fft_resolution, 1, 1)
			_rd.compute_list_end()
			
			_rd.free_rid(uniform_set)
			
			p <<= 1
			is_sub_ping_phase = not is_sub_ping_phase
		
		## Retrieve the displacement map from the Spectrum texture, and store it
		## CPU side for use by buoyancy and wave interaction systems.
		if sync_heightmap:
			_waves_image_cascade[cascade].set_data(fft_resolution, fft_resolution, false, Image.FORMAT_RGBAF, _rd.texture_get_data(_spectrum_tex_cascade[cascade], 0))
	
	## This needs to get updated outside the cascade iteration loop
	_is_ping_phase = not _is_ping_phase
