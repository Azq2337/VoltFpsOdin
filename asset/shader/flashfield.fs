#version 330

in vec3 fragWorldPosition;
in vec3 fragNormal;

uniform vec3 cameraPos;
uniform vec3 cameraForward;
uniform vec3 fieldCenter;
uniform float time;
uniform float fieldRadius;

out vec4 finalColor;

void main()
{
    vec3 normal = normalize(fragNormal);
    vec3 viewToCamera = normalize(cameraPos - fragWorldPosition);
    vec3 spherePosition = normalize(fragWorldPosition - fieldCenter);

    float cameraDistance = length(cameraPos - fieldCenter);
    bool cameraInside = cameraDistance < fieldRadius;

    float viewIntensity;

    if (cameraInside)
    {
        // FPS: keep the central combat view clear and reveal the physical
        // shell progressively toward peripheral viewing directions.
        vec3 viewRay = normalize(fragWorldPosition - cameraPos);
        float forwardAlignment = max(
            dot(viewRay, normalize(cameraForward)),
            0.0
        );
        float peripheral = 1.0 - forwardAlignment;

        viewIntensity = smoothstep(
            0.20,
            0.40,
            peripheral
        );
    }
    else
    {
        // TPS: conventional Fresnel gives the sphere its bright silhouette.
        float facing = abs(dot(normal, viewToCamera));
        viewIntensity = pow(1.0 - facing, 2.5);
    }

    // Moving interference patterns keep the field from reading as a clean
    // static force-field bubble. These are intentionally broad and soft;
    // the lightning arcs provide the high-frequency detail.
    float waveA = sin(
        spherePosition.x * 18.0 +
        spherePosition.y * 11.0 +
        time * 2.8
    );
    float waveB = sin(
        spherePosition.z * 23.0 -
        spherePosition.y * 15.0 -
        time * 3.6
    );
    float waveC = sin(
        (spherePosition.x + spherePosition.z) * 31.0 +
        spherePosition.y * 9.0 +
        time * 5.1
    );

    float fieldNoise = clamp(
        0.50 +
        waveA * 0.22 +
        waveB * 0.17 +
        waveC * 0.11,
        0.0,
        1.0
    );

    // Thin moving high-energy veins appear inside the broader purple/blue
    // texture. They are procedural, so no texture asset is required yet.
    float veinSignal = abs(sin(
        spherePosition.x * 37.0 +
        spherePosition.y * 29.0 +
        spherePosition.z * 33.0 +
        sin(spherePosition.y * 13.0 - time * 4.0) * 2.2 +
        time * 6.0
    ));
    float veins = smoothstep(0.90, 0.995, veinSignal);

    float pulse =
        0.88 +
        0.12 * sin(time * 4.5 + spherePosition.y * 7.0);

    float electricEnergy = clamp(
        fieldNoise * 0.72 +
        veins * 1.15,
        0.0,
        1.0
    );

    vec3 purple = vec3(0.22, 0.05, 0.65);
    vec3 deepBlue = vec3(0.04, 0.25, 0.95);
    vec3 cyan = vec3(0.28, 0.92, 1.00);

    vec3 baseColor = mix(purple, deepBlue, fieldNoise);
    vec3 color = mix(baseColor, cyan, electricEnergy);

    float alpha =
        viewIntensity *
        (0.17 + fieldNoise * 0.14 + veins * 0.24) *
        pulse;

    finalColor = vec4(color, alpha);
}
