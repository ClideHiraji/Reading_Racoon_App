shader_type canvas_item;
// A Closet card's tier (D-026), drawn behind the card's picture and words: a frame in the tier's
// colour and a wash of its light colour at the top. From silver up a shine sweeps across now and
// then (more often at higher tiers); gold and diamond add twinkles on the frame; diamond's frame
// is a slow rainbow. Slow and soft: nothing flashes.

uniform int tier = 0;
uniform vec4 frame_color : source_color = vec4(0.77, 0.48, 0.27, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 rect_size = vec2(200.0, 290.0);
uniform float radius = 22.0;
uniform float border = 5.0;
uniform float seed = 0.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 3.7) * 43758.5453);
}

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	vec3 rgb = (top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(a, 0.0001);
	return vec4(rgb, a);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = px - rect_size * 0.5;
	float d = sd_round_box(c, rect_size * 0.5, radius);
	float inside = 1.0 - smoothstep(-0.6, 0.6, d);
	float ring = inside * smoothstep(-border - 0.6, -border + 0.6, d);
	float t = TIME + seed;
	vec3 fc = frame_color.rgb;
	if (tier == 4) {
		float ang = atan(c.y, c.x) / 6.2832;
		fc = 0.6 + 0.4 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + ang + t * 0.12));
	}
	float wash = inside * (1.0 - ring) * smoothstep(0.62, 0.0, UV.y) * (0.45 + 0.1 * float(tier));
	vec4 col = vec4(light_color.rgb, wash);
	if (tier >= 1) {
		float period = 6.5 - float(tier) * 0.8;
		float run = mod(t, period);
		float pos = run / 1.1 * 1.8 - 0.4;
		float dd = abs(UV.x * 0.7 + UV.y * 0.45 - pos);
		float band = run < 1.1 ? smoothstep(0.12, 0.0, dd) : 0.0;
		col = over(vec4(1.0, 1.0, 1.0, band * inside * (0.22 + 0.05 * float(tier))), col);
	}
	col = over(vec4(fc, ring), col);
	if (tier >= 3) {
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			// a spot on the frame, going round it
			float u = hash(fi + 1.0);
			vec2 spot;
			float per = 2.0 * (rect_size.x + rect_size.y);
			float s = u * per;
			if (s < rect_size.x) { spot = vec2(s, border * 0.5); }
			else if (s < rect_size.x + rect_size.y) { spot = vec2(rect_size.x - border * 0.5, s - rect_size.x); }
			else if (s < 2.0 * rect_size.x + rect_size.y) { spot = vec2(2.0 * rect_size.x + rect_size.y - s, rect_size.y - border * 0.5); }
			else { spot = vec2(border * 0.5, per - s); }
			spot = clamp(spot, vec2(radius * 0.6), rect_size - vec2(radius * 0.6));
			float tw = pow(max(0.0, sin(t * (1.1 + hash(fi + 9.0)) + fi * 2.3)), 8.0);
			vec2 g = abs(px - spot);
			float star = max(smoothstep(1.6, 0.0, g.x) * smoothstep(11.0, 0.0, g.y),
					smoothstep(1.6, 0.0, g.y) * smoothstep(11.0, 0.0, g.x));
			col = over(vec4(1.0, 1.0, 0.94, star * tw), col);
		}
	}
	COLOR = col;
}
