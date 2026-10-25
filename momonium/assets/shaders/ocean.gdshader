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
	col += glint_color.rgb * sun_strength * (glint * 0.5 + column * 0.3 * (0.4 + n));

	// Foam: a bright line at the waterline and soft rings travelling outward.
	float band = smoothstep(0.05, 0.25, shore) * (1.0 - smoothstep(0.38, 0.46, shore));
	float rings = 0.5 + 0.5 * sin(shore * 26.0 - time_s * 1.8 + n * 3.0);
	float foam = band * smoothstep(0.7, 0.95, rings) * 0.45;
	foam += smoothstep(0.4, 0.5, shore) * 0.9;
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 1.0) * 0.85);

	COLOR = vec4(col, 1.0);
}
