shader_type canvas_item;
// Racoon's face parts (brows, mask, eyes, blush) show only where his head is (D-024): the head's
// alpha on the sheet (racoon_atlas.svg) is the mask. head_rect is the head part's box in drawing
// units; head_uv is where it is on the sheet (0-1).
uniform sampler2D head_mask : filter_linear_mipmap, repeat_disable;
uniform vec4 head_rect;
uniform vec4 head_uv = vec4(0.0, 0.0, 1.0, 1.0);
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// COLOR already holds the texture (Godot 4 multiplies it in before fragment())
	vec2 q = (local_pos - head_rect.xy) / head_rect.zw;
	float inside = step(0.0, q.x) * step(q.x, 1.0) * step(0.0, q.y) * step(q.y, 1.0);
	COLOR.a *= texture(head_mask, head_uv.xy + clamp(q, 0.0, 1.0) * head_uv.zw).a * inside;
}
