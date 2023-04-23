#version 450 core

layout(local_size_x = 8, local_size_y = 4, local_size_z = 1) in;
layout(rgba32f, binding = 0) uniform image2D screen;

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
    float aspect_ratio = float(dims.x) / float(dims.y); // get aspect ratio of the window
    float x = -(float(pixel_coords.x * 2 - dims.x) / dims.x); // transforms to [-1.0, 1.0]
    float y = -(float(pixel_coords.y * 2 - dims.y) / dims.y); // transforms to [-1.0, 1.0]
    float fov = 90.0;
    vec3 cam_o = vec3(0.0, 0.0, (fov / 2.0));
    vec3 ray_o = vec3(x * aspect_ratio, y, 0.0); // account for aspect ratio
    vec3 ray_d = normalize(ray_o - cam_o);
  
    float t = marchRay(cam_o, ray_d);
    if (t >= 0.0) {
        vec3 p = cam_o + t * ray_d;
        vec3 n = normalize(vec3(
            sphereSDF(vec3(p.x + EPSILON, p.y, p.z), 1.0) - sphereSDF(vec3(p.x - EPSILON, p.y, p.z), 1.0),
            sphereSDF(vec3(p.x, p.y + EPSILON, p.z), 1.0) - sphereSDF(vec3(p.x, p.y - EPSILON, p.z), 1.0),
            sphereSDF(vec3(p.x, p.y, p.z + EPSILON), 1.0) - sphereSDF(vec3(p.x, p.y, p.z - EPSILON), 1.0)
        ));
        pixel = vec4((n + 1.0) / 2.0, 1.0);
    }
  
    imageStore(screen, pixel_coords, pixel);
}