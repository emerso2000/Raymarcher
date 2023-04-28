#version 450 core

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 uvs;

uniform mat4 uMVP;

out vec2 UVs;

void main()
{
	gl_Position = uMVP * vec4(pos.x, pos.y, pos.z, 1.0);
	UVs = uvs;
}
