shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;
uniform int samples = 12;

void fragment() {
    vec4 color_accum = vec4(0.0);
    vec2 center = vec2(0.5, 0.5);
    
    // Max blur angle (radians). Reduced to prevent invisibility.
    float max_angle = 0.2; 
    float current_angle_range = blur_strength * max_angle;
    
    // If blur is very low, just sample once to save performance/artifacts
    if (blur_strength < 0.01) {
        vec4 col = texture(texture_albedo, UV);
        ALBEDO = col.rgb;
        ALPHA = col.a;
    } else {
        for (int i = 0; i < samples; i++) {
            float t = float(i) / float(samples - 1);
            float angle = (t - 0.5) * current_angle_range;
            
            float s = sin(angle);
            float c = cos(angle);
            mat2 rot = mat2(vec2(c, -s), vec2(s, c));
            
            vec2 uv = UV - center;
            uv = rot * uv;
            uv += center;
            
            color_accum += texture(texture_albedo, uv);
        }
        
        vec4 final_color = color_accum / float(samples);
        ALBEDO = final_color.rgb;
        // Boost alpha slightly to counteract blurring transparency
        ALPHA = clamp(final_color.a * 1.5, 0.0, 1.0);
    }
}
