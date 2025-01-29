shader_type particles;
render_mode keep_data;
// Particle process shader for the underwater (marine snow) particle effect.
// Emitted using a spherical emitter, and emits on the surface of the sphere.
// Particles persist data between life cycles until they leave the emission
// sphere. Upon leaving the emission sphere, a particle is made inactive, and
// it is allowed to respawn at a new random location on the sphere surface.


uniform float emission_sphere_radius = 250.0;
uniform vec3 gravity = vec3(0.0, -2.5, 0.0);


group_uniforms Turbulence;
/******************************************************************************/
// Turbulence implementation from Godot 4.0.rc5's ParticleProcessMaterial
uniform float turbulence_noise_strength = 0.25;
uniform float turbulence_noise_scale = 0.896;
uniform float turbulence_influence_min = 0.1;
uniform float turbulence_influence_max = 0.1;
uniform float turbulence_initial_displacement_min = 0.0;
uniform float turbulence_initial_displacement_max = 0.0;
uniform float turbulence_noise_speed_random = 0.0;
uniform vec3 turbulence_noise_speed = vec3(0.5, 0.5, 0.5);


// 3D Noise with friendly permission by Inigo Quilez
vec3 hash_noise( vec3 p ) {
	p *= mat3(vec3(127.1, 311.7, -53.7), vec3(269.5, 183.3, 77.1), vec3(-301.7, 27.3, 215.3));
	return 2.0 * fract(fract(p)*4375.55) -1.;
}


float noise( vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return 2.0*mix( mix( mix( dot( hash_noise( i + vec3(0.0,0.0,0.0) ), f - vec3(0.0,0.0,0.0) ), dot( hash_noise( i + vec3(1.0,0.0,0.0) ), f - vec3(1.0,0.0,0.0) ), u.x),
			mix( dot( hash_noise( i + vec3(0.0,1.0,0.0) ), f - vec3(0.0,1.0,0.0) ), dot( hash_noise( i + vec3(1.0,1.0,0.0) ), f - vec3(1.0,1.0,0.0) ), u.x), u.y),
		mix( mix( dot( hash_noise( i + vec3(0.0,0.0,1.0) ), f - vec3(0.0,0.0,1.0) ), dot( hash_noise( i + vec3(1.0,0.0,1.0) ), f - vec3(1.0,0.0,1.0) ), u.x),
			mix( dot( hash_noise( i + vec3(0.0,1.0,1.0) ), f - vec3(0.0,1.0,1.0) ), dot( hash_noise( i + vec3(1.0,1.0,1.0) ), f - vec3(1.0,1.0,1.0) ), u.x), u.y), u.z);
}


// Curl 3D and noise_3d function with friendly permission by Isaac Cohen
vec3 noise_3d(vec3 p) {
	float s = noise(p);
	float s1 = noise(vec3(p.y - 19.1, p.z + 33.4, p.x + 47.2));
	float s2 = noise(vec3(p.z + 74.2, p.x - 124.5, p.y + 99.4));
	vec3 c = vec3(s, s1, s2);
	return c;
}


vec3 curl_3d(vec3 p, float c) {
	float epsilon = 0.001 + c;
	vec3 dx = vec3(epsilon, 0.0, 0.0);
	vec3 dy = vec3(0.0, epsilon, 0.0);
	vec3 dz = vec3(0.0, 0.0, epsilon);
	vec3 x0 = noise_3d(p - dx).xyz;
	vec3 x1 = noise_3d(p + dx).xyz;
	vec3 y0 = noise_3d(p - dy).xyz;
	vec3 y1 = noise_3d(p + dy).xyz;
	vec3 z0 = noise_3d(p - dz).xyz;
	vec3 z1 = noise_3d(p + dz).xyz;
	float x = y1.z - y0.z - z1.y + z0.y;
	float y = z1.x - z0.x - x1.z + x0.z;
	float z = x1.y - x0.y - y1.x + y0.x;
	float divisor = 1.0 / (2.0 * epsilon);
	return vec3(normalize(vec3(x, y, z) * divisor));
}


vec3 get_noise_direction(vec3 pos, vec3 emission_pos, vec3 time_noise) {
	float adj_contrast = max((turbulence_noise_strength - 1.0), 0.0) * 70.0;
	vec3 noise_time = (vec3(TIME) * turbulence_noise_speed) + time_noise;
	vec3 noise_pos = (pos * turbulence_noise_scale) - emission_pos;
	vec3 diff = pos - emission_pos;
	vec3 noise_direction = curl_3d(noise_pos + noise_time - diff, adj_contrast);
	noise_direction = mix(0.9 * noise_direction, noise_direction, turbulence_noise_strength - 9.0);
	return noise_direction;
}


float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0)
	s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0) {
		s += 2147483647;
	}
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}


uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}


void start() {
	uint alt_seed = hash(NUMBER + uint(1) + RANDOM_SEED);
	float linear_dist = length(TRANSFORM[3].xyz - EMISSION_TRANSFORM[3].xyz);
	
	// Restart at a new valid position
	if (TRANSFORM[3].xyz == vec3(0.0) || linear_dist > emission_sphere_radius && RESTART_POSITION) {
		float s = rand_from_seed(alt_seed) * 2.0 - 1.0;
		float t = rand_from_seed(alt_seed) * 2.0 * PI;
		float radius = emission_sphere_radius * sqrt(1.0 - s * s);
		
		// Sphere emission, surface
		TRANSFORM[3].xyz = vec3(radius * cos(t), radius * sin(t), emission_sphere_radius * s);
		
		// Sphere emission, volume
		//float p = rand_from_seed(alt_seed);
		//TRANSFORM[3].xyz = mix(vec3(0.0, 0.0, 0.0), vec3(radius * cos(t), radius * sin(t), emission_sphere_radius * s), p);
		
		if (RESTART_VELOCITY) {
			VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		}
		
		vec3 time_noise = noise_3d( vec3(TIME) * turbulence_noise_speed_random ) * -turbulence_noise_speed;
		vec3 noise_direction = get_noise_direction(TRANSFORM[3].xyz, EMISSION_TRANSFORM[3].xyz, time_noise);
		float turb_init_displacement = mix(turbulence_initial_displacement_min, turbulence_initial_displacement_max, rand_from_seed(alt_seed));	TRANSFORM[3].xyz += noise_direction * turb_init_displacement;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
}


void process() {
	uint alt_seed = hash(NUMBER + uint(1) + RANDOM_SEED);
	
	// apply attractor forces
	vec3 force = gravity + ATTRACTOR_FORCE;
	VELOCITY += force * DELTA;
	
	// apply turbulence
	const float turbulence_influence = 1.0;
	vec3 time_noise = noise_3d( vec3(TIME) * turbulence_noise_speed_random ) * -turbulence_noise_speed;
	vec3 noise_direction = get_noise_direction(TRANSFORM[3].xyz, EMISSION_TRANSFORM[3].xyz, time_noise);
	
	if (!COLLIDED) {
		float vel_mag = length(VELOCITY);
		float vel_infl = clamp(mix(turbulence_influence_min, turbulence_influence_max, rand_from_seed(alt_seed)) * turbulence_influence, 0.0, 1.0);
		VELOCITY = mix(VELOCITY, normalize(noise_direction) * vel_mag * (1.0 + (1.0 - vel_infl) * 0.2), vel_infl);
	}
	
	// If particle is outside the emission sphere, set it inactive and allow it
	// to respawn.
	float linear_dist = length(TRANSFORM[3].xyz - EMISSION_TRANSFORM[3].xyz);
	if (linear_dist > emission_sphere_radius) {
		ACTIVE = false;
	}
}
