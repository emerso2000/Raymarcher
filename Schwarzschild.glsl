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
    float floor_height;
    float ceiling_height;
} camera;


layout (std140, binding = 2) uniform MatricesBlock {
    mat4 view;
} matrices;

const int MAX_STEPS = 7000;

float sphereSDF(vec3 p, float r) {
    return length(p) - r;
}

float floorSDF(vec3 p, float height) {
    return p.y - height;
}

float wallSDF(vec3 p, vec3 normal, float distance) {
    return dot(p, normal) + distance;
}

float ceilingSDF(vec3 p, float height) {
    return height - p.y;
}

//V1
float marchRay(vec3 origin, vec3 direction) {
    float t = 0.0;
    float prevDistSphere = sphereSDF(origin, 1.0);
    float prevDistFloor = floorSDF(origin, camera.floor_height);
    float prevDistCeiling = ceilingSDF(origin, camera.ceiling_height);
    float prevDistWall1 = wallSDF(origin, vec3(0.0, 0.0, 1.0), 3.0); // Distance to the first wall
    float prevDistWall2 = wallSDF(origin, vec3(0.0, 0.0, -1.0), 3.0); // Distance to the second wall
    float prevDistWall3 = wallSDF(origin, vec3(1.0, 0.0, 0.0), 3.0); // Distance to the third wall
    float prevDistWall4 = wallSDF(origin, vec3(-1.0, 0.0, 0.0), 3.0); // Distance to the fourth wall
    float minStepSize = 0.001;

    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = origin + t * direction;
        float currentDistSphere = sphereSDF(p, 1.0);
        float currentDistFloor = floorSDF(p, camera.floor_height);
        float currentDistCeiling = ceilingSDF(p, camera.ceiling_height);
        float currentDistWall1 = wallSDF(p, vec3(0.0, 0.0, 1.0), 3.0); // Distance to the first wall
        float currentDistWall2 = wallSDF(p, vec3(0.0, 0.0, -1.0), 3.0); // Distance to the second wall
        float currentDistWall3 = wallSDF(p, vec3(1.0, 0.0, 0.0), 3.0); // Distance to the third wall
        float currentDistWall4 = wallSDF(p, vec3(-1.0, 0.0, 0.0), 3.0); // Distance to the fourth wall

        if (prevDistSphere > 0.0 && currentDistSphere <= 0.0) {
            return t;
        }

        if (prevDistFloor > 0.0 && currentDistFloor <= 0.0) {
            return t;
        }

        if (prevDistCeiling > 0.0 && currentDistCeiling <= 0.0) {
            return t;
        }

        if (prevDistWall1 > 0.0 && currentDistWall1 <= 0.0) {
            return t;
        }

        if (prevDistWall2 > 0.0 && currentDistWall2 <= 0.0) {
            return t;
        }

        if (prevDistWall3 > 0.0 && currentDistWall3 <= 0.0) {
            return t;
        }

        if (prevDistWall4 > 0.0 && currentDistWall4 <= 0.0) {
            return t;
        }

        float stepSize = min(min(min(min(min(min(currentDistSphere, currentDistFloor), currentDistCeiling), currentDistWall1), currentDistWall2), currentDistWall3), currentDistWall4);
        if (stepSize < minStepSize) {
            stepSize = minStepSize;
        }

        t += stepSize;

        prevDistSphere = currentDistSphere;
        prevDistFloor = currentDistFloor;
        prevDistCeiling = currentDistCeiling;
        prevDistWall1 = currentDistWall1;
        prevDistWall2 = currentDistWall2;
        prevDistWall3 = currentDistWall3;
        prevDistWall4 = currentDistWall4;
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
    vec3 ray_d = vec3(ray_o.x, ray_o.y, -1.0 / tan(camera.fov / 2.0));
    // Apply matrices.view transformation to ray_d
    ray_d = (matrices.view * vec4(ray_d, 0)).xyz;
    ray_d = normalize(ray_d);

    float t = marchRay(camera.cam_o, ray_d);

    //V1
    if (t >= 0.0) {
        vec3 p = camera.cam_o + t * ray_d;
        vec3 sphereColor = vec3(1.0, 0.0, 0.0); // Red color for the sphere
        vec3 floorColor = vec3(0.0, 0.0, 1.0); // green color for the floor
        vec3 ceilingColor = vec3(0.0, 1.0, 0.0); // blue color for the ceiling
        vec3 wallColor1 = vec3(1.0, 1.0, 0.0); // yellow color for the first wall
        vec3 wallColor2 = vec3(0.0, 1.0, 1.0); // cyan color for the second wall
        vec3 wallColor3 = vec3(0.5, 0.0, 0.5); // magenta color for the third wall
        vec3 wallColor4 = vec3(1.0, 0.5, 1.0); // orange color for the fourth wall

        float sphereDist = sphereSDF(p, 1.0);
        float floorDist = floorSDF(p, camera.floor_height);
        float ceilingDist = ceilingSDF(p, camera.ceiling_height);
        float wallDist1 = wallSDF(p, vec3(0.0, 0.0, 1.0), 3.0); // Distance to the first wall
        float wallDist2 = wallSDF(p, vec3(0.0, 0.0, -1.0), 3.0); // Distance to the second wall
        float wallDist3 = wallSDF(p, vec3(1.0, 0.0, 0.0), 3.0); // Distance to the third wall
        float wallDist4 = wallSDF(p, vec3(-1.0, 0.0, 0.0), 3.0); // Distance to the fourth wall

        if (sphereDist < floorDist && sphereDist < ceilingDist && sphereDist < wallDist1 && sphereDist < wallDist2 && sphereDist < wallDist3 && sphereDist < wallDist4) {
            // The hit point is closer to the sphere
            pixel = vec4(sphereColor, 1.0);
        } else if (floorDist < ceilingDist && floorDist < wallDist1 && floorDist < wallDist2 && floorDist < wallDist3 && floorDist < wallDist4) {
            // The hit point is closer to the floor
            pixel = vec4(floorColor, 1.0);
        } else if (ceilingDist < wallDist1 && ceilingDist < wallDist2 && ceilingDist < wallDist3 && ceilingDist < wallDist4) {
            // The hit point is closer to the ceiling
            pixel = vec4(ceilingColor, 1.0);
        } else if (wallDist1 < wallDist2 && wallDist1 < wallDist3 && wallDist1 < wallDist4) {
            // The hit point is closer to the first wall
            pixel = vec4(wallColor1, 1.0);
        } else if (wallDist2 < wallDist3 && wallDist2 < wallDist4) {
            // The hit point is closer to the second wall
            pixel = vec4(wallColor2, 1.0);
        } else if (wallDist3 < wallDist4) {
            // The hit point is closer to the third wall
            pixel = vec4(wallColor3, 1.0);
        } else {
            // The hit point is closer to the fourth wall
            pixel = vec4(wallColor4, 1.0);
        }
    }

    imageStore(screen, pixel_coords, pixel);
}
