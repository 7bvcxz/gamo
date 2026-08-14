shader_type canvas_item;

// The grade over the whole scene: a vignette that closes in as the situation
// gets worse, and a cold cast at the top of the frame.
//
// Deliberately an overlay and nothing else. It never reads SCREEN_TEXTURE, which
// on WebGL means a framebuffer copy every frame -- the same class of cost that
// forced the cold fog to be baked into a texture when it was pinning the
// software build near 15 fps. That rules out bloom, which needs the frame back.
// A factory game is looked at for hours; a frame that always holds is worth more
// than a glow that costs a copy.
//
// Measured, three runs each, on a software rasteriser (the pessimistic case --
// on any real GPU a full-screen blend is free): 15.6 fps without, 14.2 with.
// The cost is filling the pixels, not the arithmetic: a first version with
// per-pixel grain measured the same as this one without it. So the shape of the
// effect was chosen to be worth that fill rather than to be cheap, since cheaper
// was not on offer.
//
// The first attempt also laid a pale wash over the middle of the frame, which
// lightened the scene and made the warm pool at the core read as less warm --
// paying the fill cost to make the picture worse. The centre is untouched now:
// everything happens at the edges.

// 0 morning, 1 deep night.
uniform float night : hint_range(0.0, 1.0) = 0.0;
// How far the corners close in. Driven by night and by how cold the player is.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
// What the edges darken toward. Not black: the corners should stay part of this
// world rather than reading as a hole cut in it.
uniform vec3 edge_tint : source_color = vec3(0.05, 0.07, 0.13);
// The cold sitting along the top of the frame, which is what gives a flat
// top-down scene any sense of there being an up.
uniform vec3 sky_tint : source_color = vec3(0.42, 0.55, 0.86);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centred = uv - vec2(0.5);
	// Corrected for aspect so the vignette is round on a wide screen instead of
	// being an oval that hugs the left and right edges.
	centred.x *= 1.35;

	// Squared distance rather than length(): no sqrt, and the falloff is nicer.
	float d2 = dot(centred, centred) * 2.2;
	float vig = smoothstep(0.30, 1.30, d2) * vignette_strength;

	// A cold band across the top, strongest at night, fading out well before the
	// middle so it never touches the part of the screen being played in.
	float sky = smoothstep(0.34, 0.0, uv.y) * (0.06 + night * 0.16);

	float alpha = vig + sky;
	COLOR = vec4(mix(sky_tint, edge_tint, vig / max(alpha, 0.001)), alpha);
}
