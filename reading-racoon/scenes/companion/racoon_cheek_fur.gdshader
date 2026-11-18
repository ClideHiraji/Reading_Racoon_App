shader_type canvas_item;
// The little tufts of fur low on Racoon's cheeks (D-024) sway. Each turns a little about its root,
// most at its tip and fading to nothing a short way off, so the rest of his head keeps still.
// racoon_puppet.gd drives the two angles with springs: the tufts flick behind quick turns and
// hops, droop as he lands, and stir a little on their own. The head and its outline are a fine
// mesh round the tufts, so they bend smoothly.

uniform vec2 tip_l = vec2(90.0, 199.0);
uniform vec2 root_l = vec2(101.0, 202.0);
uniform float ang_l = 0.0;
uniform vec2 tip_r = vec2(311.0, 195.0);
uniform vec2 root_r = vec2(300.0, 198.0);
uniform float ang_r = 0.0;
uniform float reach = 20.0;   // drawing units from a tip where the bend fades out

vec2 bend(vec2 v, vec2 root, vec2 tip, float a) {
	float w = 1.0 - smoothstep(reach * 0.3, reach, distance(v, tip));
	float t = a * w;
	vec2 d = v - root;
	return root + vec2(cos(t) * d.x - sin(t) * d.y, sin(t) * d.x + cos(t) * d.y);
}

void vertex() {
	VERTEX = bend(VERTEX, root_l, tip_l, ang_l);
	VERTEX = bend(VERTEX, root_r, tip_r, ang_r);
}
