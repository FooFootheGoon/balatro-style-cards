shader_type canvas_item;

uniform vec2 tilt = vec2(0.0, 0.0); // x=pitch, y=yaw (radians)
uniform float perspective = 0.35;   // 0.0..1.0 (bigger = stronger perspective)
uniform float shade_strength = 0.12;
uniform float feather = 0.035;      // 0.02..0.06 (bigger = softer edge)

void fragment() {
	vec2 p = UV * 2.0 - 1.0;     // -1..1
	vec3 v = vec3(p, 1.0);       // pretend the card is a plane at z=1

	float ax = tilt.x;
	float ay = tilt.y;

	// Yaw (rotate around Y axis)
	float cy = cos(ay);
	float sy = sin(ay);
	v = vec3(v.x * cy + v.z * sy, v.y, -v.x * sy + v.z * cy);

	// Pitch (rotate around X axis)
	float cx = cos(ax);
	float sx = sin(ax);
	v = vec3(v.x, v.y * cx - v.z * sx, v.y * sx + v.z * cx);

	// Perspective divide
	float inv = 1.0 / (1.0 + (v.z - 1.0) * perspective);
	vec2 q = v.xy * inv;

	// Project back into UV space
	vec2 uv2 = (q + 1.0) * 0.5;

	// Clamp for safe sampling (prevents wrap/garbage)
	vec2 uv_clamped = clamp(uv2, vec2(0.0), vec2(1.0));

	// How far outside [0..1] did we go?
	float out_x = max(-uv2.x, uv2.x - 1.0);
	float out_y = max(-uv2.y, uv2.y - 1.0);
	float out_amt = max(out_x, out_y);

	// Fade alpha as we go out-of-bounds (no discard)
	float mask = 1.0 - smoothstep(0.0, feather, out_amt);

	vec4 col = texture(TEXTURE, uv_clamped);

	// Subtle shading based on "depth" change from tilt
	float sh = 1.0 - abs(v.z - 1.0) * shade_strength;
	col.rgb *= clamp(sh, 0.75, 1.0);

	col.a *= mask;

	COLOR = col;
}
