shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 cloud_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float cloud_density : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D noise_texture;
uniform vec2 noise_tiling = vec2(1.0);
uniform vec2 wind_speed = vec2(0.1, 0.0);
uniform float cloud_height_offset = 0.0;
uniform float softness : hint_range(0.0, 1.0) = 0.1;
uniform float fade_distance : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    vec2 uv = UV * noise_tiling + wind_speed * TIME;
    float noise = texture(noise_texture, uv).r;
    
    // Simple thresholding for clouds
    float alpha = smoothstep(cloud_density - softness, cloud_density + softness, noise);
    
    // Fade edges
    float dist_from_center = distance(UV, vec2(0.5));
    float fade = 1.0 - smoothstep(0.5 - fade_distance, 0.5, dist_from_center);
    alpha *= fade;
    
    ALBEDO = cloud_color.rgb;
    ALPHA = alpha * cloud_color.a;
}
