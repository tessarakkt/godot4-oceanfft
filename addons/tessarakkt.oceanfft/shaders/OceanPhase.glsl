#[compute]
#version 460 core

#define COMPUTE_WORK_GROUP_DIM 32

const float PI = 3.14159265359;
const float g = 9.81;
const float KM = 370.0;

layout(local_size_x = COMPUTE_WORK_GROUP_DIM, local_size_y = COMPUTE_WORK_GROUP_DIM) in;

layout(set = 0, binding = 25, r32f) readonly uniform image2D u_phases;
layout(set = 0, binding = 26, r32f) writeonly uniform image2D u_delta_phases;

layout(set = 0, binding = 0) buffer UniformsBuffer {
    int resolution;
    int ocean_size;
    float delta_time;
} u;

float omega(float k) {
    return sqrt(g * k * (1.0 + k * k / KM * KM));
}

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);

    float n = (pixel_coord.x < 0.5f * u.resolution) ? pixel_coord.x : pixel_coord.x - u.resolution;
    float m = (pixel_coord.y < 0.5f * u.resolution) ? pixel_coord.y : pixel_coord.y - u.resolution;

    vec2 wave_vector = (2.f * PI * vec2(n, m)) / u.ocean_size;
    float k = length(wave_vector);

    float delta_phase = omega(k) * u.delta_time;
    float phase = imageLoad(u_phases, pixel_coord).r;
    phase = mod(phase + delta_phase, 2.f * PI);

    imageStore(u_delta_phases, pixel_coord, vec4(phase, 0.f, 0.f, 0.f));
}
