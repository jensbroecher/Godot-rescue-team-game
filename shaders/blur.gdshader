shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	if (blur_amount > 0.0) {
		vec4 color = vec4(0.0);
		float weight_total = 0.0;
		
		// Simple box/gaussian approximation layout
		// Adjust radius based on blur_amount
		float radius = blur_amount * 0.002; // Scale to UV space roughly
		
		// 9-tap sample
		for(float x = -1.0; x <= 1.0; x+=1.0) {
			for(float y = -1.0; y <= 1.0; y+=1.0) {
				vec2 uv_offset = vec2(x, y) * radius;
				// Simple weighting: center is stronger
				float weight = 1.0 / (1.0 + length(vec2(x, y)));
				color += texture(screen_texture, SCREEN_UV + uv_offset) * weight;
				weight_total += weight;
			}
		}
		
		COLOR = color / weight_total;
		// DEBUG: Tint red to prove shader is active
		// COLOR.r += 0.2; 
	} else {
		COLOR = texture(screen_texture, SCREEN_UV);
	}
}
