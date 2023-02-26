@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("BuoyancyBody3D", "RigidBody3D", preload("res://addons/tessarakkt.oceanfft/components/BuoyancyBody3D.gd"), preload("res://addons/tessarakkt.oceanfft/icons/BuoyancyBody3D.svg"))
	add_custom_type("BuoyancyProbe3D", "Marker3D", preload("res://addons/tessarakkt.oceanfft/components/BuoyancyProbe3D.gd"), preload("res://addons/tessarakkt.oceanfft/icons/BuoyancyProbe3D.svg"))
	add_custom_type("Ocean3D", "Spatial", preload("res://addons/tessarakkt.oceanfft/components/Ocean3D.gd"), preload("res://addons/tessarakkt.oceanfft/icons/Ocean3D.svg"))
	add_custom_type("QuadTree3D", "Spatial", preload("res://addons/tessarakkt.oceanfft/components/QuadTree3D.gd"), preload("res://addons/tessarakkt.oceanfft/icons/QuadTree3D.svg"))
	add_custom_type("MotorVesselBody3D", "BuoyancyBody3D", preload("res://addons/tessarakkt.oceanfft/components/MotorVesselBody3D.gd"), preload("res://addons/tessarakkt.oceanfft/icons/BuoyancyBody3D.svg"))
	add_custom_type("OceanEnvironment", "WorldEnvironment", preload("res://addons/tessarakkt.oceanfft/components/OceanEnvironment.gd"), preload("res://addons/tessarakkt.oceanfft/icons/OceanEnvironment.svg"))


func _exit_tree():
	remove_custom_type("BuoyancyBody3D")
	remove_custom_type("BuoyancySphere3D")
	remove_custom_type("Ocean3D")
	remove_custom_type("QuadTree3D")
	remove_custom_type("MotorVesselBody3D")
	remove_custom_type("OceanEnvironment")
