// The whole sea in one screen-space pass: endless, anchored to the world.
//
// Each pixel below the horizon is mapped back to a logical point on the water
// plane (through the inverse camera transform and the inverse tile
// projection), so waves, glints and foam stay put on the ground while the
// camera moves -- and since the pattern is procedural noise, not a tiled
// texture, there is no seam and no visible repeat anywhere. The coast comes
// from one small "shore field" texture (1 on land, falling to 0 a tile or two
// out), so the same cost covers a 2x2 islet or a thousand-cell island.
shader_type canvas_item;
render_mode unshaded;

uniform vec2 inv_x = vec2(1.0, 0.0);
uniform vec2 inv_y = vec2(0.0, 1.0);
uniform vec2 inv_o = vec2(0.0);
uniform float horizon_y = 400.0;
uniform vec2 screen_size = vec2(720.0, 1280.0);
uniform vec2 half_tile = vec2(64.0, 49.0);
uniform float water_drop = 36.0;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec4 field_rect = vec4(-4.0, -4.0, 10.0, 10.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.62, 0.88, 1.0);
uniform vec4 mid_color : source_color = vec4(0.18, 0.71, 0.97, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.17, 0.84, 0.86, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.41, 0.72, 0.99, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 1.0, 0.95, 1.0);
uniform vec2 sun_screen = vec2(450.0, 300.0);
uniform float sun_strength = 1.0;
uniform float quality = 1.0;
uniform float time_s = 0.0;

varying vec2 screen_pos;

void vertex() {
	screen_pos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(17.13, 3.71)));
}

// Distance to the nearest cell edge of a Voronoi pattern (F2 - F1): thin
// bright lines where cells meet, the net of light the concept's water wears.
// Only the 2x2 cells nearest the point are read, with their seeds kept near
// the cell centres so the two nearest are always among them -- a quarter of
// the full 3x3 search's cost (it is drawn over most of the screen).
float caustic(vec2 p) {
	vec2 b = floor(p - 0.5);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = 0; y <= 1; y++) {
		for (int x = 0; x <= 1; x++) {
			vec2 cell = b + vec2(float(x), float(y));
			vec2 c = cell + 0.5 + (hash2(cell) - 0.5) * 0.5 - p;
			float d = dot(c, c);
			d2 = d < d1 ? d1 : min(d2, d);
			d1 = min(d1, d);
		}
	}
	return sqrt(d2) - sqrt(d1);
}

// Step 52: the concept's sparkles -- four-pointed stars scattered over the
// sea, each twinkling on its own beat. One star per cell at most, and one
// hash per pixel: where it sits and how big it is come from the same number.
float sparkle(vec2 p, float t) {
	vec2 i = floor(p);
	float h = hash(i);
	if (h < 0.5) {
		return 0.0;
	}
	vec2 d = abs(fract(p) - 0.5 - (vec2(fract(h * 13.7), fract(h * 91.3)) - 0.5) * 0.5);
	// A triangle wave for the twinkle and straight falloffs for the arms:
	// the same star as smoothsteps and a sine, at a fraction of the cost.
	float beat = abs(fract(t * (0.25 + 0.3 * h) + h * 7.0) * 2.0 - 1.0);
	float size = 0.14 + 0.24 * fract(h * 7.1);
	vec2 arm = clamp(1.0 - d / size, 0.0, 1.0) * clamp(1.0 - d.yx / 0.035, 0.0, 1.0);
	float core = clamp(1.0 - (d.x + d.y) / 0.09, 0.0, 1.0);
	return (max(arm.x, arm.y) + core) * beat * beat;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	if (screen_pos.y < horizon_y) {
		discard;
	}
	vec2 world = inv_x * screen_pos.x + inv_y * screen_pos.y + inv_o;
	// A point on the water plane is drawn `water_drop` lower than the same
	// logical point on the grass, so undo that before inverting the projection.
	vec2 w = vec2(world.x, world.y - water_drop);
	vec2 logical = vec2((w.x / half_tile.x + w.y / half_tile.y) * 0.5, (w.y / half_tile.y - w.x / half_tile.x) * 0.5);
	// 0 at the horizon, 1 at the bottom of the screen: distance from the eye.
	float t = clamp((screen_pos.y - horizon_y) / max(screen_size.y - horizon_y, 1.0), 0.0, 1.0);

	vec2 fuv = (logical - field_rect.xy) / field_rect.zw;
	float shore = 0.0;
	if (fuv.x >= 0.0 && fuv.y >= 0.0 && fuv.x <= 1.0 && fuv.y <= 1.0) {
		shore = texture(shore_field, fuv).r;
	}

	vec3 col = mix(horizon_color.rgb, mix(mid_color.rgb, deep_color.rgb, t), smoothstep(0.0, 0.3, t));
	col = mix(col, shallow_color.rgb, smoothstep(0.02, 0.5, shore));

	vec2 p = logical * 1.4;
	float n = vnoise(p + vec2(time_s * 0.13, time_s * 0.06)) * 0.6
		+ vnoise(p * 2.3 - vec2(time_s * 0.09, -time_s * 0.08)) * 0.4;
	if (quality > 0.5) {
		n = n * 0.75 + vnoise(p * 5.3 + vec2(time_s * 0.21)) * 0.25;
	}
	// Gentle swell: brightness rolling across the water, stronger up close.
	col += (n - 0.5) * 0.09 * (0.35 + t);

	// Sun glitter: small sparse points that wink in and out, and a reflected
	// column under the sun.
	float g = vnoise(p * 22.0 + vec2(time_s * 1.3, -time_s * 0.9)) * vnoise(p * 9.0 - vec2(time_s * 0.4));
	float glint = smoothstep(0.62, 0.8, g) * (0.25 + 0.75 * t);
	float dx = (screen_pos.x - sun_screen.x) / screen_size.x;
	float column = exp(-dx * dx * 45.0) * (1.0 - 0.6 * t);
	// Under a low sun the column carries the glitter: a path of light (concepts).
	glint *= 1.0 + column * 2.5 * max(sun_strength - 1.0, 0.0);
	col += glint_color.rgb * sun_strength * (glint * 0.5 + column * 0.22 * (0.4 + n));

	// The net of light on the water, brightest in the shallows (concepts).
	// Sunlight draws it: it fades with the water's own brightness, so the
	// night sea is not crazed with white lines -- and is not computed at all
	// when it would not show (it is the sea's most expensive term).
	float daylight = smoothstep(0.25, 0.6, dot(mid_color.rgb, vec3(0.3, 0.5, 0.2)));
	if (quality > 0.5 && daylight > 0.01) {
		// Warped by the swell's own noise: organic cells, not a mesh.
		float edge = caustic(logical * 2.2 + vec2(time_s * 0.05, time_s * 0.03) + vec2(n - 0.5, 0.5 - n) * 1.1);
		// Deeper blue inside the cells, white where they meet.
		col = mix(col, deep_color.rgb * 0.92, smoothstep(0.25, 0.7, edge) * 0.22 * (0.3 + 0.7 * t) * daylight);
		float net = smoothstep(0.15, 0.02, edge) * (0.2 + 0.45 * smoothstep(0.0, 0.4, shore)) * (0.35 + 0.65 * t);
		col = mix(col, foam_color.rgb, net * daylight);
	}
	// Sparkles. Up close a tile covers more of the screen, so the cells there
	// are smaller -- a star stays a few pixels wide from the horizon to the
	// bottom edge instead of growing into a streak. Fewer and dimmer at night.
	vec2 sp = vec2(logical.x - logical.y, (logical.x + logical.y) * 0.55) * (2.4 + 5.0 * t);
	col += glint_color.rgb * sparkle(sp, time_s) * (0.45 + 0.75 * daylight) * sun_strength * (1.0 - smoothstep(0.3, 0.5, shore));

	// Foam: a bright line at the waterline and soft rings travelling outward.
	float band = smoothstep(0.05, 0.25, shore) * (1.0 - smoothstep(0.38, 0.46, shore));
	float rings = 0.5 + 0.5 * sin(shore * 26.0 - time_s * 1.8 + n * 3.0);
	float foam = band * smoothstep(0.7, 0.95, rings) * 0.45;
	foam += smoothstep(0.4, 0.5, shore) * 0.9;
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 1.0) * 0.85);

	COLOR = vec4(col, 1.0);
}
