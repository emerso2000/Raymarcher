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

vec3 cartesianToSpherical(vec3 cartesian) {
    float radius = length(cartesian);
    float inclination = acos(cartesian.z / radius);
    float azimuth = atan(cartesian.y, cartesian.x);

    return vec3(radius, inclination, azimuth);
}

vec3 sphericalToCartesian(vec3 spherical) {
    float x = spherical.x * sin(spherical.y) * cos(spherical.z);
    float y = spherical.x * sin(spherical.y) * sin(spherical.z);
    float z = spherical.x * cos(spherical.y);

    return vec3(x, y, z);
}

vec3 cartesianToAzELR(vec3 cartesianVec, vec3 newRayOrigin) {
    float r = sqrt((newRayOrigin.x * newRayOrigin.x) + (newRayOrigin.y * newRayOrigin.y) + (newRayOrigin.z * newRayOrigin.z));
    float az = acos(newRayOrigin.z / r);
    float el = newRayOrigin.z;

    // float r = newRayOrigin.x;
    // float az = newRayOrigin.y;
    // float el = newRayOrigin.z;

    mat3 transformationMatrix = mat3(
        -sin(az),  cos(az),  0.0,
        -sin(el) * cos(az), -sin(el) * sin(az),  cos(el),
        cos(el) * cos(az),  cos(el) * sin(az),  sin(el)
    );

    return transformationMatrix * cartesianVec;
}

vec3 sphericalToAzELR(vec3 sphericalVec, vec3 newRayOrigin) {
    float r = newRayOrigin.x;
    float az = newRayOrigin.y;
    float el = newRayOrigin.z;

    mat3 transformationMatrix = mat3(
        -sin(az),  -sin(el) * cos(az),  cos(el) * cos(az),
        cos(az), -sin(el) * sin(az),  cos(el) * sin(az),
        0.0,  cos(el),  sin(el)
    );

    return transformationMatrix * sphericalVec;
}

mat3 calculateChristoffelSymbolsAlphaR(vec3 position) {
    float r = position.x;
    float theta = position.y;

    mat3 christoffelSymbols_alpha_r;

    float rs = 0.0; // Schwarzschild radius

    christoffelSymbols_alpha_r[0][0] = -rs / (2.0 * r) * (r - rs);
    christoffelSymbols_alpha_r[0][1] = 0.0;
    christoffelSymbols_alpha_r[0][2] = 0.0;

    christoffelSymbols_alpha_r[1][0] = 0.0;
    christoffelSymbols_alpha_r[1][1] = rs - r;
    christoffelSymbols_alpha_r[1][2] = 0.0;

    christoffelSymbols_alpha_r[2][0] = 0.0;
    christoffelSymbols_alpha_r[2][1] = 0.0;
    christoffelSymbols_alpha_r[2][2] = (rs - r) * sin(theta) * sin(theta);

    return christoffelSymbols_alpha_r;
}

mat3 calculateChristoffelSymbolsAlphaTheta(vec3 position) {
    float r = position.x;
    float theta = position.y;

    mat3 christoffelSymbols_alpha_theta;

    float rs = 0.0; // Schwarzschild radius

    christoffelSymbols_alpha_theta[0][0] = rs - r;
    christoffelSymbols_alpha_theta[0][1] = 1.0 / r;
    christoffelSymbols_alpha_theta[0][2] = 0.0;

    christoffelSymbols_alpha_theta[1][0] = 0.0;
    christoffelSymbols_alpha_theta[1][1] = 1.0 / tan(theta);
    christoffelSymbols_alpha_theta[1][2] = 0.0;

    christoffelSymbols_alpha_theta[2][0] = 0.0;
    christoffelSymbols_alpha_theta[2][1] = 0.0;
    christoffelSymbols_alpha_theta[2][2] = (rs - r) * sin(theta) * sin(theta);

    return christoffelSymbols_alpha_theta;
}

mat3 calculateChristoffelSymbolsAlphaPhi(vec3 position) {
    float r = position.x;
    float theta = position.y;

    mat3 christoffelSymbols_alpha_phi;

    float rs = 0.0; // Schwarzschild radius

    christoffelSymbols_alpha_phi[0][0] = 1.0 / r;
    christoffelSymbols_alpha_phi[0][1] = 1.0 / r;
    christoffelSymbols_alpha_phi[0][2] = 1.0 / r;

    christoffelSymbols_alpha_phi[1][0] = 0.0;
    christoffelSymbols_alpha_phi[1][1] = 0.0;
    christoffelSymbols_alpha_phi[1][2] = -sin(theta) * cos(theta);

    christoffelSymbols_alpha_phi[2][0] = 0.0;
    christoffelSymbols_alpha_phi[2][1] = 0.0;
    christoffelSymbols_alpha_phi[2][2] = 1.0 / r;

    return christoffelSymbols_alpha_phi;
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

    vec3 accel = vec3(0.0);

    float stepSize = 0.0;

    vec3 p = origin;
    for (int i = 0; i < MAX_STEPS; i++) {
        p += stepSize * direction;

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
        stepSize = min(min(min(min(min(min(currentDistSphere, currentDistFloor), currentDistCeiling), currentDistWall1), currentDistWall2), currentDistWall3), currentDistWall4);
        
        if (stepSize < minStepSize) {
            stepSize = minStepSize;
        }

        mat3 christoffelSymbols_alpha_r = calculateChristoffelSymbolsAlphaR(p);
        mat3 christoffelSymbols_alpha_theta = calculateChristoffelSymbolsAlphaTheta(p);
        mat3 christoffelSymbols_alpha_phi = calculateChristoffelSymbolsAlphaPhi(p);

        // Calculate the accelerations using the geodesic equation
        accel.x = -dot(direction, christoffelSymbols_alpha_r * direction);
        accel.y = -dot(direction, christoffelSymbols_alpha_theta * direction);
        accel.z = -dot(direction, christoffelSymbols_alpha_phi * direction);

        direction += accel * stepSize;

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


void main() {
    vec4 pixel = vec4(0.115, 0.133, 0.173, 1.0);
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dims = imageSize(screen);
    float aspect_ratio = float(dims.x) / float(dims.y);
    //normalized screen coordinates
    float x = -(float(pixel_coords.x * 2 - dims.x) / dims.x);
    float y = -(float(pixel_coords.y * 2 - dims.y) / dims.y);

    vec3 ray_o = vec3(x * aspect_ratio, y, 0.0);

    // vec3 new_ray_o = (cartesianToSpherical(ray_o));;

    vec3 ray_d = vec3(ray_o.x, ray_o.y, -1.0 / tan(camera.fov / 2.0));
    // Apply matrices.view transformation to ray_d
    ray_d = (matrices.view * vec4(ray_d, 0)).xyz;

    ray_d = cartesianToAzELR(ray_d, ray_o); //new_ray_o is in spherical ray_d is cartesian now ray_d is in (r, theta, phi)
    ray_d = normalize(ray_d);

    ray_d.y /= ray_d.x;
    
    ray_d.z /= (ray_d.x * sin(ray_d.y));

    float t = marchRay(cartesianToSpherical(camera.cam_o), ray_d);

    //V1
    if (t >= 0.0) {
        vec3 p = sphericalToCartesian(camera.cam_o) + t * sphericalToAzELR(ray_d, ray_o);

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
        } 
        else if (floorDist < ceilingDist && floorDist < wallDist1 && floorDist < wallDist2 && floorDist < wallDist3 && floorDist < wallDist4) {
            // The hit point is closer to the floor
            pixel = vec4(floorColor, 1.0);
        } 
        else if (ceilingDist < wallDist1 && ceilingDist < wallDist2 && ceilingDist < wallDist3 && ceilingDist < wallDist4) {
            // The hit point is closer to the ceiling
            pixel = vec4(ceilingColor, 1.0);
        } 
        else if (wallDist1 < wallDist2 && wallDist1 < wallDist3 && wallDist1 < wallDist4) {
            // The hit point is closer to the first wall
            pixel = vec4(wallColor1, 1.0);
        } 
        else if (wallDist2 < wallDist3 && wallDist2 < wallDist4) {
            // The hit point is closer to the second wall
            pixel = vec4(wallColor2, 1.0);
        } 
        else if (wallDist3 < wallDist4) {
            // The hit point is closer to the third wall
            pixel = vec4(wallColor3, 1.0);
        } 
        else {
            // The hit point is closer to the fourth wall
            pixel = vec4(wallColor4, 1.0);
        }
    }
    imageStore(screen, pixel_coords, pixel);
}
