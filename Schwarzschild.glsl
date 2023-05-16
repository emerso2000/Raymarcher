#version 450 core

layout(local_size_x = 8, local_size_y = 4, local_size_z = 1) in;

layout(rgba32f, binding = 0) uniform image2D screen;

layout(std140, binding = 1) uniform CameraBlock {
    vec3 cam_o;
    float padding1;
    vec3 forward;
    float padding2;
    vec3 right;
    float padding3;
    vec3 up;
    float padding4;
    float fov;
} camera;


layout (std140, binding = 2) uniform MatricesBlock {
    mat4 move;
    mat4 view;
} matrices;

const int MAX_STEPS = 100;
const float EPSILON = 0.001;

float sphereSDF(vec3 p, float r) {
    return length(p) - r;
}

float marchRay(vec3 origin, vec3 direction) {
    float t = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = origin + t * direction;
        float d = sphereSDF(p, 1.0);
        if (d < EPSILON) {
            return t;
        }
        t += d;
    }
    return -1.0;
}

void main()
{
    vec4 pixel = vec4(0.115, 0.133, 0.173, 1.0);
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

    ivec2 dims = imageSize(screen);
    float aspect_ratio = float(dims.x) / float(dims.y);

    //normalized screen coordinates
    float x = -(float(pixel_coords.x * 2 - dims.x) / dims.x);
    float y = -(float(pixel_coords.y * 2 - dims.y) / dims.y);

    vec3 ray_o = vec3(x * aspect_ratio, y, 0.0);
    // vec3 ray_d = normalize((matrices.view * vec4(ray_o, 1)).xyz);
    vec3 ray_d = normalize(vec3(ray_o.x, ray_o.y, -1.0 / tan(camera.fov / 2.0)));

    // Apply matrices.view transformation to ray_d
    ray_d = (matrices.view * vec4(ray_d, 0)).xyz;

    // ray_d *= aspect_ratio;

    float t = marchRay(camera.cam_o, ray_d);
    if (t >= 0.0) {
        vec3 p = camera.cam_o + t * ray_d;
        vec3 n = normalize(vec3(
            sphereSDF(vec3(p.x + EPSILON, p.y, p.z), 1.0) - sphereSDF(vec3(p.x - EPSILON, p.y, p.z), 1.0),
            sphereSDF(vec3(p.x, p.y + EPSILON, p.z), 1.0) - sphereSDF(vec3(p.x, p.y - EPSILON, p.z), 1.0),
            sphereSDF(vec3(p.x, p.y, p.z + EPSILON), 1.0) - sphereSDF(vec3(p.x, p.y, p.z - EPSILON), 1.0)
        ));
        pixel = vec4((n + 1.0) / 2.0, 1.0);
    }

    imageStore(screen, pixel_coords, pixel);
}
