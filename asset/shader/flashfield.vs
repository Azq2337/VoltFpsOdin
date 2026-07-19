#version 330

in vec3 vertexPosition;
in vec3 vertexNormal;

uniform mat4 mvp;
uniform vec3 fieldCenter;

out vec3 fragWorldPosition;
out vec3 fragNormal;

void main()
{
    fragWorldPosition = vertexPosition + fieldCenter;
    fragNormal = normalize(vertexNormal);

    gl_Position = mvp * vec4(vertexPosition, 1.0);
}

