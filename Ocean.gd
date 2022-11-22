extends MeshInstance3D


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
	NORMAL = 31,
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
		_is_normal_changed = true
		_is_subdivision_changed = true
		_is_scale_changed = true

@export_range(0, 2048) var horizontal_dimension := 256:
	set(new_horizontal_dimension):
		horizontal_dimension = new_horizontal_dimension
		_is_initial_spectrum_changed = true
		_is_normal_changed = true
		_is_spectrum_changed = true
		_is_subdivision_changed = true
		_is_scale_changed = true

@export_range(0.0, 10.0) var horizontal_scale := 1.0:
	set(new_horizontal_scale):
		horizontal_scale = new_horizontal_scale
		_is_scale_changed = true

@export_range(0.0, 10.0) var subdivision := 1.0:
	set(new_subdivision):
		subdivision = new_subdivision
		_is_subdivision_changed = true

@export_range(0.001, 100.0) var time_scale := 1.0

@export_range(0.0, 100.0) var choppiness := 1.5:
	set(new_choppiness):
		choppiness = new_choppiness
		_is_spectrum_changed = true

@export_range(0.0, 360.0) var wind_direction_degrees := 0.0:
	set(new_wind_direction_degrees):
		wind_direction_degrees = clamp(new_wind_direction_degrees, 0.0, 360.0)
		_wind_rad = deg_to_rad(new_wind_direction_degrees)
		material_override.set_shader_parameter("wind_angle", _wind_rad)

@export_range(0.0, 100.0) var wave_speed := 0.0

@export_range(0.0, 1760.0) var wave_length := 300.0:
	set(new_wave_length):
		wave_vector = wave_vector.normalized() * new_wave_length
	get:
		return wave_vector.length()

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
var _initial_spectrum_settings_buffer:RID
var _initial_spectrum_settings_uniform := RDUniform.new()
var _initial_spectrum_uniform := RDUniform.new()
var _initial_spectrum_image:Image
var _initial_spectrum_tex:RID

var _phase_shader:RID
var _phase_pipeline:RID
var _phase_settings_buffer:RID
var _phase_settings_uniform := RDUniform.new()
var _ping_uniform := RDUniform.new()
var _pong_uniform := RDUniform.new()
var _ping_image:Image
var _pong_image:Image
var _ping_tex:RID
var _pong_tex:RID

var _spectrum_shader:RID
var _spectrum_pipeline:RID
var _is_spectrum_changed := true
var _spectrum_settings_buffer:RID
var _spectrum_settings_uniform := RDUniform.new()
var _spectrum_uniform := RDUniform.new()
var _spectrum_image:Image
var _spectrum_tex:RID

var _fft_horizontal_shader:RID
var _fft_horizontal_pipeline:RID
var _fft_vertical_shader:RID
var _fft_vertical_pipeline:RID
var _fft_settings_buffer:RID
var _fft_settings_uniform := RDUniform.new()
var _sub_pong_uniform := RDUniform.new()
var _sub_pong_image:Image
var _sub_pong_tex:RID

var _normal_shader:RID
var _normal_pipeline:RID
var _is_normal_changed := true
var _normal_settings_buffer:RID
var _normal_settings_uniform := RDUniform.new()
var _normal_map_uniform := RDUniform.new()
var _normal_map_image:Image
var _normal_map_tex:RID
var _normal_map_texture:ImageTexture

var _waves_image:Image
var _waves_texture:ImageTexture

var _is_ping_phase := true
var _is_subdivision_changed := true
var _is_scale_changed := true

var _frameskip := 0
var _accumulated_delta := 0.0

var _wind_uv_offset := Vector2.ZERO
var _wind_rad := 0.0

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
	shader_file = load("res://shaders/OceanInitialSpectrum.glsl")
	_initial_spectrum_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_initial_spectrum_pipeline = _rd.compute_pipeline_create(_initial_spectrum_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_initial_spectrum_settings()
	_initial_spectrum_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_initial_spectrum_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_initial_spectrum_settings_uniform.binding = Binding.SETTINGS
	_initial_spectrum_settings_uniform.add_id(_initial_spectrum_settings_buffer)
	
	## Initialized empty, it will be generated on the first frame
	_initial_spectrum_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RF)
	_initial_spectrum_tex = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [_initial_spectrum_image.get_data()])
	_initial_spectrum_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_initial_spectrum_uniform.binding = Binding.INITIAL_SPECTRUM
	_initial_spectrum_uniform.add_id(_initial_spectrum_tex)
	
	#### Compile & Initialize Phase Shader
	############################################################################
	## Applies time based flow to a crafted random data spectrum.
	
	## Compile Shader
	shader_file = load("res://shaders/OceanPhase.glsl")
	_phase_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_phase_pipeline = _rd.compute_pipeline_create(_phase_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_phase_settings(0.0)
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
	
	_ping_image = Image.create_from_data(fft_resolution, fft_resolution, false, Image.FORMAT_RF, ping_data.to_byte_array())
	_ping_tex = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [_ping_image.get_data()])
	_ping_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_ping_uniform.binding = Binding.PING
	_ping_uniform.add_id(_ping_tex)
	
	## The Pong buffer is initialized empty; it will be generated as the output
	## of the first iteration of the Phase shader based on the Ping input
	_pong_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RF)
	_pong_tex = _rd.texture_create(_fmt_r32f, RDTextureView.new(), [_pong_image.get_data()])
	_pong_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_pong_uniform.binding = Binding.PONG
	_pong_uniform.add_id(_pong_tex)
	
	#### Compile & Initialize Spectrum Shader
	############################################################################
	## Merges the weather parameters calculated in the Initial Spectrum with the
	## crafted time varying randomness calculated in Phase (and stored in the
	## Ping/Pong textures)
	
	## Compile Shader
	shader_file = load("res://shaders/OceanSpectrum.glsl")
	_spectrum_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_spectrum_pipeline = _rd.compute_pipeline_create(_spectrum_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_spectrum_settings()
	_spectrum_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_spectrum_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_spectrum_settings_uniform.binding = Binding.SETTINGS
	_spectrum_settings_uniform.add_id(_spectrum_settings_buffer)
	
	## Initialized empty, it will be generated each frame
	_spectrum_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGF)
	_spectrum_tex = _rd.texture_create(_fmt_rg32f, RDTextureView.new(), [_spectrum_image.get_data()])
	_spectrum_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_spectrum_uniform.binding = Binding.SPECTRUM
	_spectrum_uniform.add_id(_spectrum_tex)
	
	#### Compile & Initialize FFT Shaders
	############################################################################
	## Converts the result of the Spectrum shader into a usable displacement map.
	##
	## Uses the Spectrum texture and SubPong texture as ping pong buffers. The
	## resulting displacement map will be stored in the Specturm texture.
	
	## Compile Shaders
	shader_file = load("res://shaders/OceanFFTHorizontal.glsl")
	_fft_horizontal_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_fft_horizontal_pipeline = _rd.compute_pipeline_create(_fft_horizontal_shader)
	
	shader_file = load("res://shaders/OceanFFTVertical.glsl")
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
	
	#### Compile & Initialize Normal Map Shader
	############################################################################
	## Generates the normal map from the displacement map.
	
	## Compile Shader
	shader_file = load("res://shaders/OceanNormalMap.glsl")
	_normal_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_normal_pipeline = _rd.compute_pipeline_create(_normal_shader)
	
	## Initialize Settings Buffer
	settings_bytes = _pack_normal_settings()
	_normal_settings_buffer = _rd.storage_buffer_create(settings_bytes.size(), settings_bytes)
	_normal_settings_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	_normal_settings_uniform.binding = Binding.SETTINGS
	_normal_settings_uniform.add_id(_normal_settings_buffer)
	
	## Initialized empty, it will be generated each frame
	_normal_map_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGBAF)
	_normal_map_tex = _rd.texture_create(_fmt_rgba32f, RDTextureView.new(), [_normal_map_image.get_data()])
	_normal_map_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	_normal_map_uniform.binding = Binding.NORMAL
	_normal_map_uniform.add_id(_normal_map_tex)
	
	## Bind the normal map texture to the visual shader
	_normal_map_texture = ImageTexture.create_from_image(_normal_map_image)
	material_override.set_shader_parameter("normal_map", _normal_map_texture)
	
	## Bind the displacement map texture to the visual shader
	_waves_image = Image.create(fft_resolution, fft_resolution, false, Image.FORMAT_RGF)
	_waves_texture = ImageTexture.create_from_image(_waves_image)
	material_override.set_shader_parameter("displacement", _waves_texture)


## Notes on compute shader usage within _process():
##  * Marshalling data between CPU and GPU is expensive performance wise. Avoid
##    it when possible. Textures can be left in VRAM and reused by multiple
##    shaders without being copied via the CPU by passing the RDUniform or
##    texture RID pointers around as needed.
##
##  * Unfortunately the displacement and normal maps DO need to be copied to CPU
##    each frame, as the compute render context and Godots main render context
##    can't share memory directly.
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
		material_override.set_shader_parameter("wind_uv_offset", _wind_uv_offset)
		
		if simulation_frameskip > 0:
			_frameskip += 1
			if _frameskip <= simulation_frameskip:
				return
			else:
				_frameskip = 0
		
		simulate(_accumulated_delta)
		_accumulated_delta = 0.0


## Simulate a single iteration of the ocean. If simulation_enabled is true, this
## will be run every frame, excluding frameskips. The resulting displacement and
## normal map textures can be retrieved using the get_waves_texture() and
## get_normal_map_texture() methods.
func simulate(delta:float) -> void:
	var uniform_set:RID
	var compute_list:int
	var settings_bytes:PackedByteArray
	
	#### Update Initial Spectrum
	############################################################################
	## Only executed on first frame, or if Wind, FFT Resolution, or Horizontal
	## Dimension inputs are changed, as the output is constant for a given set
	## of inputs. The Initial Spectrum is cached in VRAM. It is not returned to
	## CPU RAM.
	
	if _is_initial_spectrum_changed:
		if _is_scale_changed:
			## Update the UV scale to allow the correct level of displacement
			## and normal map tiling
			material_override.set_shader_parameter("uv_scale", (horizontal_dimension * horizontal_scale) / float(fft_resolution))
			
			## Re-scale and Re-subdivide the plane mesh
			## This should generally be avoided during gameplay, as it can cause
			## a significant stall.
			mesh.size = Vector2(horizontal_dimension * horizontal_scale, horizontal_dimension * horizontal_scale)
			
			_is_scale_changed = false
		
		## If subdivision has changed, re-subdivide the plane mesh.
		## This should generally be avoided during gameplay, as it can cause a
		## significant stall.
		if _is_subdivision_changed:
			@warning_ignore(integer_division)
			mesh.subdivide_width = ((horizontal_dimension * horizontal_scale) / fft_resolution) * subdivision * fft_resolution
			@warning_ignore(integer_division)
			mesh.subdivide_depth = ((horizontal_dimension * horizontal_scale) / fft_resolution) * subdivision * fft_resolution
			
			_is_subdivision_changed = false
		
		## Update Settings Buffer
		settings_bytes = _pack_initial_spectrum_settings()
		if _rd.buffer_update(_initial_spectrum_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
			print("error updating initial spectrum settings buffer")
		
		## Build Uniform Set
		uniform_set = _rd.uniform_set_create([
				_initial_spectrum_settings_uniform,
				_initial_spectrum_uniform], _initial_spectrum_shader, UNIFORM_SET)
		
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
		
		## Prevent this from running again until the Wind, FFT Resolution, or
		## Horizontal Dimension inputs are changed.
		_is_initial_spectrum_changed = false
	
	#### Execute Phase Shader; Updates Ping Pong Buffers
	############################################################################
	
	## Leave the textures in place in VRAM, and just switch the binding points.
	if _is_ping_phase:
		_ping_uniform.binding = Binding.PING
		_pong_uniform.binding = Binding.PONG
	
	else:
		_ping_uniform.binding = Binding.PONG
		_pong_uniform.binding = Binding.PING
	
	## Update Settings Buffer
	settings_bytes = _pack_phase_settings(delta * time_scale)
	if _rd.buffer_update(_phase_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
		print("error updating phase settings buffer")
	
	## Build Uniform Set
	uniform_set = _rd.uniform_set_create([
			_phase_settings_uniform,
			_ping_uniform,
			_pong_uniform], _phase_shader, UNIFORM_SET)
	
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
	
	#### Execute Spectrum Shader
	############################################################################
	
	## Ensure the Spectrum texture binding is correct from previous frames. It
	## gets changed later on in simulate().
	_spectrum_uniform.binding = Binding.SPECTRUM
	
	## Update Settings Buffer
	if _is_spectrum_changed:
		_is_spectrum_changed = false
		settings_bytes = _pack_spectrum_settings()
		if _rd.buffer_update(_spectrum_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
			print("error updating spectrum settings buffer")
	
	## Build Uniform Set
	uniform_set = _rd.uniform_set_create([
			_spectrum_settings_uniform,
			_initial_spectrum_uniform,
			_spectrum_uniform,
			_ping_uniform,
			_pong_uniform], _spectrum_shader, UNIFORM_SET)
	
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
	
	#### Execute Horizontal FFT Shader
	############################################################################
	
	var is_sub_ping_phase := true
	var p := 1
	while p < fft_resolution:
		## Leave the textures in place in VRAM, and just switch the binding points.
		if is_sub_ping_phase:
			_spectrum_uniform.binding = Binding.INPUT
			_sub_pong_uniform.binding = Binding.OUTPUT
		
		else:
			_spectrum_uniform.binding = Binding.OUTPUT
			_sub_pong_uniform.binding = Binding.INPUT
		
		## Update Settings Buffer
		settings_bytes = _pack_fft_settings(p)
		if _rd.buffer_update(_fft_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
			print("error updating horizontal FFT settings buffer")
		
		## Build Uniform Set
		uniform_set = _rd.uniform_set_create([
				_fft_settings_uniform,
				_sub_pong_uniform,
				_spectrum_uniform], _fft_horizontal_shader, UNIFORM_SET)
		
		## Create Compute List
		compute_list = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(compute_list, _fft_horizontal_pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
		_rd.compute_list_dispatch(compute_list, fft_resolution, 1, 1)
		_rd.compute_list_end()
		
		## Submit to GPU and wait for results
		_rd.submit()
		_rd.sync()
		
		p <<= 1
		is_sub_ping_phase = not is_sub_ping_phase
	
	#### Execute Vertical FFT Shader
	############################################################################
	
	p = 1
	while p < fft_resolution:
		## Leave the textures in place in VRAM, and just switch the binding points.
		if is_sub_ping_phase:
			_spectrum_uniform.binding = Binding.INPUT
			_sub_pong_uniform.binding = Binding.OUTPUT
		
		else:
			_spectrum_uniform.binding = Binding.OUTPUT
			_sub_pong_uniform.binding = Binding.INPUT
		
		## Update Settings Buffer
		settings_bytes = _pack_fft_settings(p)
		if _rd.buffer_update(_fft_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
			print("error updating vertical FFT settings buffer")
		
		## Build Uniform Set
		uniform_set = _rd.uniform_set_create([
				_fft_settings_uniform,
				_sub_pong_uniform,
				_spectrum_uniform], _fft_vertical_shader, UNIFORM_SET)
		
		## Create Compute List
		compute_list = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(compute_list, _fft_vertical_pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
		_rd.compute_list_dispatch(compute_list, fft_resolution, 1, 1)
		_rd.compute_list_end()
		
		## Submit to GPU and wait for results
		_rd.submit()
		_rd.sync()
		
		p <<= 1
		is_sub_ping_phase = not is_sub_ping_phase
	
	## Retrieve the displacement map from the Spectrum texture, and store it CPU
	## side. This has already been bound to the visual shader in _ready(), we do
	## not need to update it there again.
	if is_sub_ping_phase:
		_waves_image.set_data(fft_resolution, fft_resolution, false, Image.FORMAT_RGF, _rd.texture_get_data(_spectrum_tex, 0))

	else:
		_waves_image.set_data(fft_resolution, fft_resolution, false, Image.FORMAT_RGF, _rd.texture_get_data(_sub_pong_tex, 0))

	_waves_texture.update(_waves_image)
	
	#### Execute Normal Map Shader
	############################################################################
	
	## Update Settings Buffer
	if _is_normal_changed:
		_is_normal_changed = false
		settings_bytes = _pack_normal_settings()
		if _rd.buffer_update(_normal_settings_buffer, 0, settings_bytes.size(), settings_bytes) != OK:
			print("error updating normal map settings buffer")
	
	## Leave the Spectrum in place and change the binding point to input it here
	_spectrum_uniform.binding = Binding.DISPLACEMENT
	
	## Build Uniform Set
	uniform_set = _rd.uniform_set_create([
			_normal_settings_uniform,
			_normal_map_uniform,
			_spectrum_uniform], _normal_shader, UNIFORM_SET)
	
	## Create Compute List
	compute_list = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, _normal_pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, uniform_set, UNIFORM_SET)
	@warning_ignore(integer_division)
	_rd.compute_list_dispatch(compute_list, fft_resolution / WORK_GROUP_DIM, fft_resolution / WORK_GROUP_DIM, 1)
	_rd.compute_list_end()
	
	## Submit to GPU and wait for results
	_rd.submit()
	_rd.sync()
	
	## Retrieve the normal map from the normal texture, and store it CPU side.
	## This has already been bound to the visual shader in _ready(), we do not
	## need to update it there again.
	_normal_map_image.set_data(fft_resolution, fft_resolution, false, Image.FORMAT_RGBAF, _rd.texture_get_data(_normal_map_tex, 0))
	_normal_map_texture.update(_normal_map_image)
	
	_is_ping_phase = not _is_ping_phase


## Get the wave displacement map as an Image.
## This returns the displacement map already cached on the CPU, it will not
## call simulate(), or marshall additional data from the GPU.
func get_waves() -> Image:
	return _waves_image


## Get the wave displacement map as an ImageTexture.
## This returns the displacement map already cached on the CPU, it will not
## call simulate(), or marshall additional data from the GPU.
func get_waves_texture() -> ImageTexture:
	return _waves_texture


## Get the wave normal map as an Image.
## This returns the normal map already cached on the CPU, it will not
## call simulate(), or marshall additional data from the GPU.
func get_normal_map() -> Image:
	return _normal_map_image


## Get the wave normal map as an ImageTexture.
## This returns the normal map already cached on the CPU, it will not
## call simulate(), or marshall additional data from the GPU.
func get_normal_map_texture() -> ImageTexture:
	return _normal_map_texture


func _pack_initial_spectrum_settings() -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension]).to_byte_array()
	settings_bytes.append_array(PackedVector2Array([wave_vector]).to_byte_array())
	return settings_bytes


func _pack_phase_settings(delta_time:float) -> PackedByteArray:
	var settings_bytes = PackedInt32Array([fft_resolution, horizontal_dimension]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([delta_time]).to_byte_array())
	return settings_bytes


func _pack_spectrum_settings() -> PackedByteArray:
	var settings_bytes = PackedInt32Array([horizontal_dimension]).to_byte_array()
	settings_bytes.append_array(PackedFloat32Array([choppiness]).to_byte_array())
	return settings_bytes


func _pack_fft_settings(subseq_count:int) -> PackedByteArray:
	return PackedInt32Array([fft_resolution, subseq_count]).to_byte_array()


func _pack_normal_settings() -> PackedByteArray:
	return PackedInt32Array([fft_resolution, horizontal_dimension]).to_byte_array()
