shader_type canvas_item;
render_mode skip_vertex_transform;

// Safe Cracker's door swing (#41): turns every vertex of the door and its dial about the hinge
// line toward the viewer and projects it in perspective, so the far edge sweeps in and grows
// taller and the door's thickness shows. Only `angle` changes while the door opens (a uniform,
// never a redraw). At 0 every vertex passes straight through.
//
// UV.x * thickness is a vertex's depth into the safe: the door's own mesh (SafeMesh.depth)
// marks the back of its far edge with 1. Pieces with UVs of their own (text) use a material
// with thickness 0.

uniform float angle = 0.0;  // radians, toward the viewer
uniform float hinge_x = 0.0;  // the hinge line, canvas x
uniform vec2 eye = vec2(0.0);  // the canvas point the viewer looks straight at
uniform float focal = 3400.0;  // the viewer's distance, px
uniform float thickness = 0.0;

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (angle > 0.0) {
		float u = w.x - hinge_x;
		float z = -UV.x * thickness;
		float c = cos(angle);
		float s = sin(angle);
		float x = hinge_x + u * c - z * s;
		float depth = u * s + z * c;
		w = eye + (vec2(x, w.y) - eye) * (focal / (focal - depth));
	}
	VERTEX = w;
}
