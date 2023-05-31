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

const int MAX_STEPS = 5000;

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
    float theta = acos(cartesian.z / radius);
    float phi = atan(cartesian.y, cartesian.x);

    return vec3(radius, theta, phi);
}

vec3 sphericalToCartesian(vec3 spherical) {
    float x = spherical.x * sin(spherical.y) * cos(spherical.z);
    float y = spherical.x * sin(spherical.y) * sin(spherical.z);
    float z = spherical.x * cos(spherical.y);

    return vec3(x, y, z);
}

vec3 cartesianToAzELR(vec3 cartesianVec, vec3 newRayOrigin) {
    // float r = sqrt((newRayOrigin.x * newRayOrigin.x) + (newRayOrigin.y * newRayOrigin.y) + (newRayOrigin.z * newRayOrigin.z));
    // float az = acos(newRayOrigin.z / r);
    // float el = newRayOrigin.z;

    float r = newRayOrigin.x;
    float az = newRayOrigin.y;
    float el = newRayOrigin.z;

    mat3 transformationMatrix = mat3(
        -sin(az),  cos(az),  0.0,
        -sin(el) * cos(az), -sin(el) * sin(az),  cos(el),
        cos(el) * cos(az),  cos(el) * sin(az),  sin(el)
    );

    vec3 newVec = transformationMatrix * cartesianVec;

    return newVec;
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

    christoffelSymbols_alpha_theta[0][0] = 0.0;
    christoffelSymbols_alpha_theta[0][1] = 1.0 / r;
    christoffelSymbols_alpha_theta[0][2] = 0.0;

    christoffelSymbols_alpha_theta[1][0] = 1.0 / r;
    christoffelSymbols_alpha_theta[1][1] = 0.0;
    christoffelSymbols_alpha_theta[1][2] = 0.0;

    christoffelSymbols_alpha_theta[2][0] = 0.0;
    christoffelSymbols_alpha_theta[2][1] = 0.0;
    christoffelSymbols_alpha_theta[2][2] = -sin(theta) * cos(theta);

    return christoffelSymbols_alpha_theta;
}

mat3 calculateChristoffelSymbolsAlphaPhi(vec3 position) {
    float r = position.x;
    float theta = position.y;

    mat3 christoffelSymbols_alpha_phi;

    float rs = 0.0; // Schwarzschild radius

    christoffelSymbols_alpha_phi[0][0] = 0.0;
    christoffelSymbols_alpha_phi[0][1] = 1.0 / r;
    christoffelSymbols_alpha_phi[0][2] = 0.0;

    christoffelSymbols_alpha_phi[1][0] = 1.0 / r;
    christoffelSymbols_alpha_phi[1][1] = 0.0;
    christoffelSymbols_alpha_phi[1][2] = 1.0 / tan(theta);

    christoffelSymbols_alpha_phi[2][0] = 0.0;
    christoffelSymbols_alpha_phi[2][1] = 1.0 / tan(theta);
    christoffelSymbols_alpha_phi[2][2] = 0.0;

    return christoffelSymbols_alpha_phi;
}

float marchRay(vec3 origin, vec3 direction) {
    float t = 0.0;

    float prevDistSphere = sphereSDF(sphericalToCartesian(origin), 1.0);

    float minStepSize = 0.001;

    float stepSize = 0.0;

    vec3 p = origin;

    vec3 accel = vec3(0.0);

    for (int i = 0; i < MAX_STEPS; i++) {
        p += stepSize * direction;
        vec3 p_cart = sphericalToCartesian(p);

        float currentDistSphere = sphereSDF(p_cart, 1.0);

        if (prevDistSphere > 0.0 && currentDistSphere <= 0.0) {
            return t;
        }

        stepSize = currentDistSphere;
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

    }
    return -1.0;
}


void main() {
    vec4 pixel = vec4(0.115, 0.133, 0.173, 1.0);
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

    ivec2 dims = imageSize(screen);

    vec2 uv = (vec2(pixel_coords) - 0.5 * dims.xy) / dims.y;

    vec3 ro = camera.cam_o;

    vec3 rd = (vec3(uv.x, uv.y, 1.0));

    rd = (matrices.view * vec4(rd, 0)).xyz;

    rd = normalize(rd);
    
    vec3 sphericalRo = cartesianToSpherical(ro);
    vec3 sphericalRd = cartesianToAzELR(rd, sphericalRo);

    sphericalRd.y /= sphericalRo.x;

    sphericalRd.z /= (sphericalRo.x * sin(sphericalRo.y));

    float d = marchRay(sphericalRo, sphericalRd);

    vec3 p = sphericalRo;

    if (d >= 0.0) {
        p += sphericalRd * d;

        vec3 p_cart = sphericalToCartesian(p);

        vec3 sphereColor = vec3(1.0, 0.0, 0.0); // Red color for the sphere

        float sphereDist = sphereSDF(p_cart, 1.0);

        pixel = vec4(sphereColor, 1.0);
    }
    
    imageStore(screen, pixel_coords, pixel);
}
