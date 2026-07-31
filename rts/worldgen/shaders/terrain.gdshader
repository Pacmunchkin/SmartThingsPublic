shader_type canvas_item;

// Ground for the generated valley.
//
// Reads two data textures baked from the world grid (see texture_baker.gd) and
// derives everything else procedurally - there are no art assets in this
// shader. Layer order matches the generation order, which makes it easy to
// reason about: rock and soil first, then canopy shade, then the things people
// made, then water on top of all of it.

uniform sampler2D field_map : filter_linear, repeat_disable;  // R height G slope B water A river distance
uniform sampler2D cover_map : filter_linear, repeat_disable;  // R road G settled B canopy A cliff

uniform vec2 map_size = vec2(1080.0, 1920.0);
uniform vec2 grid_size = vec2(180.0, 320.0);
uniform float time_scale = 1.0;

// Sun for the hillshade. Azimuth is measured the same way the rest of the
// project measures angles: 0 = +X, 270 = up the screen.
uniform float sun_azimuth_deg = 315.0;
uniform float sun_elevation = 0.62;
uniform float relief_strength = 0.85;

uniform vec3 rock_colour     = vec3(0.44, 0.42, 0.40);
uniform vec3 scree_colour    = vec3(0.53, 0.50, 0.45);
uniform vec3 heath_colour    = vec3(0.36, 0.36, 0.24);
uniform vec3 meadow_colour   = vec3(0.34, 0.44, 0.22);
uniform vec3 valley_colour   = vec3(0.28, 0.40, 0.20);
uniform vec3 shingle_colour  = vec3(0.56, 0.53, 0.46);
uniform vec3 road_colour     = vec3(0.48, 0.41, 0.31);
uniform vec3 tilled_colour   = vec3(0.42, 0.35, 0.24);
uniform vec3 water_shallow   = vec3(0.28, 0.42, 0.44);
uniform vec3 water_deep      = vec3(0.10, 0.20, 0.29);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < octaves; i++) {
		total += value_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 uv = UV;
	vec2 world_px = uv * map_size;
	vec4 field = texture(field_map, uv);
	vec4 cover = texture(cover_map, uv);

	float height = field.r;
	float slope = field.g;
	float water = field.b;
	float river_distance = field.a;

	float road = cover.r;
	float settled = cover.g;
	float canopy = cover.b;
	float cliff = cover.a;

	// --- relief -------------------------------------------------------------
	// Gradient from the height channel. Sampling a texel apart keeps the
	// hillshade tied to the generated grid rather than to screen resolution.
	vec2 texel = 1.0 / grid_size;
	float hx = texture(field_map, uv + vec2(texel.x, 0.0)).r
			 - texture(field_map, uv - vec2(texel.x, 0.0)).r;
	float hy = texture(field_map, uv + vec2(0.0, texel.y)).r
			 - texture(field_map, uv - vec2(0.0, texel.y)).r;
	vec3 normal = normalize(vec3(-hx * relief_strength * 40.0,
								 -hy * relief_strength * 40.0, 1.0));
	float azimuth = radians(sun_azimuth_deg);
	vec3 sun = normalize(vec3(cos(azimuth), sin(azimuth), sun_elevation));
	float lambert = clamp(dot(normal, sun), 0.0, 1.0);
	// Sky light from straight up, so shadowed faces stay readable.
	float ambient = 0.55 + 0.16 * normal.z;
	float shade = ambient + 0.58 * lambert;

	// --- soil ---------------------------------------------------------------
	float grain = fbm(world_px * 0.035, 4);
	float coarse = fbm(world_px * 0.008, 3);

	// Hypsometric tint: valley floor through meadow and heath to bare rock.
	vec3 ground = mix(valley_colour, meadow_colour, smoothstep(0.20, 0.38, height));
	ground = mix(ground, heath_colour, smoothstep(0.38, 0.58, height));
	ground = mix(ground, scree_colour, smoothstep(0.58, 0.76, height));
	ground = mix(ground, rock_colour, smoothstep(0.72, 0.90, height));
	ground *= 0.88 + 0.24 * coarse;

	// Steep ground goes bare regardless of how high it is.
	float bareness = smoothstep(0.46, 0.78, slope);
	ground = mix(ground, rock_colour * (0.9 + 0.3 * grain), bareness);

	// Cliff faces get horizontal strata, banded on height so the bands follow
	// the contour rather than the screen. Blended rather than branched: the
	// cliff mask is a filtered 8-bit channel over 6 px cells, so a hard cutoff
	// leaves a stair-stepped outline along every rock face.
	float rock_face = smoothstep(0.35, 0.75, cliff);
	float strata = 0.5 + 0.5 * sin(height * 46.0 + fbm(world_px * 0.015, 2) * 9.0);
	vec3 cliff_colour = mix(rock_colour * 0.78, scree_colour * 1.12, strata * 0.7 + 0.15);
	cliff_colour *= 0.86 + 0.28 * grain;
	ground = mix(ground, cliff_colour, rock_face);

	// Shingle where the river has scoured the bank.
	float bank = 1.0 - smoothstep(0.02, 0.075, river_distance);
	ground = mix(ground, shingle_colour * (0.85 + 0.3 * grain), bank * 0.7);

	// --- canopy shade -------------------------------------------------------
	// The trees themselves are instanced on top; this is the light they steal.
	float shade_under_wood = canopy * 0.55;
	ground = mix(ground, ground * vec3(0.55, 0.62, 0.50), shade_under_wood);

	// --- what people made ---------------------------------------------------
	// Fields: tilled earth with faint ridge and furrow, aligned to a coarse
	// noise direction so neighbouring fields are not all ploughed the same way.
	float field_angle = fbm(world_px * 0.0016, 2) * 6.28318;
	vec2 furrow_dir = vec2(cos(field_angle), sin(field_angle));
	float furrows = sin(dot(world_px, furrow_dir) * 0.42);
	float tilled = smoothstep(0.20, 0.55, settled);
	vec3 field_ground = tilled_colour * (0.92 + 0.10 * furrows + 0.16 * grain);
	ground = mix(ground, field_ground, tilled * 0.75);

	// Village core: trodden ground, no furrows.
	float core = smoothstep(0.65, 1.0, settled);
	ground = mix(ground, tilled_colour * (1.06 + 0.12 * grain), core * 0.7);

	// Roads: worn earth with a soft edge and cart ruts down the middle.
	float road_edge = smoothstep(0.30, 0.82, road);
	float ruts = 0.5 + 0.5 * sin(fbm(world_px * 0.05, 2) * 12.0);
	vec3 metalled = road_colour * (0.94 + 0.14 * ruts + 0.12 * grain);
	ground = mix(ground, metalled, road_edge * 0.88);

	vec3 colour = ground * shade;

	// --- water --------------------------------------------------------------
	// Drawn last and over everything, including the road, so a ford reads as a
	// road going into the water rather than water with a stripe across it.
	if (water > 0.001) {
		float depth = clamp(water * 1.6, 0.0, 1.0);
		vec3 river = mix(water_shallow, water_deep, depth);

		float t = TIME * time_scale;
		// Two ripple fields drifting downstream at different rates.
		float ripple = fbm(world_px * 0.05 + vec2(0.0, -t * 1.6), 3)
					 + fbm(world_px * 0.11 + vec2(t * 0.4, -t * 2.4), 2) * 0.5;
		river += (ripple - 0.75) * 0.10 * (1.0 - depth * 0.6);

		// Specular glitter on the surface, strongest where it is shallow and
		// moving over the bed.
		float glint = pow(clamp(ripple - 0.62, 0.0, 1.0) * 2.6, 3.0);
		river += glint * 0.30 * (1.0 - depth * 0.5);

		// Foam against the bank and wherever the channel narrows.
		float shore = 1.0 - smoothstep(0.0, 0.30, depth);
		float foam = shore * (0.35 + 0.65 * step(0.72, ripple));
		river = mix(river, vec3(0.82, 0.86, 0.86), foam * 0.35);

		// Bed shows through the shallows.
		river = mix(ground * 0.75, river, clamp(0.35 + depth, 0.0, 1.0));

		float water_mask = smoothstep(0.0, 0.06, water);
		colour = mix(colour, river * (0.86 + 0.24 * shade), water_mask);
	}

	// Very slight vignette to settle the edges of the map.
	float vignette = 1.0 - 0.18 * pow(length(uv - 0.5) * 1.35, 2.5);
	COLOR = vec4(colour * vignette, 1.0);
}
