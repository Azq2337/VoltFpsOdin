#version 330

in vec3 fragWorldPosition;
in vec3 fragNormal;

uniform vec3 cameraPos;
uniform vec3 cameraForward;
uniform vec3 fieldCenter;

out vec4 finalColor;

void main()
{
    vec3 normal = normalize(fragNormal);
    vec3 viewToCamera =
        normalize(cameraPos - fragWorldPosition);

    float cameraDistance =
        length(cameraPos - fieldCenter);

    bool cameraInside =
        cameraDistance < 2.5;

    float intensity;

    if (cameraInside)
    {
        // Direction from camera toward this point on the sphere.
        vec3 viewRay =
            normalize(fragWorldPosition - cameraPos);

        // 1 at screen/view center, decreasing toward peripheral vision.
        float forwardAlignment =
            max(dot(
                viewRay,
                normalize(cameraForward)
            ), 0.0);

        float peripheral =
            1.0 - forwardAlignment;

        // Keep central vision clear, then ramp up sharply.
        intensity =
            smoothstep(
                0.2,
                0.4,
                peripheral
            );
    }
    else
    {
        // Normal exterior Fresnel for TPS.
        float facing =
            abs(dot(
                normal,
                viewToCamera
            ));

        intensity =
            pow(
                1.0 - facing,
                2.5
            );
    }

    vec3 deepBlue =
        vec3(0.05, 0.25, 1.0);

    vec3 cyan =
        vec3(0.30, 0.90, 1.0);

    vec3 color =
        mix(
            deepBlue,
            cyan,
            intensity
        );

    float alpha =
        intensity * 0.45;

    finalColor =
        vec4(
            color,
            alpha
        );
}