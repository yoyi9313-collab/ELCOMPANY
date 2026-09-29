shader_type spatial;
render_mode unshaded;
uniform vec4 uniform_color : source_color = vec4(0.35, 0.39, 0.34, 1.0);
uniform sampler2D albedo_texture : source_color;
uniform bool use_texture = false;
void fragment() {
	// Stable, soft directional shading for the textureless FBX surfaces.
	float light = 0.68 + 0.32 * max(dot(normalize(NORMAL), normalize(vec3(-0.5, 0.8, 0.6))), 0.0);
	ALBEDO = uniform_color.rgb * light * (use_texture ? texture(albedo_texture, UV).rgb : vec3(1.0));
}
