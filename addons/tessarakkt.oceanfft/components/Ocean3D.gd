extends Node3D
class_name Ocean3D


const UNIFORM_SET := 0
const WORK_GROUP_DIM := 32


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


@export var simulation_enabled := true
@export_range(0, 30, 1) var simulation_frameskip := 0
@export var fft_resolution:FFTResolution = FFTResolution.FFT_256x256:
	set(new_fft_resolution):
		fft_resolution = new_fft_resolution
		_is_initial_spectrum_changed = true
		_is_spectrum_changed = true
		_is_scale_changed = true
		_material.set_shader_parameter("fft_resolution", fft_resolution)

@export_range(0, 2048) var horizontal_dimension := 256:
	set(new_horizontal_dimension):
		horizontal_dimension = new_horizontal_dimension
		_is_initial_spectrum_changed = true
		_is_spectrum_changed = true
		_is_scale_changed = true

@export_range(0.0, 10.0) var horizontal_scale := 1.0:
	set(new_horizontal_scale):
		horizontal_scale = new_horizontal_scale
		_is_scale_changed = true

@export_range(0.001, 5.0) var time_scale := 1.0

@export_range(0.0, 10.0) var choppiness := 1.5:
	set(new_choppiness):
		choppiness = new_choppiness
		_is_spectrum_changed = true

@export_range(0.0, 360.0) var wind_direction_degrees := 0.0:
	set(new_wind_direction_degrees):
		wind_direction_degrees = clamp(new_wind_direction_degrees, 0.0, 360.0)
		_wind_rad = deg_to_rad(new_wind_direction_degrees)

@export_range(0.0, 100.0) var wave_speed := 0.0

@export_range(0.0, 1000.0) var wave_length := 300.0:
	set(new_wave_length):
		wave_vector = wave_vector.normalized() * new_wave_length
	get:
		return wave_vector.length()

@export var cascade_ranges:Array[Vector2] = [Vector2(0.0, 0.04), Vector2(0.04, 0.15), Vector2(0.15, 1.0)]
@export var cascade_scales:Array[float] = [1.0, 0.7, 0.3]

var wave_vector := Vector2(300.0, 0.0):
	set(new_wave_vector):
		wave_vector = new_wave_vector
		_is_initial_spectrum_changed = true


var _rd:RenderingDevice = RenderingServer.create_local_rendering_device()

var _fmt_r32f := RDTextureFormat.new()
var _fmt_rg32f := RDTextureFormat.new()
var _fmt_rgba32f := RDTextureFormat.new()

var _initial_spectrum_shader:RID
var _initial_spectrum_pipeline:RID
var _is_initial_spectrum_changed := true
var _initial_spectrum_settings_buffer_cascade:Array[RID] = []
var _initial_spectrum_settings_uniform_cascade:Array[RDUniform] = []
var _initial_spectrum_uniform_cascade:Array[RDUniform] = []
var _initial_spectrum_image_cascade:Array[Image] = []
var _initial_spectrum_tex_cascade:Array[RID] = []

var _phase_shader:RID
var _phase_pipeline:RID
var _phase_settings_buffer:RID
var _phase_settings_uniform := RDUniform.new()
var _ping_uniform_cascade:Array[RDUniform] = []
var _pong_uniform_cascade:Array[RDUniform] = []
var _ping_image_cascade:Array[Image] = []
var _pong_image_cascade:Array[Image] = []
var _ping_tex_cascade:Array[RID] = []
var _pong_tex_cascade:Array[RID] = []

var _spectrum_shader:RID
var _spectrum_pipeline:RID
var _is_spectrum_changed := true
var _spectrum_settings_buffer:RID
var _spectrum_settings_uniform := RDUniform.new()
var _spectrum_uniform_cascade:Array[RDUniform] = []
var _spectrum_image_cascade:Array[Image] = []
var _spectrum_tex_cascade:Array[RID] = []

var _fft_horizontal_shader:RID
var _fft_horizontal_pipeline:RID
var _fft_vertical_shader:RID
var _fft_vertical_pipeline:RID
var _fft_settings_buffer:RID
var _fft_settings_uniform := RDUniform.new()
var _sub_pong_uniform := RDUniform.new()
var _sub_pong_image:Image
var _sub_pong_tex:RID

var _waves_image_cascade:Array[Image] = []
var _waves_texture_cascade:Array[ImageTexture] = []

var _is_ping_phase := true
var _is_scale_changed := true

var _frameskip := 0
var _accumulated_delta := 0.0

var _wind_uv_offset := Vector2.ZERO
var _wind_rad := 0.0

var _material:ShaderMaterial = preload("res://addons/tessarakkt.oceanfft/Ocean.material")

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var shader_file:Resource
	var settings_bytes:PackedByteArray
	
	_rng.randomize()
	
	#### Initialize RDTextureFormats
	############################################################################
	## These are initialized once and reused as needed.
	
	_fmt_r32f.width = fft_resolution
	_fmt_r32f.height = fft_resolution
	_fmt_r32f.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	_fmt_r32f.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	_fmt_rg32f.width = fft_resolution
	_fmt_rg32f.height = fft_resolution
	_fmt_rg32f.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	_fmt_rg32f.usage_bits = _fmt_r32f.usage_bits
	
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
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/OceanInitialSpectrum.glsl")
	_initial_spectrum_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_initial_spectrum_pipeline = _rd.compute_pipeline_create(_initial_spectrum_shader)
	
	## Initialize cascaded FFTs
	_initial_spectrum_settings_buffer_cascade.resize(cascade_ranges.size())
	_initial_spectrum_settings_uniform_cascade.resize(cascade_ranges.size())
	_initial_spectrum_image_cascade.resize(cascade_ranges.size())
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
		_initial_spectrum_image_cascade[i] = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RF)
		_initial_spectrum_tex_cascade[i] = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [_initial_spectrum_image_cascade[i].get_data()])
		_initial_spectrum_uniform_cascade[i] = RDUniform.new()
		_initial_spectrum_uniform_cascade[i].uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		_initial_spectrum_uniform_cascade[i].binding = Binding.INITIAL_SPECTRUM
		_initial_spectrum_uniform_cascade[i].add_id(_initial_spectrum_tex_cascade[i])
	
	#### Compile & Initialize Phase Shader
	############################################################################
	## Applies time based flow to a crafted random data spectrum.
	
	## Compile Shader
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/OceanPhase.glsl")
	_phase_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_phase_pipeline = _rd.compute_pipeline_create(_phase_shader)
	
	## Initialize cascade arrays
	_ping_uniform_cascade.resize(cascade_ranges.size())
	_pong_uniform_cascade.resize(cascade_ranges.size())
	_ping_image_cascade.resize(cascade_ranges.size())
	_pong_image_cascade.resize(cascade_ranges.size())
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
		_pong_image_cascade[cascade] = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RF)
		_pong_tex_cascade[cascade] = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [_pong_image_cascade[cascade].get_data()])
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
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/OceanSpectrum.glsl")
	_spectrum_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_spectrum_pipeline = _rd.compute_pipeline_create(_spectrum_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_spectrum_settings(0)
	_spectrum_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_spectrum_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_spectrum_settings_uniform.binding = Binding.SETTINGS
	_spectrum_settings_uniform.add_id(_spectrum_settings_buffer)
	
	_spectrum_image_cascade.resize(cascade_ranges.size())
	_spectrum_tex_cascade.resize(cascade_ranges.size())
	_spectrum_uniform_cascade.resize(cascade_ranges.size())
	_waves_image_cascade.resize(cascade_ranges.size())
	_waves_texture_cascade.resize(cascade_ranges.size())
	
	for i in cascade_ranges.size():
		## Initialized empty, it will be generated each frame
		_spectrum_image_cascade[i] = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGF)
		_spectrum_tex_cascade[i] = _rd.texture_create(_fmt_rg32f, RDTextureView.new(), [_spectrum_image_cascade[i].get_data()])
		_spectrum_uniform_cascade[i] = RDUniform.new()
		_spectrum_uniform_cascade[i].uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		_spectrum_uniform_cascade[i].binding = Binding.SPECTRUM
		_spectrum_uniform_cascade[i].add_id(_spectrum_tex_cascade[i])
		
		## Bind the displacement map cascade texture to the visual shader
		_waves_image_cascade[i] = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGF)
		_waves_texture_cascade[i] = ImageTexture.create_from_image(_waves_image_cascade[i])
	
	_material.set_shader_parameter("cascade_displacements", _waves_texture_cascade)
	_material.set_shader_parameter("cascade_uv_scales", cascade_scales)
	
	#### Compile & Initialize FFT Shaders
	############################################################################
	## Converts the result of the Spectrum shader into a usable displacement map.
	##
	## Uses the Spectrum texture and SubPong texture as ping pong buffers. The
	## resulting displacement map will be stored in the Specturm texture.
	
	## Compile Shaders
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/OceanFFTHorizontal.glsl")
	_fft_horizontal_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_fft_horizontal_pipeline = _rd.compute_pipeline_create(_fft_horizontal_shader)
	
	shader_file = load("res://addons/tessarakkt.oceanfft/shaders/OceanFFTVertical.glsl")
	_fft_vertical_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_fft_vertical_pipeline = _rd.compute_pipeline_create(_fft_vertical_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_fft_settings(0)
	_fft_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_fft_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_fft_settings_uniform.binding = Binding.SETTINGS
	_fft_settings_uniform.add_id(_fft_settings_buffer)
	
	## Initialize empty, will be calculated based on the Spectrum
	_sub_pong_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGF)
	_sub_pong_tex = _rd.texture_create(_fmt_rg32f, RDTextureView.new(), [_sub_pong_image.get_data()])
	_sub_pong_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_sub_pong_uniform.add_id(_sub_pong_tex)


## Notes on compute shader usage within _process():
##  * Marshalling data between CPU and GPU is expensive performance wise. Avoid
##    it when possible. Textures can be left in VRAM and reused by multiple
##    shaders without being copied via the CPU by passing the RDUniform or
##    texture RID pointers around as needed.
##
##  * The displacement map does need to be copied to CPU each frame, as the
##    compute render context and Godots main render context can't share memory
##    directly. The silver lining of this is the displacement map is already
##    available to the CPU to sample for buoyancy, so any perfomance lost in
##    copying to the CPU should be made up in buoyancy simulation.
##
##  * RDUniforms, texture RIDs, storage buffer RIDs, shader RIDs, and pipeline
##    RIDs can be initialized once and reused.
##
##  * RDUniform properties (such as binding), and content of textures and
##    storage buffers can be updated as needed, but not between calls of
##    _rd.compute_list_begin() and _rd.compute_list_end().
##
##  * Uniform set RIDs and compute list IDs are single use, and can NOT be reused.
##
##  * Multiple compute lists can not be executed simultaneously, thus I DO need
##    to run RenderingDevice#sync() after each submission. It doesn't seem to
##    like me beginning the next compute list as the previous is still executing,
##    but I might have been doing that wrong.
func _process(delta:float) -> void:
	if simulation_enabled:
		_accumulated_delta += delta
		
		_wind_uv_offset += Vector2(cos(_wind_rad), sin(_wind_rad)) * wave_speed * delta
		_material.set_shader_parameter("wind_uv_offset", _wind_uv_offset)
		
		if simulation_frameskip > 0:
			_frameskip += 1
			if _frameskip <= simulation_frameskip:
				return
			else:
				_frameskip = 0
		
		simulate(_accumulated_delta)
		_accumulated_delta = 0.0


func _enter_tree() -> void:
	add_to_group("ocean")


## Simulate a single iteration of the ocean. If simulation_enabled is true, this
## will be run every frame, excluding frameskips. The resulting displacement map
## texture can be retrieved using the get_waves_texture() function.
func simulate(delta:float) -> void:
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
			@warning_ignore(integer_division)
			_rd.compute_list_dispatch(compute_list, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM, 1)
			_rd.compute_list_end()
			
			## Submit to GPU and wait for results
			_rd.submit()
			_rd.sync()
			
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
		@warning_ignore(integer_division)
		_rd.compute_list_dispatch(compute_list, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM, 1)
		_rd.compute_list_end()
		
		## Submit to GPU and wait for results
		_rd.submit()
		_rd.sync()
		
		_rd.free_rid(uniform_set)
	
		#### Execute Spectrum Shader Cascades
		########################################################################
		
		## Update Settings Buffer
		settings_bytes = _pack_spectrum_settings(cascade)
		if _rd.buffer_update(_spectrum_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
			print("error updating spectrum settings buffer")
		
		## Ensure the Spectrum texture binding is correct from previous frames.
		## It gets changed later on in simulate().
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
		@warning_ignore(integer_division)
		_rd.compute_list_dispatch(compute_list, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM, 1)
		_rd.compute_list_end()
		
		## Submit to GPU and wait for results
		_rd.submit()
		_rd.sync()
		
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
			
			## Submit to GPU and wait for results
			_rd.submit()
			_rd.sync()
			
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
			
			## Submit to GPU and wait for results
			_rd.submit()
			_rd.sync()
			
			_rd.free_rid(uniform_set)
			
			p <<= 1
			is_sub_ping_phase = not is_sub_ping_phase
		
		## Retrieve the displacement map from the Spectrum texture, and store it
		## CPU side. This has already been bound to the visual shader in
		## _ready(), we do not need to update it there again.
		if is_sub_ping_phase:
			_waves_image_cascade[cascade].set_data(fft_resolution, fft_resolution, false, Image.FORMAT_RGF, _rd.texture_get_data(_spectrum_tex_cascade[cascade], 0))

		else:
			_waves_image_cascade[cascade].set_data(fft_resolution, fft_resolution, false, Image.FORMAT_RGF, _rd.texture_get_data(_sub_pong_tex, 0))

		_waves_texture_cascade[cascade].update(_waves_image_cascade[cascade])
	
	## This needs to get updated outside the cascade iteration loop
	_is_ping_phase = not _is_ping_phase


## Convert a global position (on the horizontal XZ plane) to a pixel coordinate
## for sampling the wave displacement texture directly. The Y coordinate is
## ignored.
func global_to_pixel(global_pos:Vector3, cascade:int) -> Vector2i:
	## The order of operations in this function is dependent on the order of
	## operations used in the vertex shader to rotate and scale the displacement
	## map before applying it. Make sure to check if the vertex shader should be
	## updated to account for any changes made here.
	
	## Convert to UV coordinate
	var uv_pos := Vector2.ZERO
	uv_pos.x = global_pos.x
	uv_pos.y = global_pos.z
	
	## Apply UV scale
	uv_pos *= 0.004
	
	## Offset by wind scrolling
	uv_pos += _wind_uv_offset * cascade_scales[cascade]
	
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
func get_wave_height(global_pos:Vector3, max_cascade:int = 1, steps:int = 3) -> float:
	var pixel:Color
	var xz_offset := Vector3.ZERO
	var total_height := 0.0
	
	for cascade in range(max_cascade):
		for i in range(steps):
			var pixel_pos := global_to_pixel(global_pos + xz_offset, cascade)
			
			pixel = _waves_image_cascade[cascade].get_pixelv(pixel_pos)
			xz_offset.x -= pixel.r
			xz_offset.z -= pixel.b
		
		total_height += pixel.g
		xz_offset = Vector3.ZERO
	
	return total_height


## Get the wave displacement map of a single cascade as an Image.
## This returns the displacement map already cached on the CPU, it will not
## call simulate(), or marshall additional data from the GPU.
func get_waves(cascade:int = 0) -> Image:
	return _waves_image_cascade[cascade]


## Get the wave displacement map of a single cascade as an ImageTexture.
## This returns the displacement map already cached on the CPU, it will not
## call simulate(), or marshall additional data from the GPU.
func get_waves_texture(cascade:int = 0) -> ImageTexture:
	return _waves_texture_cascade[cascade]


## Get the wave displacement maps of all cascades as an Array of Images.
## This returns the displacement map already cached on the CPU, it will not
## call simulate(), or marshall additional data from the GPU.
func get_all_waves() -> Array[Image]:
	return _waves_image_cascade


## Get the wave displacement maps of all cascades as an Array of ImageTextures.
## This returns the displacement map already cached on the CPU, it will not
## call simulate(), or marshall additional data from the GPU.
func get_all_waves_textures() -> Array[ImageTexture]:
	return _waves_texture_cascade


func _pack_initial_spectrum_settings(cascade:int) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension * cascade_scales[cascade]]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([cascade_ranges[cascade].x, cascade_ranges[cascade].y]).to_byte_array())
	settings_bytes.append_array(PackedVector2Array([wave_vector]).to_byte_array())
	return settings_bytes


func _pack_phase_settings(delta_time:float, cascade:int) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension * cascade_scales[cascade]]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([delta_time]).to_byte_array())
	return settings_bytes


func _pack_spectrum_settings(cascade:int) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([horizontal_dimension * cascade_scales[cascade]]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([choppiness * clamp(1.0 - cascade_scales[cascade], 0.5, 1.0), fft_resolution]).to_byte_array())
	return settings_bytes


func _pack_fft_settings(subseq_count:int) -> PackedByteArray:
	return PackedInt32Array([fft_resolution, subseq_count]).to_byte_array()
