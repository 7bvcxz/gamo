// The sky band above the horizon: gradient, sun or moon with glow, stars at
// night, and clouds drifting with the clock -- the painted cloud band when
// there is one (assets/textures/clouds.png), else two procedural layers.
// Everything is driven by uniforms the day cycle sets each frame; the shader
// keeps no time of its own beyond cloud drift and twinkle.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.15, 0.58, 0.97, 1.0);
uniform vec4 mid_color : source_color = vec4(0.27, 0.69, 0.99, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.75, 0.87, 0.99, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0);
uniform vec4 cloud_shade : source_color = vec4(0.79, 0.86, 0.95, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 moon_color : source_color = vec4(0.99, 0.93, 0.73, 1.0);
uniform vec2 sun_uv = vec2(0.62, 0.3);
uniform vec2 moon_uv = vec2(0.62, 2.0);
uniform float sun_size = 0.075;
uniform float moon_size = 0.07;
uniform float stars = 0.0;
uniform float cloud_drift = 0.0;
uniform float twinkle_time = 0.0;
uniform float aspect = 0.5;
// Painted cloud band (Step 46): r = how sunlit, a = cover; tinted by the
// time of day's cloud colours, so sunset and night still colour it.
uniform sampler2D clouds_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform float painted_clouds = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	// Width in units of height, so round things stay round on any screen.
	vec2 q = vec2(uv.x * aspect, uv.y);
	vec3 col = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.65, uv.y));
	col = mix(col, horizon_color.rgb, smoothstep(0.55, 1.0, uv.y));

	// Stars: sparse, twinkling, only above the haze near the horizon.
	if (stars > 0.01) {
		vec2 cell = floor(q * 70.0);
		float h = hash(cell);
		if (h > 0.985) {
			vec2 c = (cell + 0.5 + (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6) / 70.0;
			float d = length(q - c) * 70.0;
			float tw = 0.6 + 0.4 * sin(twinkle_time * (1.5 + h * 3.0) + h * 40.0);
			col += vec3(1.0, 0.97, 0.9) * smoothstep(0.35, 0.0, d) * tw * stars * (1.0 - smoothstep(0.55, 0.95, uv.y));
		}
	}

	// Sun (added after the clouds, so a low sun shines over the cloud bank)
	// and moon, with soft glow.
	vec2 sq = vec2(sun_uv.x * aspect, sun_uv.y);
	float ds = length(q - sq);
	vec3 sun = sun_color.rgb * (smoothstep(sun_size, sun_size * 0.92, ds) * 0.9 + exp(-ds * 9.0) * 0.35 + exp(-ds * 3.0) * 0.12);
	// Soft rays turning slowly around the sun, as in the concept art.
	float ang = atan(q.y - sq.y, q.x - sq.x);
	float rays = pow(0.5 + 0.5 * sin(ang * 9.0 + twinkle_time * 0.15), 6.0);
	sun += sun_color.rgb * rays * exp(-ds * 5.5) * smoothstep(sun_size * 0.9, sun_size * 1.6, ds) * 0.22;
	vec2 mq = vec2(moon_uv.x * aspect, moon_uv.y);
	float dm = length(q - mq);
	float moon_disc = smoothstep(moon_size, moon_size * 0.93, dm);
	float craters = vnoise((q - mq) * 38.0) * 0.18;
	col = mix(col, moon_color.rgb * (0.92 - craters), moon_disc);
	col += moon_color.rgb * exp(-dm * 10.0) * 0.25;

	if (painted_clouds > 0.5) {
		// A far, smaller and paler row first, then the near heaps standing on
		// the horizon haze; both drift slowly with the clock.
		// Clouds thin out at night (stars = how much night it is).
		float cover = mix(1.0, 0.5, stars);
		vec2 far_uv = vec2(q.x * 1.5 - cloud_drift * 0.05 + 0.41, (uv.y - 0.3) / 0.46);
		if (far_uv.y > 0.0 && far_uv.y < 1.0) {
			vec4 c = texture(clouds_tex, far_uv);
			vec3 cc = mix(cloud_shade.rgb, cloud_color.rgb, c.r);
			col = mix(col, mix(cc, horizon_color.rgb, 0.4), c.a * 0.45 * cover);
		}
		vec2 near_uv = vec2(q.x * 0.9 + cloud_drift * 0.12, (uv.y - 0.4) / 0.6);
		if (near_uv.y > 0.0 && near_uv.y < 1.0) {
			vec4 c = texture(clouds_tex, near_uv);
			vec3 cc = mix(cloud_shade.rgb, cloud_color.rgb, c.r);
			col = mix(col, cc, c.a * 0.96 * cover);
		}
		col = mix(col, horizon_color.rgb, smoothstep(0.9, 1.0, uv.y) * 0.5);
	} else {
	// Clouds: a thick low bank near the horizon and thin high wisps.
	// Cumulus heaps sitting above the horizon with blue between them: the band's
	// top edge is lifted by a second noise, so the clouds rise in mounds.
	vec2 cp = vec2(q.x * 2.6 + cloud_drift, uv.y * 4.5);
	float lift = vnoise(vec2(q.x * 3.0 + cloud_drift * 0.8, 3.0)) * 0.3;
	float low = fbm(cp + vec2(0.0, 1.7)) * smoothstep(0.42 - lift, 0.7 - lift, uv.y) * (1.0 - smoothstep(0.96, 1.0, uv.y));
	float lowmask = smoothstep(0.4, 0.52, low);
	vec2 hp = vec2(q.x * 1.2 + cloud_drift * 0.6, uv.y * 2.5);
	float high = fbm(hp * vec2(1.0, 3.0) + vec2(5.3, 0.0)) * (1.0 - smoothstep(0.2, 0.55, uv.y));
	float highmask = smoothstep(0.56, 0.76, high) * 0.5;
	float shade = smoothstep(0.52, 0.4, low);
	vec3 cloud = mix(cloud_color.rgb, cloud_shade.rgb, shade * 0.6);
	col = mix(col, cloud, lowmask * 0.92);
	col = mix(col, cloud_color.rgb, highmask);
	}

	col += sun;
	COLOR = vec4(col, 1.0);
}
