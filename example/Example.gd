extends WorldEnvironment


@onready var ocean:Ocean3D = $Ocean3D
@onready var wave_height_sampler = $WaveHeightSampler


func _process(_delta:float) -> void:
	wave_height_sampler.position.y = ocean.get_wave_height(wave_height_sampler.position, 3)
