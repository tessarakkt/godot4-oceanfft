shader_type particles;


#include "OceanCommon.gdshaderinc"


uniform int splash_subparticles = 10;
uniform float splash_jacobian_limit = -3.0;
uniform float splash_coverage = 1.0;
uniform float sea_level = 0.0;


group_uniforms ParticleSettings;
/******************************************************************************/
// These uniforms and functions they tweak were converted from Godot 4.0.rc5's
// ParticleProcessMaterial.

group_uniforms ParticleSettings.Time;
uniform float lifetime_randomness = 0.25;

group_uniforms ParticleSettings.EmissionShape;
uniform vec3 emission_box_extents = vec3(500.0, 0.0, 500.0);

group_uniforms ParticleSettings.Direction;
uniform vec3 direction = vec3(1.0, 1.0, 0.0);
uniform float spread = 45.0;

group_uniforms ParticleSettings.Gravity;
uniform vec3 gravity = vec3(20.0, -9.8, 0.0);

group_uniforms ParticleSettings.InitialVelocity;
uniform float initial_linear_velocity_min = 25.0;
uniform float initial_linear_velocity_max = 35.0;


group_uniforms Internal;
/******************************************************************************/
uniform vec3 camera_position_world;


float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0)
	s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0)
		s += 2147483647;
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}


float rand_from_seed_m1_p1(inout uint seed) {
	return rand_from_seed(seed) * 2.0 - 1.0;
}


uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}


void start() {
	uint alt_seed = hash(NUMBER + uint(1) + RANDOM_SEED);
	float degree_to_rad = PI / 180.0;
	
	if (RESTART_VELOCITY) {
		float spread_rad = spread * degree_to_rad;
		float angle1_rad = rand_from_seed_m1_p1(alt_seed) * spread_rad;
		float angle2_rad = rand_from_seed_m1_p1(alt_seed) * spread_rad;
		vec3 direction_xz = vec3(sin(angle1_rad), 0.0, cos(angle1_rad));
		vec3 direction_yz = vec3(0.0, sin(angle2_rad), cos(angle2_rad));
		
		// better uniform distribution
		direction_yz.z = direction_yz.z / max(0.0001,sqrt(abs(direction_yz.z)));
		vec3 spread_direction = vec3(direction_xz.x * direction_yz.z, direction_yz.y, direction_xz.z * direction_yz.z);
		vec3 direction_nrm = length(direction) > 0.0 ? normalize(direction) : vec3(0.0, 0.0, 1.0);
		
		// rotate spread to direction
		vec3 binormal = cross(vec3(0.0, 1.0, 0.0), direction_nrm);
		if (length(binormal) < 0.0001) {
			// direction is parallel to Y. Choose Z as the binormal.
			binormal = vec3(0.0, 0.0, 1.0);
		}
		binormal = normalize(binormal);
		vec3 normal = cross(binormal, direction_nrm);
		spread_direction = binormal * spread_direction.x + normal * spread_direction.y + direction_nrm * spread_direction.z;
		VELOCITY = spread_direction * mix(initial_linear_velocity_min, initial_linear_velocity_max,rand_from_seed(alt_seed));
	}
	
	// Restart at a new valid position
	if (RESTART_POSITION) {
		// Start with a random position within emission zone
		TRANSFORM[3].xyz = vec3(rand_from_seed(alt_seed) * 2.0 - 1.0, 0.0, rand_from_seed(alt_seed) * 2.0 - 1.0) * emission_box_extents;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
		
		// Fix it to sea level (not wave height) for simplicity
		TRANSFORM[3].y = sea_level;
		
		float linear_dist = length(TRANSFORM[3].xyz - camera_position_world);
		vec2 domain_warped_uv = domain_warp(TRANSFORM[3].xz, linear_dist);
		
		// Wave displacement, and determining if this particle is on a wave
		// crest via Jacobian.
		vec3 displacement = get_displacement(domain_warped_uv);
		TRANSFORM[3].xyz += displacement;
		vec4 nj = get_normals_jacobian(domain_warped_uv, displacement);
		
		float splash_value = clamp((-nj.w + splash_jacobian_limit) * splash_coverage, 0.0, 1.0);
		
		if (splash_value < 0.5) {
			// Not enough turbulence here. Disable the particle.
			ACTIVE = false;
		}
		
		if (RESTART_VELOCITY) {
			VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		}
	}
	
	CUSTOM.y = 0.0;
	CUSTOM.w = (1.0 - lifetime_randomness * rand_from_seed(alt_seed));
}


void process() {
	vec3 pos = TRANSFORM[3].xyz;
	
	// If particle is below wave surface, disable it.
	float linear_dist = length(pos - camera_position_world);
	vec2 domain_warped_uv = domain_warp(pos.xz, linear_dist);
	vec3 displacement = get_displacement(domain_warped_uv);
	if (pos.y < sea_level + displacement.y) {
		ACTIVE = false;
	
	// If above wave surface, and this is the first tick for this particle,
	// spawn more splash particles at the location to make a bigger splash.
	} else if (RESTART) {
		for (int i = 0; i < splash_subparticles; i++) {
			uint flags = FLAG_EMIT_POSITION;
			emit_subparticle(TRANSFORM, vec3(0.0), vec4(0.0), vec4(0.0), flags);
		}
	}
	
	// apply attractor forces
	vec3 force = gravity + ATTRACTOR_FORCE;
	VELOCITY += force * DELTA;
	
	// If current life time exceeds this particles max age, set it inactive
	CUSTOM.y += DELTA / LIFETIME;
	if (CUSTOM.y > CUSTOM.w) {
		ACTIVE = false;
	}
	
	COLOR = vec4(1.0, 1.0, 1.0, 1.0 - (CUSTOM.y / CUSTOM.w));
}

