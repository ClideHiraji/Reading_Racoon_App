shader_type canvas_item;
// Racoon's clothes (D-029): a top or a dress is drawn only where his body is grey fill, like his belly
// (racoon_belly_clip.gdshader), so its sides follow his outline exactly and never cover it, however he
// moves. It also shows its Closet tier (closet_item.gdshader, D-026): silver and up shine now and then,
// violet breathes, gold has glints, diamond a slow rainbow.

uniform sampler2D body_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 body_uv = vec4(0.0, 0.0, 1.0, 1.0);    // the body's rectangle on its sheet (0-1)
uniform vec4 body_rect = vec4(0.0, 0.0, 1.0, 1.0);  // the body's box, in drawing units
uniform vec3 ink = vec3(0.231, 0.176, 0.227);
uniform int tier = 0;                                // 0 copper (plain) to 4 diamond
uniform vec4 box = vec4(0.0, 0.0, 100.0, 100.0);   // the top's box, in drawing units
uniform float seed = 0.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;   // already the texture (Godot 4)
	// the clip: the clothes and his body share one transform, so a point is the same on both
	vec2 q = (local_pos - body_rect.xy) / body_rect.zw;
	float inside = step(0.0, q.x) * step(q.x, 1.0) * step(0.0, q.y) * step(q.y, 1.0);
	vec4 m = texture(body_tex, body_uv.xy + clamp(q, 0.0, 1.0) * body_uv.zw);
	float not_ink = smoothstep(0.12, 0.3, distance(m.rgb, ink));
	c.a *= m.a * not_ink * inside;
	if (tier > 0 && c.a > 0.004) {
		vec2 u = (local_pos - box.xy) / max(box.zw, vec2(1.0));
		float t = TIME + seed;
		vec3 rgb = c.rgb;
		if (tier >= 2) {
			float breathe = 0.5 + 0.5 * sin(t * 2.1);
			vec3 tint = tier == 2 ? vec3(0.95, 0.8, 1.0) : vec3(1.0, 0.93, 0.72);
			rgb += (0.03 + 0.04 * breathe) * tint;
		}
		if (tier == 4) {
			vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + u.x * 0.9 + u.y * 0.5 - t * 0.3));
			rgb = mix(rgb, rgb * 0.6 + rainbow * 0.5, 0.25);
		}
		float period = tier == 1 ? 5.0 : (tier == 2 ? 4.0 : 3.2);
		float run = mod(t, period);
		float pos = run / 0.9 * 1.7 - 0.35;
		float d = abs(u.x * 0.75 + u.y * 0.45 - pos);
		float band = run < 0.9 ? smoothstep(tier >= 3 ? 0.14 : 0.1, 0.0, d) : 0.0;
		rgb = mix(rgb, vec3(1.0), band * (tier == 1 ? 0.3 : (tier == 2 ? 0.36 : 0.48)));
		if (tier >= 3) {
			vec2 cell = floor(local_pos / 24.0);
			vec2 g = abs(fract(local_pos / 24.0) - 0.5 - (vec2(hash(cell + 1.7), hash(cell + 3.1)) - 0.5) * 0.5);
			float h = hash(cell + seed);
			float tw = pow(max(0.0, sin(t * (1.3 + h * 1.7) + h * 6.2832)), 10.0);
			float star = max(smoothstep(0.07, 0.0, g.x) * smoothstep(0.32, 0.0, g.y),
					smoothstep(0.07, 0.0, g.y) * smoothstep(0.32, 0.0, g.x));
			rgb = mix(rgb, vec3(1.0), star * tw * step(0.55, h));
		}
		c.rgb = rgb;
	}
	COLOR = c;
}
