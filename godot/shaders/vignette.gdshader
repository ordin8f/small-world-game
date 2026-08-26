shader_type canvas_item;
// Port of index.html's #lens-overlay (styles.css:34-41): a radial
// vignette plus a warmth-tinted gradient (warm top / cool bottom),
// driven by EmotionalLens.get_visuals()'s vignette/warmth values.

uniform float vignette_amount : hint_range(0.0, 1.0) = 0.28;
uniform float warmth : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;
	float edge = smoothstep(0.38, 1.0, dist);

	vec3 dark = vec3(6.0, 9.0, 13.0) / 255.0;
	vec3 warm_tint = vec3(255.0, 170.0, 80.0) / 255.0;
	vec3 cool_tint = vec3(30.0, 50.0, 72.0) / 255.0;

	float warm_alpha = warmth * 0.04 * (1.0 - UV.y);
	float cool_alpha = (1.0 - warmth) * 0.08 * UV.y;
	float vignette_alpha = edge * vignette_amount;

	vec3 color = dark * vignette_alpha + warm_tint * warm_alpha + cool_tint * cool_alpha;
	float total_alpha = clamp(vignette_alpha + warm_alpha + cool_alpha, 0.0, 1.0);
	COLOR = vec4(color, total_alpha);
}
