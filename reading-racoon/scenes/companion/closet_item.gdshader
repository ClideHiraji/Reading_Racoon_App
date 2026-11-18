shader_type canvas_item;
// A Closet item's tier, shown while Racoon wears it (D-026, FR-07). Each tier adds to the one before:
//   0 copper   plain (this shader isn't used)
//   1 silver   a shine that sweeps across now and then
//   2 violet   + a soft glow that breathes, the shine more often
//   3 gold     + a brighter, wider gleam and little glints that twinkle on it
//   4 diamond  + a rainbow that drifts across it
// Nothing flashes fast or fills the screen: the effects stay on the item, slow and soft.

uniform int tier = 1;
uniform vec4 box = vec4(0.0, 0.0, 100.0, 100.0);   // the item's box, in drawing units
uniform float seed = 0.0;                            // so two items don't shine in step

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;   // already the texture times the vertex colour (Godot 4)
	if (tier > 0 && c.a > 0.004) {
		vec2 q = (local_pos - box.xy) / max(box.zw, vec2(1.0));
		float t = TIME + seed;
		vec3 rgb = c.rgb;
		if (tier >= 2) {
			float breathe = 0.5 + 0.5 * sin(t * 2.1);
			vec3 tint = tier == 2 ? vec3(0.95, 0.8, 1.0) : vec3(1.0, 0.93, 0.72);
			rgb += (0.04 + 0.05 * breathe) * tint;
		}
		if (tier == 4) {
			vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + q.x * 0.9 + q.y * 0.5 - t * 0.3));
			rgb = mix(rgb, rgb * 0.6 + rainbow * 0.5, 0.3);
		}
		// the shine: a slanted band of light crosses the item in 0.9 s, then rests
		float period = tier == 1 ? 5.0 : (tier == 2 ? 4.0 : 3.2);
		float run = mod(t, period);
		float pos = run / 0.9 * 1.7 - 0.35;
		float d = abs(q.x * 0.75 + q.y * 0.45 - pos);
		float width = tier >= 3 ? 0.14 : 0.1;
		float band = run < 0.9 ? smoothstep(width, 0.0, d) : 0.0;
		float strength = tier == 1 ? 0.42 : (tier == 2 ? 0.48 : 0.62);
		rgb = mix(rgb, vec3(1.0), band * strength);
		if (tier >= 3) {
			// glints: a few little four-point stars that come and go on the item
			vec2 cell = floor(local_pos / 24.0);
			vec2 f = fract(local_pos / 24.0) - 0.5;
			float h = hash(cell + seed);
			vec2 o = (vec2(hash(cell + 1.7), hash(cell + 3.1)) - 0.5) * 0.5;
			vec2 g = abs(f - o);
			float tw = pow(max(0.0, sin(t * (1.3 + h * 1.7) + h * 6.2832)), 10.0);
			float star = max(smoothstep(0.07, 0.0, g.x) * smoothstep(0.32, 0.0, g.y),
					smoothstep(0.07, 0.0, g.y) * smoothstep(0.32, 0.0, g.x));
			rgb = mix(rgb, vec3(1.0), star * tw * step(0.55, h));
		}
		c.rgb = rgb;
	}
	COLOR = c;
}
