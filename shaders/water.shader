shader_type canvas_item;

// Tiled animated water shader
// Samples frames from an atlas without stretching or distortion
// Uses TIME to cycle through frames smoothly

uniform sampler2D atlas : hint_default_white;
uniform int frame_count : hint_range(1, 100) = 17;
uniform int cols : hint_range(1, 16) = 4;
uniform int rows : hint_range(1, 16) = 5;
uniform float animation_speed : hint_range(0.1, 5.0) = 1.0;
uniform int tile_scale : hint_range(1, 8) = 2;  // How many times to tile across the quad

void fragment() {
	// Get normalized frame index based on time
	float frame_idx = mod(TIME * animation_speed, float(frame_count));
	int frame = int(frame_idx);
	
	// Clamp frame to valid range
	frame = clamp(frame, 0, frame_count - 1);
	
	// Calculate row and column of this frame in the atlas
	int frame_col = frame % cols;
	int frame_row = frame / cols;
	
	// Calculate UV for sampling this frame
	// First, tile the input UV across the quad
	vec2 tiled_uv = fract(UV * vec2(tile_scale));
	
	// Then map to the frame's position in the atlas
	vec2 frame_uv = vec2(frame_col, frame_row) / vec2(cols, rows);
	vec2 frame_size = vec2(1.0 / cols, 1.0 / rows);
	
	// Sample from the atlas at the correct frame offset
	vec2 final_uv = frame_uv + tiled_uv * frame_size;
	
	COLOR = texture(atlas, final_uv);
}
