shader_type canvas_item;

// Step 42: a belt's chevrons, pointing to where the goods go (the glass tube, or along the
// packing line). The rectangle is drawn once; only `phase` (pixels moved) changes, and only
// while a machine on that line runs -- so a stopped line stops and reduced motion holds it.
uniform float phase = 0.0;
uniform float spacing = 14.0;
uniform float height = 5.0;
uniform vec4 ink : source_color = vec4(0.22, 0.22, 0.27, 0.55);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float y = abs(local.y - height * 0.5);
	float m = mod(local.x - phase + y * 0.9, spacing);
	float a = smoothstep(0.0, 1.2, m) * (1.0 - smoothstep(2.4, 3.6, m));
	COLOR = vec4(ink.rgb, ink.a * a);
}
