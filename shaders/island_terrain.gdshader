shader_type spatial;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap;
uniform sampler2D sand_texture : source_color, filter_linear_mipmap;
uniform float texture_scale = 0.02;
uniform float texture_blur = 5.0;

varying float blend_factor;
varying float sand_mix;

void vertex() {
	// Pass the red channel of vertex color to fragment shader
	// 0.0 = grass, 1.0 = ground
	blend_factor = COLOR.r;
	// 0.0 = no sand, 1.0 = sand
	sand_mix = COLOR.g;
}

void fragment() {
	// Triplanar mapping logic for better terrain texturing
	vec3 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	// Basic top-down UV for simplicity first, or triplanar if needed.
	// Since the island is mostly flat/terrain, top-down projection (xz) is usually fine
	// but triplanar is better for cliffs.
	
	// Use world position for tiling consistency.
	vec2 uv_world = p.xz * texture_scale;
	
	vec4 grass = textureLod(grass_texture, uv_world, texture_blur);
	vec4 ground = textureLod(ground_texture, uv_world, texture_blur);
	vec4 sand = textureLod(sand_texture, uv_world, texture_blur);
	
	// Mix based on vertex color
	vec4 terrain_color = mix(grass, ground, blend_factor);
	vec4 final_color = mix(terrain_color, sand, sand_mix);
	
	ALBEDO = final_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = COLOR.a; // Use the alpha we baked into the vertex color
}

