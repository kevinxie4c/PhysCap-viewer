#version 330 core

in vec3 normal;
in vec4 fragPosLightSpace;
in vec4 wPos;
out vec4 fragColor;

uniform sampler2D shadowMap;

uniform vec3 lightIntensity;
uniform vec3 lightDir;
uniform vec3 color;
uniform float alpha;
uniform int enableShadow;
uniform int checker;

void main(void)
{
    vec3 ambience = vec3(0.5);
    vec3 lighting = vec3(0.0);
    vec3 color1 = vec3(1.0);
    vec3 color2 = vec3(0.68, 0.85, 0.90);
    vec3 finalColor;
    float width = 0.5;
    if (checker == 1)
    {
        if ((mod(wPos.x, 2 * width) > width) == (mod(wPos.y, 2 * width) > width))
            finalColor = color1;
        else
            finalColor = color2;
    }
    else
        finalColor = color;
    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    projCoords = projCoords * 0.5 + 0.5;
    float closestDepth = texture(shadowMap, projCoords.xy).r; 
    float currentDepth = projCoords.z;
    int outside = 1;
    if (-1 < projCoords.x && projCoords.x < 1 && -1 < projCoords.y && projCoords.y < 1 && -1 < projCoords.z && projCoords.z < 1)
        outside = 0;
    if (outside == 1 || enableShadow == 0 || currentDepth - 1e-3 < closestDepth)
        lighting = lightIntensity * max(0, dot(-lightDir, normalize(normal)));
    fragColor = vec4((ambience + lighting), alpha) * vec4(finalColor, 1.0);
}
