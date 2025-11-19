#[compute]
#version 460 core

#define WORK_GROUP_DIM 256

#define PI 3.14159265358979323846

layout(local_size_x = WORK_GROUP_DIM) in;

layout(set = 0, binding = 27, rgba32f) uniform readonly image2D u_input;
layout(set = 0, binding = 28, rgba32f) uniform writeonly image2D u_output;

layout(set = 0, binding = 0) buffer UniformsBuffer {
    int total_count;
    int subseq_count;
} u;

vec2 MultiplyComplex(vec2 a, vec2 b) {
    return vec2(a[0] * b[0] - a[1] * b[1], a[1] * b[0] + a[0] * b[1]);
}

vec4 ButterflyOperation(vec2 a, vec2 b, vec2 twiddle) {
    vec2 twiddle_b = MultiplyComplex(twiddle, b);
    vec4 result = vec4(a + twiddle_b, a - twiddle_b);
    return result;
}

void main() {
    ivec2 pixel_coord = ivec2(gl_WorkGroupID.x, gl_LocalInvocationID.x);

    int thread_count = int(u.total_count * 0.5f);
    int thread_idx = pixel_coord.y;

    int in_idx = thread_idx & (u.subseq_count - 1);
    int out_idx = ((thread_idx - in_idx) << 1) + in_idx;

    float angle = -PI * (float(in_idx) / float(u.subseq_count));
    vec2 twiddle = vec2(cos(angle), sin(angle));

    vec4 a = imageLoad(u_input, ivec2(pixel_coord.x, pixel_coord.y));
    vec4 b = imageLoad(u_input, ivec2(pixel_coord.x, pixel_coord.y + thread_count));

    vec4 result0 = ButterflyOperation(a.xy, b.xy, twiddle);
    vec4 result1 = ButterflyOperation(a.zw, b.zw, twiddle);

    imageStore(u_output, ivec2(pixel_coord.x, out_idx), vec4(result0.xy, result1.xy));
    imageStore(u_output, ivec2(pixel_coord.x, out_idx + u.subseq_count), vec4(result0.zw, result1.zw));
}
