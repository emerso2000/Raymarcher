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
// float marchRay(vec3 origin, vec3 direction) {
//     float t = 0.0;
//     for (int i = 0; i < MAX_STEPS; i++) {
//         vec3 p = origin + t * direction;
//         float d = sphereSDF(p, 1.0);
//         if (d < EPSILON) {
//             return t;
//         }
//         t += d;
//     }
//     return -1.0;
// }

//V2
// float marchRay(vec3 origin, vec3 direction) {
//     float t = 0.0;
//     for (int i = 0; i < MAX_STEPS; i++) {
//         vec3 p = origin + t * direction;
//         float d1 = sphereSDF(p, 1.0);
//         float d2 = floorSDF(p, camera.floor_height);
//         if (d1 < EPSILON || d2 < EPSILON) {
//             return t;
//         }
//         t += min(d1, d2);
//     }
//     return -1.0;
// }

//V3
// float marchRay(vec3 origin, vec3 direction) {
//     float t = 0.0;
//     for (int i = 0; i < MAX_STEPS; i++) {
//         vec3 p = origin + t * direction;
//         float d1 = sphereSDF(p, 1.0);
//         float d2 = floorSDF(p, camera.floor_height);
//         float d3 = wallSDF(p, vec3(0.0, 0.0, 1.0), 5.0); // 5 is distance to wall
//         if (d1 < EPSILON || d2 < EPSILON || d3 < EPSILON) {
//             return t;
//         }
//         t += min(min(d1, d2), d3);
//     }
//     return -1.0;
// }

//V4
// float marchRay(vec3 origin, vec3 direction) {
//     float t = 0.0;
//     for (int i = 0; i < MAX_STEPS; i++) {
//         vec3 p = origin + t * direction;
//         float d1 = sphereSDF(p, 1.0);
//         float d2 = floorSDF(p, camera.floor_height);
//         float d3 = wallSDF(p, vec3(0.0, 0.0, 1.0), 3.0); // Wall 1
//         float d4 = wallSDF(p, vec3(0.0, 1.0, 0.0), 3.0); // Wall 2
//         float d5 = wallSDF(p, vec3(1.0, 0.0, 0.0), 3.0); // Wall 3
//         float d6 = wallSDF(p, vec3(0.0, 0.0, -1.0), 3.0); // Wall 4

//         if (d1 < EPSILON || d2 < EPSILON || d3 < EPSILON || d4 < EPSILON || d5 < EPSILON || d6 < EPSILON) {
//             return t;
//         }
//         t += min(min(min(min(min(d1, d2), d3), d4), d5), d6); 
    
//     }
//     return -1.0;
// }

//V5
// float marchRay(vec3 origin, vec3 direction) {
//     float t = 0.0;
//     float prevDist = sphereSDF(origin, 1.0); // Distance at the starting point

//     for (int i = 0; i < MAX_STEPS; i++) {
//         vec3 p = origin + t * direction;
//         float currentDist = sphereSDF(p, 1.0); // Distance at the current point

//         if (prevDist > 0.0 && currentDist <= 0.0) {
//             // Transition from outside to inside, indicating a hit
//             return t;
//         }

//         t += currentDist;
//         prevDist = currentDist;
//     }

//     return -1.0; // No hit found
// }

//V6
// float marchRay(vec3 origin, vec3 direction) {
//     float t = 0.0;
//     float prevDistSphere = sphereSDF(origin, 1.0); // Distance to the sphere at the starting point
//     float prevDistFloor = floorSDF(origin, camera.floor_height); // Distance to the floor at the starting point

//     for (int i = 0; i < MAX_STEPS; i++) {
//         vec3 p = origin + t * direction;
//         float currentDistSphere = sphereSDF(p, 1.0); // Distance to the sphere at the current point
//         float currentDistFloor = floorSDF(p, camera.floor_height); // Distance to the floor at the current point

//         if (prevDistSphere > 0.0 && currentDistSphere <= 0.0) {
//             // Transition from outside to inside the sphere, indicating a hit
//             return t;
//         }

//         if (prevDistFloor > 0.0 && currentDistFloor <= 0.0) {
//             // Transition from outside to inside the floor, indicating a hit
//             return t;
//         }

//         t += min(currentDistSphere, currentDistFloor); // Take the minimum distance for marching

//         prevDistSphere = currentDistSphere;
//         prevDistFloor = currentDistFloor;
//     }

//     return -1.0; // No hit found
// }

//V7
// float marchRay(vec3 origin, vec3 direction) {
//     float t = 0.0;
//     float prevDistSphere = sphereSDF(origin, 1.0); // Distance to the sphere at the starting point
//     float prevDistFloor = floorSDF(origin, camera.floor_height); // Distance to the floor at the starting point

//     float minStepSize = 0.001; // Minimum step size

//     for (int i = 0; i < MAX_STEPS; i++) {
//         vec3 p = origin + t * direction;
//         float currentDistSphere = sphereSDF(p, 1.0); // Distance to the sphere at the current point
//         float currentDistFloor = floorSDF(p, camera.floor_height); // Distance to the floor at the current point

//         if (prevDistSphere > 0.0 && currentDistSphere <= 0.0) {
//             // Transition from outside to inside the sphere, indicating a hit
//             return t;
//         }

//         if (prevDistFloor > 0.0 && currentDistFloor <= 0.0) {
//             // Transition from outside to inside the floor, indicating a hit
//             return t;
//         }

//         float stepSize = min(currentDistSphere, currentDistFloor);
//         if (stepSize < minStepSize) {
//             stepSize = minStepSize; // Limit the step size to the minimum value
//         }

//         t += stepSize;

//         prevDistSphere = currentDistSphere;
//         prevDistFloor = currentDistFloor;
//     }

//     return -1.0; // No hit found
// }

//V8
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
    // if (t >= 0.0) {
    //     vec3 p = camera.cam_o + t * ray_d;
    //     vec3 n = normalize(vec3(
    //         sphereSDF(vec3(p.x + EPSILON, p.y, p.z), 1.0) - sphereSDF(vec3(p.x - EPSILON, p.y, p.z), 1.0),
    //         sphereSDF(vec3(p.x, p.y + EPSILON, p.z), 1.0) - sphereSDF(vec3(p.x, p.y - EPSILON, p.z), 1.0),
    //         sphereSDF(vec3(p.x, p.y, p.z + EPSILON), 1.0) - sphereSDF(vec3(p.x, p.y, p.z - EPSILON), 1.0)
    //     ));
    //     pixel = vec4((n + 1.0) / 2.0, 1.0);
    // }

    //V2
    // if (t >= 0.0) {
    //     vec3 p = camera.cam_o + t * ray_d;
    //     vec3 n = normalize(vec3(
    //         sphereSDF(vec3(p.x + EPSILON, p.y, p.z), 1.0) - sphereSDF(vec3(p.x - EPSILON, p.y, p.z), 1.0),
    //         sphereSDF(vec3(p.x, p.y + EPSILON, p.z), 1.0) - sphereSDF(vec3(p.x, p.y - EPSILON, p.z), 1.0),
    //         sphereSDF(vec3(p.x, p.y, p.z + EPSILON), 1.0) - sphereSDF(vec3(p.x, p.y, p.z - EPSILON), 1.0)
    //     ));
        // if (floorSDF(p, camera.floor_height) < EPSILON) {
        //     n = vec3(0.0, -1.0, 0.0); // Set the normal vector for the floor surface
        // }
    //     pixel = vec4((n + 1.0) / 2.0, 1.0);
    // }

    //V3
    // if (t >= 0.0) {
    //     vec3 p = camera.cam_o + t * ray_d;
    //     vec3 n = normalize(vec3(
    //         sphereSDF(vec3(p.x + EPSILON, p.y, p.z), 1.0) - sphereSDF(vec3(p.x - EPSILON, p.y, p.z), 1.0),
    //         sphereSDF(vec3(p.x, p.y + EPSILON, p.z), 1.0) - sphereSDF(vec3(p.x, p.y - EPSILON, p.z), 1.0),
    //         sphereSDF(vec3(p.x, p.y, p.z + EPSILON), 1.0) - sphereSDF(vec3(p.x, p.y, p.z - EPSILON), 1.0)
    //     ));
    //     if (floorSDF(p, camera.floor_height) < EPSILON) {
    //         n = vec3(0.0, -1.0, 0.0); // Set the normal vector for the floor surface
    //     } 
    //     else if (wallSDF(p, vec3(0.0, 0.0, 1.0), 5.0) < EPSILON) { // Check if point is on the wall
    //         n = vec3(1.0, 0.0, 0.0); // Set the normal vector for the wall surface
    //     }

    //     pixel = vec4((n + 1.0) / 2.0, 1.0);
    // }

    //V4
    // if (t >= 0.0) {
    //     vec3 p = camera.cam_o + t * ray_d;
    //     vec3 n = normalize(vec3(
    //         sphereSDF(vec3(p.x + EPSILON, p.y, p.z), 1.0) - sphereSDF(vec3(p.x - EPSILON, p.y, p.z), 1.0),
    //         sphereSDF(vec3(p.x, p.y + EPSILON, p.z), 1.0) - sphereSDF(vec3(p.x, p.y - EPSILON, p.z), 1.0),
    //         sphereSDF(vec3(p.x, p.y, p.z + EPSILON), 1.0) - sphereSDF(vec3(p.x, p.y, p.z - EPSILON), 1.0)
    //     ));
    //     if (floorSDF(p, camera.floor_height) < EPSILON) {
    //         n = vec3(0.0, -1.0, 0.0); // Set the normal vector for the floor surface
    //     } 
    //     else if (wallSDF(p, vec3(0.0, 0.0, 1.0), 3.0) < EPSILON) { // Check if point is on the first wall
    //         n = vec3(0.0, 0.0, -1.0); // Set the normal vector for the wall surface
    //     }
    //     else if (wallSDF(p, vec3(0.0, 1.0, 0.0), 3.0) < EPSILON) { // Check if point is on the second wall
    //         n = vec3(0.0, -1.0, 0.0); // Set the normal vector for the wall surface
    //     }
    //     else if (wallSDF(p, vec3(1.0, 0.0, 0.0), 3.0) < EPSILON) { // Check if point is on the third wall
    //         n = vec3(-1.0, 0.0, 0.0); // Set the normal vector for the wall surface
    //     }
    //     else if (wallSDF(p, vec3(0.0, 0.0, -1.0), 3.0) < EPSILON) { // Check if point is on the wall behind the camera
    //         n = vec3(0.0, 0.0, 1.0); // Set the normal vector for the wall surface
    //     }

    //     pixel = vec4((n + 1.0) / 2.0, 1.0);
    // }

    //V5
    // if (t >= 0.0) {
    //     vec3 p = camera.cam_o + t * ray_d;
    //     vec3 color = vec3(1.0, 0.0, 0.0); // Solid red color
    //     pixel = vec4(color, 1.0);
    // }

    //V6
    // if (t >= 0.0) {
    //     vec3 p = camera.cam_o + t * ray_d;
    //     vec3 sphereColor = vec3(1.0, 0.0, 0.0); // Red color for the sphere
    //     vec3 floorColor = vec3(0.0, 0.0, 1.0); // Blue color for the floor

    //     // Check if the hit point is closer to the sphere or the floor
    //     float sphereDist = sphereSDF(p, 1.0);
    //     float floorDist = floorSDF(p, camera.floor_height);

    //     if (sphereDist > floorDist) {
    //         // The hit point is closer to the floor
    //         pixel = vec4(floorColor, 1.0);
    //     } else {
    //         // The hit point is closer to the sphere
    //         pixel = vec4(sphereColor, 1.0);
    //     }
    // }

    //V8
    if (t >= 0.0) {
        vec3 p = camera.cam_o + t * ray_d;
        vec3 sphereColor = vec3(1.0, 0.0, 0.0); // Red color for the sphere
        vec3 floorColor = vec3(1.0, 1.0, 1.0); // Blue color for the floor
        vec3 ceilingColor = vec3(0.0, 0.0, 1.0); // White color for the ceiling
        vec3 wallColor1 = vec3(0.0, 1.0, 0.0); // Green color for the first wall
        vec3 wallColor2 = vec3(1.0, 1.0, 0.0); // Yellow color for the second wall
        vec3 wallColor3 = vec3(1.0, 0.0, 1.0); // Magenta color for the third wall
        vec3 wallColor4 = vec3(0.0, 1.0, 1.0); // Cyan color for the fourth wall

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
