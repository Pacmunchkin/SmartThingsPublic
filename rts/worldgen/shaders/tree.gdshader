shader_type canvas_item;

// Canopy instances. One MultiMesh, one draw call, a few thousand trunks.
//
// The atlas is generated in code (TextureBaker.bake_tree_atlas) and holds
// three species side by side. Per-instance INSTANCE_CUSTOM carries:
//   x  species frame, 0..2
//   y  hue jitter, 0..1
//   z  a stable per-tree random, 0..1, used for sway phase
//   w  unused
//
// Instance data is only readable in the vertex stage, so everything the
// fragment stage needs is forwarded through varyings. The frame index is flat
// because interpolating it across the quad would blend two species together
// at the seam of the atlas.
//
// The instance tint arrives as COLOR, which the generator sets from canopy
// density so trees in a deep wood sit darker than the ones on a field edge.

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform float frames = 3.0;
uniform float sway_strength = 0.010;
uniform float sway_speed = 0.85;
uniform vec3 autumn_tint = vec3(0.62, 0.48, 0.20);
uniform float autumn_amount = 0.22;
uniform float shadow_alpha = 0.28;
uniform vec2 shadow_offset = vec2(0.10, 0.075);

varying flat float v_frame;
varying float v_jitter;
varying vec4 v_tint;

void vertex() {
	v_frame = clamp(floor(INSTANCE_CUSTOM.x + 0.5), 0.0, frames - 1.0);
	v_jitter = INSTANCE_CUSTOM.y;
	v_tint = COLOR;

	// Sway the top of the quad only, so the trunk stays planted.
	float phase = INSTANCE_CUSTOM.z * 6.28318;
	float top = 1.0 - UV.y;
	VERTEX.x += sin(TIME * sway_speed + phase) * sway_strength * top * 64.0;
}

void fragment() {
	float frame = v_frame;

	// Sample the instance's frame out of the horizontal atlas.
	vec2 frame_uv = vec2((UV.x + frame) / frames, UV.y);
	vec4 canopy = texture(atlas, frame_uv);

	// Ground shadow: the same silhouette, offset, flattened and darkened.
	// Sampled before the discard so a tree still casts where its own texel is
	// transparent.
	vec2 shadow_uv = UV - shadow_offset;
	shadow_uv.y = shadow_uv.y * 1.25;
	float shadow = 0.0;
	if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0
			&& shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0) {
		shadow = texture(atlas, vec2((shadow_uv.x + frame) / frames, shadow_uv.y)).a;
	}

	if (canopy.a < 0.02 && shadow < 0.02) {
		discard;
	}

	// Species and per-tree hue variation, plus a scatter of autumn crowns so
	// the wood is not one flat green.
	vec3 leaf = canopy.rgb;
	float autumn = step(0.86, v_jitter) * autumn_amount;
	leaf = mix(leaf, autumn_tint * (0.6 + 0.8 * canopy.g), autumn);
	leaf *= mix(0.88, 1.14, v_jitter);
	leaf *= v_tint.rgb;

	// Composite the canopy over its own shadow.
	vec3 shadow_colour = vec3(0.06, 0.08, 0.05);
	float shadow_mask = shadow * shadow_alpha * (1.0 - canopy.a);
	vec3 result = leaf * canopy.a + shadow_colour * shadow_mask;
	float alpha = canopy.a + shadow_mask;

	COLOR = vec4(result / max(alpha, 0.0001), alpha * v_tint.a);
}
