// Paper background: a flat color with fine grain and a soft vignette (D-009).
shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.996, 0.992, 0.878, 1.0);
uniform float grain = 0.035;
uniform float vignette = 0.10;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float n = hash(floor(FRAGCOORD.xy / 1.5)) - 0.5;
	float fibers = hash(floor(FRAGCOORD.xy / vec2(9.0, 2.0))) - 0.5;
	vec2 d = UV - vec2(0.5);
	float v = 1.0 - vignette * dot(d, d) * 2.2;
	vec3 c = paper.rgb * v + (n * grain + fibers * grain * 0.5);
	COLOR = vec4(c, paper.a);
}
