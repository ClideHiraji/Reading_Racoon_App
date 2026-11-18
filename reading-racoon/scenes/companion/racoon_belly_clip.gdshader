shader_type canvas_item;
// Racoon's belly (D-024) is drawn only where his body is grey fill, so its white never covers the
// body's ink outline, however far he turns. The body's own texture is the mask: where it's
// see-through (outside him) or ink (the outline), the belly isn't drawn.

uniform sampler2D body_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 body_uv = vec4(0.0, 0.0, 1.0, 1.0);    // the body's rectangle on its sheet (0-1)
uniform vec4 body_rect = vec4(0.0, 0.0, 1.0, 1.0);  // the body's box, in drawing units
uniform vec2 to_body_x = vec2(1.0, 0.0);            // a belly point -> the body's drawing units
uniform vec2 to_body_y = vec2(0.0, 1.0);
uniform vec2 to_body_o = vec2(0.0, 0.0);
uniform vec3 ink = vec3(0.231, 0.176, 0.227);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// COLOR already holds the texture (Godot 4 multiplies it in before fragment())
	vec2 b = to_body_x * local_pos.x + to_body_y * local_pos.y + to_body_o;
	vec2 q = (b - body_rect.xy) / body_rect.zw;
	float inside = step(0.0, q.x) * step(q.x, 1.0) * step(0.0, q.y) * step(q.y, 1.0);
	vec4 m = texture(body_tex, body_uv.xy + clamp(q, 0.0, 1.0) * body_uv.zw);
	float not_ink = smoothstep(0.12, 0.3, distance(m.rgb, ink));
	COLOR.a *= m.a * not_ink * inside;
}
