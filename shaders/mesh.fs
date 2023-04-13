#version 330 core

in vec4 wPos;
out vec4 fragColor;

uniform vec3 lightIntensity;
uniform vec3 lightDir;
uniform vec3 color;
uniform float alpha;

void main(void)
{
    vec3 ambience = vec3(0.5);
    vec3 lighting = vec3(0.0);
    vec3 ndc_pos = wPos.xyz / wPos.w;
    vec3 dx = dFdx(ndc_pos);
    vec3 dy = dFdy(ndc_pos);
    vec3 normal = normalize(cross(dx, dy));
    //normal *= sign(normal.z);
    lighting = lightIntensity * max(0, dot(-lightDir, normalize(normal)));
    fragColor = vec4((ambience + lighting), alpha) * vec4(color, 1.0);
    //fragColor = vec4(color, 1.0);
}
