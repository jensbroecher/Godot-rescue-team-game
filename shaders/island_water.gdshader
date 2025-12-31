shader_type spatial;

render_mode blend_mix;

const float EPSILON = 1e-5;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

uniform vec3 color_shallow : source_color = vec3(0.01, 0.2, 0.3);
uniform vec3 color_deep : source_color = vec3(0.3, 0.5, 0.6);

uniform float transparency : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float transparency_tint : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float screen_mix_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float surface_alpha : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.25;

uniform float max_visible_depth : hint_range(0.1, 100.0, 0.1) = 20.0;

uniform sampler2D wave_a;
uniform sampler2D wave_b;
// Replaced directional vectors with radial parameters
uniform float wave_speed : hint_range(0.0, 5.0) = 0.5; 
uniform float wave_frequency : hint_range(0.1, 100.0, 0.1) = 20.0;
uniform float wave_amplitude : hint_range(0.0, 10.0, 0.1) = 1.0;

uniform float wave_noise_scale_a = 15.0;
uniform float wave_noise_scale_b = 15.0;
uniform float wave_height_scale = 1.0;
uniform float wave_normal_flatness : hint_range(0.1, 100.0, 0.1) = 50.0;

uniform sampler2D surface_normals_a;
uniform sampler2D surface_normals_b;
uniform float surface_texture_roughness : hint_range(0.0, 1.0, 0.01) = 0.15;
uniform float surface_texture_scale : hint_range(0.001, 2.0, 0.001) = 0.1;
uniform float surface_texture_time_scale : hint_range(0.001, 2.0, 0.001) = 0.06;

uniform float ssr_resolution   : hint_range(0.01, 10.0, 0.1)	= 1.0;
uniform float ssr_max_travel   : hint_range(0.0, 200.0, 0.1) 	= 30.0;
uniform float ssr_max_diff     : hint_range(0.1, 10.0, 0.1) 	= 4.0;
uniform float ssr_mix_strength : hint_range(0.0, 1.0, 0.01) 	= 0.7;
uniform float ssr_screen_border_fadeout: hint_range(0.0, 1.0, 0.1)	= 0.3;

uniform float refraction_intensity : hint_range(0.0, 1.0, 0.01) = 0.4; 
uniform vec3 sky_top_color : source_color = vec3(0.55, 0.75, 0.9);
uniform vec3 sky_horizon_color : source_color = vec3(0.45, 0.65, 0.85);
uniform float sky_curve : hint_range(0.0, 2.0, 0.01) = 0.3;
uniform float sky_reflect_strength : hint_range(0.0, 1.0, 0.01) = 0.4;

uniform vec3  border_color : source_color = vec3(1.0);
uniform float border_scale : hint_range(0.0, 5.0, 0.01) = 2.0;
uniform float border_near = 0.5;
uniform float border_far = 300.0;

// Edge Fading Parameters
uniform float fade_distance : hint_range(0.0, 1.0) = 0.2;
uniform float fade_smoothness : hint_range(0.0, 1.0) = 0.1;
uniform float noise_fade_scale : hint_range(0.1, 50.0) = 10.0;
uniform float noise_fade_strength : hint_range(0.0, 1.0) = 0.2;

varying vec2 vertex_uv; 
varying vec3 local_position;

// Function to convert Cartesian UV to Polar UV
vec2 cartesian_to_polar(vec2 uv) {
    vec2 centered = uv - 0.5;
    float radius = length(centered) * 2.0; // 0 at center, 1 at edge (approx)
    float angle = atan(centered.y, centered.x);
    return vec2(radius, angle);
}

float get_wave_height(vec2 uv_a, vec2 uv_b)
{
	float height1 = texture(wave_a, uv_a).y;
	float height2 = texture(wave_b, uv_b).y;
	return (height1 + height2) / 2.0;
}

vec3 get_mixed_normals(vec3 color1, vec3 color2) 
{
    vec3 normal1 = normalize(color1 * 2.0 - 1.0);
    vec3 normal2 = normalize(color2 * 2.0 - 1.0);
    vec3 up = vec3(0.0, 0.0, 1.0);
    vec3 tangent = normalize(normal1 + normal2);
    vec3 binormal = normalize(cross(up, tangent));
    vec3 mixedNormal = normalize(cross(tangent, binormal));
    return mixedNormal * 0.5;
}

void vertex()
{
	local_position = VERTEX;
    
    // UV Mapping logic
    vec2 object_scale = vec2(
        max(length(MODEL_MATRIX[0].xyz), 0.0001),
        max(length(MODEL_MATRIX[2].xyz), 0.0001)
    );
	vertex_uv = UV; 
    
    // Modify UVs based on time and radius to simulate radial movement
    // Instead of complex flow map, let's use the distance from center to offset the phase of the wave
    float dist = length(vertex_uv - 0.5);
    
    // Slower, larger waves
    float phase = dist * wave_frequency - TIME * wave_speed;
    
    float ring_wave = sin(phase) * 0.5 + 0.5;
    
    // Combine with noise for irregularity
	vec2 noise_uv_a = vertex_uv * 3.0 + vec2(TIME * 0.02); // Slower drifting noise
    float noise_val = texture(wave_a, noise_uv_a).r;
    
    // Reduce noise influence which caused "rays" if stretched
    float base_height = (ring_wave * 0.7 + noise_val * 0.3) * wave_amplitude * wave_height_scale;
    
    // Falloff wave height near edges to blend
    float edge_dampen = 1.0 - smoothstep(0.4, 0.5, dist);
    base_height *= edge_dampen; // Dampen waves at the very outer edge

    // Dampen at center to avoid spike
    float center_dampen = smoothstep(0.0, 0.05, dist);
    base_height *= center_dampen;

	float object_scale_y = max(length(MODEL_MATRIX[1].xyz), 0.0001);
	VERTEX.y += base_height / object_scale_y;
	
    // Recalculate basic normal (simplified) for the rings
    // Derivative of sin(k*r - w*t) is k*cos(k*r - w*t)
    // This gives us a radial slope.
    float wave_slope = cos(phase) * wave_frequency * 0.1; // approximate factor
    vec2 dir_to_center = normalize(0.5 - vertex_uv);
    vec3 wave_normal = normalize(vec3(dir_to_center.x * wave_slope, 1.0, dir_to_center.y * wave_slope));
    
	NORMAL = wave_normal; 
}

bool is_within_screen_boundaries(vec2 position) 
{
	return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
}

vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m)
{
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
	return position_ndc.xy * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m)
{
	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
	vec4 view_position = inv_proj_m * position_ndc;
	return view_position.xyz /= view_position.w;
}

bool is_zero(float value) 
{
    return abs(value) < EPSILON;
}

float get_screen_border_alpha(vec2 screen_position)
{
    vec2 shifted_screen_position = 4.0 * screen_position * (1.0 - screen_position);
	float mask = shifted_screen_position.x * shifted_screen_position.y; 
	float offset = mix(0.0, 0.5, (clamp(ssr_screen_border_fadeout, 0.75, 1.0)-0.75) / 0.25);
	float alpha = clamp(smoothstep(0.0, 2.0 * ssr_screen_border_fadeout, mask) - offset, 0.0, 1.0);
	return is_zero(ssr_screen_border_fadeout) ? 1.0 : alpha;
}

vec4 get_ssr_color(vec3 surface_view_position, vec3 normal_view_space, vec3 view_view_space, mat4 proj_m, mat4 inv_proj_m)
{
	if (ssr_max_travel < EPSILON)
	{
		return vec4(0);
	}
	
	vec3 current_position_view_space = surface_view_position;
	vec3 view_direction_view_space = view_view_space * -1.0;
	vec3 reflect_vector_view_space = normalize(reflect(view_direction_view_space.xyz, normal_view_space.xyz));
	
	vec2 current_screen_position = vec2(0.0);
	
	vec3 resulting_color = vec3(-1.0);
	for(float travel=0.0; resulting_color.x < 0.0 && travel < ssr_max_travel; travel = travel + ssr_resolution)
	{
		current_position_view_space += reflect_vector_view_space * ssr_resolution;
		current_screen_position = get_uv_from_view_position(current_position_view_space, proj_m);

		if (!is_within_screen_boundaries(current_screen_position)) {
			break;
		}

		float depth_texture_probe_raw = texture(DEPTH_TEXTURE, current_screen_position).x;
		vec3 depth_texture_probe_view_position = get_view_position_from_uv(current_screen_position, depth_texture_probe_raw, inv_proj_m);
		
		float depth_diff = depth_texture_probe_view_position.z - current_position_view_space.z;
		
		if (depth_diff >= 0.0 && depth_diff < ssr_max_diff) {
			resulting_color = texture(SCREEN_TEXTURE, current_screen_position.xy).rgb;
			break;
		}
	}

	float alpha = get_screen_border_alpha(current_screen_position);
	return vec4(resulting_color,alpha);
}

float linear_depth(float cur_depth)
{
    return border_far * border_near / (border_near + cur_depth * (border_far - border_near));
}

float normalize_float(float min_v, float max_v, float value) 
{
	float clamped_value = clamp(value, min_v, max_v);
	return  (clamped_value - min_v) / (max_v - min_v);
}

vec2 get_refracted_uv(vec2 raw_screen_uv, float screen_depth_raw, vec3 view, vec3 normal, mat4 proj_m, mat4 inv_proj_m)
{
		vec3 screen_view_position_original = get_view_position_from_uv(raw_screen_uv, screen_depth_raw, inv_proj_m);
		float screen_center_distance = clamp(abs(length(raw_screen_uv - vec2(0.5, 0.5))) * 2.0, 0.0, 1.0);
		float refraction_intensity_deglitched = mix(1.0 - refraction_intensity, 1.0, screen_center_distance);
		vec3 refraction_position_view_space = screen_view_position_original + normalize(refract(view, -normal, refraction_intensity_deglitched));
		vec2 refraction_uv = get_uv_from_view_position(refraction_position_view_space, proj_m);
		return refraction_uv;
}

void fragment() 
{
    vec3 normal = NORMAL;
	
	float screen_depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	
	vec2 refraction_uv = refraction_intensity > 0.0 ? get_refracted_uv(SCREEN_UV, screen_depth_raw, VIEW, normal, PROJECTION_MATRIX, INV_PROJECTION_MATRIX) : SCREEN_UV;
	
	float screen_depth = texture(DEPTH_TEXTURE, refraction_uv).x;
	float surface_depth = FRAGCOORD.z;
	
	float border_diff = linear_depth(screen_depth_raw) - linear_depth(surface_depth);
	
    // Radial movement for surface texture/normals
    vec2 centered_uv = vertex_uv - 0.5;
    float dist = length(centered_uv);
    vec2 direction_to_center = normalize(-centered_uv);
    
    // Instead of stretching UVs which causes rays, let's just scroll two texture layers
    // towards the center at different speeds/scales
    
    vec2 offset = direction_to_center * TIME * wave_speed * 0.05; // much slower
    
	vec3 normal_texture_blend 	= get_mixed_normals(
        texture(surface_normals_a, vertex_uv * surface_texture_scale + offset).xyz, 
        texture(surface_normals_b, vertex_uv * surface_texture_scale * 1.5 + offset * 1.2).xyz
    );
	vec3 normal_blend 			= mix(normal, normal_texture_blend, surface_texture_roughness);

	
	vec3 screen_view_position 	= get_view_position_from_uv(refraction_uv, screen_depth, INV_PROJECTION_MATRIX);
	vec3 surface_view_position 	= get_view_position_from_uv(SCREEN_UV, surface_depth, INV_PROJECTION_MATRIX);
	// Boost depth visibility to make water more opaque
	float depth_visibility 		= 1.0 - normalize_float(0.0, max_visible_depth, length(surface_view_position - screen_view_position));
    depth_visibility = pow(depth_visibility, 0.5); // Curve it to be more opaque sooner
	
    vec3 screen_color 				= texture(SCREEN_TEXTURE, refraction_uv).rgb;
    vec3 tinted_screen              = mix(screen_color, color_shallow, transparency_tint);
    
    vec4 ssr_color 					= get_ssr_color(surface_view_position, normal, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
    
    vec3 surface_color_transparency	= mix(color_shallow, tinted_screen, transparency * screen_mix_strength);
    
    // Ensure we really mix to deep color when depth is high
    vec3 surface_depth_color_mix 	= mix(color_deep, surface_color_transparency, depth_visibility);
    
    vec3 surface_color_ssr_mix		= (ssr_max_travel > EPSILON) ? mix(surface_depth_color_mix, ssr_color.rgb, ssr_mix_strength * ssr_color.a) : vec3(0);
    vec3 water_color 				= (ssr_color.x >= 0.0) ? surface_color_ssr_mix : surface_depth_color_mix;

    vec3 view_dir = normalize(VIEW * -1.0);
    float fresnel = pow(1.0 - clamp(dot(view_dir, normalize(normal)), 0.0, 1.0), 3.0);
    vec3 refl = normalize(reflect(view_dir, normalize(normal)));
    float sky_t = clamp(refl.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 sky_grad = mix(sky_horizon_color, sky_top_color, pow(sky_t, sky_curve));
    water_color = mix(water_color, sky_grad, sky_reflect_strength * fresnel);
	vec3 final_color				= mix(border_color, water_color, step(border_scale, border_diff));
	
	ALBEDO.rgb = final_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL = normal_blend;
	
	// ORGANIC EDGE FADING
    float uv_dist = distance(vertex_uv, vec2(0.5));
    float edge_noise = texture(wave_a, vertex_uv * noise_fade_scale).r * noise_fade_strength;
    float fade_boundary = 0.5 - edge_noise;
    float fade = 1.0 - smoothstep(fade_boundary - fade_distance, fade_boundary, uv_dist);
    
    // Use opaque mode logic where possible
    // We boost alpha to make it harder to see through
    ALPHA = clamp(surface_alpha + 0.5, 0.0, 1.0) * fade; 
}
