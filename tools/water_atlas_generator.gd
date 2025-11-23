@tool
extends Node

## Tool script to pack water texture frames into a single atlas.
## Place this script on a Node, run it, then delete it after generating the atlas.
## The output is saved as res://water_atlas.png

const FRAME_DIR = "res://watertextures/"
const OUTPUT_PATH = "res://water_atlas.png"
const FRAMES_PER_ROW = 4  # Adjust grid layout if needed

func _ready() -> void:
	if Engine.is_editor_hint():
		generate_atlas()

func generate_atlas() -> void:
	var frames = _load_frames()
	if frames.is_empty():
		push_error("No frames found in " + FRAME_DIR)
		return
	
	print("Loaded %d frames" % frames.size())
	
	# Calculate atlas layout
	var frame_size = frames[0].get_size()
	var cols = FRAMES_PER_ROW
	var rows = int(ceil(float(frames.size()) / float(cols)))
	var atlas_size = Vector2i(frame_size.x * cols, frame_size.y * rows)
	
	# Create the atlas
	var atlas = Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGB8)
	
	for idx in range(frames.size()):
		var col = idx % cols
		var row = idx / cols
		var pos = Vector2i(col * frame_size.x, row * frame_size.y)
		
		# Blit frame into atlas
		var frame_img = frames[idx]
		if frame_img.get_size() != frame_size:
			frame_img.resize(frame_size.x, frame_size.y)
		
		for x in range(frame_size.x):
			for y in range(frame_size.y):
				atlas.set_pixel(pos.x + x, pos.y + y, frame_img.get_pixel(x, y))
	
	# Save atlas
	atlas.save_png(OUTPUT_PATH)
	print("Atlas saved to ", OUTPUT_PATH)
	print("Atlas size: %dx%d, Frames: %d, Layout: %d cols x %d rows" % [atlas_size.x, atlas_size.y, frames.size(), cols, rows])
	
	# Save metadata as a resource
	_save_metadata(frame_size, cols, rows, frames.size())

func _load_frames() -> Array:
	var frames: Array = []
	var dir = DirAccess.open(FRAME_DIR)
	
	if dir == null:
		push_error("Could not open directory: " + FRAME_DIR)
		return frames
	
	var files = dir.get_files()
	files.sort()
	
	for file in files:
		var lower = file.to_lower()
		if lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".png") or lower.ends_with(".webp"):
			var path = FRAME_DIR + file
			var img = Image.new()
			if img.load(path) == OK:
				frames.append(img)
			else:
				push_warning("Failed to load: " + path)
	
	return frames

func _save_metadata(frame_size: Vector2i, cols: int, rows: int, frame_count: int) -> void:
	var meta_path = "res://water_atlas_meta.tres"
	var dict = {
		"frame_size": frame_size,
		"cols": cols,
		"rows": rows,
		"frame_count": frame_count
	}
	var resource = Resource.new()
	for key in dict:
		resource.set_meta(key, dict[key])
	ResourceSaver.save(resource, meta_path)
	print("Metadata saved to " + meta_path)
