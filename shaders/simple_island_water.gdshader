shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

// Colors
uniform vec3 water_color : source_color = vec3(0.0, 0.4, 0.8);
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0);

// Shape
uniform float radius = 0.45;     // 0.5 is full UV width
uniform float fade_width = 0.05; // Softness of the outer edge

// Waves
uniform float wave_speed = 1.0;
uniform float wave_frequency = 20.0;
uniform float wave_amplitude = 0.2; // Height displacement
uniform float foam_width = 0.05; // Width of the "foam" at wave peaks

// Noise
uniform sampler2D noise_texture; // Input noise for distortion
uniform float noise_scale = 10.0;
uniform float wave_distortion = 0.1; // How much noise distorts the wave shape
uniform float surface_detail_strength : hint_range(0.0, 1.0) = 0.5;

// Depth
uniform float depth_fade_distance : hint_range(0.0, 10.0) = 1.0;
uniform float depth_opacity : hint_range(0.0, 1.0) = 0.95; // Base opacity of deep water

// Texture helper
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void vertex() {
	// Radial Waves Displacement
	vec2 center = vec2(0.5, 0.5);
    
    // Sample texture for vertex noise
    float v_noise = texture(noise_texture, UV * 2.0 + vec2(TIME * 0.05)).r;
    
    // Distort UVs slightly for the distance calculation to break the perfect circle rings
    vec2 distorted_uv = UV + (vec2(v_noise) - 0.5) * wave_distortion;
    
	float dist = distance(distorted_uv, center);
	
	float wave_phase = dist * wave_frequency + TIME * wave_speed;
    
    // Add extra phase noise
    wave_phase += v_noise * 3.0; 
    
	float displacement = sin(wave_phase) * wave_amplitude;
    
    // Dampen waves at the center and very edge
    float dampening = smoothstep(0.0, 0.1, dist) * (1.0 - smoothstep(radius, radius + 0.1, dist));
    
	VERTEX.y += displacement * dampening;
    
    // Calculate Normal (Approximation with noise)
    // We want a rolling slope + noise bumpiness
    float slope = cos(wave_phase) * wave_frequency * wave_amplitude * dampening;
    vec2 dir = normalize(UV - center);
    
    // Mix in noise normal
    vec3 wave_normal = normalize(vec3(-dir.x * slope, 1.0, -dir.y * slope));
    
    // We will refine normals in fragment shader
    NORMAL = wave_normal;
}

void fragment() {
	// 1. Radial Transparency (The "Round Island" Look)
	vec2 center = vec2(0.5, 0.5);
    
    // Edge noise for the shape itself
    vec2 noise_uv_edge = UV * 5.0 + vec2(TIME * 0.01);
    float edge_noise_val = texture(noise_texture, noise_uv_edge).r;
    float dist_distorted = distance(UV, center) + (edge_noise_val - 0.5) * 0.05; // Wobbly edge
    
	float alpha_shape = 1.0 - smoothstep(radius, radius + fade_width, dist_distorted);
	
    // 2. Sample Noise for Surface Detail
    vec2 noise_uv = UV * noise_scale + vec2(TIME * 0.05); // Drifting noise
    vec2 noise_uv2 = UV * (noise_scale * 1.5) - vec2(TIME * 0.03); // Counter-drift
    
    float n1 = texture(noise_texture, noise_uv).r;
    float n2 = texture(noise_texture, noise_uv2).r;
    float surface_noise = (n1 + n2) * 0.5;
    
	// 3. Wave Foam Pattern
    // Use the same phase logic as vertex but with texture noise added
	float wave_phase = dist_distorted * wave_frequency + TIME * wave_speed;
    wave_phase += surface_noise * 4.0; // Distort the foam lines heavily
    
	// Foam appears at peaks (sin close to 1)
	float wave_height = sin(wave_phase);
	float foam_mask = smoothstep(1.0 - foam_width, 1.0, wave_height);
    
    // Add "broken" look to foam
    foam_mask *= smoothstep(0.4, 0.6, surface_noise); // Only show foam where noise is mid-high
    foam_mask *= smoothstep(0.0, 0.1, dist_distorted); // No foam at exact center
	
	// 4. Surface Normals (Ripples)
    // Convert noise to normal map style
    // Simple dFdx/dFdy style normal generation from height map (noise)
    float h = surface_noise * surface_detail_strength;
    /* 
       To do this properly without dFdx/dFdy (which can be blocky), 
       we'd sample 3 times. But for styling, built-in NORMAL_MAP usually works better 
       if we had one. Here we assume just a noise texture.
       Let's stick to modifying NORMAL based on view-space derivatives or just use the noise as roughness/specular mix.
    */
    
    // Perturb existing NORMAL
    vec3 view_normal = NORMAL; // Vertex normal
    // Add noise frequency
    view_normal.x += (n1 - 0.5) * surface_detail_strength;
    view_normal.z += (n2 - 0.5) * surface_detail_strength;
    view_normal = normalize(view_normal);
    NORMAL = view_normal;

	// 5. Depth Fog (Hiding the ground)
    float depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float linear_depth = -view.z;
    float vertex_depth = VERTEX.z; // View space Z
    float depth_diff = linear_depth - (-vertex_depth); 
    
    float depth_alpha = clamp(depth_diff / depth_fade_distance, 0.0, 1.0);
    
    // 6. Color Mixing
    // Base color varying slightly with noise
    vec3 organic_water = mix(water_color, water_color * 0.8, surface_noise * 0.2); 
    vec3 final_color = mix(organic_water, foam_color, foam_mask * 0.8); // Foam is mostly additive/white
	
	ALBEDO = final_color;
	
    // Metallic/Roughness for shiny water
	METALLIC = 0.1;
	ROUGHNESS = 0.2 + (1.0 - surface_noise) * 0.2; // Varied roughness
    
    // Specular highlights will look better with the perturbed normal
	
	// Combine alphas
	// Force opacity higher on main body, fade edges
	ALPHA = clamp(alpha_shape * (depth_alpha + 0.3), 0.0, 1.0);
}
